require 'vacuum' # amazon
require 'rspotify' #spotify

class Url_handlers

  def initialize(config)
    @config = config

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
      puts("Amazon request failed: #{e.message}. URL was: #{url}")
      song.error = Exception.new('Amazon could not be reached, or the URL provided was malformed.')
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
  def process_spotify_url(url)

    song = Song.new

    # https://play.spotify.com/track/68y4C6DGkdX0C9DjRbKB2g
    itemid = URI(url).path.split('/')[2]

    begin
      track = RSpotify::Track.find(itemid)
    rescue Exception => e
      puts("Spotify request failed: #{e.message}. URL was: #{url}")
      song.error = e
      return song
    end

    if track.nil?
      song.error = Exception.new('Spotify could not be reached, or the URL provided was malformed.')
      return song
    end

    song.artist = track.artists[0].name
    song.title = track.name
    song.album = track.album.name
    song.url = url

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
