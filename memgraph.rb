#!/bin/env ruby
#
# メモリプロファイラ
#
require 'gnuplot'
require 'objspace'
require './tools'

module MemProf
  PROFILE_RESOLUTION = 0.01

  WATCH_TYPE = [
      :TOTAL#, :T_ARRAY, :T_STRING, :T_HASH
  ]
  TEXT_OUTPUT = false

  GNUPLOT_OUTPUT = true
  GNPULOT_FORMAT = "png"
  GNUPLOT_OUTFILE = "memory.png"

  MAX_OUTPUT = true

  OUTPUT_OBJECT_NUMBER = false

  mem_snapshot = []
  Thread.new(mem_snapshot) do |ms|
    prevtime = 0
    while true do
      currenttime = Process.times.utime
      if currenttime - prevtime > PROFILE_RESOLUTION then
        if OUTPUT_OBJECT_NUMBER
          ms.push [currenttime, ObjectSpace.count_objects]
        else
          ms.push [currenttime, {TOTAL: ObjectSpace.memsize_of_all}]
        end
      end
      prevtime = currenttime
      Thread.pass
    end
  end

  END {
    if TEXT_OUTPUT
      WATCH_TYPE.each do |ev|
        print "# #{ev} \n"
        mem_snapshot.each do |t, v|
          print "#{t} #{v[ev]}\n"
        end
        print "\n\n"
      end
    end

    if GNUPLOT_OUTPUT
      Gnuplot.open do |gp|
        Gnuplot::Plot.new(gp) do |plot|
          plot.terminal GNPULOT_FORMAT
          plot.output GNUPLOT_OUTFILE
          plot.title "Memory usage"
          x = mem_snapshot.map {|n| n[0]}
          WATCH_TYPE.each do |ev|
            y = mem_snapshot.map {|n| n[1][ev]}
            plot.data << Gnuplot::DataSet.new([x, y]) do |ds|
              ds.with = "line"
              ds.title = ev.to_s.sub(/T_/,'')
            end
          end
        end
      end
    end

    if MAX_OUTPUT
      WATCH_TYPE.each do |ev|
        max = 0
        mem_snapshot.each do |t, v|
          max = v[ev] if max < v[ev]
        end
        puts "#{ev} Memory MAX : #{max.to_s_comma} byte"
      end
    end
  }
end

$0 = ARGV[0]
fn = ARGV[0]
ARGV.shift

load fn, true