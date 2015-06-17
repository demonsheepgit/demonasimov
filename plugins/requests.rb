require 'date'
require 'open-uri'
require 'pp'
require 'redis'
require 'json'
require_relative 'song'

class Requests

  def initialize(*args)
    super

    @redis = Redis.new

    @next_show_date = get_next_show_date()
    @requests = load_requests(@next_show_date)

  end

  # @param nick [String] user nick
  # @param song [SongStruct] the song to be added
  #
  # @return [int] the int id of the song added
  #   nil otherwise
  def add(nick, song)

    @requests[nick] = {} unless @requests.key?(nick)
    song_id = @requests[nick].length + 1
    @requests[nick][song_id] = song

    save_requests

    return song_id
  end

  # @param nick [String] user nick
  # @param id [int] the song to be removed
  #
  # @return void
  def remove(nick, id)
    return if @requests[nick].nil?
    return if @requests[nick][id.to_i].nil?

    @requests[nick].delete(id.to_i)

    # re-sequence the request_id keys
    idx = 1

    @requests[nick].keys.each do |id|
      @requests[nick][idx] = @requests[nick].delete(id)
      idx += 1
    end

    save_requests

  end

  # Fetch the requested song
  # @param nick [String] user nick
  # @param id [int] the request to be modified
  #
  # @return [SongStruct]
  def get(nick, id)
    return nil if @requests[nick].nil?
    return nil if @requests[nick][id.to_i].nil?

    return @requests[nick][id.to_i]
  end

  # Replace/update the song identified by id
  # @param nick [String] user nick
  # @param id [int] the request to be modified
  # @param song [SongStruct] the updated song
  #
  # @return void
  def update(nick, id, song)
    return if @requests[nick].nil?
    return if @requests[nick][id.to_i].nil?

    @requests[nick][id.to_i] = song

  end

  # @param nick [String] user's nick or nil for all users
  #
  # @return [int] the number of songs in the user's request queue
  #    or the total request count if nil
  #   nil otherwise
  def count(nick=nil)

    return 0 if @requests[nick].nil?

    count_request = 0
    if (nick.nil?)
      @requests.each do |nick|
        count_request += @requests[nick].length
      end
    else
      count_request = @requests[nick].length
    end

    return count_request
  end

  # List the songs requested for the nick
  # @param nick [String] user's nick
  #
  # @return [Array] of the user's requests
  def list(nick)
    return {} if @requests[nick].nil?
    return @requests[nick]
  end

  # Write the data out to the persistence layer (ie redis)
  # @return void
  # TODO set up a periodic save
  # TODO request a save on exit
  def save_requests
    @redis.set("requests-#{@next_show_date}", @requests.to_json)
  end

  # Retrieve the data from the persistence layer (ie redis)
  # @param show_date [Date]
  #
  # @return [Hash]
  def load_requests(show_date)
    request_data = @redis.get("requests-#{show_date}")
    if request_data.nil?
      return {}
    else

      request_data = JSON.parse(request_data, :create_additions => true)

      # convert the string representations of the request sequence id to an integer
      request_data.keys.each do |nick|
        request_data[nick].keys.each do |id_string|
          request_data[nick][id_string.to_i] = request_data[nick].delete(id_string)
        end
      end

      return request_data
    end

  end

  # Calculate the next/upcoming show date
  #
  # @return [Date] date of the upcoming Saturday
  def get_next_show_date
    saturday = 6
    interval = saturday - Date.today().wday
    interval = saturday if (interval < 0)

    return Date.today() + interval

  end

end
