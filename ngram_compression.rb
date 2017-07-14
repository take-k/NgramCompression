require 'optparse'
require 'benchmark'
require './encode.rb'
require './ngram_table.rb'
require './tools.rb'

include Benchmark

$info = false

$naive = false
$lz78 = false
$indexcoding = false
$monogramfile = 'n-grams/dic10000'
$omega_encode = false
$test = false
$show_distribution = false

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

opts.parse!(ARGV)

$targetfile = ARGV[0] ? ARGV[0]:'cantrbry/alice29.txt'
$is_db = config[:d] != nil || ENV['DB'] == 'true'
$n = 2
$ngramfile = ARGV[1] ? ARGV[1]:'n-grams/w2-s.tsv'
$dbname = ARGV[1] ? ARGV[1]:'google2gram'

#==================Ngram処理====================

class NgramCompression

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

    #ngramセットアップ
    if $is_db
      ngram = NgramTableFromPg.new($dbname)
      puts "tablename: #{$dbname}" if $info
    else
      ngram = NgramTableFromFile.new($ngramfile)
      puts "ngramfile: #{$ngramfile}" if $info
    end

    #圧縮
    if $naive
      bin = naive_compress(words,ngram)
    elsif $lz78
      bin = lz78_compress(words,ngram)
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

    str = lz78_decompress(bin,ngram)

    File.open(file, 'wb') do |f|
      f.write(str)
    end

    ngram.finish
  end
  #=====
  def ppm_compress(words)
    bin = 0
    file_names = ["test1gm","test2gm","test3gm","test4gm","test5gm"]
    max_n = file_names.size
    ngrams = file_names.each_with_index.map {|name,i| NgramTableFromFile.new(name,i+1)}
    words.each_with_index do |word,i|
      ngrams.reverse_each do |ngram|
        freq = ngram.rank(words[(i - (ngram.n - 1))..i],true)
        bin = range_code(bin,freq)
      end
    end
    bin
  end
  ###========================================================
  def convert_to_ranks(words,ngram)#最初の文字群とrankの配列
    n = ngram.n
    first_words = []
    ranks = []
    words.each_with_index do |word,i|
      if i < (n-1)
        first_words << word
      else
        words[i-(n-1)..i]
        rank = ngram.rank(words[i-(n-1)..i],false)
        ranks << rank if rank != nil
      end
    end
    [first_words,ranks]
  end

  def lz78_compress(words,ngram)
    words_hash = {[]=>0}
    results = []
    counter = 0
    ary = []

    words.each_with_index do |word,i|
      ary << word
      if words_hash[ary] == nil
        counter += 1
        words_hash[ary] = counter # {[a]=>1,[a,b]=>2}

        results << [word,words_hash[ary[0,ary.count-1]]]
        ary = []
      elsif i == words.count-1 #最後の文字が出力されていない場合
        results << ['',words_hash[ary]]
      end
    end

    output(results.to_s,$lz78_file) if $show_lz78

    monogram = NgramTableFromFile.new($monogramfile)

    bin = lz78convert_mix(results,ngram,monogram)

    puts '--hit rate--' if $info
    ngram.print_rate if $info

    monogram.print_rate if $info
    monogram.finish

    bin
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

  def lz78convert_2gram(lz78dict,ngram)
    bin = 4
    (1..results.count-1).each do |i|
      rank = ngram.rank([results[i-(n-1)..i][0]],true)
      bin = delta(bin,rank)
      bin = delta( bin ,results[i][1] + 1) #0は符号化できない
    end
    bin
  end

  $ll = 0
  def lz78convert_mix(lz78dict,ngram,monogram = NgramTableFromFile.new($monogramfile))
    @length_ngram = 0
    @length_1gram = 0
    @length_raw = 0
    @length_code = 0
    @num_ngram = 0
    @num_1gram = 0
    @num_raw = 0
    @total = 0
    ol = 0
    bin = 0
    int_encode = $omega_encode ? method(:omega):method(:delta)

    dist_ngram = []
    dist_1gram = []
    dist_raw = []
    dist_index = []

    ranks_ngram = []
    ranks_1gram = []

    (0..lz78dict.count-1).each do |i|
      length = lz78dict[i][0].length
      @total += length
      ol = bin.bit_length if $info
      if $indexcoding
        bin = int_encode( bin ,lz78dict[i][1] + 1)
      else
        bin <<= i.bit_length
        bin += lz78dict[i][1]
      end
      @length_code += bin.bit_length - ol if $info
      count_collection(dist_index,lz78dict[i][1]) if $show_distribution

      ol = bin.bit_length if $info
      if bin != 0 && rank = ngram.rank_mru_i([lz78dict[i][1] == 0 ? lz78dict[i-1][0]: lz78dict[lz78dict[i][1] - 1][0],lz78dict[i][0]])
        @num_ngram += length if $info
        bin <<= 1
        bin = int_encode.call(bin,rank)
        @length_ngram += bin.bit_length - ol if $info
        count_collection(dist_ngram,rank) if $show_distribution
        ranks_ngram << rank if $show_ranks
      else
        if rank = monogram.rank_mru_i([lz78dict[i][0]])
          @num_1gram += length if $info
          bin <<= 2
          bin += 2
          bin = int_encode.call(bin,rank)
          @length_1gram += bin.bit_length - ol if $info
          count_collection(dist_1gram,rank) if $show_distribution
          ranks_1gram << rank if $show_ranks
        else
          @num_raw += length if $info
          bin <<= 2
          bin += 3
          bin = int_encode.call(bin,lz78dict[i][0].size + 1)
          lz78dict[i][0].unpack("C*").each do |char|
            bin = int_encode.call(bin,char) #TODO:fix
            count_collection(dist_raw,char) if $show_distribution
          end
          @length_raw += bin.bit_length - ol if $info
        end
      end
    end

    puts '--lz78 data--' if $info
    bitl = bin.bit_length / 8
    puts_rate(@num_ngram,@total , 'ngram chars') if $info
    puts_rate(@num_1gram,@total , '1gram chars') if $info
    puts_rate(@num_raw,@total , 'rawtxt chars') if $info

    puts '--compression size--' if $info
    puts_rate(@length_ngram / 8,bitl,'ngram size','byte') if $info
    puts_rate(@length_1gram / 8,bitl,'1gram size','byte') if $info
    puts_rate(@length_raw / 8,bitl,'rawtxt size','byte') if $info
    puts_rate(@length_code / 8,bitl,'code size','byte') if $info

    puts_distribution([dist_ngram,dist_1gram,dist_raw,dist_index ]) if $show_distribution
    output("#{ranks_ngram.to_s}\n#{ranks_1gram.to_s}", $ranks_file) if $show_ranks
    bin
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

  def lz78deconvert_mix(bin,ngram)
    monogram = NgramTableFromFile.new($monogramfile)
    words = []
    lz78dict = []
    counter = 0

    pre = ''
    length = bin.bit_length
    while(length > 0)
      if $indexcoding
        (freq,length) = decode_omega(bin,length)
        freq -= 1
      else
        flength = length
        length -= counter.bit_length
        freq = (bin % (1 << flength)) / (1 << length)
        counter+=1
      end

      if(bin[length - 1] == 0)
        length -= 1
        (rank,length) = decode_omega(bin,length)
        word = ngram.next_word_i([freq == 0 ? pre : words[freq-1][0]],rank)
      else
        if(bin[length - 2] == 0)
          length -= 2
          (rank,length) = decode_omega(bin,length)
          word = monogram.next_word_i([],rank)
          ngram.register_word([freq == 0 ? pre : words[freq-1][0]],word) if counter != 1
        else
          length -= 2
          (size,length) = decode_omega(bin,length)#サイズ情報
          size -= 1
          word = ''
          (1..size).each do |i|
            (char,length) = decode_omega(bin,length)
            word << char.chr
          end
          monogram.register_word([],word)
          ngram.register_word([freq == 0 ? pre : words[freq-1][0]],word) if counter != 1
        end
      end
      words << [word,freq]
      pre = word
    end
    words
  end

  def lz78_decompress(bin,ngram)
    words_hash = {0=>[]}
    counter = 0

    pairs = lz78deconvert_mix(bin,ngram)

    results = []
    pairs.each do |word,num|
      words = words_hash[num] + [word]
      results += words
      counter += 1
      words_hash[counter] = words
    end
    join_words(results)
  end

  def naive_compress(words,ngram)
    bin = 4
    first_words,ranks = convert_to_ranks(words,ngram)
    ranks.each do |rank|
      #@ary.push(rank)
      bin = delta(bin,rank)
    end
    puts 'naive'
    ngram.print_rate
    bin
  end

  def naive_decompress(ngram,ranks,first)
    pre = first
    words = ranks.map do |rank|
      word = ngram.next_word([pre],rank)
      pre = word
    end
    join_words([first] + words)
  end

  #===============================================================
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

  def table_letter_naive_compress(add_table_str)
    table = letter_table(add_table_str)
    bin = 4
    add_table_str.each_char do |c|
      bin = omega(bin,table[c])
    end
    p '2-gram-table naive'
    p "content:#{bin.bit_length / 8}"
    bin
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
