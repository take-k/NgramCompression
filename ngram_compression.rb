class NgramCompression
end

def read
end
str = ""
open('cantrbry/alice29.txt') do |io|
  str = io.read
end
words = str.split(/[\s,.;:`()]/) - [""]

