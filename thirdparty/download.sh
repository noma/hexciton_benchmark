#!/bin/bash

# Copyright (c) 2015 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# get noma-ocl and dependencies
# Standalone/Library Build
git clone git@github.com:noma/ocl.git
git clone git@github.com:noma/bmt.git
git clone git@github.com:noma/misc.git
git clone git@github.com:noma/typa.git
cd ocl/thirdparty
ln -s ../../bmt/ bmt
ln -s ../../misc/ misc
ln -s ../../typa/ typa
cd ../../
# Include it into a CMake-Project
#dependencies=(ocl bmt misc typa)
#for i in "${dependencies[@]}"
#do
	#git clone git@github.com:noma/${i}.git
	#cd ${i}
	#git checkout-index -a -f --prefix=../../../hexciton_benchmark/thirdparty/${i}/
	#cd ..
#done

# get Vc
git clone https://github.com/VcDevel/Vc vc.git

# get VCL
wget http://www.agner.org/optimize/vectorclass.zip
unzip vectorclass.zip -d vcl
unzip vectorclass.zip -d vcl_mic # second copy for merging with VCLKNC
rm -f vectorclass.zip

# get VLCKNC
git clone https://bitbucket.org/veclibknc/vclknc.git vclknc.git
# merge with vcl 
cp -rf vclknc.git/* vcl_mic
