class Song

  attr_accessor :title
  attr_accessor :artist
  attr_accessor :album
  attr_accessor :remarks
  attr_accessor :url
  attr_accessor :error

  @short_url

  def to_s
    s = "#{title} by #{artist}"
    s << " on #{album}" if album
    s << " (Remarks: #{remarks})" if remarks
    s << " #{shorten(url)}" if url
    s
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