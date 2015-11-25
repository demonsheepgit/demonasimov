require 'pp'

class Cinch::Plugins::RollCall
  include Cinch::Plugin

  listen_to :channel
  match /roll call/,  :method => :roll_call

  def initialize(*args)
    super

    # Time in seconds before someone is considered a lurker
    @idle_time=600
    @users = {}
  end

  def listen(msg)
    @users[msg.user.nick] = Time.now
  end

  def roll_call(msg)

    user_counts = {
        :named_users => 0,
        :lurkers     => 0,
        :anonymous   => 0
    }

    msg.channel.users.each do |user|
      pp user[0]
      nick = user[0].nick
      modes = user[1]

      next if modes.include?('a') # ustream bot

      if /^ustreamer-[0-9+]/.match(nick)
        user_counts[:anonymous] += 1
      else
        user_counts[:named_users] += 1
      end

      if @users.has_key?(nick)
        if @users[nick] + @idle_time > Time.now
          user_counts[:lurkers] += 1
        end
      end

    end

    msg.reply("Roll call: #{user_counts[:named_users]} users, #{user_counts[:lurkers]} lurking, #{user_counts[:anonymous]} anonymous")

  end

end
