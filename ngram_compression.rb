require 'csv'
#require 'pg'
#connection = PG::Connection(:host =>"localhost",:dbname => "coca2gram")

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

def encode
  str = ''
  open('cantrbry/alice29.txt') do |io|
    str = io.read
  end
  excludes = [',','.',';',':','`','\n','\r']
  words = str.split(/ |(,)|(\.)|(;)|(:)|(`)|(\n)|(\r)/)
  #辞書作成　
  #符号化 [word1][word2] > rank
  #復号 [word1][rank]> word2
  dic = {}
  decode_dic = {}
  CSV.foreach('w2-s.tsv', :col_sep => "\t") do |row|
    dic[row[0]] = {} if dic[row[0]] == nil
    dic[row[0]][row[1]] = row[2].to_i
    decode_dic[row[0]] = {} if decode_dic[row[0]] == nil
    decode_dic[row[0]][row[2].to_i] = row[1]
  end

  ary = []
  bin = 4
  (1..words.count-1).each do |i|
    dic[words[i-1]] = {} if dic[words[i-1]] == nil
    rank_dic = dic[words[i-1]]
    if rank_dic[words[i]] == nil
      rank = rank_dic.count + 1
      rank_dic[words[i]] = rank
      decode_dic[words[i-1]] = {} if decode_dic[words[i-1]] == nil
      decode_dic[words[i-1]][rank] = words[i]
    end
    ary.push(rank_dic[words[i]])
    bin = omega(bin,rank_dic[words[i]])
  end
  p bin.bit_length / 8

  ranks = ary
  #ranks = d_omega(bin)
  #ranks.shift

  str = words[0]
  pre = words[0]
  ranks.each do |rank|
    pre = decode_dic[pre][rank]
    str += ' ' if !excludes.include?(pre)
    str += pre
  end
  File.open("decode.txt", "w") do |f|
    f.puts(str)
  end
end
encode
# data = Array.new(ary.max,0)
# ary.each { |x|
#   data[x] = 0 if data[x] == nil
#   data[x] += 1
# }

# require 'gnuplot'
# Gnuplot.open do |gp|
#   Gnuplot::Plot.new(gp) do |plot|
#     plot.title  'test'
#     plot.ylabel 'ylabel'
#     plot.xlabel 'xlabel'
#
#     x = (0..data.count-1).map {|v| v}
#     y = data
#
#     plot.data << Gnuplot::DataSet.new( [x, y] ) do |ds|
#       ds.with = "lines"
#       ds.notitle
#     end
#   end
# end

#p sum
#p code
#p code.size

#alpha
#30767961b
#3848496B
#3.848495125MB

#alpha -nodic
#870494
#108812B
#108KB

#gamma
#269513b
#33689.125B
#33KB

#delta
#244457b
#30557.125B
#30KB

#omega
#260309b
#32538.625B
#32.5KB

#zip 55KB