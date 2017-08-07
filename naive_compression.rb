module NaiveCompression
  def convert_to_ranks(words,ngram)#最初の文字群とrankの配列
    n = ngram.n
    first_words = []
    ranks = []
    words.each_with_index do |word,i|
      if i < (n-1)
        first_words << word
      else
        words[i-(n-1)..i]
        rank = ngram.rank(words[i-(n-1)..i],false)
        ranks << rank if rank != nil
      end
    end
    [first_words,ranks]
  end

  def naive_compress(words)
    ngram = ngram_table()
    bin = 4
    first_words,ranks = convert_to_ranks(words,ngram)
    ranks.each do |rank|
      #@ary.push(rank)
      bin = delta(bin,rank)
    end
    puts 'naive'
    ngram.print_rate
    bin
  end

  def naive_decompress(ngram,ranks,first)
    pre = first
    words = ranks.map do |rank|
      word = ngram.next_word([pre],rank)
      pre = word
    end
    join_words([first] + words)
  end
end