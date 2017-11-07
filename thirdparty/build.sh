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
cmake -DNOMA_OCL_STANDALONE=TRUE
make -j8
cd ../..

# build Vc
export MIC_SDK_DIR=$(dirname $(dirname $(dirname `which icpc`)))
cd vc.git
mkdir -p build
cd build
cmake -DCMAKE_CXX_COMPILER=icpc -DCMAKE_C_COMPILER=icc -DCMAKE_INSTALL_PREFIX="../../vc" -DBUILD_TESTING=OFF ..
make -j8
make install
cd ../..
