require './ngram_table'
require './encode.rb'
require './ppmc'
require 'test/unit'

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

  table.each {|c| ngram.update_freq([],c,true)}
  result = []
  word.each do |c|
    char,length = ngram.symbol(rc,nil,bin,length,[],true)
    result << char
    ngram.update_freq([],char,true)
  end
  result
end

class TestPPMC < Test::Unit::TestCase
  def test_simple
    table = ['a','b']
    word = "a".split("")
    bin = encode_test(table,word)
    assert_equal(word,decode_test(bin, table,word)
    )

    word = "b".split("")
    bin = encode_test(table,word)
    assert_equal(word,decode_test(bin, table,word)
    )
  end

  def test_continious
    table = ['a','b']
    word = "ab".split("")
    bin = encode_test(table,word)
    assert_equal(word,decode_test(bin, table,word)
    )
  end
end
