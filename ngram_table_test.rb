require './encode.rb'
require './ppmc_opt'
require 'test/unit'

def encode_test(table,word,exclusion = false)
  bin = 1
  ngram = PPMCopt.new(nil,1)
  rc = RangeCoder.new
  exclusions = exclusion ? []: nil

  table.each {|c| ngram.update_freq([],c)}
  word.each { |c| bin,exact = ngram.freq(rc,exclusions,bin,[c],true)}
  rc.finish(bin)
end

def decode_test(bin,table,word,exclusion = false)
  ngram = PPMCopt.new(nil,1)
  rc = RangeCoder.new
  length = bin.bit_length
  length -= 1
  length = rc.load_low(bin, length)
  ex = exclusion ? []: nil

  table.each {|c| ngram.update_freq([],c,true)}
  result = []
  word.each do |c|
    char,length = ngram.symbol(rc,ex,bin,length,[],true)
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
    alphabets = ['a','b','c']
    1.upto(3) do |time|
      alphabets.repeated_permutation(time) do |chars|
        bin = encode_test(alphabets,chars)
        assert_equal(chars,decode_test(bin, alphabets,chars)
      )
      end
    end
  end

  def test_continious_with_exclusion
    alphabets = ['a','b','c']
    1.upto(3) do |time|
      alphabets.repeated_permutation(time) do |chars|
        bin = encode_test(alphabets,chars,true)
        assert_equal(chars,decode_test(bin, alphabets,chars,true)
        )
      end
    end
  end

end
