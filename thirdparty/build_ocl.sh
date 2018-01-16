#!/bin/bash

# Copyright (c) 2015 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# noma-ocl
# Standalone/Library Build
cd ocl
mkdir -p build
cd build
cmake -DNOMA_OCL_STANDALONE=TRUE -DCMAKE_BUILD_TYPE=Release ..
make -j8
cd ../..
