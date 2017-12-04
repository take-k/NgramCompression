def normalize
  file = ARGV[0]
  if file
    open(file,'rb') do |f|
      sum = 0
      while (input = f.gets) do
        row = input.split("\t")
        freq = row[-1].to_i
        sum += freq
      end
    end

    shift = ARGV[1] || 1
    return if shift == 0

    open("#{file}_output",'wb') do |output_f|
      open(file,'rb') do |input_f|
        while (input = input_f.gets) do
          row = input.split("\t")
          words = row[0,row.size-1]
          freq = row[-1].to_i <<= shift
          output_f.puts("#{words.join(" ")} #{freq}") if freq > 0
        end
      end
    end
  end
end

normalize