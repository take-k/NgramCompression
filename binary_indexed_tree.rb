
class BinaryIndexedTree
  attr_accessor :count,:count_max,:data
  def initialize
    @data = [0] * 2
    @count = 0 #BITノードの数
    @count_max = 1 #BITの最大値
  end

  def self.create_bit(bit)
    new_bit = BinaryIndexedTree.new
    new_bit.data = bit.data.clone
    new_bit.count = bit.count
    new_bit.count_max = bit.count_max
    new_bit
  end

  def select( i)
    value = @data[i]
    if i > 0 && i & 1 == 0
      p = i & (i - 1)
      i -= 1
      while i != p
        value -= @data[i]
        i = i & (i - 1)
      end
    end
    value
  end

  def update(i, x)
    while i <= @count_max
      @data[i] += x
      i += i & -i
    end
  end

  def sum( i)
    s = 0
    while i > 0
      s += @data[i]
      i -= i & -i
    end
    s
  end

  def add(x)
    @count += 1
    if @count > @count_max #BIT拡大
      @data.concat(Array.new( @count_max, 0))
      temp = @count_max
      @count_max <<= 1
      @data[@count_max]  = @data[temp]
    end
    update(@count, x)
    @count
  end

  def sum_all
    @data[@count_max]
  end

  def search_range(low,range)
    total = sum_all
    count_sum = 0
    index = 0
    child = @count_max / 2
    while child > 0
      if index + child < @count && low >= (range * (count_sum + @data[index + child])) / total
        count_sum += @data[index + child]
        index += child
      end
      child >>= 1
    end
    index += 1
    [index,count_sum]
  end
end

class BinaryIndexedTreeFreq < BinaryIndexedTree
  attr_accessor :freq
  def initialize
    super
    @freq = [0] * 2
  end

  def self.create_bit(bit)
    new_bit = BinaryIndexedTreeFreq.new
    new_bit.data = bit.data.clone
    new_bit.count = bit.count
    new_bit.count_max = bit.count_max
    new_bit.freq = bit.freq.clone
    new_bit
  end

  def update(i,x)
    super
    @freq[i] += x
  end

  def select(i)
    @freq[i]
  end

  def add(x)
    @count += 1
    if @count > @count_max #BIT拡大
      @data.concat(Array.new( @count_max, 0))
      @freq.concat(Array.new( @count_max, 0))
      temp = @count_max
      @count_max <<= 1
      @data[@count_max]  = @data[temp]
    end
    update(@count, x)
    @count
  end
end