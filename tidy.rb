#!/usr/bin/ruby

require 'date'
require 'pathname'

USAGE = "usage: #{$PROGRAM_NAME} <snapshot-directory> <snapshot-pattern>

For example:
  #{$PROGRAM_NAME} /snapshot/system 'root-%Y-%m-%d-%H%M%S'"
TIME_ZONE = Time.now.strftime("%z")
SNAPSHOT_DIRECTORY = ARGV[0]
SNAPSHOT_PATTERN = ARGV[1]

if SNAPSHOT_PATTERN.nil? || SNAPSHOT_PATTERN.nil?
  abort(USAGE)
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

ss_dir = Pathname::new(SNAPSHOT_DIRECTORY)
archives = ss_dir.children.sort {|x, y| y <=> x }

keep = []
delete = []
for archive in archives
  # Parse the timestamp
  time = begin
    DateTime.strptime(archive.basename.to_s + TIME_ZONE, SNAPSHOT_PATTERN + '%z')
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

keep.each do |archive|
  puts("\033[1;32m" + '✔️ ' + "\033[0m" + archive.to_s)
end

delete.each do |archive|
  puts("\033[1;31m" + '✘ ' + "\033[0m" + archive.to_s)
end

puts("#{keep.length} snapshots will be kept, and #{delete.length} snapshots will be deleted.")
