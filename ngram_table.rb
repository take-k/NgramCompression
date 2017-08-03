require 'csv'
require 'pg'

class NgramTable
  attr_reader :add_table_str,:n

  def initialize
    @encode_add_table = {}
    @rank_table = {}
    @n = 1
  end

  def next_word_i(pre_words,rank)
    rank_table = pre_words.inject(@rank_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    rank_table["ranks"] = [] if rank_table["ranks"] == nil
    ranks = rank_table["ranks"]
    diff = rank
    ranks.reverse_each do |j|
      if diff == 1
        diff = j
        break if diff <= 0
      elsif j <= 0 || diff <= j
        diff -= 1
      end
    end
    ranks << rank
    diff_rank = diff

    encode_last_dic = pre_words.inject(@encode_add_table) {|d,key| d[key] == nil ? d[key] = {} : d[key]}
    word = encode_last_dic[diff_rank]
    word = self.next_word(pre_words,diff_rank) if word == nil
    word
  end

  def register_word(pre_words ,word)
    encode_last_dic = pre_words.inject(@encode_add_table) {|d,key| d[key] == nil ? d[key] = {} : d[key]}
    count = encode_last_dic.count * -1
    encode_last_dic[count] = word

    rank_table = pre_words.inject(@rank_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    rank_table["ranks"] = [] if rank_table["ranks"] == nil
    rank_table["ranks"] << count
  end

  def rank_mru_i(keywords,update = true)
    notfound = false
    words = keywords[0,keywords.size-1]
    last = keywords[-1]
    rank_table = words.inject(@rank_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    rank_table["ranks"] = [] if rank_table["ranks"] == nil
    ranks = rank_table["ranks"]
    rank = self.rank(keywords,false)
    if rank == nil
      return nil if !update
      notfound = true
      rank = self.rank(keywords,true) #更新
    end
    diff = rank
    ranks.each do |j|
      if diff == j
        diff = 1
      elsif diff < j
        diff += 1
      end
    end
    ranks << diff
    return nil if notfound
    diff
  end

  def rank_mru(keywords,update = true) words = keywords[0,keywords.size-1]
    last = keywords[-1]
    encode_add_last_dic = words.inject(@encode_add_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    rank = encode_add_last_dic[last]
    if rank == nil
      counter = encode_add_last_dic.count
      table_rank = self.rank(keywords)
      notfound = table_rank == nil
      return nil if notfound && !update
      rank = notfound ? counter : table_rank + counter
    end

    encode_add_last_dic.each do |k, v|
      encode_add_last_dic[k] = v + 1 if v < rank
    end
    encode_add_last_dic[last] = 1
    return nil if notfound
    rank
  end

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
    puts "hit: #{@total - @fail}/#{@total}(#{((@total - @fail).to_f / @total * 100.0).round})%" if @total > 0
  end
end

class NgramTableFromPg < NgramTable
  def initialize(db_name='coca2gram',n = 2)
    super()
    @n = n
    @db_name = db_name
    reset_count
    @connection = PG::connect(dbname: "ngram")
    @encode_table = {}
    @decode_table = {}
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

  def rank(keywords,update = false)
    condition = (1..keywords.count).map{|i| "word#{i} = $#{i}"}.join(' AND ')
    results = @connection.exec("SELECT rank FROM #{@db_name} WHERE #{condition}",keywords)
    @total+= 1
    not_found = (results.count == 0)
    if not_found
      @fail += 1
      words = keywords[0,keywords.size-1]
      last = keywords[-1]
      @add_table_str << keywords.join(' ') << '   '
      return nil if !update
      encode_last_dic = words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
      return encode_last_dic[last] if encode_last_dic[last] != nil
      decode_last_dic = words.inject(@decode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
      condition = (1..words.count).map{|i| "word#{i} = $#{i}"}.join(' AND ')
      word1_count_results = @connection.exec("SELECT COUNT(rank) FROM #{@db_name} WHERE #{condition}",words)
      rank = word1_count_results[0]['count'].to_i + encode_last_dic.count + 1
      encode_last_dic[last] = rank
      decode_last_dic[rank] = last
      @add_table_str << keywords.join(' ') << ' ' << rank.to_s << "\n"
    else
      rank = results[0]['rank'].to_i
    end
    rank
  end

  def next_word(pre_words,rank,use_decode_table = false)
    words = pre_words
    condition = (1..words.count).map{|i| "word#{i} = $#{i}"}.join(' AND ')
    results = @connection.exec("SELECT word2 FROM #{@db_name} WHERE #{condition} AND rank = #{rank}",words)
    if results.count == 0
      return nil if !use_decode_table
      pre_words.inject(@decode_table) { |d, key| d[key] }[rank]
    else
      results[0]['word2']
    end
  end

  def finish
    @connection.finish
  end
end
$escape_character = "ESCC"
$null_character = "NULLC"
$empty_character = "EMPTYC"
$return_character = "CRLNC"
class NgramTableFromFile < NgramTable
  attr_accessor :encode_table,:decode_table
  def initialize(file = nil,n = nil,encode_table = {},decode_table = {})
    super()
    @n = n
    @encode_table = encode_table
    @decode_table = decode_table
    reset_count
    @count = 0
    if file
      @file = file
      f = open(file,'rb')
      while (input = f.gets) do
        row = input.split("\t")
        words = row[0,row.size-1] #rank以外を取り出す
        words.each_with_index do |w,i|
          words[i] = "\x00" if w == $null_character
          words[i] = "" if w == $empty_character
          words[i] = "\r\n" if w == $return_character
        end
        rank = row[-1].to_i
        last = words.pop
        @n = words.size unless @n
        encode_last_dic = words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
        encode_last_dic[last] = rank
        decode_last_dic = words.inject(@decode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
        decode_last_dic[rank] = last
        @count += 1
      end
    end
  end

  def list(hash,i)#{{{}}}
    return [[hash]] if i == 0

    hash.reduce([]) do |array,(k,v)|
      array.concat(list(v,i-1).map{|strs| [k].concat(strs)})
    end
  end

  def write(output = @file)
    list = list(@encode_table,@n).sort {|a1,a2| a1.last <=> a2.last}.reverse.map{|a| a.join("\t")}
    str = list.join("\n")
    open(output,"wb").write(str)
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
      #@add_table_str << keywords.join(' ') << ' '
    end
    encode_last_dic[last]
  end

  def next_word(pre_words,rank)
    pre_words.inject(@decode_table) { |d, key| d[key] }[rank]
  end

  def freq(rc,exclusion,bin,keywords,update = false)
    @total += 1
    words = keywords[0,keywords.size-1]
    last = keywords[-1]
    encode_last_dic = words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    total = 1
    count_sum = 0
    hit = false
    encode_last_dic.each do |k, v|
      if !exclusion.include?(k)
        total += v
        exclusion << k
        if !hit
          if k == last
            hit = true
          else
            count_sum += v
          end
        end
      end
    end

    if hit
      f = encode_last_dic[last]
      encode_last_dic[last] += 1 if update
    else
      encode_last_dic[last] = 1 if update
      f = 1
      @fail+=1
    end

    rc.low += rc.range * count_sum / total
    rc.range = rc.range * f / total
    bin = rc.encode_shift(bin)
    [bin,hit]
  end

  def symbol(rc,exclusion,bin,length,pre_words,update = false)
    encode_last_dic = pre_words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    total = 1
    count_sum = 0
    hit = false

    last = nil
    total = encode_last_dic.reduce(1) do |s,(k,v)|
      if !exclusion.include?(k)
        s += v
      else
        s
      end
    end
    encode_last_dic.each do |k, v|
      if !exclusion.include?(k)
        if !hit
          #if rc.code < rc.low + (rc.range * (count_sum + v) / total)
          if rc.low < (rc.range * (count_sum + v) / total)
            hit = true
            last = k
          else
            count_sum += v
          end
        end
        exclusion << k
      end
    end

    f = encode_last_dic[last] ? encode_last_dic[last] : 1

    rc.low -= rc.range * count_sum / total
    rc.range = rc.range * f / total
    length = rc.decode_shift(bin,length)
    [last,length]
  end

  def update_freq(pre,symbol)
    encode_last_dic = pre.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    encode_last_dic[symbol] = 0 unless encode_last_dic[symbol]
    encode_last_dic[symbol] += 1
  end
end

class PPMA < NgramTableFromFile
  attr_accessor :esc
  def reset_count
    super
    @esc = 30
    puts "PPMA n = #{@n} esc = #{@esc} "
  end

  def freq(rc,exclusion,bin,keywords,update = false)
    words = keywords[0,keywords.size-1]
    last = keywords[-1]
    encode_last_dic = words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    total = @esc
    count_sum = 0
    hit = false
    encode_last_dic.each do |k, v|
      if !exclusion.include?(k)
        total += v
        exclusion << k
        if !hit
          if k == last
            hit = true
          else
            count_sum += v
          end
        end
      end
    end

    if hit
      f = encode_last_dic[last]
      encode_last_dic[last] += 1 if update
    else
      encode_last_dic[last] = 1 if update
      f = @esc
    end

    rc.low += rc.range * count_sum / total
    rc.range = rc.range * f / total
    bin = rc.encode_shift(bin)
    [bin,hit]
  end

end

class PPMB < NgramTableFromFile
  def reset_count
    super
    @esc = 1
  end

  def freq(rc,exclusion,bin,keywords,update = false)
    words = keywords[0,keywords.size-1]
    last = keywords[-1]
    encode_last_dic = words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    total = 1
    count_sum = 0
    hit = false
    encode_last_dic.each do |k, v|
      if !exclusion.include?(k)
        total += v
        exclusion << k
        if !hit
          if k == last && v > 1
            hit = true
          else
            count_sum += v
          end
        end
      end
    end

    if hit
      f = encode_last_dic[last] - 1
      encode_last_dic[last] += 1 if update
    else
      encode_last_dic[last] = encode_last_dic[last] ? 2:1 if update
      f = @esc
      @esc += 1 if encode_last_dic[last] == 1
    end

    rc.low += rc.range * count_sum / total
    rc.range = rc.range * f / total
    bin = rc.encode_shift(bin)
    [bin,hit]
  end

end


class PPMC < NgramTableFromFile
  def reset_count
    super
    @esc = 1
    puts "PPMC n = #{@n} esc = #{@esc} "
  end
  def freq(rc,exclusion,bin,keywords,update = false)
    words = keywords[0,keywords.size-1]
    last = keywords[-1]
    encode_last_dic = words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    total = 0
    count_sum = 0
    hit = false
    encode_last_dic.each do |k, v|
      if !exclusion.include?(k)
        total += v
        exclusion << k
        if !hit
          if k == last
            hit = true
          else
            count_sum += v
          end
        end
      end
    end
    total += @esc

    if hit
      f = encode_last_dic[last]
      encode_last_dic[last] += 1 if update
    else
      encode_last_dic[last] = 1 if update
      f = @esc
      @esc += 1
    end
    rc.low += rc.range * count_sum / total
    rc.range = rc.range * f / total
    bin = rc.encode_shift(bin)
    [bin,hit]
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
