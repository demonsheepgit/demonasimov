require 'open-uri'
require 'vacuum' # amazon
require 'rspotify' #spotify
require 'digest'
require 'taglib'
require 'public_suffix'

class Song

  MAX_STR_LENGTH = 64
  MAX_URL_LENGTH = 256
  MAX_REMARKS_LENGTH = 128
  ONE_MB = 1048576 # 1MB
  MAX_FILESIZE = 15728640 # 15MB


  attr_reader :title
  attr_reader :artist
  attr_reader :album
  attr_reader :remarks
  attr_reader :url
  attr_reader :short_url

  # TODO make this a reader only
  attr_accessor :filename
  # TODO make this a reader only
  attr_accessor :state
  attr_accessor :error
  attr_accessor :thread

  def to_s
    s = "#{title} by #{artist}"
    s << " on #{album}" if album
    s << " (Remarks: #{remarks})" if remarks
    s << " #{short_url}" if short_url
    s
  end

  def initialize(
      title     = nil,
      artist    = nil,
      album     = nil,
      remarks   = nil,
      url       = nil,
      short_url = nil,
      filename  = nil
  )

    @title      = title
    @artist     = artist
    @album      = album
    @remarks    = remarks
    @url        = url
    @short_url  = short_url
    @filename   = filename

    @state = nil
    @thread = nil
  end

  def title=(value)
    @title = value.nil? ? nil : value.slice(0..MAX_STR_LENGTH)
  end

  def artist=(value)
    @artist = value.nil? ? nil : value.slice(0..MAX_STR_LENGTH)
  end

  def album=(value)
    @album = value.nil? ? nil : value.slice(0..MAX_STR_LENGTH)
  end

  def url=(value)
    @short_url = self.shorten_url(value)
    @url = value.slice(0..MAX_URL_LENGTH)
  end

  def remarks=(value)
    @remarks = value.nil? ? nil : value.slice(0..MAX_REMARKS_LENGTH)
  end

  def to_json(*a)
    {
        :json_class => self.class.name,
        :data => {
            :title      => title,
            :artist     => artist,
            :album      => album,
            :remarks    => remarks,
            :url        => url,
            :short_url  => short_url,
            :filename   => filename
        }
    }.to_json(*a)
  end

  def self.json_create(*o)
    new(
       o[0]['data']['title'],
       o[0]['data']['artist'],
       o[0]['data']['album'],
       o[0]['data']['remarks'],
       o[0]['data']['url'],
       o[0]['data']['short_url'],
       o[0]['data']['filename']
    )
  end

  def set_element(key, value)
    case key
      when 'title'
        @title = value
      when 'album'
        @album = value
      when 'artist'
        @artist = value
      when 'url'
        @url = value
      when 'remarks'
        @remarks = value
      else
        nil
    end
  end

  def shorten_url(url)
    # cache the short URL
    return @short_url unless @short_url.nil?

    begin
      short_url = open("http://tinyurl.com/api-create.php?url=#{URI.escape(url)}").read
      short_url == 'Error' ? url : short_url
    rescue OpenURI::HTTPError
      url
    end

    @short_url = short_url
  end

  # TODO additional error handling
  #   ie an amazon URL that isn't a song
  # @param [String] url Amazon URL of the specific song
  #
  # @return [Song] populated if request is valid
  #   nil otherwise
  def self.process_amazon_url(url)

    song = Song.new

    itemid = URI(url).path.split('/')[2]
    resp_hash = Hash.new

    begin
      response = @amazon.item_lookup(
          query: {
              :ItemId => itemid,
              :ResponseGroup => %w(RelatedItems Small).join(','),
              :RelationshipType => 'Tracks'
          }
      )

      resp_hash = response.to_h
      if resp_hash['ItemLookupResponse']['Items']['Request']['Errors']
        raise resp_hash['ItemLookupResponse']['Items']['Request']['Errors']['Error']['Message']
      end
    rescue Exception => e
      error("Amazon request failed: #{e.message}")
      song.error = e
      return song
    end

    item = resp_hash['ItemLookupResponse']['Items']['Item']

    song.title  = item['ItemAttributes']['Title']
    song.artist = item['ItemAttributes']['Creator']['__content__']
    song.album  = item['RelatedItems']['RelatedItem']['Item']['ItemAttributes']['Title']
    song.url    = item['DetailPageURL']

    return song

  end


  # TODO additional error handling
  # @param [String] url Spotify URL of the specific song
  #
  # @return [Song] populated if request is valid
  #   nil otherwise
  def self.process_spotify_url(url)

    song = Song.new

    # https://play.spotify.com/track/68y4C6DGkdX0C9DjRbKB2g
    itemid = URI(url).path.split('/')[2]

    begin
      track = RSpotify::Track.find(itemid)
    rescue Exception => e
      error("Spotify request failed: #{e.message}")
      song.error = e
      return song
    end

    song.artist = track.artists[0].name
    song.title = track.name
    song.album = track.album.name
    song.url = url

    return song

  end

  # TODO Handle Rhapsody URLs
  # @param [String] url Rhapsody URL of the specific song
  #
  # @return [Song] populated if request is valid
  #   nil otherwise
  def self.process_rhapsody_url(url)

  end

end