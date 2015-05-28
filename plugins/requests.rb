require 'vacuum'
require 'uri'
require 'open-uri'
require 'pp'

# Accept and remember DFM all request show requests
class Cinch::Requests
  include Cinch::Plugin

  class SongStruct < Struct.new(:title, :artist, :remarks, :url)
    def to_s
      s = "#{title} by #{artist}"
      s += " (Remarks: #{remarks})" if remarks
      s += " #{shorten(url)}" if url
      s
    end

    def shorten(url)
      url = open("http://tinyurl.com/api-create.php?url=#{URI.escape(url)}").read
      url == 'Error' ? nil : url
    rescue OpenURI::HTTPError
      nil
    end

  end

  def initialize(*args)
    super
    @requests = {}
    @admins = ['demonsheep']
    @amazon = Vacuum.new
  end

  # A single user cannot have more than max_requests
  @max_requests = 5

  set :prefix, /^dj\s+/

  listen_to :connect,                           :method => :on_connect
  match /request (http.*)\s*$/,              :method => :add_request_byurl
  match /request title:(.*) artist:(.*)$/,   :method => :add_request_byname
  match /add remarks (\d) (.*)/,             :method => :add_remarks
  match /list requests\s*$/,                 :method => :list_requests
  match /drop request (\d)\s*$/,             :method => :drop_request
  match /email requests\s*$/,                :method => :email_requests


  def on_connect(*)
    @amazon.configure(
        aws_access_key_id: config[:aws_access_key_id],
        aws_secret_access_key: config[:aws_secret_access_key],
        associate_tag: 'tag'
    )

  end

  # Allow a user to create a new request by giving a url
  def add_request_byurl(msg, url)
    init_requests(msg.user)

    # attempt to resolve the url to a product
    case URI(url).host
      when /amazon.com$/
        song = process_amazon_url(url)
      # TODO support spotify
      # when /spotify.com$/
      #   song = process_spotify_url(url)
      # TODO support rhapsody
      # when /rhapsody.com$/
      #   song = process_rhapsody_url(url)
      else
        # TODO support cloud storage
        # this one will be harder and will
        # require us to download the mp3 file
        error("Unable to process URL at #{URI(url).host}")
        return
    end

    @requests[msg.user.nick] << song
    msg.reply('Added request for ' + song.to_s)
  end

  def add_request_byname(msg,title,artist)
    init_requests(msg.user)

    @requests[msg.user.nick] = [] if @requests[msg.nick].nil?
    @requests[msg.user.nick] << SongStruct.new(title, artist, nil, nil)
  end

  def add_remarks(msg, id, remarks)
    init_requests(msg.user)

    if @requests[msg.user.nick][id].nil?
      msg.reply("Can't find matching id #{id}")
      return
    end
    @requests[msg.user.nick][id][:remarks] = remarks
  end

  # Allow a user to drop one of their requests
  # They must specify the sequence id #
  def drop_request(msg, id)
    @requests[msg.user.nick][id].delete
  end

  # Tell the user what songs they've requested for this week
  # Each request should have a prefix sequence id # to allow
  # them to drop a request from the list
  def list_requests(msg)
    init_requests(msg.user)

    count_requests(msg)
    @requests[msg.user.nick].each_with_index do |song, index|
      msg.reply("[#{index}] #{song.to_s}")
    end
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