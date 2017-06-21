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

config = {}
opts = OptionParser.new
opts.on("-d") {|v| config[:d] = true}
opts.on("-n") {|v| $naive = true}
opts.on("-l") {|v| $lz78 = true}
opts.on("-i") {|v| $info = true}
opts.on("--indexcoding") {$indexcoding = true}
opts.on("-1 value") {|v| $monogramfile = v}
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
    @n = $n
    if $is_db
      ngram = NgramTableFromPg.new($dbname)
      puts "tablename: #{$dbname}" if $info
    else
      ngram = NgramTableFromFile.new($ngramfile)
      puts "ngramfile: #{$ngramfile}" if $info
    end

    @ary = []

    #圧縮
    if $naive
      bin = naive_compress(words,ngram)
    else
      bin = lz78_compress(words,ngram)
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

  ###========================================================

  def convert_to_ranks(words,ngram)#最初の文字群とrankの配列
    n = @n
    first_words = []
    ranks = []
    words.each_with_index do |word,i|
      if i < (n-1)
        first_words << word
      else
        words[i-(n-1)..i]
        ranks << ngram.rank(words[i-(n-1)..i],true)
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
        @ary << [word,words_hash[ary[0,ary.count-1]]]
        ary = []
      elsif i == words.count-1 #最後の文字が出力されていない場合
        results << ['',words_hash[ary]]
        @ary << ['',words_hash[ary]]
      end
    end

    monogram = NgramTableFromFile.new($monogramfile)

    bin = lz78convert_mix(results,ngram,monogram)

    puts '--hit rate--' if $info
    ngram.print_rate if $info
    #ngram.print_add_table

    monogram.print_rate if $info
    monogram.finish

    bin
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
    (0..lz78dict.count-1).each do |i|
      length = lz78dict[i][0].length
      @total += length
      ol = bin.bit_length if $info
      if $indexcoding
        bin = omega( bin ,lz78dict[i][1] + 1)
      else
        bin <<= i.bit_length
        bin += lz78dict[i][1]
      end
      @length_code += bin.bit_length - ol if $info

      ol = bin.bit_length if $info
      if bin != 0 && rank = ngram.rank_mru_i([lz78dict[i][1] == 0 ? lz78dict[i-1][0]: lz78dict[lz78dict[i][1] - 1][0],lz78dict[i][0]])
        @num_ngram += length if $info
        bin <<= 1
        bin = omega(bin,rank)
        @length_ngram += bin.bit_length - ol if $info
      else
        if rank = monogram.rank_mru_i([lz78dict[i][0]])
          @num_1gram += length if $info
          bin <<= 2
          bin += 2
          bin = omega(bin,rank)
          @length_1gram += bin.bit_length - ol if $info
        else
          @num_raw += length if $info
          bin <<= 2
          bin += 3
          bin = omega(bin,lz78dict[i][0].size + 1)
          lz78dict[i][0].unpack("C*").each do |char|
            bin = omega(bin,char) #TODO:fix
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
    bin
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
      bin = omega(bin,rank)
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
    ngram.decode bin
    puts Benchmark::CAPTION
  }
else
  bin = ngram.compress $targetfile #cantrbry/alice29.txt
end
