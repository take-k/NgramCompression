#require 'pg'
require 'csv'

str = ''
open('cantrbry/alice29.txt') do |io|
  str = io.read
end
words = str.split(/[\s,.;:`()]/) - [""]

#辞書作成　
#符号化 [word1][word2] > rank
#復号 [word1,rank] > word2
dic = {}
CSV.foreach('w2-s.tsv', :col_sep => "\t") do |row|
  dic[row[0]] = {} if dic[row[0]] == nil
  dic[row[0]][row[1]] = row[2].to_i
end

#connection = PG::Connection(:host =>"localhost",:dbname => "coca2gram")

def gamma(number,x)
  digit = x.bit_length
  (number << (digit + digit - 1)) + x
end


def delta(number,x)
  digit = x.bit_length
  (gamma(number,digit) << (digit - 1)) + digit - (1 << digit)
end

ary = []
bin = 0
(1..words.count-1).each do |i|
  dic[words[i-1]] = {} if dic[words[i-1]] == nil
  ndic = dic[words[i-1]]
  ndic[words[i]] = ndic.count + 1 if ndic[words[i]] == nil
  ary.push(ndic[words[i]])
  bin = delta(bin,ndic[words[i]])
end
p bin.to_s(2)
p bin.bit_length


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

#30767961b
#3848496B
#3.848495125MB

#870494
#108812B
#108KB

#720166b
#90020.75B
#90KB


#244457b
#66991B
#67KB


#zip 55KB