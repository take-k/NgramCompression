require 'csv'

dic = {}
#CSV.foreach('vocab', :col_sep => "\t") do |row|
#  dic[row[0]] = row[1].to_i
#
#end
$stdin = open("vocab", "r")
$stdout = open("out", "w")

while input = gets do
  str,freq = input.split("\t")
  dic[str] = freq.to_i
end
dic = dic.sort{ |(k1,v1),(k2,v2)| v2 <=> v1}

dic.each { |k, v| puts "#{k}\t#{v}" }