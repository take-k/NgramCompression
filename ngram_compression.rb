require 'set'
require 'optparse'
require 'benchmark'
require './encode.rb'
require './ngram_table.rb'
require './tools.rb'
require './naive_compression'
require './lz78_compression'
require './ppmc'
require './ppmc_opt'

include Benchmark

$monogramfile = 'n-grams/dic10000'

config = {}
opts = OptionParser.new
opts.on("-d") {|v| config[:d] = true}
opts.on("-n") {|v| $naive = true}
opts.on("-l") {|v| $lz78 = true}
opts.on("-i") {|v| $info = true}
opts.on("--indexcoding") {$indexcoding = true}
opts.on("-1 value") {|v| $monogramfile = v}
opts.on("-o") {|v| $omega_encode = true}
opts.on("-t") {|v| $omega_encode = true; $test = true}
opts.on("--dist[=path]") { |v| $show_distribution = true , $distribution_file = v}
opts.on("--rank[=path]") { |v| $show_ranks = true , $ranks_file = v}
opts.on("--lz78[=path]") { |v| $show_lz78 = true , $lz78_file = v}
opts.on("--nonupdate") { |v| $nonupdate = true}
opts.on("--esc") { |v| $esc = v.to_i}
opts.on("--ppma") { |v| $method = PPMA}
opts.on("--ppmb") { |v| $method = PPMB}
opts.on("--ppmc") { |v| $method = PPMC}
opts.on("--ppmd") { |v| $method = PPMD}
opts.on("--nonexclusion") { |v| $nonexclusion = true}
opts.on("--maxn[=value]") { |v| $max_n = v.to_i}
opts.on("--maxcharn[=value]") { |v| $max_char_n = v.to_i}
opts.on("--ipath[=path]") { |v| $ipath = v}
opts.on("--opath[=path]") { |v| $opath = v}
opts.on("--benchmark") { |v| $benchmark = true}
opts.parse!(ARGV)

$is_db = config[:d] != nil || ENV['DB'] == 'true'
$ngramfile = ARGV[1] || 'n-grams/w2-s.tsv'
$dbname = ARGV[1] || 'google2gram'
$targetfile = ARGV[0] || 'cantrbry/alice29.txt'
$n = 2
$method ||= PPMCopt

class NgramCompression
  include NaiveCompression
  include Lz78Compression

  def initialize
    @excludes = [",",".",";",":","?","!","`","-","_","[","]","'","(",")","\"","\r\n","\n","\r"]
  end

  def compress(file)
    puts "targetfile: #{file} =========================" if $info
    str = open(file,'rb').read
    #parse
    regex = Regexp.new(" |#{@excludes.map{|s| "(#{Regexp.escape(s)})"}.join('|')}")
    words = str.split(regex)
    #@excludes.each {|x| words.delete(x)}
    #words.delete("")

    #圧縮
    if $naive
      bin = naive_compress(words)
    elsif $lz78
      bin = lz78_compress(words)
    else
      bin = ppm_compress(words)
    end
    puts "#{$targetfile} :#{(str.length).to_s_comma} -> #{(bin.bit_length / 8).to_s_comma} byte (#{(((bin.bit_length / 8.0) / str.length ) * 100.0)}%)" unless $benchmark
    puts "#{$targetfile}\t#{(str.length)}\t#{(bin.bit_length / 8)}\t#{(((bin.bit_length / 8.0) / str.length ) * 100.0)}" if $benchmark
    bin
  end

  def decode(bin ,file = 'decode.txt')
    if $is_db
      #ngram = NgramTableFromPg.new($dbname)
    else
      #ngram = NgramTableFromFile.new($ngramfile)
    end

    str = ''
    if $naive
      str = naive_decompress(words,ngram)
    elsif $lz78
      str = lz78_decompress(bin,ngram)
    else
      str = ppm_decompress(bin)
    end

    File.open(file, 'wb') do |f|
      f.write(str)
    end

    #ngram.finish
  end

  def ngram_table()
    #ngramセットアップ
    ngram = nil
    if $is_db
      ngram = NgramTableFromPg.new($dbname)
      puts "tablename: #{$dbname}" if $info
    else
      ngram = NgramTableFromFile.new($ngramfile)
      puts "ngramfile: #{$ngramfile}" if $info
    end
    ngram
  end

  def ppm_table(path = nil)
    max_n = $max_n || 5
    max_char_n = $max_char_n || 5
    method = $method || PPMCopt
    puts method.name if $info
    ngrams = max_n.downto(1).map {|i| method.new(path ? "#{path}/word#{i}.tsv" : nil,i)}
    ngrams[max_n - 1].update_freq([],"\x00", $test != nil) if max_n > 0
    char_ngrams = max_char_n.downto(1).map {|i| method.new(path ? "#{path}/char#{i}.tsv" : nil,i)}
    (0..255).each{|i| char_ngrams[max_char_n - 1].update_freq([],i.chr, $test != nil)}
    char_ngrams[max_char_n - 1].update_freq([],"", $test != nil)
    [ngrams,char_ngrams]
  end

  def ppm_compress(words)
    update = $nonupdate ? false : true
    bin = 1 #head
    cbin = 1

    ngrams,char_ngrams = ppm_table($ipath)
    rc = RangeCoder.new
    exclusion_collection = $method == PPMCopt ? Array : Set
    exclusion = exclusion_collection.new unless $nonexclusion

    char_rc = RangeCoder.new
    char_exclusion = exclusion_collection.new unless $nonexclusion

    words << "\x00"
    words.each_with_index do |word,i|
      exclusion.clear unless $nonexclusion
      hit = ngrams.any? do |ngram|
        bin,exist = ngram.freq(rc,exclusion,bin,words[(i - (ngram.n - 1))..i],update) if i >= ngram.n - 1
        exist
      end
      if !hit
        chars = word.chars << "\x00" #終端文字
        chars.each_with_index do |char,i|
          char_exclusion.clear unless $nonexclusion
          char_ngrams.any? do |char_ngram|
            cbin,exist = char_ngram.freq(char_rc,char_exclusion,cbin,chars[(i - (char_ngram.n - 1))..i],update) if i >= char_ngram.n - 1
            exist
          end
        end
      end
    end
    bin = rc.finish(bin)
    cbin = char_rc.finish(cbin)

    #ngrams.each {|n| print "n = #{n.n} ";n.print_rate} if $info
    #print "\n" if $info
    #char_ngrams.each {|n| n.print_rate} if $info
    ngrams.each {|n| n.write("#{$opath}/word#{n.n}.tsv")} if $opath
    char_ngrams.each {|n| n.write("#{$opath}/char#{n.n}.tsv")} if $opath
    puts ("word:#{bin.bit_length / 8} byte char:#{cbin.bit_length / 8} byte") if $info
    result = 1
    result = omega(result,bin.bit_length)
    result = (result << bin.bit_length) + bin
    result = (result << cbin.bit_length) + cbin
    result
  end

  def ppm_decompress(bin)
    update = $nonupdate ? false: true

    cbin = bin
    ngrams,char_ngrams = ppm_table($ipath)

    rc = RangeCoder.new
    exclusion_collection = $method == PPMCopt ? Array : Set
    exclusion = exclusion_collection.new unless $nonexclusion

    char_rc = RangeCoder.new
    char_exclusion = exclusion_collection.new unless $nonexclusion

    total_length = bin.bit_length - 1
    size,length = decode_omega(bin,total_length)
    clength = length - size
    length -= 1
    length = rc.load_low(bin,length)

    clength -= 1
    clength = char_rc.load_low(cbin,clength)

    pre_words = []
    words = []
    i = 0
    while(true)
      exclusion.clear unless $nonexclusion
      esc_ngrams = []
      word = ngrams.reduce(nil) do |symbol, ngram|
        if i >= ngram.n - 1
          symbol,length = ngram.symbol(rc,exclusion,bin,length,pre_words[pre_words.size - ngram.n + 1,ngram.n - 1],update)
          esc_ngrams << ngram
          break symbol if symbol
        end
      end
      break if word == "\x00"

      if word == nil
        chars = []
        j = 0
        pre_chars = []
        while true
          char_exclusion.clear unless $nonexclusion
          esc_char_ngrams = []
          char = char_ngrams.reduce(nil) do |symbol,char_ngram|
            if j >= char_ngram.n - 1
              symbol,clength = char_ngram.symbol(char_rc,char_exclusion,cbin,clength,pre_chars[pre_chars.size - char_ngram.n+ 1,char_ngram.n - 1],update)
              esc_char_ngrams << char_ngram
              break symbol if symbol
            end
          end
          esc_char_ngrams.each do |char_ngram|
            char_ngram.update_freq(pre_chars[pre_chars.size - char_ngram.n + 1,char_ngram.n - 1], char ,true) if update #頻度表の更新
          end
          pre_chars << char
          pre_chars.shift if pre_chars.size >= char_ngrams.size
          if char == "\x00"
            word = chars.join
            break
          end
          chars << char
          j+=1
        end
        word = chars.join
      end

      esc_ngrams.each do |ngram|
        ngram.update_freq(pre_words[pre_words.size - ngram.n + 1,ngram.n - 1], word, true) if update #頻度表の更新
      end
      pre_words << word
      pre_words.shift if pre_words.size >= ngrams.size
      words << word
      i+=1
    end
    join_words(words)
  end

  def output(str,file = nil)
    if file
      File.open(file,'wb') do |f|
        f.write(str)
      end
    else
      puts str
    end
  end

  def count_collection(collection,x)
    collection[x] = 0 if collection[x] == nil
    collection[x] += 1
  end

  def puts_distribution(dists , tag = '--distributions--' ,separator = "\n", sparse = false, with_index = true, nilstr = '')
    puts tag if $distribution_file == nil
    str = ''
    max_i = dists.reduce(0) { |max,d| max < d.count ? d.count : max}
    max_i = 1000000 if max_i > 1000000

    #stochastic
    total = dists.map do |d|
      d.reduce(0) {|sum,x| sum += (x || 0)}
    end

    (0..max_i).each do |i|
      if sparse || dists.any? { |dist| dist[i]}
        str << "#{i.to_s}," if with_index
        dists.each_with_index do |dist,j|
          str << ',' if j!= 0
          dist[i] == nil ? str << nilstr:str << (dist[i].to_f / total[j]).to_s
        end
        str << separator if i != max_i
      end
    end

    output(str,$distribution_file)
  end

  def puts_rate(x,total,prefix = 'hit', suffix = '')
    if total > 0
      puts "#{prefix}:#{x.to_s_comma} / #{total.to_s_comma}#{suffix}(#{(x.to_f/total * 100).round}%)"
    else
      puts "#{prefix} : #{x}/0#{suffix}"
    end
  end

  def join_words(words)
    str = ''
    pre = words[0]
    words.each_with_index do |word,i|
      if !@excludes.include?(pre) && !@excludes.include?(word) #TODO ハッシュ化
        str << ' ' if i != 0
      end
      str << word
      pre = word
    end
    str
  end
end

ngram = NgramCompression.new
if $info
  bin = 0
  puts Benchmark.measure {
    bin = ngram.compress $targetfile #cantrbry/alice29.txt
    puts Benchmark::CAPTION
  }

  puts Benchmark.measure {
    ngram.decode(bin)
    puts Benchmark::CAPTION
  } if $test

else
  bin = ngram.compress $targetfile #cantrbry/alice29.txt
  ngram.decode(bin) if $test
end
