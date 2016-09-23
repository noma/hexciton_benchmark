#!/bin/bash

# Copyright (c) 2015 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

OMP_NUM_THREADS=256 KMP_AFFINITY=granularity=core,compact KMP_BLOCK_TIME=0 numactl --membind 1 `pwd`/$1

