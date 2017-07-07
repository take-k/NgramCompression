#!/bin/bash
gunzip 3gm-*.gz
cat 3gm-* > 3gm
ruby entropy.rb 3gm > entropy
