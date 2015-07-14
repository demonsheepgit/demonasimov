#!/usr/bin/ruby

require 'cinch'
require 'open3'
require 'yaml'
require 'cinch/plugins/identify'

# Plugins
# require 'cinch/plugins/fortune'
require_relative 'plugins/nowplaying'
require_relative 'plugins/dj'


#Cinch::Plugins::Fortune.configure do |config|
#  config.max_length=160
#end

config = YAML.load_file('dsbot.yml')

bot = Cinch::Bot.new do
  configure do |param|
    param.server = config['irc']['server']
    param.messages_per_second = config['irc']['messages_per_second']
    param.server_queue_size = config['irc']['server_queue_size']
    param.channels = config['irc']['channels']
    param.nick = config['irc']['nick']
    param.user = config['irc']['user']
    param.password = config['irc']['password']
    param.realname = config['irc']['realname']

    # Plugin options
    param.plugins.prefix = lambda{|msg| Regexp.compile("^#{Regexp.escape(msg.bot.nick)}:?\s*")}

    param.plugins.options[Cinch::Plugins::Identify] = {
        :username => config['irc']['user'],
        :password => config['irc']['password'],
        :type     => :nickserv,
    }

    param.plugins.options[Cinch::NowPlaying] = {
        :url => config['nowplaying']['url'],
        :mplayer => config['nowplaying']['mplayer'],
        :twitter_consumer_key => config['twitter']['consumer_key'],
        :twitter_consumer_secret => config['twitter']['consumer_secret'],
        :twitter_access_token => config['twitter']['access_token'],
        :twitter_access_token_secret=> config['twitter']['access_token_secret']
    }
    param.plugins.options[Cinch::Plugin::DJ] = {
        :aws_access_key_id  => config['amazon']['aws_access_key_id'],
        :aws_secret_access_key  => config['amazon']['aws_secret_access_key']
    }

    param.plugins.plugins = [
        Cinch::NowPlaying,
        # Cinch::Plugins::Fortune,
        Cinch::Plugin::DJ,
    ]

    # only include the nickserv plugin if we're not on ustream
    unless config['irc']['server'] == 'c.ustream.tv'
      param.plugins.plugins << Cinch::Plugins::Identify
    end

  end

  on :channel, /bye$/ do |m|
    m.reply 'bye!'
    sleep 1
    exit(0)
  end

end

bot.start
