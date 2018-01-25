#!/usr/bin/env bash
#ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=0
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=1
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=2
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=4
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=8
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=16
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=32
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=64
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=128
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=256
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=512
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=1024
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=2048
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=4096
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=8192
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=16384
ruby ngram_compression.rb cantrbry/alice29.txt -i --maxn=5 --maxcharn=5 --negative-order --ppmc --freq-upper=32768
