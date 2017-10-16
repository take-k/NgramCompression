#!/bin/bash
ruby ngram_compression.rb --benchmark calgary/bib
ruby ngram_compression.rb --benchmark calgary/book1
ruby ngram_compression.rb --benchmark calgary/book2
ruby ngram_compression.rb --benchmark calgary/geo
ruby ngram_compression.rb --benchmark calgary/news
ruby ngram_compression.rb --benchmark calgary/obj1
ruby ngram_compression.rb --benchmark calgary/obj2
ruby ngram_compression.rb --benchmark calgary/paper1
ruby ngram_compression.rb --benchmark calgary/paper2
ruby ngram_compression.rb --benchmark calgary/pic
ruby ngram_compression.rb --benchmark calgary/progc
ruby ngram_compression.rb --benchmark calgary/progl
ruby ngram_compression.rb --benchmark calgary/progp
ruby ngram_compression.rb --benchmark calgary/trans

#real	12m23.965s
#user	12m14.813s 734.813
#sys	0m6.669s


real    3m50.965s
user    3m38.591s
sys     0m10.644s
