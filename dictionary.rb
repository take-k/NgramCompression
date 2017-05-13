$stdin = open("vocab", "r")
$stdout = open("dic2byte", "w")

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
