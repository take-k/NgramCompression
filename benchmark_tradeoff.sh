#!/usr/bin/env bash
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=0
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=1
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=2
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=4
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=8
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=16
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=32
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=64
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=128
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=256
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=512
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=1024
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=2048
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=4096
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=8192
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=16384
ruby ngram_compression.rb cantrbry/alice29.txt --benchmark --maxn=5 --maxcharn=5 --negative-order --ppmc --memory=32768
