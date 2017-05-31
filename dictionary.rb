input = ARGV[0]
output = ARGV[1]

$stdin = open(input, "r")
$stdout = open(output, "w") if ARGV[1]

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
  freq_threadshold = 0
  dic = {}
  while input = gets do
    str,freqstr = input.split("\t")
    freq = freqstr.to_i
    words = str.split
    dic[words] = freq if freq > freq_threadshold
  end
  dic = dic.sort{ |(k1,v1),(k2,v2)| v2 <=> v1}
  dic.each_with_index { |(k, v),i| puts "#{k.join("\t")}\t#{i+1}" }
end

web2gm