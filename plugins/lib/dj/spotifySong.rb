require 'rspotify'
require_relative '../logging'
require 'pp'

class SpotifySong < Song
  include Logging

  attr_reader :playlist_origin

  # Example URL
  # https://play.spotify.com/track/68y4C6DGkdX0C9DjRbKB2g
  def initialize(
    properties = {}
  )
    super
    unless properties['spotify'].nil?
      @playlist_origin  = properties['spotify']['playlist_origin'] || nil
    end

  end

  def playlist_origin=(value)
    @playlist_origin = value.nil? ? nil : value.slice(0..MAX_STR_LENGTH)
  end

  def auth(key, secret)
    @auth = {
        :key => key,
        :secret => secret
    }

    RSpotify.authenticate(@auth[:key], @auth[:secret]) if @do_auth
  end

  def itemid
    URI(self.url).path.split('/')[-1]
  end

  # allow process to handle a url or a track object
  # track objects would come from spotifyPlaylist
  def process(o)

    unless o.is_a?(RSpotify::Track)
      # Handle a URL

      self.url = o

      begin
        track = RSpotify::Track.find(self.itemid)
      rescue Exception => e
        # TODO: log this error somewhere
        raise("Spotify request failed: #{e.message}.")
      end

      if track.nil?
        # TODO: log this error somewhere
        raise('Spotify could not be reached, or the URL provided was malformed.')
      end
    else
      track = o
    end

    self.artist = track.artists[0].name
    self.title = track.name
    self.album = track.album.name

  end


  def to_h
    super.merge(
        {
            spotify: {playlist_origin: self.playlist_origin}
        })
  end

  def to_json(*a)
    {
        :json_class => self.class.name,
        :data => self.to_h
    }.to_json(*a)
  end

  def self.json_create(*o)
    new(
        o[0]['data']
    )
  end

end
