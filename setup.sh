#!/bin/bash
ruby dictionary.rb n-grams/2gm n-grams/2gmt
sed -e 's/\\/\\\\/g' n-grams/2gmt >> n-grams/2gmts
