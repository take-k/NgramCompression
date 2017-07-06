require 'optparse'
require 'benchmark'
include Benchmark

opts = OptionParser.new
opts.on("-coca") {|v| $coca = true}

opts.parse!(ARGV)


$in = ARGV[0]
$out = ARGV[1]
$threshold = ARGV[2].to_i

#$stdin = open(input, "rb")
$stdout = open($out, "wb") if ARGV[1]

def coca2gm
  entropies = {} # entropy * conditional_total_freq
  conditions = {}
  tmp = nil
  total_freq = 0
  condition_total_freq = 0
  word1 = ''
  open($in,'rb').each_line do |line|
    freqstr,word1,word2 = line.split("\t")
    freq = freqstr.to_i
    if word1 != tmp
      entropies[word1] = calc_entropy( conditions,condition_total_freq)
      conditions = {}
      tmp = word1
      condition_total_freq = 0
    end
    conditions[word2] = freq
    condition_total_freq += freq
    total_freq += freq
  end
  entropies[word1] = calc_entropy( conditions,condition_total_freq)

  puts (entropies.reduce(0.0) {|sum , (k,v)| sum += v} / total_freq) * -1
end

def calc_entropy(conditions,condition_total_freq)
  entropy = conditions.reduce(0.0) {|sum , (k,freq)| p = (freq.to_f / (condition_total_freq).to_f); sum += (freq.to_f * Math.log2(p))}
  entropy
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

coca2gm
