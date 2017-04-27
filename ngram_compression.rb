require 'csv'
require 'pg'
require 'benchmark'
require './encode.rb'
include Benchmark

$add_table_str = ''

class NgramTableFromPg
  def setup(encode_dic=nil,decode_dic=nil)
    @connection = PG::connect(dbname: "ngram")
  end

  def insert_str(str)
    str = $add_table_str
    counts = Array.new(256){|i| [i,0]}
    str.each_byte do |b|
      counts[b][1] += 1
    end
    counts.sort_by! { |a| -a[1]}

    counts.each_with_index do |a,i|
      @connection.exec("INSERT INTO letter1gram(letter, rank) VALUES ($1,$2)",[a[0].chr("UTF-8"),i+2])
    end
  end

  def rank_from(keywords)
    condition = (1..keywords.count).map{|i| "word#{i} = $#{i}"}.join(' AND ')
    results = @connection.exec("SELECT rank FROM coca2gram WHERE #{condition}",words)
    results.count > 0 ? results[0]['rank'].to_i : nil
  end

  def rank(keywords,encode_add_dic,decode_add_dic)
    words = keywords.clone
    condition = (1..words.count).map{|i| "word#{i} = $#{i}"}.join(' AND ')
    results = @connection.exec("SELECT rank FROM coca2gram WHERE #{condition}",words)
    if results.count == 0
      last = words.pop
      encode_last_dic = words.inject(encode_add_dic){|d,key| d[key] == nil ? d[key] = {} : d[key]}
      return encode_last_dic[last] if encode_last_dic[last] != nil
      decode_last_dic = words.inject(decode_add_dic){|d,key| d[key] == nil ? d[key] = {} : d[key]}
      condition = (1..words.count).map{|i| "word#{i} = $#{i}"}.join(' AND ')
      word1_count_results = @connection.exec("SELECT COUNT(rank) FROM coca2gram WHERE #{condition}",words)
      rank = word1_count_results[0]['count'].to_i + encode_last_dic.count + 1
      encode_last_dic[last] = rank
      decode_last_dic[rank] = last
      $add_table_str << keywords.join(' ') << ' ' << rank.to_s << "\n"
    else
      rank = results[0]['rank'].to_i
    end
    rank
  end

  def next_word(pre_words,rank,decode_dic)
    words = pre_words
    condition = (1..words.count).map{|i| "word#{i} = $#{i}"}.join(' AND ')
    results = @connection.exec("SELECT word2 FROM coca2gram WHERE #{condition} AND rank = #{rank}",words)
    if results.count == 0
      pre_words.inject(decode_dic) { |d, key| d[key] }[rank]
    else
      results[0]['word2']
    end
  end

  def finish
    @connection.finish
  end

end

class NgramTableFromCsv
  def setup(encode_dic,decode_dic)
    CSV.foreach('w2-s.tsv', :col_sep => "\t") do |row|
      encode_dic[row[0]] = {} if encode_dic[row[0]] == nil
      encode_dic[row[0]][row[1]] = row[2].to_i
      decode_dic[row[0]] = {} if decode_dic[row[0]] == nil
      decode_dic[row[0]][row[2].to_i] = row[1]
    end
  end

  def rank(keywords,encode_add_dic,decode_add_dic)
    words = keywords.clone
    last = words.pop
    encode_last_dic = words.inject(encode_add_dic){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    decode_last_dic = words.inject(decode_add_dic){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    if encode_last_dic[last] == nil
      rank = encode_last_dic.count + 1
      encode_last_dic[last] = rank
      decode_last_dic[rank] = last
      $add_table_str << keywords.join(' ') << ' ' << "\n"
    end
    encode_last_dic[last]
  end

  def next_word(pre_words,rank,decode_dic)
    pre_words.inject(decode_dic) { |d, key| d[key] }[rank]
  end

  def finish
  end
end

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
    ngram.setup(encode_dic,@decode_dic)
    @ary = []

    #圧縮
    bin = lz78_compress(words,ngram,encode_dic)
    ngram.finish
  end

  def decode(bin , first_word ,file = 'decode.txt')
    ngram = NgramTableFromPg.new
    ngram.setup
    #復号
    #ranks = d_omega(bin)
    #ranks.shift
    #first = first_word

    str = naive_decompress(ngram,@ary,@first)

    File.open(file, 'wb') do |f|
      f.write(str)
    end

    ngram.finish
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
    (1..words.count-1).each do |i|
      rank = ngram.rank([words[i-1],words[i]],encode_dic,@decode_dic)
      #@ary.push(rank)
      bin = omega(bin,rank)
    end
    p '2-gram naive'
    p "content:#{bin.bit_length / 8}"
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

  def talbe_letter_naive_compress
    add_table_str = $add_table_str
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
  ngram.compress 'calgary/book1' #cantrbry/alice29.txt
  ngram.decode 0,0
  puts Benchmark::CAPTION
}
