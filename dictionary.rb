
require 'benchmark'
include Benchmark

$in = ARGV[0]
$out = ARGV[1]
$threshold = ARGV[2].to_i

$stdin = open($in, "rb") if $in
$stdout = open($out, "wb") if $out

def web1gm_freq
  freq_threadshold = 100000000
  dic = {}
  while input = gets do
    str,freqstr = input.split("\t")
    freq = freqstr.to_i
    dic[str] = freq if freq > freq_threadshold
  end

  dic.each_with_index { |(k, v),i| puts "#{k}\t#{2}" }
end

def web1gm
  freq_threadshold = 10000
  dic = {}
  while input = gets do
    str,freqstr = input.split("\t")
    freq = freqstr.to_i
    dic[str] = freq if freq > freq_threadshold
  end
  dic = dic.sort{ |(k1,v1),(k2,v2)| v2 <=> v1}
  upper = (2**16) - 1

  dic[0..upper].each_with_index { |(k, v),i| puts "#{k}\t#{i+1}" }
end

def web2gm
  freq_threadshold = $threshold
  dic = {}
  tmp = ''
  open($in,'rb').each_line do |line|
    str,freqstr = line.split("\t")
    freq = freqstr.to_i
    if $threshold <= freq
      word1,word2 = str.split
      if word1 == tmp
        dic[word2] = freq
      else
        dic = dic.sort{ |(k1,v1),(k2,v2)| v2 <=> v1}
        dic.each_with_index { |(k, v),i| puts "#{tmp}\t#{k}\t#{i+1}" }
        dic = {}
        dic[word2] = freq
        tmp = word1
      end
    end
  end

  dic = dic.sort{ |(k1,v1),(k2,v2)| v2 <=> v1}
  dic.each_with_index { |(k, v),i| puts "#{tmp}\t#{k}\t#{i+1}" }
  #dic.each do |word1,word2_dic|
  #  ranks = word2_dic.sort{ |(k1,v1),(k2,v2)| v2 <=> v1}
  #  ranks.each_with_index { |(k, v),i| puts "#{word1}\t#{k}\t#{i+1}" }
  #end
end

web1gm_freq


