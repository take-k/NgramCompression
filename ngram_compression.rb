require 'set'
require 'optparse'
require 'benchmark'
require './encode.rb'
require './ngram_table.rb'
require './tools.rb'
require './naive_compression'
require './lz78_compression'

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
opts.on("--nonupdate") { |v| $nonupdate = false}
opts.on("--output") { |v| $table_output = true}
opts.on("--esc") { |v| $esc = v.to_i}
opts.on("--maxn") { |v| $max_n = v.to_i}
opts.on("--max_char_n") { |v| $max_char_n = v.to_i}
opts.on("--file") { |v| $file = true}
opts.parse!(ARGV)

$is_db = config[:d] != nil || ENV['DB'] == 'true'
$ngramfile = ARGV[1] || 'n-grams/w2-s.tsv'
$dbname = ARGV[1] || 'google2gram'
$targetfile = ARGV[0] || 'cantrbry/alice29.txt'
$n = 2

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
    puts "#{$targetfile} :#{(str.length).to_s_comma} -> #{(bin.bit_length / 8).to_s_comma} byte (#{(((bin.bit_length / 8.0) / str.length ) * 100.0)}%)"
    bin
  end

  def decode(bin ,file = 'decode.txt')
    if $is_db
      ngram = NgramTableFromPg.new($dbname)
    else
      ngram = NgramTableFromFile.new($ngramfile)
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

    ngram.finish
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

  def ppm_table(file = false)
    max_n = $max_n || 5
    max_char_n = $max_char_n || 5
    ngrams = max_n.downto(1).map {|i| PPMC.new(file ? "n-grams/word#{i}gm" : nil,i)}
    ngrams[max_n - 1].encode_table["\x00"] ||= 1
    char_ngrams = max_char_n.downto(1).map {|i| PPMC.new(file ? "n-grams/test#{i}gm" : nil,i)}
    (0..255).each{|i| char_ngrams[max_char_n - 1].encode_table[i.chr] ||= 1}
    char_ngrams[max_char_n - 1].encode_table[""] ||= 1
    [ngrams,char_ngrams]
  end

  def ppm_compress(words)
    update = $nonupdate ? false : true
    bin = 1 #head
    cbin = 1

    ngrams,char_ngrams = ppm_table($file)
    rc = RangeCoder.new
    exclusion = Set.new

    char_rc = RangeCoder.new
    char_exclusion = Set.new

    words << "\x00"
    words.each_with_index do |word,i|
      exclusion.clear
      hit = ngrams.any? do |ngram|
        bin,exist = ngram.freq(rc,exclusion,bin,words[(i - (ngram.n - 1))..i],update) if i >= ngram.n - 1
        exist
      end
      if !hit
        chars = word.chars << "\x00" #終端文字
        chars.each_with_index do |char,i|
          char_exclusion.clear
          char_ngrams.any? do |char_ngram|
            cbin,exist = char_ngram.freq(char_rc,char_exclusion,cbin,chars[(i - (char_ngram.n - 1))..i],update) if i >= char_ngram.n - 1
            exist
          end
        end
      end
    end
    bin = rc.finish(bin)
    cbin = char_rc.finish(cbin)

    ngrams.each {|n| print "n = #{n.n} ";n.print_rate} if $info
    char_ngrams.each {|n| n.print_rate} if $info
    ngrams.each {|n| n.write("n-grams/output/word#{n.n}out.tsv")} if $table_output
    char_ngrams.each {|n| n.write("n-grams/output/char#{n.n}.tsv")} if $table_output
    puts ("word:#{bin.bit_length / 8} byte char:#{cbin.bit_length / 8} byte")
    result = 1
    result = omega(result,bin.bit_length)
    result = (result << bin.bit_length) + bin
    result = (result << cbin.bit_length) + cbin
    result
  end

  def ppm_decompress(bin)
    update = $nonupdate ? false: true

    cbin = bin
    ngrams,char_ngrams = ppm_table($file)

    rc = RangeCoder.new
    exclusion = Set.new
    char_rc = RangeCoder.new
    char_exclusion = Set.new

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
      exclusion.clear
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
          char_exclusion.clear
          esc_char_ngrams = []
          char = char_ngrams.reduce(nil) do |symbol,char_ngram|
            if j >= char_ngram.n - 1
              symbol,clength = char_ngram.symbol(char_rc,char_exclusion,cbin,clength,pre_chars[pre_chars.size - char_ngram.n+ 1,char_ngram.n - 1],update)
              esc_char_ngrams << char_ngram
              break symbol if symbol
            end
          end
          esc_char_ngrams.each do |char_ngram|
            char_ngram.update_freq(pre_chars[pre_chars.size - char_ngram.n + 1,char_ngram.n - 1], char) if update #頻度表の更新
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
        ngram.update_freq(pre_words[pre_words.size - ngram.n + 1,ngram.n - 1], word) if update #頻度表の更新
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
  puts Benchmark.measure {
    bin = ngram.compress $targetfile #cantrbry/alice29.txt
    ngram.decode(bin) if $test
    puts Benchmark::CAPTION
  }
else
  bin = ngram.compress $targetfile #cantrbry/alice29.txt
end
