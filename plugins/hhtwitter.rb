# -*- coding: utf-8 -*-
#
# = Cinch HH Twitter plugin
# Echo the tweet stream from @hughhewitt
#
#



require 'open-uri'
require 'pp'
require 'tweetstream'
require 'uri'

HEWITT_ID = 15075999

class Cinch::Plugins::HHTwitter
  include Cinch::Plugin

  @hh_twitter
  @last_tweet

  match /hughtweets (on|off)\s*$/,  :method => :set_hugh_tweets
  listen_to :connect,               :method => :on_connect

  def initialize(*args)
    super

    @hh_twitter = false
    @last_tweet = Time.new.to_i

    # stupid ustream. flood limit is 3 lines every 5 seconds
    # so a multi-line tweet or a tweet with more than 3 lines
    # in 5 seconds gets us kicked out.
    @line_limit = 3 # lines
    @time_limit = 8 # seconds

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

    @client = TweetStream::Client.new

  end

  def set_hugh_tweets(msg, state)

    state = state == 'on' ? true : false

    # don't re-apply current state
    if @hh_twitter == state
      msg.reply "HH tweets already #{@hh_twitter ? 'enabled' : 'disabled'}"
      return
    end

    state ? toggle_hugh_tweets_on(msg) : toggle_hugh_tweets_off(msg)

  end

  def toggle_hugh_tweets_on(msg)
    @hh_twitter = true

    msg.reply('ok')

    @client.on_error do |message|
      puts message
      msg.reply "Got an error, stopping tweet stream (#{message.lines.first.strip})"
      @hh_twitter = false
      @client.stop
    end

    @client.on_limit do |discarded_count|
      puts "Twitter rate limit. #{discarded_count} discarded"
    end

    @client.follow(HEWITT_ID) do |status|

      @client.stop unless @hh_twitter

      # skip this tweet if it doesn't meet the criteria
      next unless repeatable?(status)

      text = nil

      if is_retweet?(status)
        text = original_text_of_rt(status)
      else
        text = status.text
      end

      # stupid ustream considers most public url shorteners as spam
      # so we'll wrap up the url in a dfm shortened url.
      text = wrap_urls(text)

      msg.reply "@HughHewitt: #{text}"
      @last_tweet = Time.new.to_i

    end
  end

  def toggle_hugh_tweets_off(msg)
    @hh_twitter = false
    @client.stop
    msg.reply('ok - no more HughTweets')
    return
  end

  def original_text_of_rt(status)
    author = status.attrs[:retweeted_status][:user][:screen_name]
    result = "RT @#{author}: #{status.attrs[:retweeted_status][:text]}"
    result

  end

  def is_retweet?(status)
    status.attrs.has_key?(:retweeted_status)
  end

  def wrap_urls(text)
    new_text = text.clone
    URI.extract(text) do |url|
      if url =~ /\A#{URI::regexp(%w(http https))}\z/
        new_text = new_text.sub(url,shorten_url(url))
      end

    end

    return new_text
  end

  def shorten_url(url)

    begin
      short_url = open("http://duanefm.com/l/shorten.php?longurl=#{URI.escape(url)}").read
      short_url == 'Error' ? url : short_url
    rescue OpenURI::HTTPError
      url
    end

    short_url
  end

  def repeatable?(status)

    repeatable = true

    repeatable = false unless [HEWITT_ID].include?(status.attrs[:user][:id])
    repeatable = false unless status.in_reply_to_status_id.nil?
    repeatable = false unless status.text.lines.count <= @line_limit
    repeatable = false unless Time.new.to_i > (@last_tweet + @time_limit)

    repeatable
  end

end



