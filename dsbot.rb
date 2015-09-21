#!/usr/bin/env ruby

require 'cinch'
require 'open3'
require 'yaml'

# Plugins
require 'cinch/plugins/fortune'
require_relative 'plugins/dj'
require_relative 'plugins/nowplaying'

Cinch::Plugins::Fortune.configure do |config|
  config.max_length=160
end

config = YAML.load_file('dsbot.yml')

bot = Cinch::Bot.new do
  configure do |param|
    param.server = config['irc']['server']
    param.messages_per_second = config['irc']['messages_per_second']
    param.server_queue_size = config['irc']['server_queue_size']
    param.delay_joins = config['irc']['delay_joins']
    param.channels = config['irc']['channels']
    param.nick = config['irc']['nick']
    param.user = config['irc']['user']
    param.password = config['irc']['password']
    param.realname = config['irc']['realname']

    # Plugin options
    param.plugins.prefix = lambda{|msg| Regexp.compile("^#{Regexp.escape(msg.bot.nick)}:?\s*")}
    param.plugins.options[Cinch::NowPlaying] = {
        :url => config['nowplaying']['url'],
        :mplayer => config['nowplaying']['mplayer'],
        :twitter_consumer_key => config['twitter']['consumer_key'],
        :twitter_consumer_secret => config['twitter']['consumer_secret'],
        :twitter_access_token => config['twitter']['access_token'],
        :twitter_access_token_secret=> config['twitter']['access_token_secret'],
        :mysql_host => config['dfm_catalog']['host'],
        :mysql_port => config['dfm_catalog']['port'],
        :mysql_username => config['dfm_catalog']['username'],
        :mysql_password => config['dfm_catalog']['password'],
        :mysql_database => config['dfm_catalog']['database']
    }
    param.plugins.options[Cinch::DJ] = {
        :aws_access_key_id => config['amazon']['aws_access_key_id'],
        :aws_secret_access_key => config['amazon']['aws_secret_access_key'],
        :spotify_client_id => config['spotify']['client_id'],
        :spotify_client_secret => config['spotify']['client_secret']
    }

    param.plugins.plugins = [Cinch::DJ, Cinch::NowPlaying, Cinch::Plugins::Fortune]
  end

  on :channel, /!bye$/ do |m|
    m.reply 'bye!'
    sleep 1
    exit(0)
  end

end

bot.start
