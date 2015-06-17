require 'open-uri'

class Song

  MAX_STR_LENGTH = 96
  MAX_URL_LENGTH = 256
  MAX_REMARKS_LENGTH = 256
  attr_reader :title
  attr_reader :artist
  attr_reader :album
  attr_reader :remarks
  attr_reader :url
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

end