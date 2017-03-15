require 'csv'
require 'pg'
require 'benchmark'
include Benchmark

def alpha(number,x)
  (number << x) + x
end

def gamma(number,x)
  digit = x.bit_length
  (number << (digit + digit - 1)) + x
end

def delta(number,x)
  digit = x.bit_length
  (gamma(number,digit) << (digit - 1)) + digit - (1 << digit)
end

def omega(number,x)
  code = 0
  return (number << 1) if x == 1 #最下位ビットに0
  y = x
  while y > 1
    code = (y << code.bit_length) + code
    y = y.bit_length - 1
  end
  code = code << 1 #最下位ビットに0
  (number << code.bit_length) + code
end

def d_omega(number)
  ary = []
  codes = number
  length = number.bit_length
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

class NgramTableFromPg
  def setup(encode_dic=nil,decode_dic=nil)
    @connection = PG::connect(dbname: "ngram")
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
      $add_table_str << keywords.join(' ') << ' ' << "\n"
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
$add_table_str = ''
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

class NgramCompression

  def initialize
    @excludes = [",",".",";",":","`","\r\n","\n","\r"]
  end

  def encode(file)
    str = ''
    File.open(file,'rb') do |io|
      str = io.read
    end

    regex = Regexp.new(" |#{@excludes.map{|s| "(#{Regexp.escape(s)})"}.join('|')}")
    words = str.split(regex)

    @first = words[0] #TODO delete

    table = NgramTableFromPg.new
    encode_dic = {}
    @decode_dic = {}
    table.setup(encode_dic,@decode_dic)#TODO csv
    @ary = []
    bin = 4
    (1..words.count-1).each do |i|
      rank = table.rank([words[i-1],words[i]],encode_dic,@decode_dic)
      @ary.push(rank)
      bin = omega(bin,rank)
    end
    table.finish

    #@decode_dic.inject(0){|sum , h| sum + h[0].size + h[1].inject(0){|s,i| s + i.size}}
  end

  def decode(bin , first_word ,file = 'decode.txt')
    table = NgramTableFromPg.new
    table.setup
    #復号
    #ranks = d_omega(bin)
    #ranks.shift
    #first = first_word

    ranks = @ary
    first = @first

    str = first
    pre = first
    ranks.each do |rank|
      word = table.next_word([pre],rank,@decode_dic)
      if !@excludes.include?(pre) && !@excludes.include?(word) #TODO ハッシュ化
        str << ' '
      end
      str << word
      pre = word
    end

    File.open(file, 'wb') do |f|
      f.write(str)
    end

    table.finish
  end
end

ngram = NgramCompression.new
puts Benchmark.measure {
  ngram.encode 'cantrbry/alice29.txt'
  ngram.decode 0,0
  puts Benchmark::CAPTION
}
