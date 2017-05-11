require 'benchmark'
require './encode.rb'
require './ngram_table.rb'
include Benchmark

#==================Ngram処理====================

class NgramCompression

  def initialize
    @excludes = [",",".",";",":","`","\r\n","\n","\r"]
  end

  def compress(file)
    str = ''
    File.open(file,'rb') do |io|
      str = io.read
    end

    #parse
    regex = Regexp.new(" |#{@excludes.map{|s| "(#{Regexp.escape(s)})"}.join('|')}")
    words = str.split(regex)

    @first = words[0] #TODO delete

    #ngramセットアップ
    ngram = NgramTableFromCsv.new
    encode_dic = {}
    @decode_dic = {}
    @n = 1
    ngram.setup('dic',encode_dic,@decode_dic)
    @ary = []

    #圧縮
    bin = naive_compress(words,ngram,encode_dic)
    ngram.finish
  end

  def decode(bin , first_word ,file = 'decode.txt')
    ngram = NgramTableFromPg.new
    ngram.setup
    #復号
    #ranks = d_omega(bin)
    #ranks.shift
    #first = first_word

    str = lz78_decompress(ngram,@ary,@first)

    File.open(file, 'wb') do |f|
      f.write(str)
    end

    ngram.finish
  end



  ###========================================================

  def convert_to_ranks(words,ngram,encode_dic)#最初の文字群とrankの配列
    n = @n
    first_words = []
    ranks = []
    words.each_with_index do |word,i|
      if i < (n-1)
        first_words << word
      else
        words[i-(n-1)..i]
        ranks << ngram.rank(words[i-(n-1)..i],encode_dic,@decode_dic)
      end
    end
    [first_words,ranks]
  end

  def lz78_compress(words,ngram,encode_dic)
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
    p @ary

    bin = 4
    (1..results.count-1).each do |i|
      rank = ngram.rank([results[i-1][0],results[i][0]],encode_dic,@decode_dic)
      bin = omega(bin,rank)
      bin = omega( bin ,results[i][1] + 1) #0は符号化できない
    end
    p '2-gram lz'
    p "content:#{bin.bit_length / 8}"
  end

  def lz78_decompress(ngram,pairs,first)
    words_hash = {0=>[]}
    counter = 0

    str = first
    results = []
    pairs.each do |word,num|
      words = words_hash[num] + [word]
      results += words
      counter += 1
      words_hash[counter] = words
    end
    join_words(results)
  end

  def naive_compress(words,ngram,encode_dic)
    bin = 4
    first_words,ranks = convert_to_ranks(words,ngram,encode_dic)
    ranks.each do |rank|
      #@ary.push(rank)
      bin = omega(bin,rank)
    end
    puts "#{@n}gram naive"
    puts "content:#{bin.bit_length / 8}"
    bin
  end

  def naive_decompress(ngram,ranks,first)
    pre = first
    words = ranks.map do |rank|
      word = ngram.next_word([pre],rank,@decode_dic)
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

  def talbe_letter_naive_compress(add_table_str)
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

def letter_table(str)
  counts = {}
  str.each_char do |c|
    counts[c] = 0 if counts[c] == nil
    counts[c]+=1
  end
  array = counts.sort_by { |k,v| -v}
  table = {}
  array.each_with_index { |v, i|
    table[v[0]] = i + 1
  }
  table
end

ngram = NgramCompression.new
puts Benchmark.measure {
  ngram.compress 'cantrbry/alice29.txt' #cantrbry/alice29.txt
  #ngram.decode 0,0
  puts Benchmark::CAPTION
}
