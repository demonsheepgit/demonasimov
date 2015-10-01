require 'rspotify'
require_relative '../logging'
require 'pp'

class SpotifySong < Song
  include Logging

  attr_reader :id
  attr_reader :playlist_origin

  def initialize(
    properties = {}
  )
    super
    @id               = properties['id'] || nil
    @playlist_origin  = properties['playlist_origin'] || nil

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

  # allow process to handle a url or a track object
  # track objects would come from spotifyPlaylist
  def process(o)

    unless o.is_a?(RSpotify::Track)
      # Handle a URL
      url = o
      # https://play.spotify.com/track/68y4C6DGkdX0C9DjRbKB2g
      itemid = URI(url).path.split('/')[-1]

      begin
        track = RSpotify::Track.find(itemid)
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

    @id = track.id
    self.artist = track.artists[0].name
    self.title = track.name
    self.album = track.album.name

    return true
  end


  def to_h
    super.merge(
        {
          id => @id,
          playlist_origin => @playlist_origin
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
