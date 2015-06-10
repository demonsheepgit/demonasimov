require 'date'
require 'open-uri'
require 'pp'
require_relative 'song'

class Requests

  def initialize(*args)
    super
    @next_show_date = get_next_show_date()
    puts "Ready for show #{@next_show_date}"
    @requests = load_requests(@next_show_date)

  end

  # @param nick [String] user nick
  # @param song [SongStruct] the song to be added
  #
  # @return [int] the int id of the song added
  #   nil otherwise
  def add(nick, song)
    @requests[nick] = [] unless @requests.key?(nick)

    @requests[nick] << song

    puts "Added request #{nick}|#{@requests[nick].count}|#{song}"

    return @requests[nick].count - 1
  end

  # @param nick [String] user nick
  # @param id [int] the song to be removed
  #
  # @return void
  def remove(nick, id)
    return if @requests[nick].nil?
    return if @requests[nick][id.to_i].nil?

    @requests[nick].delete_at(id.to_i)

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
        count_request += @requests[nick].count
      end
    else
      count_request = @requests[nick].count
    end

    return count_request
  end

  # List the songs requested for the nick
  # @param nick [String] user's nick
  #
  # @return [Array] of the user's requests
  def list(nick)
    return [] if @requests[nick].nil?
    return @requests[nick]
  end

  # Write the data out to the persistence layer (ie redis)
  # @return void
  def save_requests
  end

  # Retrieve the data from the persistence layer (ie redis)
  # @param showdate [Date]
  #
  # @return [Hash]
  def load_requests(showdate)
    return {}
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
