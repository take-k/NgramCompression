require 'benchmark'
require './encode.rb'
require './ngram_table.rb'
require './tools.rb'
include Benchmark

$targetfile = 'cantrbry/alice29.txt'
$is_db = false
$n = 2
$ngramfile = 'n-grams/w2-s.tsv'
$dbname = 'coca2gram'
$monogramfile = 'n-grams/dic10000'
#==================Ngram処理====================

class NgramCompression

  def initialize
    @excludes = [",",".",";",":","?","!","`","-","_","[","]","'","(",")","\"","\r\n","\n","\r"]
  end

  def compress(file)
    puts "targetfile: #{file} ========================="
    str = ''
    File.open(file,'rb') do |io|
      str = io.read
    end
    #parse
    regex = Regexp.new(" |#{@excludes.map{|s| "(#{Regexp.escape(s)})"}.join('|')}")
    words = str.split(regex)
    @first = words[0] #TODO delete

    #ngramセットアップ
    @n = $n
    if $is_db
      ngram = NgramTableFromPg.new
      puts "tablename: #{$dbname}"
      ngram.setup
    else
      ngram = NgramTableFromFile.new
      puts "ngramfile: #{$ngramfile}"
      ngram.setup($ngramfile)
    end

    @ary = []

    #圧縮
    bin = lz78_compress(words,ngram)
    puts "before:#{(str.length).to_s_comma} byte"
    puts "after:#{(bin.bit_length / 8).to_s_comma} byte"
    ngram.print_rate
    ngram.print_add_table
    ngram.finish
    bin
  end

  def decode(bin ,file = 'decode.txt')
    if $is_db
      ngram = NgramTableFromPg.new
      puts "tablename: #{$dbname}"
      ngram.setup
    else
      ngram = NgramTableFromFile.new
      ngramfile = $ngramfile
      puts "ngramfile: #{ngramfile}"
      ngram.setup(ngramfile)
    end
    #復号
    #ranks = d_omega(bin)
    #ranks.shift
    #first = first_word

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
    bin = lz78convert_mix(results,ngram)
    p '2-gram lz'
    p "content:#{bin.bit_length / 8}"

#    p @ary
#    p lz78deconvert_mix(bin,ngram)

    bin
  end

  def lz78convert_2gram(lz78dict,ngram)
    bin = 4
    (1..results.count-1).each do |i|
      rank = ngram.rank([results[i-(n-1)..i][0]],true)
      bin = omega(bin,rank)
      bin = omega( bin ,results[i][1] + 1) #0は符号化できない
    end
    bin
  end

  def lz78convert_mix(lz78dict,ngram)
    dict = NgramTableFromFile.new
    dict.setup($monogramfile)
    bin = 0
    (0..lz78dict.count-1).each do |i|
      if bin != 0 && rank = ngram.rank([lz78dict[i-1][0],lz78dict[i][0]])
        bin <<= 1
        bin = omega(bin,rank)
      else
        if rank = dict.rank([lz78dict[i][0]])
          bin <<= 2
          bin += 2
          bin = omega(bin,rank)
        else
          bin <<= 2
          bin += 3
          bin = omega(bin,lz78dict[i][0].size + 1)
          lz78dict[i][0].unpack("C*").each do |char|
            bin = omega(bin,char)
          end
        end
      end
      bin = omega( bin ,lz78dict[i][1] + 1) #0は符号化できない
    end
    dict.finish
    dict.print_rate
    dict.print_add_table
    bin
  end

  def lz78deconvert_mix(bin,ngram)
    dict = NgramTableFromFile.new
    edic = {}
    ddic = {}
    dict.setup($monogramfile,edic,ddic)
    ary = []
    lz78dict = []

    pre = ''
    length = bin.bit_length
    while(length > 0)
      if(bin[length - 1] == 0)
        length -= 1
        (rank,length) = decode_omega(bin,length)
        word = ngram.next_word([pre],rank)
      else
        if(bin[length - 2] == 0)
          length -= 2
          (rank,length) = decode_omega(bin,length)
          word = dict.next_word([],rank)
        else
          length -= 2
          (size,length) = decode_omega(bin,length)#サイズ情報
          size -= 1
          word = ''
          (1..size).each do |i|
            (char,length) = decode_omega(bin,length)
            word << char.chr
          end
        end
      end
      (freq,length) = decode_omega(bin,length)
      freq -= 1
      ary << [word,freq]
      pre = word
    end
    ary
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
    puts "#{@n}gram naive"
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
puts Benchmark.measure {
  bin = ngram.compress $targetfile #cantrbry/alice29.txt
  ngram.decode bin
  puts Benchmark::CAPTION
}
