require 'optparse'
require 'benchmark'
include Benchmark

opts = OptionParser.new
opts.on("--coca") {|v| $coca = true}

opts.parse!(ARGV)


$in = ARGV[0]
$out = ARGV[2]
$n = ARGV[1].to_i

#$stdin = open(input, "rb")
$stdout = open($out, "wb") if ARGV[1]

def calc_entropy
  entropies = {} # entropy * conditional_total_freq
  conditions = {}
  tmp = nil
  total_freq = 0
  condition_total_freq = 0
  word1 = ''
  open($in,'rb').each_line do |line|
    if $coca
      freq_string,word1,word2 = line.split("\t")
      freq = freq_string.to_i
    else
      str,freq_string = line.split("\t")
      freq = freq_string.to_i
      word1,word2 = str.split
    end
    if word1 != tmp
      entropies[word1] = calc_entropy_by_freq( conditions,condition_total_freq)
      conditions = {}
      tmp = word1
      condition_total_freq = 0
    end
    conditions[word2] = freq
    condition_total_freq += freq
    total_freq += freq
  end
  entropies[word1] = calc_entropy_by_freq( conditions,condition_total_freq)

  puts (entropies.reduce(0.0) {|sum , (k,v)| sum += v} / total_freq) * -1
end

def calc_entropy_by_freq(freqs,total_freq)
  entropy = freqs.reduce(0.0) {|sum , (k,freq)| p = (freq.to_f / (total_freq).to_f); sum += (freq.to_f * Math.log2(p))}
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

calc_entropy
