
class NgramCompression
end

def read
end
str = ""
open('cantrbry/alice29.txt') do |io|
  str = io.read
end
words = str.split(/[\s,.;:`()]/) - [""]


require 'csv'
#辞書作成　
#符号化 [word1,word2] > rank
#復号 [word1,rank] > word2
dic = {}
CSV.foreach('w2-s.tsv', :col_sep => "\t") do |row|
  dic[[row[0],row[1]]] = row[2].to_i
end

p dic