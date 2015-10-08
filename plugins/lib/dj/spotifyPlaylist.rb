require 'rspotify'
require_relative '../logging'
require 'pp'

class SpotifyPlaylist < Song
  include Logging

  def auth(key, secret)
    @auth = {
        :key => key,
        :secret => secret
    }

    RSpotify.authenticate(@auth[:key], @auth[:secret])
  end

  def itemid
    URI(self.url).path.split('/')[-1]
  end

  def user
    URI(self.url).path.split('/')[-3]
  end

  # http://open.spotify.com/user/conservativela/playlist/7fl70xvClWq2K1rYyK8wyI
  # Return an array of Spotify tracks
  def process

    songs = []

    begin
      playlist = RSpotify::Playlist.find(self.user, self.itemid)
    rescue Exception => e
      # TODO: log this error somewhere
      raise("Spotify request failed: #{e.message}.")
    end

    playlist.tracks.each do |track|

      song = SpotifySong.new
      song.process(track)
      song.playlist_origin = url

      songs << song
    end

    return songs
  end


  def to_h
    super.merge(
        {
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
