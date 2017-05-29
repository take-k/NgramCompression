class Integer
  def to_s_comma
    self.to_s.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\1,')
  end
end


def erase_msb(bin,length)
  bin & ((1 << (bin.bit_length - length)) - 1)
end