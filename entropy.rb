require 'optparse'
require 'benchmark'
include Benchmark

opts = OptionParser.new
opts.on("--tsv") {|v| $tsv = true}

opts.parse!(ARGV)


$in = ARGV[0]
$out = ARGV[2]
$n = ARGV[1].to_i > 0 ? ARGV[1].to_i : 1

#$stdin = open(input, "rb")
$stdout = open($out, "wb") if $out

def calc_entropy
  entropies = {} # entropy * conditional_total_freq
  conditions = {}
  tmp = nil
  total_freq = 0
  condition_total_freq = 0
  word1 = ''
  open($in,'rb').each_line do |line|
    if $tsv
      freq_string,word1,word2 = line.split("\t")
      freq = freq_string.to_i
    else
      str,freq_string = line.split("\t")
      freq = freq_string.to_i
      word1,word2 = str.split
    end

    if word1 != tmp
      entropies[tmp] = calc_entropy_by_freq( conditions,condition_total_freq)
      conditions = {}
      tmp = word1
      condition_total_freq = 0
    end
    conditions[word2] = freq
    condition_total_freq += freq
    total_freq += freq
  end
  entropies[word1] = calc_entropy_by_freq( conditions,condition_total_freq)

  (entropies.reduce(0.0) {|sum , (k,v)| sum += v} / total_freq) * -1
end


def calc_conditional_entropy
  entropies = [] # entropy * conditional_total_freq
  conditions = []
  tmp = nil
  total_freq = 0
  condition_total_freq = 0
  keywords = []
  open($in,'rb').each_line do |line|
    if $tsv
      strs = line.split("\t")
      freq_string = strs[0]
      keywords = strs[1,strs.size-1]
      freq = freq_string.to_i
    else
      str,freq_string = line.split("\t")
      freq = freq_string.to_i
      keywords = str.split
    end
    words = keywords[0,keywords.size-1]

    if words != tmp
      entropies << calc_centropy_by_freq( conditions,condition_total_freq)
      conditions = []
      tmp = words
      condition_total_freq = 0
    end
    conditions << freq
    condition_total_freq += freq
    total_freq += freq
  end
  entropies << calc_centropy_by_freq( conditions,condition_total_freq)

  (entropies.reduce(0.0) {|sum , v| sum += v} / total_freq) * -1
end

def calc_centropy_by_freq(freqs,total_freq)
  freqs.reduce(0.0) {|sum , freq| p = (freq.to_f / (total_freq).to_f); sum += (freq.to_f * Math.log2(p))}
end


def calc_entropy_by_freq(freqs,total_freq)
  entropy = freqs.reduce(0.0) {|sum , (k,freq)| p = (freq.to_f / (total_freq).to_f); sum += (freq.to_f * Math.log2(p))}
  entropy
end

e = calc_conditional_entropy
puts "#{$in} : #{e}"
