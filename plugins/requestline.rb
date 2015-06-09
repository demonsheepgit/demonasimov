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

  listen_to :connect,             :method => :on_connect
  match /request (http.*)\s*$/,   :method => :add_request_byurl
  match /request (title:.*)$/,    :method => :add_request_byname
  match /list requests\s*$/,      :method => :list_requests
  match /drop request (\d)\s*$/,  :method => :drop_request
  match /set title (\d) (.*)/,    :method => :set_title
  match /set artist (\d) (.*)/,   :method => :set_artist
  match /set album (\d) (.*)/,    :method => :set_album
  match /add remarks (\d) (.*)/,  :method => :set_remarks
  match /email requests\s*$/,     :method => :email_requests
  # match isn't functioning ... we need to match on 'help' and only 'help'
  # match /^dj\s+help\s*$/,         :method => :help, :prefix => nil

  def initialize(*args)
    super
    @requests = {}
    @admins = ['demonsheep']
    @amazon = Vacuum.new

    @reqs = Requests.new
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
  def add_request_byurl(msg, url)
    init_requests(msg.user)

    # attempt to resolve the url to a product
    case URI(url).host
      when /amazon.com$/
        song = process_amazon_url(url)
      when /spotify.com$/
        song = process_spotify_url(url)
      # TODO support rhapsody
      # when /rhapsody.com$/
      #   song = process_rhapsody_url(url)
      else
        # TODO support cloud storage
        # this one will be harder and will
        # require us to download the mp3 file
        error("Unable to process URL for #{URI(url).host}")
        return
    end

    unless song.nil?
      @reqs.add(msg.user.nick, song)
      @requests[msg.user.nick] << song
      msg.reply('Added request: ' + song.to_s)
    else
      msg.reply("Couldn't process your request.")
    end

  end

  def add_request_byname(msg,subject)
    init_requests(msg.user)

    song = SongStruct.new()
    tokens = subject.split(/(title|album|artist):\s*/)

    tokens.each_with_index do |token, index|
      if (index + 1) == tokens.size
        break
      end

      case token
        when 'title'
          song[:title] = tokens[index+1].strip
        when 'artist'
          song[:artist] = tokens[index+1].strip
        when 'album'
          song[:album] = tokens[index+1].strip
      end
    end

    if song[:title] == nil || song[:artist] == nil
      msg.reply('You must supply at least title and artist')
    else
      @reqs.add(msg.user.nick, song)
      @requests[msg.user.nick] << song
      msg.reply("Added request #{@requests[msg.user.nick].count}: #{song.to_s}")
    end

  end

  def set_title(msg, id, title)
    set_song_param(msg, id, :title, title)
  end

  def set_artist(msg, id, artist)
    set_song_param(msg, id, :artist, artist)
  end

  def set_album(msg, id, album)
    set_song_param(msg, id, :album, album)
  end

  def set_remarks(msg, id, remarks)
    set_song_param(msg, id, :remarks, remarks)
  end

  def set_song_param(msg, id, key, val)
    init_requests(msg.user)
    if @requests[msg.user.nick][id.to_i].nil?
      msg.reply("Can't find song ##{id}")
      return
    end
    @requests[msg.user.nick][id.to_i][key] = val.strip
  end

  # Allow a user to drop one of their requests
  # They must specify the sequence id #
  def drop_request(msg, id)
    init_requests(msg.user)

    if @requests[msg.user.nick][id.to_i].nil?
      msg.reply "Can't find song ##{id}"
      return
    end

    song = @requests[msg.user.nick][id.to_i]
    @requests[msg.user.nick].delete_at(id.to_i)
    @reqs.remove(msg.user.nick, id)
    msg.reply("Dropped ##{id}, #{song[:title]} by #{song[:artist]}")
  end

  # Tell the user what songs they've requested for this week
  # Each request should have a prefix sequence id # to allow
  # them to drop a request from the list
  def list_requests(msg)
    init_requests(msg.user)

    count_requests(msg)
    @requests[msg.user.nick].each_with_index do |song, index|
      msg.reply("##{index}) #{song.to_s}")
    end

    puts @reqs.list(msg.user.nick)

  end

  # Tell the user how many requests they have
  def count_requests(msg)
    init_requests(msg.user)
    count = @requests[msg.user.nick].count
    case count
      when 0
        msg.reply('You have no requests.')
      when 1
        msg.reply("You have #{count} request.")
      else
        msg.reply("You have #{count} requests.")
    end

    puts "#{msg.user.nick} count #{@reqs.count(msg.user.nick)}"

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

  # @param [String] url Amazon URL of the specific song
  #
  # @return [SongStruct] populated if request is valid
  #   nil otherwise
  def process_amazon_url(url)

    itemid = URI(url).path.split('/')[2]

    response = @amazon.item_lookup(
        query: { 'ItemId' => itemid }
    )

    resp_hash = response.to_h

    if resp_hash['ItemLookupResponse']['Items']['Request']['Errors']
      error(resp_hash['ItemLookupResponse']['Items']['Request']['Errors']['Error']['Message'])
      return nil
    end

    item = resp_hash['ItemLookupResponse']['Items']['Item']
    song = SongStruct.new()
    song.title = item['ItemAttributes']['Title']
    song.artist = item['ItemAttributes']['Manufacturer']
    song.url = item['DetailPageURL']

    return song

  end

  # @param [String] url Spotify URL of the specific song
  #
  # @return [SongStruct] populated if request is valid
  #   nil otherwise
  # TODO
  def process_spotify_url(url)
    # https://play.spotify.com/track/68y4C6DGkdX0C9DjRbKB2g
    itemid = URI(url).path.split('/')[2]

    track = RSpotify::Track.find(itemid)
    song = SongStruct.new()
    song.artist = track.artists[0].name
    song.title = track.name
    song.url = url

    return song

  end

  # TODO
  # @param [String] url Rhapsody URL of the specific song
  #
  # @return [SongStruct] populated if request is valid
  #   nil otherwise
  def process_rhapsody_url(url)

  end

  # init the @requests hash for a user
  # @return [void]
  # TODO - make this happen for each user on_connect
  # TODO - watch the join to make this happen for each new user
  def init_requests(user)
    @requests[user.nick] = [] if @requests[user.nick].nil?
  end

  # @param [User] user The user to check for admin status
  # @return [Boolean] true if user is admin, false otherwise
  def is_admin?(user)
    user.refresh # be sure to refresh the data, or someone could steal
    # the nick
    @admins.include?(user.authname)
  end

end