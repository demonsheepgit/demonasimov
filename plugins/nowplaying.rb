# -*- coding: utf-8 -*-
#
# = Cinch Now Playing plugin
#
# Plugin to output the track currently
# playing on DuaneFM
#
# == Configuration
# Add the following to your bot's configure.do stanza
#   config.plugins.options[Cinch::Nowplaying] = {
#     :mplayer => "/usr/local/bin/mplayer"
#     :url => "http://3143.live.streamtheworld.com:80/HUGHIRAAC_SC"
# }
# [mplayer]
#   path to the mplayer binary
# [url]
#   url of the mp3 stream

require 'twitter'

class Cinch::NowPlaying
  include Cinch::Plugin

  set :required_options, [:mplayer, :url]

  @@loop_active = false
  @@tweet = true
  
  # How long to wait after noticing a change to announce it
  ANNOUNCE_DELAY = 8 # seconds
  # How often to check the stream for changes
  LOOP_INTERVAL = 5 # seconds

  match /start announcing/, :method => :start_announcements
  match /stop announcing/,  :method => :stop_announcements
  match /start tweeting/,   :method => :start_tweeting
  match /stop tweeting/,    :method => :stop_tweeting
  match /status/,           :method => :show_status
  listen_to :connect,       :method => :on_connect

  # Do some setup work when we first connect
  def on_connect(*)
    @mplayer_cmd = "#{config[:mplayer]} -nosound #{config[:url]}"
    @twitter_client = Twitter::REST::Client.new do |twitter_config|
      twitter_config.consumer_key = config[:twitter_consumer_key]
      twitter_config.consumer_secret = config[:twitter_consumer_secret]
      twitter_config.access_token = config[:twitter_access_token]
      twitter_config.access_token_secret = config[:twitter_access_token_secret]
    end
  end

  # Responds with state information
  def show_status(msg)
    if @@loop_active
      msg.reply 'song announcements: yes'
      if @@tweet
        msg.reply ' - tweeting: yes'
      else
        msg.reply ' - tweeting: no'
      end
    else
      msg.reply 'song announcements: no'
    end

  end

  # Set the tweeting flag to true
  def start_tweeting(msg)
    msg.reply "will tweet the set list to @demonasimov's timeline."
    @@tweet = true
  end

  # Turn off the tweeting flag
  def stop_tweeting(msg)
    msg.reply "okay, no more tweeting."
    @@tweet = false
  end

  # The "main" loop runs in this function for as long as
  # @@loop_active is true
  def start_announcements(msg)

    if @@loop_active == true
      msg.reply "Already announcing the titles, #{msg.user.nick}. Pay attention."
      return
    else
      @@loop_active=true
    end

    # Need to get the current stream title as a baseline
    prev_stream_title = nil
    stream_title = get_stream_title()

    msg.reply "#{msg.user.nick}, here's what's playing on DuaneFM: #{stream_title}"
    msg.reply "I'll keep announcing what's playing until someone tells me to stop"

    prev_stream_title = stream_title

    # There's probably a better way than this goofy loop to do this
    while @@loop_active
      stream_title = get_stream_title()
      if stream_title != prev_stream_title
        # delay a little before making the announcement
        # otherwise we get ahead of the music since we
        # can see the title change before the music actually
        # changes
        sleep(ANNOUNCE_DELAY)
        msg.reply "Now playing: #{stream_title}"

        tweet(stream_title)

        prev_stream_title = stream_title
      end
      sleep(LOOP_INTERVAL)
    end
    msg.reply "okay, #{msg.user.nick}. 'now playing' announcements silenced."
  end

  # Silence all announcements
  # they'll actually stop on the next pass through
  # the main loop
  def stop_announcements(msg)
    if @@loop_active
      msg.reply "Give me a few seconds, #{msg.user.nick}"
      @@loop_active=false
    else
      msg.reply "#{msg.user.nick}: nothing to stop"
    end
  end

  # Tweet out the title
  def tweet(title)
    unless @twitter_client.nil?

      # Make sure the title is short enough
      if title.length > 90
        title = title[0,90]
      end
      if @@tweet
        @twitter_client.update("Now playing on #DuaneFM: #{title} http://bit.ly/1ErYiZr")
      end

    end
  end

  # Fetch the stream title
  def get_stream_title()
    stream_title = nil
    Open3.popen3(@mplayer_cmd) do |stdin, stdout, stderr, wait_thr|
      while line = stdout.gets
        if line.match('ICY Info:')
          stream_title = line.split('=')[1].tr("';","")
        end
      end
    end
    return stream_title
  end

end
