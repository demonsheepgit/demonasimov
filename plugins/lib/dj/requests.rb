require 'date'
require 'open-uri'
require 'pp'
require 'redis'
require 'json'
require_relative '../logging'
require_relative 'song'
require_relative 'amazonSong'
require_relative 'spotifySong'
require_relative 'spotifyPlaylist'

class Requests
  include Logging

  SATURDAY = 6
  DEADLINE_HOUR = 9

  attr_reader :show_date

  def initialize(*args)
    super

    logger.debug("#{self.class.name}::#{__method__}")

    @redis = Redis.new
    @lock = Mutex.new
    @show_date = next_show_date
    @requests = load_requests(@show_date)
    @roller_status = nil
    start_show_date_roller
  end

  # @param nick [String] user nick
  # @param song [Song] the song to be added
  #
  # @return [int] the int id of the song added
  #   nil otherwise
  def add(nick, song)
    @requests[nick] = [] unless @requests.key?(nick)
    @requests[nick] << song

    save_requests

    @requests[nick].length
  end

  # @param nick [String] user nick
  # @param index [int] the song to be removed
  #
  # @return void
  def remove(nick, index)
    return if @requests[nick].nil?
    return if @requests[nick][index.to_i].nil?

    @requests[nick].delete(index.to_i)

    save_requests
  end

  def remove_all(nick)
    @requests[nick] = []

    save_requests
  end

  # Fetch the requested song
  # @param nick [String] user nick
  # @param index [int] the request to be modified
  #
  # @return [Song]
  def get(nick, index)
    return nil if @requests[nick].nil?
    return nil if @requests[nick][index.to_i].nil?

    @requests[nick][index.to_i]
  end

  # Replace/update the song identified by id
  # This allows updating the remarks, adding an
  # album title, etc
  # @param nick [String] user nick
  # @param index [int] the request to be modified
  # @param song [Song] the updated song
  #
  # @return void
  def update(nick, index, song)
    return if @requests[nick].nil?
    return if @requests[nick][index.to_i].nil?

    @requests[nick][index.to_i] = song
  end

  # @param nick [String] user's nick or nil for all users
  #
  # @return [int] the number of songs in the user's request queue
  #    or the total request count if nil
  #   nil otherwise
  def count(nick=nil)
    return 0 if @requests[nick].nil?

    count_request = 0
    if nick.nil?
      @requests.each do |nick|
        count_request += @requests[nick].length
      end
    else
      count_request = @requests[nick].length
    end

    count_request
  end

  # List the songs requested for the nick
  # @param nick [String] user's nick
  #
  # @return [Hash] of the user's requests
  def list(nick)
    return [] if @requests[nick].nil?
    @requests[nick]
  end

  # Write the data out to the persistence layer (ie redis)
  # @return void
  def save_requests
    @redis.set("requests-#{@show_date}", @requests.to_json)
  end

  # Retrieve the data from the persistence layer (ie redis)
  # @param load_show_date [Date]
  #
  # @return [Hash]
  def load_requests(load_show_date)
    request_json = @redis.get("requests-#{load_show_date}")
    if request_json.nil?
      {}
    else
      JSON.parse(request_json, :create_additions => true)
    end
  end

  # Calculate the next/upcoming show date
  #
  # @return [Date] date of the upcoming Saturday
  def next_show_date
    interval = SATURDAY - Date.today().wday
    interval = SATURDAY if (interval < 0)

    Date.today + interval
  end

  def past_deadline?
    Date.today >= @show_date && Time.now.hour >= DEADLINE_HOUR
  end

  # If necessary, roll @show_date to the next week
  # @return void
  def start_show_date_roller
    if @roller_status == 'run' || @roller_status == 'sleep'
      raise("Error in #{__method__}: roller thread already running!")
    end

    # do not join this thread, we don't care about it finishing
    Thread.new do
      @roller_status = Thread.current.status
      while true do
        sleep 600
        if Date.today > @show_date
          @lock.synchronize do
            save_requests
            @requests = {}
          end
          @show_date = next_show_date
        end
      end
    end
  end

end
