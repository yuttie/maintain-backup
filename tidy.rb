#!/usr/bin/ruby

require 'date'
require 'optparse'
require 'pathname'

TIME_ZONE = Time.now.strftime("%z")

optp = OptionParser.new
optp.banner = "Usage: #{$PROGRAM_NAME} <snapshot-pattern>"
optp.on('-n', '--dry-run') {|v| v }
optp.on('--help') {|v| v }

opts = {}
optp.parse!(ARGV, into: opts)
SNAPSHOT_PATTERN = ARGV[0]

if opts[:help] || SNAPSHOT_PATTERN.nil?
  puts("#{optp}
Example:
    #{$PROGRAM_NAME} 'data/home@%Y-%m-%d-%H%M%S'")
  exit
end

def add_hours(t, hours)
  ret = t + hours * 60 * 60
  unless ret.sec == t.sec and ret.min == t.min
    raise "Leap detected"
  end
  ret
end

def add_days(t, days)
  dt = t.to_datetime
  (dt + days).to_time
end

def add_weeks(t, weeks)
  add_days(t, 7 * weeks)
end

def add_months(t, months)
  dt = t.to_datetime
  (dt >> months).to_time
end

def add_years(t, years)
  add_months(t, 12 * years)
end

def start_of_hour(t)
  Time.new(t.year, t.mon, t.day, t.hour, nil, nil, t.utc_offset)
end

def start_of_day(t)
  Time.new(t.year, t.mon, t.day, nil, nil, nil, t.utc_offset)
end

def start_of_week(t)
  t = start_of_day(t)
  until t.monday?
    t = add_days(t, -1)
  end
  t
end

def start_of_month(t)
  Time.new(t.year, t.mon, nil, nil, nil, nil, t.utc_offset)
end

def start_of_year(t)
  Time.new(t.year, nil, nil, nil, nil, nil, t.utc_offset)
end

def enclosing_period(t, add, start_of)
  s = start_of.call(t)
  e = add.call(s, 1)
  [s, e]
end

now = Time.now

periods = []
0.downto(-24) do |h|
  periods << [
    enclosing_period(add_hours(now, h), method(:add_hours), method(:start_of_hour)),
    []
  ]
end
-1.downto(-7) do |d|
  periods << [
    enclosing_period(add_days(now, d), method(:add_days), method(:start_of_day)),
    []
  ]
end
-1.downto(-4) do |w|
  periods << [
    enclosing_period(add_weeks(now, w), method(:add_weeks), method(:start_of_week)),
    []
  ]
end
-1.downto(-12) do |m|
  periods << [
    enclosing_period(add_months(now, m), method(:add_months), method(:start_of_month)),
    []
  ]
end

archives = STDIN.each.map {|line| line.chomp }.to_a.sort {|x, y| y <=> x }

keep = []
delete = []
for archive in archives
  # Parse the timestamp
  time = begin
    DateTime.strptime(archive + TIME_ZONE, SNAPSHOT_PATTERN + '%z')
  rescue ArgumentError
    next
  end.to_time

  allocated = false
  periods.each do |(s, e), found|
    if found.length == 0 && s <= time && time < e
      found << archive
      keep << archive
      allocated = true
      break
    end
  end
  unless allocated
    delete << archive
  end
end

if opts[:"dry-run"]
  keep.each do |archive|
    puts("\033[1;32m" + '✔️ ' + "\033[0m" + archive.to_s)
  end

  delete.each do |archive|
    puts("\033[1;31m" + '✘ ' + "\033[0m" + archive.to_s)
  end

  puts("#{keep.length} snapshots will be kept, and #{delete.length} snapshots will be deleted.")
else
  delete.each do |archive|
    puts(archive.to_s)
  end
end
