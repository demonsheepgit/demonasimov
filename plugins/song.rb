require 'open-uri'
require 'vacuum' # amazon
require 'rspotify' #spotify

class Song

  MAX_STR_LENGTH = 96
  MAX_URL_LENGTH = 256
  MAX_REMARKS_LENGTH = 256
  MAX_FILESIZE = 15728640 # 15MB
  ONE_MB = 1048576 # 1MB
  attr_reader :title
  attr_reader :artist
  attr_reader :album
  attr_reader :remarks
  attr_reader :url
  attr_reader :state
  attr_accessor :error

  @short_url

  def to_s
    s = "#{title} by #{artist}"
    s << " on #{album}" if album
    s << " (Remarks: #{remarks})" if remarks
    s << " #{shorten(url)}" if url
    s
  end

  def initialize(
      title   = nil,
      artist  = nil,
      album   = nil,
      remarks = nil,
      url     = nil
  )

    @title   = title
    @artist  = artist
    @album   = album
    @remarks = remarks
    @url     = url
    @state = nil
  end

  def title=(value)
    @title = value.slice(0..MAX_STR_LENGTH)
  end

  def artist=(value)
    @artist = value.slice(0..MAX_STR_LENGTH)
  end

  def album=(value)
    @album = value.slice(0..MAX_STR_LENGTH)
  end

  def url=(value)
    @url = value.slice(0..MAX_URL_LENGTH)
  end

  def remarks=(value)
    @remarks = value.slice(0..MAX_REMARKS_LENGTH)
  end

  def to_json(*a)
    {
        'json_class' => self.class.name,
        'data' => {
            :title    => title,
            :artist   => artist,
            :album    => album,
            :remarks  => remarks,
            :url      => url
        }
    }.to_json(*a)
  end

  def self.json_create(*o)
    new(
       o[0]['data']['title'],
       o[0]['data']['artist'],
       o[0]['data']['album'],
       o[0]['data']['remarks'],
       o[0]['data']['url']
    )
  end

  def set_element(key, value)
    case key
      when 'title'
        self.title = value
      when 'album'
        self.album = value
      when 'artist'
        self.artist = value
      when 'url'
        self.url = value
      when 'remarks'
        self.remarks = value
    end
  end

  def shorten(url)
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

    song = Song.new()

    itemid = URI(url).path.split('/')[2]
    resp_hash = Hash.new

    begin
      response = @amazon.item_lookup(
          query: {
              'ItemId'           => itemid,
              'ResponseGroup'    => %w(RelatedItems Small).join(','),
              'RelationshipType' => 'Tracks'
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

  # @param [String] url URL to an mp3 file
  # @return [Song] populated if request is valid
  #   nil otherwise
  # TODO implement me
  # will require us to download the mp3 file
  # and analyze the id3 data
  # https://dl.dropboxusercontent.com/u/36902/dfm_allrequest/20150328/03282015-Llamas_with_Hats.mp3
  def self.process_cloudstorage_url(url)
    song = Song.new(nil, nil, nil, nil, url)
    song = Song._error_check(song)

    if song.error.is_a?(Exception)
      return song
    end

    song.title = '(downloading)'

    return song
  end

  def self.get_remote_size(uri)
    begin
      http = Net::HTTP.start(uri.host)

      resp = http.head(uri.path)
      size = resp['content-length'].to_i
      http.finish
    rescue Exception => e
      puts "Could not determine size of file at #{uri}: #{e.message}"
      return -1
    end

    return size

  end

  def self._error_check(song)
    begin
      unless song.url =~ URI::regexp
        raise 'Invalid URL or URL format unknown'
      end

      uri = URI.parse(song.url)

      unless uri.path.end_with? '.mp3'
        raise 'Cloud storage URL must point directly to an mp3 file'
      end

      unless Song.get_remote_size(uri) <= MAX_FILESIZE
        raise "File must be less than #{MAX_FILESIZE / ONE_MB}MB"
      end

    rescue Exception => e
      puts e.backtrace.pretty_inspect
      song.error = e
    end

    return song
  end
  #@_private
end