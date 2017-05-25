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
    encode_dic = {}
    @decode_dic = {}
    if $is_db
      ngram = NgramTableFromPg.new
      puts "tablename: #{$dbname}"
      ngram.setup
    else
      ngram = NgramTableFromFile.new
      ngramfile = $ngramfile
      puts "ngramfile: #{ngramfile}"
      ngram.setup(ngramfile,encode_dic,@decode_dic)
    end

    @ary = []

    #圧縮
    bin = lz78_compress(words,ngram,encode_dic)
    puts "before:#{(str.length).to_s_comma} byte"
    puts "after:#{(bin.bit_length / 8).to_s_comma} byte"
    ngram.print_rate
    ngram.print_add_table
    ngram.finish
  end

  def decode(bin , first_word ,file = 'decode.txt')
    ngram = NgramTableFromPg.new
    ngram.setup
    #復号
    #ranks = d_omega(bin)
    #ranks.shift
    #first = first_word

    str = lz78_decompress(ngram,@ary ,@first)

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
    bin = lz78convert_mix(results,ngram,encode_dic)
    p '2-gram lz'
    p "content:#{bin.bit_length / 8}"
    bin
  end

  def lz78convert_2gram(lz78dict,ngram,encode_dic)
    bin = 4
    (1..results.count-1).each do |i|
      rank = ngram.rank([results[i-(n-1)..i][0]],encode_dic,@decode_dic)
      bin = omega(bin,rank)
      bin = omega( bin ,results[i][1] + 1) #0は符号化できない
    end
    bin
  end

  def lz78convert_mix(lz78dict,ngram,encode_dic)
    dict = NgramTableFromFile.new
    edic = {}
    ddic = {}
    dict.setup($monogramfile,edic,ddic)
    bin = 0
    (1..lz78dict.count-1).each do |i|
      if bin != 0 && rank = ngram.check_rank([lz78dict[i-1][0],lz78dict[i][0]],encode_dic)
        bin << 1
        bin = omega(bin,rank)
      else
        if rank = dict.check_rank([lz78dict[i][0]],edic)
          bin << 2
          bin += 2
          bin = omega(bin,rank)
        else
          bin << 2
          bin += 3
          lz78dict[i][0].unpack("C*").each do |char|
            bin << 8
            bin += char
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

    length = bin.bit_length
    while(length > 0)
      if(bin[bin.bit_length - 1] == 0)
        bin.erase_msb(1)
        length -= 1
        (rank,bin,length) = decode()
        word = ngram.next_word(rank)
      else
        if(bin[bin.bit_length - 2] == 0)
          bin.erase_msb(2)
          length -= 2
          (rank,bin,length) = decode()
          word = ngram.next_word(rank)
        else
          bin.erase_msb(2)
          length -= 2
          (rank,bin,length) = decode()
          word = rank.chr
        end
      end
      (rank,bin,length) = decode()
      freq = rank.chr

      ary << [word,freq]
    end

    #omega decode
    codes = bin
    length = bin.bit_length
    while length > 0
      n = 1
      while codes[length - 1] == 1
        length -= (n + 1)
        (n,codes) = codes.divmod(1 << length)
      end
      ary.push(n)
      length -= 1
    end
    ary
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
  ngram.compress $targetfile #cantrbry/alice29.txt
  #ngram.decode 0,0
  puts Benchmark::CAPTION
}
