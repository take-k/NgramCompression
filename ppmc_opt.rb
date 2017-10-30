require "./ngram_table"
require './binary_indexed_tree'

class PPMCopt < NgramTableFromFile
  def initialize(file = nil,n = nil)
    super(file,n)
    @symbol_inc = 1
    @symbol_init = 1
    @escape_inc = 1
    @escape_init = 1
  end

  def freq(rc,exclusion,bin,keywords,update = false)
    words = keywords[0,keywords.size-1]
    last = keywords[-1]
    encode_last_dic = words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}

    if encode_last_dic[:esc] == nil # init
      update_freq_by_dic(encode_last_dic,:esc)
    end

    bit = encode_last_dic[:bit]

    total = bit.sum_all
    escape_count_sum = bit.sum(encode_last_dic[:esc])

    if encode_last_dic[last]
      f = bit.select(encode_last_dic[last])
      count_sum = bit.sum(encode_last_dic[last]) - f
      hit = true
      target = encode_last_dic[last]
    else
      f = bit.select( encode_last_dic[:esc])
      update_freq_by_dic(encode_last_dic, :esc)
      count_sum = escape_count_sum - f
      hit = false
      target = encode_last_dic[:esc]
    end
    if exclusion
      exclusion.each do |ex|
        if encode_last_dic[ex] && ex != :bit &&  ex !=:esc
          ef = bit.select(encode_last_dic[ex])
          count_sum -= ef if target > encode_last_dic[ex]
          total -= ef
        end
      end
      if !hit
        exclusion.concat(encode_last_dic.keys)
        exclusion.uniq!
      end
    end

    update_freq_by_dic(encode_last_dic, last) if update

    rc.low += rc.range * count_sum / total
    rc.range = rc.range * f / total
    bin = rc.encode_shift(bin)
    [bin,hit]
  end

  def symbol(rc,exclusion,bin,length,pre_words,update = false)
    encode_last_dic = pre_words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}

    if encode_last_dic[:esc] == nil # init
      update_freq_by_dic(encode_last_dic,:esc,true)
    end

    if exclusion
      bit = BinaryIndexedTree.create_bit(encode_last_dic[:bit])
      exclusion.each do |ex|
        if encode_last_dic[ex] && ex != :bit &&  ex !=:esc && ex != :decode
          ef = bit.select(encode_last_dic[ex])
          bit.update(encode_last_dic[ex], -1 * ef)
        end
      end
    else
      bit = encode_last_dic[:bit]
    end

    total = bit.sum_all

    index,count_sum = bit.search_range(rc.low,rc.range)
    f = bit.select(index)
    last = encode_last_dic[:decode][index]
    if last == :esc
      update_freq_by_dic(encode_last_dic,:esc,true)
      last= nil
    end

    if exclusion && last == nil
      exclusion.concat(encode_last_dic.keys)
      exclusion.uniq!
    end

    rc.low -= rc.range * count_sum / total
    rc.range = rc.range * f / total
    length = rc.decode_shift(bin,length)
    [last,length]
  end

  def update_freq(pre,symbol,decode = false)
    encode_last_dic = pre.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    update_freq_by_dic( encode_last_dic, symbol, decode)
  end

  def update_freq_by_dic(encode_last_dic,symbol, decode = false)
    if encode_last_dic[:bit] == nil
      encode_last_dic[:bit] = BinaryIndexedTree.new
      encode_last_dic[:decode] = [] if decode
    end
    bit = encode_last_dic[:bit]

    if encode_last_dic[symbol]
      bit.update(encode_last_dic[symbol], @symbol_inc)
    else
      new_index = bit.add(@symbol_init)
      encode_last_dic[symbol] = new_index
      encode_last_dic[:decode][new_index] = symbol if decode
    end
  end
end

