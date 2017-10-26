require "./ngram_table"

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

    total = bit[encode_last_dic[:bit_count_max]]
    escape_count_sum = sum( bit, encode_last_dic[:esc])

    if encode_last_dic[last]
      f = select( bit,encode_last_dic[last])
      count_sum = sum( bit, encode_last_dic[last]) - f
      hit = true
      target = encode_last_dic[last]
    else
      f = select( bit,encode_last_dic[:esc])
      update_freq_by_dic(encode_last_dic, :esc)
      count_sum = escape_count_sum - f
      hit = false
      target = encode_last_dic[:esc]
    end
    if exclusion
      exclusion.each do |ex|
        if encode_last_dic[ex] && ex != :bit && ex !=:bit_count && ex !=:bit_count_max && ex !=:esc
          ef = select(bit, encode_last_dic[ex])
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
      update_freq_by_dic(encode_last_dic,:esc)
    end

    def search(encode_last_dic,w)
      bit = encode_last_dic[:bit]
      return 0 if w < 0
      index = 0
      child = encode_last_dic[:bit_count_max] / 2
      while child > 0
        if index + child < encode_last_dic[:bit_count] && bit[index + child] <= w
          w -= bit[index + child]
          index += child
        end
        child >>= 1
      end
      return index + 1
    end

    bit = encode_last_dic[:bit]

    total = bit[encode_last_dic[:bit_count_max]]
    bit_index = search(encode_last_dic,rc.low * total / rc.range)
    f = select(bit,bit_index)
    count_sum = sum(bit , bit_index) - f
    last = encode_last_dic[:decode][bit_index]

    rc.low -= rc.range * count_sum / total
    rc.range = rc.range * f / total
    length = rc.decode_shift(bin,length)
    [last,length]
  end

  def select(bit, i)
    value = bit[i]
    if i > 0 && i & 1 == 0
      p = i & (i - 1)
      i -= 1
      while i != p
        value -= bit[i]
        i = i & (i - 1)
      end
    end
    value
  end

  def add(bit, i, x)
    while (i < bit.count)
      bit[i] += x
      i += i & -i
    end
  end

  def sum( bit, i)
    s = 0
    while i > 0
      s += bit[i]
      i -= i & -i
    end
    s
  end

  def update_freq(pre,symbol,decode = false)
    encode_last_dic = pre.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    update_freq_by_dic( encode_last_dic, symbol, decode)
  end

  def update_freq_by_dic(encode_last_dic,symbol, decode = false)
    if encode_last_dic[:bit] == nil
      encode_last_dic[:bit] = [0] * 2
      encode_last_dic[:bit_count] = 0 #BITノードの数
      encode_last_dic[:bit_count_max] = 1 #BITの最大値
      encode_last_dic[:decode] = [] if symbol
    end

    if encode_last_dic[symbol]
      add(encode_last_dic[:bit], encode_last_dic[symbol], @symbol_inc)
    else
      encode_last_dic[:bit_count] += 1
      encode_last_dic[symbol] = encode_last_dic[:bit_count]
      if decode
        dic = encode_last_dic[:decode]
        dic[encode_last_dic[:bit_count]] = symbol
      end
      if encode_last_dic[:bit_count] > encode_last_dic[:bit_count_max] #BIT拡大
        encode_last_dic[:bit].concat(Array.new( encode_last_dic[:bit_count_max], 0))
        encode_last_dic[:bit][encode_last_dic[:bit_count_max] << 1]  = encode_last_dic[:bit][encode_last_dic[:bit_count_max]]
        encode_last_dic[:bit_count_max] <<= 1
      end
      add(encode_last_dic[:bit], encode_last_dic[:bit_count], @symbol_init)
    end
  end
end

