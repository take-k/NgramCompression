class Integer
  def to_s_comma
    self.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
  end

  def erase_msb(length)
    self = self & ((1 << (self.bit_length - length)) - 1)
  end
end
