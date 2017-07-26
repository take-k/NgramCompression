require './encode.rb'
require './ngram_table.rb'


dic = {}
#dic["a"]=1
#dic["b"]=1
#dic["c"]=1
#dic["d"]=1
#dic = (0..255).reduce({}) {|d,i| d[i.chr] = 1;d}
#dic[''] = 1


ngram = NgramTableFromFile.new(nil,1,dic)

rc = RangeCoder.new()

str = File.open("cantrbry/alice29.txt","rb").read
#str =  "this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this this"
bin = 1

str.chars.each do |char|
  bin,hit = ngram.freq(rc,[],bin,[char],true)
end
bin = rc.finish(bin)

p bin.to_s(2)
p bin.bit_length
ngram = NgramTableFromFile.new(nil,1,{})

drc = RangeCoder.new()
length = bin.bit_length - 1
length = drc.load_low(bin,length)
words = []
str.chars.each do |c|
  word,length = ngram.symbol(drc,[],bin,length,[],false)
  ngram.update_freq([],c)
  word = c if !word
  words << word
end
puts words.join
