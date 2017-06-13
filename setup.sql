COPY google2gram(word1,word2,rank) from '/home/orange/NgramCompression/n-grams/2gmts';
create index google2gram__index_words
  on google2gram (word1, word2)
;
