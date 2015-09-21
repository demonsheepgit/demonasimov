# -*- coding: utf-8 -*-
#
# = Cinch UStream plugin
#
# Plugin to handle ustream-specific commands
# For now, allows normal users to fix the silly no-URLs
# channel mode

class Cinch::Plugins::UStream
  include Cinch::Plugin

  set :help, <<-EOF
fix channel mode - reset the channel mode -U+g
  EOF

  match /fix channel mode\s*$/,          :method => :fix_channel_mode

  def fix_channel_mode(msg)
    if msg.channel.voiced?(msg.user) || msg.channel.opped?(msg.user)
      msg.reply 'Fixing channel mode'
      msg.channel.mode('-U')
    end
  end

end
