require 'uri'
require 'open-uri'
require 'pp'
require_relative 'lib/dj/requests'

# Accept and remember DFM all request show requests
class Cinch::Plugins::DJ
  include Cinch::Plugin

  set :prefix, /^dj\s+/

  listen_to :connect,                               :method => :on_connect
  match /request (http.*)\s*$/,                     :method => :add_request_by_url
  match /request (title:.*)$/,                      :method => :add_request_by_name
  match /request (artist:.*)$/,                     :method => :add_request_by_name
  match /list requests\s*$/,                        :method => :list_requests
  match /count requests\s*$/,                       :method => :count_requests
  match /drop request\s+(\d)\s*$/,                  :method => :drop_request
  match /clear requests\s*$/,                       :method => :clear_requests
  match /clear requests for (.*)\s*$/,              :method => :clear_requests
  match /set (title|artist|album)\s+(\d)\s+(.*)/,   :method => :set_song_param
  match /set (remarks|url)\s+(\d)\s+(.*)/,          :method => :set_song_param
  match /email requests\s*$/,                       :method => :email_requests
  match /help\s*$/,                                 :method => :show_help
  match /help urls\s*/,                             :method => :help_urls

  def initialize(*args)
    super
    @requests = Requests.new
    # TODO: SET THIS TO something reasonable BEFORE PRODUCTION
    # TODO: make this dynamically settable at runtime
    @admins = %w(demonsheep)
    # A single user cannot have more than max_requests
    @max_requests = config[:max_requests]
  end

  def on_connect(*)

  end

  def show_help(msg)
    help_content = <<-EOF
dj request <http://...> - Request a song by URL (Currently supported: Amazon, Spotify)
dj request title:<title> artist:<artist> (album:<album>) - request a song by name
dj set title <N> <title> - change the title of request <N>
dj set artist <N> <artist> - change the artist of request <N>
dj set album <N> <album> - add/change the album of request <N>
dj set remarks <N> <remarks> - add/change remarks (year, etc) of request <N>
dj list requests - list your current requests
dj drop request <N> - forget request number <N>
dj clear - forget all of your requests
dj help urls - Show the URL types I can process into songs
EOF
    _private_reply(msg, help_content)
  end

  def help_urls(msg)
    help_content = <<-EOF
The following URLs/sites are supported:
* Amazon  - example URL: http://www.amazon.com/dp/B00Q804ADY
* Spotify - example URL: http://play.spotify.com/track/68y4C6DGkdX0C9DjRbKB2g
* Spotify playlist - example URL: https://open.spotify.com/user/demonsheep/playlist/abc13sdy3ddd6hg
EOF
    _private_reply(msg, help_content)
  end

  # Allow a user to create a new request by giving a url
  def add_request_by_url(msg, url)

    song = nil

    unless _request_allowed(msg.user.nick, :add).nil?
      _address_reply(msg, _request_allowed(msg.user.nick, :add))
      return
    end

    unless url =~ URI::regexp
      _address_reply(msg, 'Invalid URL')
      return
    end

    # attempt to resolve the url to a product
    begin
      case URI(url).host
        when /amazon.com$/
          song = AmazonSong.new({'url' => url, 'is_new' => true})
          song.auth(config[:aws_access_key_id], config[:aws_secret_access_key])
          # wrap song.process in a thread?
          # that should allow us to watch/notify the user when we're done
          # delays may come from outgoing calls, unavailable services, etc
          #
          # We can allow multiple waiting requests per user - ie multiple youtube URLs
          # but we'll have to be careful not to allow the user to somehow exceed their limit
          # This will primarily manifest itself when processing multi-song requests, such as a
          # playlist.
          #
          # We need to handle a timeout from a request, and handle a user canceling/dropping the
          # request before it finished processing.
          song_id = _add_request(msg, song)
          song.process
          # TODO: post-process
          # a post-process action needs to happen here that looks at the song's
          # progress attribute to determine if the song should be kept (:complete)
          # or removed (:failed, :canceled) and to notify the user of the result
          # TODO: figure out some way to handle incomplete requests
          # when we're starting back up - because we've already committed the request
          # to disk

          @requests.update(msg.user.nick, song_id, song)

        when /spotify.com$/
          query_type = URI(url).path.split('/')[-2]

          case query_type
            when 'track'
              song = SpotifySong.new({'url' => url, 'is_new' => true})
              song_id = _add_request(msg, song)
              song.auth(config[:spotify_client_id], config[:spotify_client_secret])
              song.process
              @requests.update(msg.user.nick, song_id, song)
            when 'playlist'
              playlist = SpotifyPlaylist.new({'url' => url, 'is_new' => true})
              playlist.auth(config[:spotify_client_id], config[:spotify_client_secret])
              songs = playlist.process
          end
        when /youtube.com$/
          # youtube = YoutubeSong.new(config, url)
          # songs = youtube.process
          # this will require special handling where the user will need to
          # supply the title/artist of the song so that we can write it into the ID3
          # data
        else
          # TODO support cloud storage
          # this one will be harder and will
          # require us to download the mp3 file
          # TODO make this count against the max_requests
          # so that a user can't send the same download request
          # a bunch of times.
          _address_reply(msg, "Don't know how to process URLs for #{URI(url).host}")
          return
      end
    rescue Exception => e
      _address_reply(msg, "Encountered a problem - #{e.message}")
      puts e.message
      puts e.backtrace
      return
    end

    # _add_request(msg, song) unless song.nil?
    _add_requests(msg, songs) unless songs.nil?

  end

  def add_request_by_name(msg, subject)

    song = Song.new
    tokens = subject.split(/(title|album|artist|remarks):\s*/)

    valid_tokens = %w(title artist album remarks)

    tokens.each_with_index do |token, index|
      break if (index + 1) == tokens.size

      if valid_tokens.include? token
        song.set_element(token, tokens[index+1].strip)
      end
    end

    if song.title.nil? || song.artist.nil?
      _address_reply(msg, 'You must supply at least title and artist')
    else

      _add_request(msg, song)
    end
  end

  # Add a single song to the request user's request list
  # @param [Cinch::Message] msg
  # @param [Song] song
  def _add_request(msg, song)

    unless _request_allowed(msg.user.nick, :add).nil?
      _address_reply(msg, _request_allowed(msg.user.nick, :add))
      return
    end

    song_id = nil
    synchronize(:request_sync) do
      song_id = @requests.add(msg.user.nick, song)
    end

    _address_reply(msg, "Added request: ##{song_id}: #{song.to_s}")

    return song_id
  end

  # Add multiple songs at once, ie from a playlist
  # @param [Cinch::Message] msg
  # @param [Array] songs
  def _add_requests(msg, songs)

    unless _request_allowed(msg.user.nick, :add).nil?
      _address_reply(msg, _request_allowed(msg.user.nick, :add))
      return
    end

    if @requests.count(msg.user.nick) + songs.size > @max_requests
      _address_reply(msg, "#{songs.size} new requests would exceed your request limit of #{@max_requests} songs.")
      return
    end

    songs.each { |song| _add_request(msg, song) }

  end

  # @param [Cinch::Message] msg
  # @param [String] key
  # @param [Integer] id
  # @param [String] val
  def set_song_param(msg, key, id, val)

    unless _request_allowed(msg.user.nick, :modify).nil?
      _address_reply(msg, _request_allowed(msg.user.nick, :modify))
      return
    end

    # TODO handle modifying the URL separately
    # The URL should only be settable if it isn't
    # already set -
    # ie, we don't want the user to supply an amazon URL
    # which we then use to populate the track information, only to
    # have the URL changed on us.

    song = @requests.get(msg.user.nick, id)

    if song.nil?
      _address_reply(msg, "Can't find song ##{id} for #{msg.user.nick}")
      return
    end

    song.set_element(key, val.strip)
    synchronize(:request_sync) do
      @requests.update(msg.user.nick, id, song)
    end

    _address_reply(msg, "Updated #{key} for request ##{id}")
  end

  # Allow a user to drop one of their requests
  # They must specify the sequence id #
  def drop_request(msg, id)

    unless _request_allowed(msg.user.nick, :delete).nil?
      _address_reply(msg, _request_allowed(msg.user.nick, :delete))
      return
    end

    song = @requests.get(msg.user.nick, id)

    if song.nil?
      _address_reply(msg, "Can't find request ##{id}")
      return
    end

    # save the title and artist for our reply message
    # before calling for the request to be deleted

    deleted_title = song.title
    deleted_artist = song.artist

    synchronize(:request_sync) do
      @requests.remove(msg.user.nick, id)
    end

    _address_reply(msg, "Dropped request ##{id}, #{deleted_title} by #{deleted_artist}")
  end

  def clear_requests(msg, subject='')

    unless _request_allowed(msg.user.nick, :delete).nil?
      _address_reply(msg, _request_allowed(msg.user.nick, :delete))
      return
    end

    subject.strip!

    unless subject.empty? || is_admin?(msg.user)
      _private_reply(msg, 'Only admins may clear requests for other users')
      return
    end

    target = subject.empty? ? msg.user.nick : subject

    synchronize(:request_sync) do
      @requests.remove_all(msg.user.nick)
    end

    (target == msg.user.nick) ?
        _address_reply(msg, 'your requests have been cleared.')
        : msg.reply("Requests for #{target} cleared.")

  end

  # Tell the user what songs they've requested for this week
  # Each request should have a prefix sequence id # to allow
  # them to drop a request from the list
  def list_requests(msg)
    request_list = @requests.list(msg.user.nick)

    count_requests(msg)

    return if request_list.count == 0

    request_list.each_with_index do |song, idx|
      _address_reply(msg, "##{idx+1}) #{song.to_s}")
    end
  end

  # Tell the user how many requests they have
  def count_requests(msg)

    count = @requests.count(msg.user.nick)
    case count
      when 0
        _address_reply(msg, "You have no requests for the #{next_show_date} show")
      when 1
        _address_reply(msg, "You have #{count} request for the show that airs #{next_show_date}")
      else
        _address_reply(msg, "You have #{count} requests for the show that airs #{next_show_date}")
    end

  end

  def next_show_date
    "#{@requests.show_date.month}/#{@requests.show_date.mday}"
  end

  # Compose an email to DP listing all the requests
  def email_requests(msg)
    # only allow admins to complete this command
    unless is_admin?(msg.user)
      _address_reply(msg, "You're not an admin!")
    end
  end

  # @param [User] user The user to check for admin status
  # @return [Boolean] true if user is admin, false otherwise
  def is_admin?(user)
    user.refresh # be sure to refresh the data, or someone could steal
    # the nick
    # TODO: SET THIS TO user.authname BEFORE PRODUCTION
    # without nickserv, there is no authname
    @admins.include?(user.nick.downcase)
  end

  def _request_allowed(nick, action)

    # Deadline should always be the first reason
    if @requests.past_deadline?
      return 'The request line for this week is closed.'
    end

    if action == :add && @requests.count(nick) >= @max_requests
      return "A maximum of #{@max_requests} requests are allowed, you have #{@requests.count(nick)}."
    end

    nil

  end

  def _private_reply(msg, text)
    User(msg.user.nick).send(text)
  end

  def _address_reply(msg, text)
    prefix = msg.channel ? "#{msg.user.nick}: " : nil
    msg.reply("#{prefix}#{text}")
  end

end

