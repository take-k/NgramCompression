require './ngram_table'

class FreqTable < NgramTableFromFile
  def freq(rc,exclusion,bin,keywords,update = false)
    words = keywords[0,keywords.size-1]
    last = keywords[-1]
    encode_last_dic = words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}

    if encode_last_dic[:esc] == nil # init
      update_freq_by_dic(encode_last_dic,:esc)
    end

    if encode_last_dic[last]
      hit = true
    else
      update_freq_by_dic(encode_last_dic, :esc)
      hit = false
    end

    update_freq_by_dic(encode_last_dic, last) if update
    [bin,hit]
  end

  def update_freq(pre,symbol,decode = false)
    encode_last_dic = pre.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    update_freq_by_dic( encode_last_dic, symbol, decode)
  end

  def update_freq_by_dic(encode_last_dic,symbol, decode = false ,inc = 1 , init = 1)
    if encode_last_dic[symbol]
      encode_last_dic[symbol] += inc
    else
      encode_last_dic[symbol] = init
    end
  end

  def set_freq(words,last,freq ,decode = false)
    encode_last_dic = words.inject(@encode_table){|d,key| d[key] == nil ? d[key] = {} : d[key]}
    update_freq_by_dic(encode_last_dic,last,decode,freq,freq)
  end
end