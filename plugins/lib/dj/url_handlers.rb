require 'vacuum' # amazon
require 'rspotify' #spotify
require 'open-uri'

class Url_handlers

  def initialize(config)
    @config = config
    @max_requests = config[:max_requests]
  end

  # TODO additional error handling
  #   ie an amazon URL that isn't a song
  # @param [String] url Amazon URL of the specific song
  #
  # @return [Song] populated if request is valid
  #   nil otherwise
  def process_amazon_url(url)
    amazon = Vacuum.new

    amazon.configure(
        aws_access_key_id: @config[:aws_access_key_id],
        aws_secret_access_key: @config[:aws_secret_access_key],
        associate_tag: 'tag'
    )

    song = Song.new

    itemid = URI(url).path.split('/')[2]
    resp_hash = Hash.new

    begin
      response = amazon.item_lookup(
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
      # TODO: log this error somewhere
      raise("Amazon request failed: #{e.message}. URL was: #{url}")
    end

    item = resp_hash['ItemLookupResponse']['Items']['Item']

    song.title  = item['ItemAttributes']['Title']
    song.artist = item['ItemAttributes']['Creator']['__content__']
    song.album  = item['RelatedItems']['RelatedItem']['Item']['ItemAttributes']['Title']
    song.url    = item['DetailPageURL']

    return Array(song)

  end

  # TODO additional error handling
  # @param [String] url Spotify URL of the specific song
  #
  # @return [Song] populated if request is valid
  #   nil otherwise
  def process_spotify_url(url)

    # https://play.spotify.com/track/68y4C6DGkdX0C9DjRbKB2g
    # http://open.spotify.com/user/conservativela/playlist/7fl70xvClWq2K1rYyK8wyI

    query_type = URI(url).path.split('/')[-2]
    itemid = URI(url).path.split('/')[-1]

    # itemid = URI(url).path.split('/')[2]

    case query_type
      when 'track'
        song = _spotify_track(itemid)
        song.url = url
        return Array(song)
      when 'playlist'
        user = URI(url).path.split('/')[-3]
        songs = _spotify_playlist(user, itemid)
        return songs
      else
        raise(ArgumentError, "Invalid or unknown query type #{query_type}")
    end

  end

  def _spotify_playlist(user, itemid)

    RSpotify.authenticate(@config[:spotify_client_id], @config[:spotify_client_secret])
    playlist = RSpotify::Playlist.find(user, itemid)
    puts "size: #{playlist.tracks.size}"
    if playlist.tracks.size > @max_requests
      raise(ArgumentError, 'Playlist contains too many tracks')
    end

    songs = Array.new

    playlist.tracks.each do |track|
      song = Song.new
      song.artist = track.artists[0].name
      song.title = track.name
      song.album = track.album.name
      song.url = track.external_urls['spotify']
      songs << song
    end

    return songs
  end

  def _spotify_track(itemid)
    song = Song.new

    begin
      track = RSpotify::Track.find(itemid)
    rescue Exception => e
      # TODO: log this error somewhere
      raise("Spotify request failed: #{e.message}. URL was: #{url}")
    end

    if track.nil?
      # TODO: log this error somewhere
      raise('Spotify could not be reached, or the URL provided was malformed.')
    end

    song.artist = track.artists[0].name
    song.title = track.name
    song.album = track.album.name

    song
  end

  # TODO Handle Rhapsody URLs
  # @param [String] url Rhapsody URL of the specific song
  #
  # @return [Song] populated if request is valid
  #   nil otherwise
  def self.process_rhapsody_url(url)

  end

end
