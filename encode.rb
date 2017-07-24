require './tools.rb'

def alpha(number,x)
  (number << x) + x
end

def gamma(number,x)
  digit = x.bit_length
  (number << (digit + digit - 1)) + x
end

def delta(number,x)
  digit = x.bit_length
  (gamma(number,digit) << (digit - 1)) + digit - (1 << digit)
end

def omega(number,x)
  code = 0
  return (number << 1) if x == 1 #最下位ビットに0
  y = x
  while y > 1
    code = (y << code.bit_length) + code
    y = y.bit_length - 1
  end
  code = code << 1 #最下位ビットに0
  (number << code.bit_length) + code
end

def decode_omega(bin,length)
  n = 1
  while bin[length - 1] == 1
    flength = length
    length -= (n + 1)
    n = (bin % (1 << flength)) / (1 << length)
  end
  length -= 1
  [n,length]
end

def d_omega(number)
  ary = []
  codes = number
  length = number.bit_length
  while length > 0
    n = 1
    while codes[length - 1] == 1
      length -= (n + 1)
      (n,codes) = codes.divmod(1 << length)
    end
    ary.push(n)
    length -= 1
  end
  ary
end

class RangeCoder
  attr_accessor :low,:range,:code
  MAX_RANGE_LENGTH = 32
  MIN_RANGE_LENGTH = 24
  SHIFT = 24  #?
  HEAD = MAX_RANGE_LENGTH - SHIFT
  MAX_RANGE = (1 << MAX_RANGE_LENGTH) - 1
  MIN_RANGE = 1 << MIN_RANGE_LENGTH

  MAX_MASK = MAX_RANGE
  SHIFT_MASK = MAX_RANGE - ((1 << SHIFT) - 1)

  def load_code(bin,start,length = MAX_RANGE_LENGTH)
    (bin >> (start - length)) & ((1 << length) - 1 ) #start+1
  end

  def initialize
    @low = 0
    @range = MAX_RANGE
    @code = 0
  end

  def encode_shift(bin)
    bin += 1 if @low >= MAX_RANGE #up digit
    while @range < MIN_RANGE
      bin <<= HEAD
      bin += (@low >> SHIFT)
      @low = (@low << HEAD) & MAX_MASK
      @range <<= HEAD
    end
    bin
  end

  def decode_shift(bin,length)
    while @range < MIN_RANGE
      @low = (@low << HEAD) & MAX_MASK
      @range <<= HEAD
      @code = (@code << 8) + load_code(bin,length,HEAD)
      length -= HEAD
    end
    length
  end

  def encode_shift_no_carry(bin)
    while @low & SHIFT_MASK == (@low + @range) & SHIFT_MASK
      bin <<= HEAD
      bin += (@low >> SHIFT)
      @low = (@low << HEAD) & MAX_MASK
      @range <<= HEAD
    end
    while @range < MIN_RANGE
      @range = (MIN_RANGE - (@low & (MIN_RANGE - 1))) << HEAD
      bin <<= HEAD
      bin += (@low >> SHIFT)
      @low = (@low << HEAD) & MAX_MASK
    end
    bin
  end

  def decode_shift_no_carry(bin,length)
    while @low & SHIFT_MASK == (@low + @range) & SHIFT_MASK
      length -= HEAD
      @code = load_code(bin,length,MAX_RANGE_LENGTH)
      @low = (@low << HEAD) & MAX_MASK
      @range <<= HEAD
    end
    while @range < MIN_RANGE
      @range = (MIN_RANGE - (@low & (MIN_RANGE - 1))) << HEAD
      length -= HEAD
      @code = load_code(bin,length,MAX_RANGE_LENGTH)
      @low = (@low << HEAD) & MAX_MASK
    end
  end

  def finish(bin)
    bin += 1 if @low >= MAX_RANGE
    bin <<= MAX_RANGE_LENGTH
    bin += @low
    bin
  end
end