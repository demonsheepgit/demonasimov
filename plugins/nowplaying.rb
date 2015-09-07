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

  set :help, <<-EOF
dj (on|off) - Turn DJ announcing on or off
dj twitter (on|off) - Turn DJ tweeting on or off (DJ announcing must be on)
dj status - Report the current DJ state (on or off)
what's playing? - Reply with the current song title/artist
EOF

  set :required_options, [:mplayer, :url]


  # How long to wait after noticing a change to announce it
  ANNOUNCE_DELAY = 8 # seconds
  # How often to check the stream for changes
  LOOP_INTERVAL = 5 # seconds

  match /dj (on|off)\s*$/,          :method => :set_dj_state
  match /dj twitter (on|off)\s*$/,  :method => :set_tweeting_state
  match /dj\s*$|dj status\s*$/,     :method => :show_status
  match /what's playing/,           :method => :whats_playing
  listen_to :connect,               :method => :on_connect

  def initialize(*args)
    super
    @show_time_excuses = [
        'That would be rude.',
        'I\'ve read The Looming Tower, but I still can\'t do that right now.',
        'Trump is good for ratings.',
        'Alger Hiss was a communist spy.',
        'Can\'t do that, seminar callers are jamming the lines.',
        'An intern pushed the wrong button.',
        'If only I had a producer...',
        'The fetching Mrs. Asimov and I saw a great movie last night.'
    ]

    @dj_state = false
    @dj_tweeting = false

  end

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

  def set_dj_state(msg, state)

    state = state == 'on' ? true : false

    # don't re-apply current state
    if @dj_state == state
      msg.reply "DJ announcements already #{@dj_state ? 'enabled' : 'disabled'}"
      return
    end

    if is_hh_show_time?
      msg.reply @show_time_excuses.sample
      return
    else
      state ? toggle_dj_on(msg) : toggle_dj_off(msg)
    end

  end

  def toggle_dj_on(msg)
    msg.reply 'DJ announcements enabled'
    @dj_state = true
    # turn on tweeting by default
    @dj_tweeting = true
    start_announcements(msg)
  end

  def toggle_dj_off(msg)
    msg.reply 'DJ announcements disabled'
    @dj_state = false
  end

  def set_tweeting_state(msg, state)

    state = state == 'on' ? true : false

    unless @dj_state
      msg.reply "Enable the DJ first with '#{bot.name} dj on'"
    else
      @dj_tweeting = state == true
      msg.reply "DJ tweets #{@dj_tweeting ? 'enabled' : 'disabled'}: https://twitter.com/demonasimov"
    end
  end

  # Responds with state information
  def show_status(msg)
    response = "DJ announcements: #{@dj_state ? 'enabled' : 'disabled'}"

    if @dj_state
      response << " DJ tweets: #{@dj_tweeting ? 'enabled' : 'disabled'}"
    end

    msg.reply response
  end

  def whats_playing(msg)
    if is_hh_show_time?
      msg.reply "It's Hugh Hewitt's turn at the mic"
    else
      stream_title = get_stream_title()
      msg.reply "#{stream_title}"
    end
  end

  # The "main" loop runs in this function for as long as
  # @dj_state is true
  def start_announcements(msg)

    # Need to get the current stream title as a baseline
    stream_title = get_stream_title()
    prev_stream_title = stream_title

    msg.reply "Here's what's playing on DuaneFM: #{stream_title}"

    # There's probably a better way than this goofy loop to do this
    while @dj_state
      stream_title = get_stream_title()

      # In some cases (Ubuntu), mplayer can return a nil title
      if stream_title != prev_stream_title && stream_title != nil
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

      # If it looks like we're running during normal show time, turn off automagically
      if is_hh_show_time?
        msg.reply "It's Hugh's turn now. Bet you wish he had an off button like I do."
        toggle_dj_off(msg)
      end

    end
  end

  # Is this a time when the HH show is on the air?
  def is_hh_show_time?
    # Monday through Friday
    if (1..5).to_a.include?(DateTime.now().wday)
      # 17:00-20:00 (Central Time)
      if (17..20).to_a.include?(DateTime.now().hour)
        return true
      end
    end
    false
  end

  # Tweet out the title
  def tweet(title)
    unless @twitter_client.nil?

      # Make sure the title is short enough
      if title.length > 80
        title = title[0,80]
      end
      if @dj_tweeting
        @twitter_client.update("Now playing on #DuaneFM: #{title} http://bit.ly/1ErYiZr #hewitt")
      end

    end
  end

  # Fetch the stream title
  def get_stream_title
    stream_title = nil
    Open3.popen3(@mplayer_cmd) do |stdin, stdout, stderr, wait_thr|
      while line = stdout.gets
        if line.match('ICY Info:')
          stream_title = line.split('=')[1].tr("';",'')
        end
      end
    end
    return stream_title
  end

end
