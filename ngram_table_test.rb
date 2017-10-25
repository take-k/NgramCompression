require './ngram_table'
require './encode.rb'

def encode_test(table,word)
  bin = 1
  ngram = PPMCopt.new(nil,1)
  rc = RangeCoder.new

  table.each {|c| ngram.update_freq([],c)}
  word.each { |c| bin,ex = ngram.freq(rc,nil,bin,[c],true)}
  rc.finish(bin)
end

def decode_test(bin,table,word)
  ngram = PPMCopt.new(nil,1)
  rc = RangeCoder.new
  length = bin.bit_length
  length -= 1
  length = rc.load_low(bin, length)

  table.each {|c| ngram.update_freq([],c)}
  word.each do |c|
    char,length = ngram.symbol(rc,nil,bin,length,[],true)
    puts char
    ngram.update_freq([],char,true)
  end
end

table = ['a','b','c','d','e']
word = "abcderf".split("")
bin = encode_test(table,word)
decode_test(bin, table,word)