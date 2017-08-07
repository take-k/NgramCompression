module Lz78Compression
  def lz78_compress(words)
    ngram = ngram_table()
    words_hash = {[]=>0}
    results = []
    counter = 0
    ary = []

    words.each_with_index do |word,i|
      ary << word
      if words_hash[ary] == nil
        counter += 1
        words_hash[ary] = counter # {[a]=>1,[a,b]=>2}

        results << [word,words_hash[ary[0,ary.count-1]]]
        ary = []
      elsif i == words.count-1 #最後の文字が出力されていない場合
        results << ['',words_hash[ary]]
      end
    end

    output(results.to_s,$lz78_file) if $show_lz78

    monogram = NgramTableFromFile.new($monogramfile)

    bin = lz78convert_mix(results,ngram,monogram)

    puts '--hit rate--' if $info
    ngram.print_rate if $info

    monogram.print_rate if $info
    monogram.finish

    bin
  end

  def lz78convert_2gram(lz78dict,ngram)
    bin = 4
    (1..results.count-1).each do |i|
      rank = ngram.rank([results[i-(n-1)..i][0]],true)
      bin = delta(bin,rank)
      bin = delta( bin ,results[i][1] + 1) #0は符号化できない
    end
    bin
  end

  $ll = 0
  def lz78convert_mix(lz78dict,ngram,monogram = NgramTableFromFile.new($monogramfile))
    @length_ngram = 0
    @length_1gram = 0
    @length_raw = 0
    @length_code = 0
    @num_ngram = 0
    @num_1gram = 0
    @num_raw = 0
    @total = 0
    ol = 0
    bin = 0
    int_encode = $omega_encode ? method(:omega):method(:delta)

    dist_ngram = []
    dist_1gram = []
    dist_raw = []
    dist_index = []

    ranks_ngram = []
    ranks_1gram = []

    (0..lz78dict.count-1).each do |i|
      length = lz78dict[i][0].length
      @total += length
      ol = bin.bit_length if $info
      if $indexcoding
        bin = int_encode( bin ,lz78dict[i][1] + 1)
      else
        bin <<= i.bit_length
        bin += lz78dict[i][1]
      end
      @length_code += bin.bit_length - ol if $info
      count_collection(dist_index,lz78dict[i][1]) if $show_distribution

      ol = bin.bit_length if $info
      if bin != 0 && rank = ngram.rank_mru_i([lz78dict[i][1] == 0 ? lz78dict[i-1][0]: lz78dict[lz78dict[i][1] - 1][0],lz78dict[i][0]])
        @num_ngram += length if $info
        bin <<= 1
        bin = int_encode.call(bin,rank)
        @length_ngram += bin.bit_length - ol if $info
        count_collection(dist_ngram,rank) if $show_distribution
        ranks_ngram << rank if $show_ranks
      else
        if rank = monogram.rank_mru_i([lz78dict[i][0]])
          @num_1gram += length if $info
          bin <<= 2
          bin += 2
          bin = int_encode.call(bin,rank)
          @length_1gram += bin.bit_length - ol if $info
          count_collection(dist_1gram,rank) if $show_distribution
          ranks_1gram << rank if $show_ranks
        else
          @num_raw += length if $info
          bin <<= 2
          bin += 3
          bin = int_encode.call(bin,lz78dict[i][0].size + 1)
          lz78dict[i][0].unpack("C*").each do |char|
            bin = int_encode.call(bin,char) #TODO:fix
            count_collection(dist_raw,char) if $show_distribution
          end
          @length_raw += bin.bit_length - ol if $info
        end
      end
    end

    puts '--lz78 data--' if $info
    bitl = bin.bit_length / 8
    puts_rate(@num_ngram,@total , 'ngram chars') if $info
    puts_rate(@num_1gram,@total , '1gram chars') if $info
    puts_rate(@num_raw,@total , 'rawtxt chars') if $info

    puts '--compression size--' if $info
    puts_rate(@length_ngram / 8,bitl,'ngram size','byte') if $info
    puts_rate(@length_1gram / 8,bitl,'1gram size','byte') if $info
    puts_rate(@length_raw / 8,bitl,'rawtxt size','byte') if $info
    puts_rate(@length_code / 8,bitl,'code size','byte') if $info

    puts_distribution([dist_ngram,dist_1gram,dist_raw,dist_index ]) if $show_distribution
    output("#{ranks_ngram.to_s}\n#{ranks_1gram.to_s}", $ranks_file) if $show_ranks
    bin
  end

  def lz78deconvert_mix(bin,ngram)
    monogram = NgramTableFromFile.new($monogramfile)
    words = []
    lz78dict = []
    counter = 0

    pre = ''
    length = bin.bit_length
    while(length > 0)
      if $indexcoding
        (freq,length) = decode_omega(bin,length)
        freq -= 1
      else
        flength = length
        length -= counter.bit_length
        freq = (bin % (1 << flength)) / (1 << length)
        counter+=1
      end

      if(bin[length - 1] == 0)
        length -= 1
        (rank,length) = decode_omega(bin,length)
        word = ngram.next_word_i([freq == 0 ? pre : words[freq-1][0]],rank)
      else
        if(bin[length - 2] == 0)
          length -= 2
          (rank,length) = decode_omega(bin,length)
          word = monogram.next_word_i([],rank)
          ngram.register_word([freq == 0 ? pre : words[freq-1][0]],word) if counter != 1
        else
          length -= 2
          (size,length) = decode_omega(bin,length)#サイズ情報
          size -= 1
          word = ''
          (1..size).each do |i|
            (char,length) = decode_omega(bin,length)
            word << char.chr
          end
          monogram.register_word([],word)
          ngram.register_word([freq == 0 ? pre : words[freq-1][0]],word) if counter != 1
        end
      end
      words << [word,freq]
      pre = word
    end
    words
  end

  def lz78_decompress(bin,ngram)
    words_hash = {0=>[]}
    counter = 0

    pairs = lz78deconvert_mix(bin,ngram)

    results = []
    pairs.each do |word,num|
      words = words_hash[num] + [word]
      results += words
      counter += 1
      words_hash[counter] = words
    end
    join_words(results)
  end


  def table_letter_naive_compress(add_table_str)
    table = letter_table(add_table_str)
    bin = 4
    add_table_str.each_char do |c|
      bin = omega(bin,table[c])
    end
    p '2-gram-table naive'
    p "content:#{bin.bit_length / 8}"
    bin
  end
end