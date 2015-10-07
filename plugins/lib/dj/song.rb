require 'open-uri'
require_relative '../logging'

class Song
  include Logging

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
  attr_reader :progress
  attr_reader :complete

  def initialize(
    properties = {}
  )

    @progress   = properties['is_new'] === true ? :pending : nil

    @title      = properties['title'] || nil
    @artist     = properties['artist'] || nil
    @album      = properties['album'] || nil
    @remarks    = properties['remarks'] || nil
    @short_url  = properties['short_url'] || nil
    @complete   = properties['complete']
    @url        = properties['url'] || nil

    pp properties
    pp self


  end


  # @param [String] value
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

  def complete=(value)
    @complete = value === true ? true : false
  end

  def progress=(value)
    @progress = value.nil? ? nil : value.slice(0..MAX_STR_LENGTH)
  end

  def to_s
    pp self
    if progress.nil? || progress.to_sym == :complete
      s = "#{title} by: #{artist}"
      s << " (on: #{album})" if album
      s << " (Remarks: #{remarks})" if remarks
      s << " #{short_url}" if short_url
    else
      s = "#{progress}, please wait (#{url})"
    end

    s
  end

  def to_h
    {
        :title      => title,
        :artist     => artist,
        :album      => album,
        :remarks    => remarks,
        :url        => url,
        :short_url  => short_url,
        :complete   => complete
    }
  end

  def to_json(*a)
    {
        :json_class => self.class.name,
        :data => self.to_h
    }.to_json(*a)
  end

  def self.json_create(*o)
    logger.debug("#{self.class.name}::#{__method__}")
    logger.debug pp(o)
    new(
       o[0]['data']
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
      short_url = open("http://duanefm.com/l/shorten.php?longurl=#{URI.escape(url)}").read
      short_url == 'Error' ? url : short_url
    rescue OpenURI::HTTPError
      url
    end

    @short_url = short_url
  end
end
