require 'vacuum' # amazon
require 'rspotify' #spotify
require 'uri'
require 'open-uri'
require 'pp'
require_relative 'requests'


# Accept and remember DFM all request show requests
class Cinch::Requestline
  include Cinch::Plugin

  set :help, <<-EOF
dj request http:... - Request a song by URL (Currently supported: Amazon, Spotify)
dj request title:<title> artist:<artist> (album:<album>) - request a song by name
dj list requests - list your current requests
dj drop request <N> - forget request number <N> (see list requests to get <N>)
dj set title <N> <title> - change the title of request <N>
dj set artist <N> <artist> - change the artist of request <N>
dj set album <N> <album> - add/change the album of request <N>
dj add remarks <N> <remarks> - add/change remarks (year, etc) to request number <N>
  EOF

  # A single user cannot have more than max_requests
  @max_requests = 5

  set :prefix, /^dj\s+/

  listen_to :connect,                               :method => :on_connect
  match /request (http.*)\s*$/,                     :method => :add_request_by_url
  match /request (title:.*)$/,                      :method => :add_request_by_name
  match /list requests\s*$/,                        :method => :list_requests
  match /drop request\s+(\d)\s*$/,                  :method => :drop_request
  match /set (title|artist|album)\s+(\d)\s+(.*)/,   :method => :set_song_param
  match /set (remarks|url)\s+(\d)\s+(.*)/,          :method => :set_song_param
  match /email requests\s*$/,                       :method => :email_requests
  # match isn't functioning ... we need to match on 'help' and only 'help'
  # match /^dj\s+help\s*$/,         :method => :help, :prefix => nil

  def initialize(*args)
    super
    @requests = Requests.new
    @admins = ['demonsheep']
    @amazon = Vacuum.new

  end

  def on_connect(*)
    @amazon.configure(
        aws_access_key_id: config[:aws_access_key_id],
        aws_secret_access_key: config[:aws_secret_access_key],
        associate_tag: 'tag'
    )
  end

  def help(msg)
    msg.reply 'Help:'
    msg.reply(:help)
  end

  # Allow a user to create a new request by giving a url
  def add_request_by_url(msg, url)

    # attempt to resolve the url to a product
    case URI(url).host
      when /amazon.com$/
        song = process_amazon_url(url)
      when /spotify.com$/
        song = process_spotify_url(url)
      # TODO support rhapsody
      # when /rhapsody.com$/
      #   song = process_rhapsody_url(url)
      # TODO support youtube
      # download the mp3 audio using youtube-dl
      # this will also mean that we'll need the user to supply the
      # song information, and we'll set the ID3 tags.
      # when /youtube.com$/
      else
        # TODO support cloud storage
        # this one will be harder and will
        # require us to download the mp3 file
        error("Unable to process URL for #{URI(url).host}")
        return
    end

    unless song.nil?
      @requests.add(msg.user.nick, song)
      msg.reply('Added request: ' + song.to_s)
    else
      msg.reply("Couldn't process your request.")
    end

  end

  def add_request_by_name(msg,subject)

    song = SongStruct.new()
    tokens = subject.split(/(title|album|artist):\s*/)

    valid_tokens = %w(title artist album)

    tokens.each_with_index do |token, index|

      if (index + 1) == tokens.size
        break # past the end
      end

      if valid_tokens.include? token
        song[token.to_sym] = tokens[index+1].strip
      end
    end

    if song[:title] == nil || song[:artist] == nil
      msg.reply('You must supply at least title and artist')
    else
      @requests.add(msg.user.nick, song)
      msg.reply("Added request #{@requests.count}: #{song.to_s}")
    end
  end

  def set_song_param(msg, key, id, val)

    # TODO handle modifying the URL separately
    # The URL should only be settable if it isn't
    # already set -
    # ie, we don't want the user to supply an amazon URL
    # which we then use to populate the track information, only to
    # have the URL changed on us.

    song = @requests.get(msg.user.nick, id)

    if song.nil?
      msg.reply("Can't find song ##{id} for #{msg.user.nick}")
      return
    end
    song[key.downcase.to_sym] = val.strip

    @requests.update(msg.user.nick,id,song)

    msg.reply("Updated #{key} for request ##{id}")
  end

  # Allow a user to drop one of their requests
  # They must specify the sequence id #
  def drop_request(msg, id)

    song = @requests.get(msg.user.nick, id)

    if song.nil?
      msg.reply "Can't find song ##{id} for #{msg.user.nick}"
      return
    end

    # save the title and artist for our reply message
    # before calling for the request to be deleted
    deleted_title = song[:title]
    deleted_artist = song[:artist]

    @requests.remove(msg.user.nick, id)
    msg.reply("Dropped request ##{id}, #{deleted_title} by #{deleted_artist}")
  end

  # Tell the user what songs they've requested for this week
  # Each request should have a prefix sequence id # to allow
  # them to drop a request from the list
  def list_requests(msg)
    request_list = @requests.list(msg.user.nick)

    if request_list.count == 0
      msg.reply('You have no requests.')
      return
    end

    request_list.each_with_index do |song, index|
      msg.reply("##{index}) #{song.to_s}")
    end
  end

  # Tell the user how many requests they have
  def count_requests(msg)

    count = @requests[msg.user.nick].count
    case count
      when 0
        msg.reply('You have no requests.')
      when 1
        msg.reply("You have #{count} request.")
      else
        msg.reply("You have #{count} requests.")
    end

  end

  # Compose an email to DP listing all the requests
  def email_requests(msg)
    # only allow admins to complete this command
    unless is_admin?(msg.user)
      msg.reply("You're not an admin!")
      return
    end
  end

  # @param [String] url URL to an mp3 file
  # @return [SongStruct] populated if request is valid
  #   nil otherwise
  # TODO
  # will require us to download the mp3 file
  # and analyze the id3 data
  def process_cloudstorage_url(url)

  end

  # TODO move the special URL handlers to their own class
  # TODO add some rescue handling to these remote calls
  # @param [String] url Amazon URL of the specific song
  #
  # @return [SongStruct] populated if request is valid
  #   nil otherwise
  def process_amazon_url(url)

    itemid = URI(url).path.split('/')[2]

    response = @amazon.item_lookup(
        query: {
            'ItemId' => itemid,
            'ResponseGroup' => %w(RelatedItems Small).join(','),
            'RelationshipType' => 'Tracks'
        }
    )

    resp_hash = response.to_h

    if resp_hash['ItemLookupResponse']['Items']['Request']['Errors']
      error(resp_hash['ItemLookupResponse']['Items']['Request']['Errors']['Error']['Message'])
      return nil
    end

    item = resp_hash['ItemLookupResponse']['Items']['Item']
    song = SongStruct.new()
    song.title = item['ItemAttributes']['Title']
    song.artist = item['ItemAttributes']['Creator']['__content__']
    song.album = item['RelatedItems']['RelatedItem']['Item']['ItemAttributes']['Title']
    song.url = item['DetailPageURL']

    return song

  end

  # @param [String] url Spotify URL of the specific song
  #
  # @return [SongStruct] populated if request is valid
  #   nil otherwise
  def process_spotify_url(url)
    # https://play.spotify.com/track/68y4C6DGkdX0C9DjRbKB2g
    itemid = URI(url).path.split('/')[2]

    track = RSpotify::Track.find(itemid)

    pp track

    song = SongStruct.new()
    song.artist = track.artists[0].name
    song.title = track.name
    song.album = track.album.name
    song.url = url

    return song

  end

  # TODO Handle Rhapsody URLs
  # @param [String] url Rhapsody URL of the specific song
  #
  # @return [SongStruct] populated if request is valid
  #   nil otherwise
  def process_rhapsody_url(url)

  end

  # @param [User] user The user to check for admin status
  # @return [Boolean] true if user is admin, false otherwise
  def is_admin?(user)
    user.refresh # be sure to refresh the data, or someone could steal
    # the nick
    @admins.include?(user.authname)
  end

end