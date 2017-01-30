
class NgramCompression
end

def read
end
str = ''
open('cantrbry/alice29.txt') do |io|
  str = io.read
end
words = str.split(/[\s,.;:`()]/) - [""]


require 'csv'
#辞書作成　
#符号化 [word1][word2] > rank
#復号 [word1,rank] > word2
dic = {}
CSV.foreach('w2-s.tsv', :col_sep => "\t") do |row|
  dic[row[0]] = {} if dic[row[0]] == nil
  dic[row[0]][row[1]] = row[2].to_i
end

code = ''
sum = 0
(1..words.count-1).each do |i|
  dic[words[i-1]] = {} if dic[words[i-1]] == nil
  ndic = dic[words[i-1]]
  ndic[words[i]] = ndic.count + 1 if ndic[words[i]] == nil
  #code += ('0' * ndic[words[i]] + '1')
  sum += ndic[words[i]]
end
p sum
#p code
#p code.size
#30767961b
#3848496B
#3.848495125MB