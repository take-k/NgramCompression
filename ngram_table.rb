require 'csv'
#require 'pg'

class NgramTable
  attr_reader :add_table_str
  def reset_count
    @fail = 0
    @total = 0
    @add_table_str = ''
  end

  def finish
  end

  def print_add_table
    print "fail_words = "
    p @add_table_str
  end

  def print_rate
    puts "fail: #{@fail}/#{@total}"
  end
end

class NgramTableFromPg < NgramTable
  def initialize(db_name='coca2gram')
    @db_name = db_name
    reset_count
    @connection = PG::connect(dbname: "ngram")
  end

  def insert_str(str)
    str = @add_table_str
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
    results = @connection.exec("SELECT rank FROM #{@db_name} WHERE #{condition}",words)
    results.count > 0 ? results[0]['rank'].to_i : nil
  end

  def rank(keywords,encode_add_dic,decode_add_dic)
    words = keywords.clone
    condition = (1..words.count).map{|i| "word#{i} = $#{i}"}.join(' AND ')
    results = @connection.exec("SELECT rank FROM #{@db_name} WHERE #{condition}",words)
    @total+= 1
    if results.count == 0
      last = words.pop
      encode_last_dic = words.inject(encode_add_dic){|d,key| d[key] == nil ? d[key] = {} : d[key]}
      return encode_last_dic[last] if encode_last_dic[last] != nil
      decode_last_dic = words.inject(decode_add_dic){|d,key| d[key] == nil ? d[key] = {} : d[key]}
      condition = (1..words.count).map{|i| "word#{i} = $#{i}"}.join(' AND ')
      word1_count_results = @connection.exec("SELECT COUNT(rank) FROM #{@db_name} WHERE #{condition}",words)
      rank = word1_count_results[0]['count'].to_i + encode_last_dic.count + 1
      encode_last_dic[last] = rank
      decode_last_dic[rank] = last
      @add_table_str << keywords.join(' ') << ' ' << rank.to_s << "\n"
      @fail += 1
    else
      rank = results[0]['rank'].to_i
    end
    rank
  end

  def next_word(pre_words,rank,decode_dic)
    words = pre_words
    condition = (1..words.count).map{|i| "word#{i} = $#{i}"}.join(' AND ')
    results = @connection.exec("SELECT word2 FROM #{@db_name} WHERE #{condition} AND rank = #{rank}",words)
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

class NgramTableFromFile < NgramTable
  attr_accessor :encode_table,:decode_table
  def initialize(file = 'n-grams/dic1000',encode_table = {},decode_table = {})
    @encode_table = encode_table
    @decode_table = decode_table
    reset_count
    @count = 0
    f = open(file,'rb')
    while (input = f.gets) do
      row = input.split("\t")
      words = row[0,row.size-1] #rank以外を取り出す
      rank = row[-1].to_i
      last = words.pop
      encode_last_dic = words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
      encode_last_dic[last] = rank
      decode_last_dic = words.inject(@decode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
      decode_last_dic[rank] = last
      @count += 1
    end
  end

  def rank(keywords,update = false)
    words = keywords[0,keywords.size-1]
    last = keywords[-1]
    encode_last_dic = words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    @total+= 1
    @fail += 1 if fail = (encode_last_dic[last] == nil)
    return encode_last_dic[last] if !update

    if fail
      if keywords.size == 1
        rank = @count + 1 #1-gramのみ計算がかかるので高速化
        @count += 1
      else
        rank = encode_last_dic.count + 1
      end

      encode_last_dic[last] = rank

      decode_last_dic = words.inject(@decode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
      decode_last_dic[rank] = last
      #@add_table_str << keywords.join(' ') << ' ' << "\n"
      @add_table_str << keywords.join(' ') << ' '
    end
    encode_last_dic[last]
  end

  def next_word(pre_words,rank)
    pre_words.inject(@decode_table) { |d, key| d[key] }[rank]
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
