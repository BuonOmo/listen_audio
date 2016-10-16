#!/usr/bin/ruby


require 'mysql'
require 'optparse'

trap('INT') { exit(1) }

class Mysql
  def self.add_view (con,episode)
    vue = con.query("SELECT vue FROM DeuxMinutes WHERE name='#{episode}'")
    puts vue
    con.query("UPDATE Writers SET vue=#{vue+1} WHERE name='#{episode}'")
  end

  def self.insert (con, *names)
    con.query("INSERT INTO DeuxMinutes(path,name,vue) VALUES(#{names.map(&:inspect).join(', ')},0)")
  end
  def self.play_next(con, number, vues = 0)
    episodes = con.query("SELECT * FROM DeuxMinutes WHERE vue=#{vues}")
    array_episodes = []
    episodes.each_hash do |episode|
      episode['vue'] = episode['vue'].to_i
      array_episodes << episode
    end
    puts "Liste des épisodes :"
    min = array_episodes.reduce(100){|memo,curr| memo < curr['vue'] ? memo : curr['vue']}
    array_episodes
        .select { |episode| episode['vue'] == min }
        .shuffle[0..number]
        .each do |episode|
      puts " - #{episode['name']}"
    end.each do |episode|
      puts "** ======================= #{episode['path'].rjust(20,' ')} ============================================ **"
      `vlc --play-and-exit #{episode['path'].inspect}`
      con.query("UPDATE DeuxMinutes SET vue=#{episode['vue'].to_i+1} WHERE path=#{episode['path'].inspect}")
    end
  end
end

begin

  con = Mysql.new 'localhost', 'root', 'root', 'ruby'

  def recreate
    con.query("DROP TABLE DeuxMinutes")
    con.query("CREATE TABLE IF NOT EXISTS DeuxMinutes(path VARCHAR(200) PRIMARY KEY, name VARCHAR(100), vue INT)")

    `ls /home/ulysse/Musique/2\\ minutes*/*.mp3`.split("\n").each do |episode|
      Mysql.insert con,episode, episode.delete('/home/ulysse/Musique/2 minutes du peuple/', '.mp3')
    end
  end

  def play(con:, number:, poweroff:)
    Mysql.play_next(con,number)
    `poweroff` if poweroff
  end


  number   = 3
  poweroff = false
  prompt   = false

  options = {}
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$0} [options]"

    opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
      options[:verbose] = v
    end

    opts.on("-n N", "--number N", Integer, "Number of episodes to play") do |n|
      number = n
    end

    opts.on("-p", "--[no-]poweroff", "Poweroff after execution (default: false)") do |po|
      poweroff = po
    end

    opts.on("--[no-]prompt", "Show a command line interface (default: true)") do |pr|
      prompt = pr
    end

  end.parse!

  if prompt
    loop do
      print '>> '
      input = gets.chomp

      case input
      when /^r(ecreate)?$/ then recreate
      when /^n(umber)? \d+$/ then number = input[/\d+/].to_i if input[/\d+/].to_i > 0
      when /^l(ist)?$/ then puts "number: #{number}", "con: #{con}", "poweroff: #{poweroff}"
      when /^p(oweroff)? ([1-9y]|true)/ then poweroff=true
      when /^p(oweroff)? ([0n]|false)/ then poweroff=false
      when /^p(lay)?$/ then play(con: con, number: number, poweroff: poweroff)
      when /^q(uit)?$/ then exit 0
      else
        puts "#{$0}: bad command"
        puts 'Commands :
    number <number>
    list
    poweroff (true|false)
    play
    recreate
    quit'
      end
    end
  else
    play(con: con, number: number, poweroff: poweroff)
  end
rescue Mysql::Error => e
  puts e.errno
  puts e.error

ensure
  con.close if con
end
