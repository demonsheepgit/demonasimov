require 'pp'

class Cinch::Plugins::RollCall
  include Cinch::Plugin

  listen_to :channel, :method => :on_message
  listen_to :join,    :method => :on_join
  listen_to :leaving, :method => :on_leave
  listen_to :connect, :method => :on_connect

  match /roll call/,  :method => :roll_call

  def initialize(*args)
    super

    # Time in seconds before someone is considered a lurker
    @idle_time=600
    @users = {}
  end

  def on_connect(*)
  end

  def on_join(m)
    # survey the channel for users if I'm the one joining the channel
    if @bot.nick == m.user.nick
      m.channel.users.each do |user|
        @users[user[0].nick] = Time.now
      end
    else
      @users[m.user.nick] = Time.now
    end
  end

  def on_leave(m, user)
    @users.delete(user.nick) if @users.has_key?(user.nick)
  end

  def on_message(msg)
    @users[msg.user.nick] = Time.now
  end

  def roll_call(msg)
    user_counts = {
        :named_users => 0,
        :lurkers     => 0,
        :anonymous   => 0
    }

    msg.channel.users.each do |user|
      nick = user[0].nick
      modes = user[1]

      next if modes.include?('a') # ustream bot

      if /^ustreamer-[0-9+]/.match(nick)
        user_counts[:anonymous] += 1
      else
        user_counts[:named_users] += 1
      end

      if @users.has_key?(nick)
        if Time.now > @users[nick] + @idle_time
          pp "lurker: #{nick}"
          user_counts[:lurkers] += 1
        end
      end

    end

    msg.reply("Roll call: #{user_counts[:named_users]} users, #{user_counts[:lurkers]} lurking, #{user_counts[:anonymous]} anonymous")

  end

end
