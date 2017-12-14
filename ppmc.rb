require "./ngram_table"

class PPMC < NgramTableFromFile
  def initialize(file = nil,n = nil)
    super(file,n)
    @symbol_inc = 1
    @symbol_init = 1
    @escape_inc = 1
    @escape_init = 1
  end

  def freq(rc,exclusion,bin,keywords,update = false)
    exclusion ||= Set.new
    words = keywords[0,keywords.size-1]
    last = keywords[-1]
    encode_last_dic = words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    encode_last_dic[:esc] ||= @escape_init
    total = 0
    count_sum = 0
    escape_count_sum = 0
    hit = false
    encode_last_dic.each do |k, v|
      if !exclusion.include?(k)
        total += v
        exclusion << k if k != :esc
        escape_count_sum = count_sum if k == :esc
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
      encode_last_dic[last] += @symbol_inc if update
    else
      encode_last_dic[last] = @symbol_init if update
      f = encode_last_dic[:esc]
      encode_last_dic[:esc] += @escape_inc
      count_sum = escape_count_sum
    end

    if total >= 10 && @n != 1
      encode_last_dic.each do |k, v|
        if v == :esc
          encode_last_dic[k] = encode_last_dic[k] >> 1 | 1
        else
          encode_last_dic[k] >>= 2
          encode_last_dic.delete(k) if encode_last_dic[k] == 0
        end
      end
    end

    rc.low += rc.range * count_sum / total
    rc.range = rc.range * f / total
    bin = rc.encode_shift(bin)
    [bin,hit]
  end

  def symbol(rc,exclusion,bin,length,pre_words,update = false)
    exclusion ||= Set.new
    encode_last_dic = pre_words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    encode_last_dic[:esc] ||= @escape_init
    count_sum = 0
    hit = false
    last = nil
    f = 0
    total = encode_last_dic.reduce(0) do |s,(k,v)|
      if !exclusion.include?(k)
        s += v
      else
        s
      end
    end
    encode_last_dic.each do |k, v|
      if !exclusion.include?(k)
        if !hit
          if rc.low < (rc.range * (count_sum + v) / total)
            hit = true
            last = k if k != :esc
            f = v
            encode_last_dic[:esc] += @escape_inc if k == :esc
          else
            count_sum += v
          end
        end
        exclusion << k if k != :esc
      end
    end

    rc.low -= rc.range * count_sum / total
    rc.range = rc.range * f / total
    length = rc.decode_shift(bin,length)
    [last,length]
  end

  def update_freq(pre,symbol,decode = false)
    encode_last_dic = pre.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    if encode_last_dic[symbol]
      encode_last_dic[symbol] += @symbol_inc
    else
      encode_last_dic[symbol] = @symbol_init
    end
  end
end

class PPMA < PPMC
  def initialize(file = nil,n = nil)
    super(file,n)
    @symbol_inc = 1
    @symbol_init = 1
    @escape_inc = 0
    @escape_init = 1
  end
end


class PPMD < PPMC
  def initialize(file = nil,n = nil)
    super(file,n)
    @symbol_inc = 2
    @symbol_init = 2
    @escape_inc = 1
    @escape_init = 1
  end
end
