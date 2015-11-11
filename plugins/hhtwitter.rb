# -*- coding: utf-8 -*-
#
# = Cinch HH Twitter plugin
# Echo the tweet stream from @hughhewitt
#
#



require 'open-uri'
require 'pp'
require 'tweetstream'

class Cinch::Plugins::HHTwitter
  include Cinch::Plugin

  @hh_twitter

  match /hhtweets (on|off)\s*$/,    :method => :set_hh_tweets
  listen_to :connect,               :method => :on_connect

  def initialize(*args)
    super

    @hh_twitter = false
  end


  # Do some setup work when we first connect
  def on_connect(*)

    TweetStream.configure do |c|
      c.consumer_key = config[:twitter_consumer_key]
      c.consumer_secret = config[:twitter_consumer_secret]
      c.oauth_token = config[:twitter_access_token]
      c.oauth_token_secret = config[:twitter_access_token_secret]
      c.auth_method = :oauth
    end

  end

  def set_hh_tweets(msg, state)

    state = state == 'on' ? true : false

    # don't re-apply current state
    if @hh_twitter == state
      msg.reply "HH tweets already #{@hh_twitter ? 'enabled' : 'disabled'}"
      return
    end

    state ? toggle_hh_tweets_on(msg) : toggle_hh_tweets_off(msg)

  end

  def toggle_hh_tweets_on(msg)
    @hh_twitter = true

    msg.reply("watching tweets")

    client = TweetStream::Client.new

    client.on_error do |message|
      puts "error: #{message}"
      msg.reply "Got an error, stopping tweet stream (#{message})"
      @hh_twitter = false
      client.stop
    end

    client.follow(15075999) do |status, client|
      if @hh_twitter === false
        msg.reply 'stopping'
        client.stop
      end

      # Only show tweets from Hugh
      if status.attrs[:user][:id] == 15075999 && status.in_reply_to_status_id.nil?
        msg.reply "@HughHewitt: #{status.text}"
      end

    end

  end

  def toggle_hh_tweets_off(msg)
    @hh_twitter = false
    return
  end


end



