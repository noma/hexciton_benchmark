#!/bin/bash

# Copyright (c) 2015-2017 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# NOTE:
# Variables to change: CC, OPTIONS, OPENCL_LIB, OPENCL_LIB_PATH

#CC=icpc # also change OPTIONS
#OPTIONS="-std=c++11 -Wall -O3 -xHost -restrict -qopenmp -qopt-report=5 -DVEC_NONE -DDIM=7"
CC=g++ # NOTE: also change OPTIONS below
OPTIONS="-std=c++11 -Wall -g -O3 -march=native -Drestrict=__restrict__ -fopenmp -DVEC_NONE -DDIM=7"

# Use standard headers
OPENCL_INCLUDE_PATH=thirdparty/OpenCL/include

OPENCL_LIB="OpenCL"
OPENCL_LIB_PATH="${INTELOCLSDKROOT}/lib64" # /opt/intel/opencl/ # NOTE: change this to your installation directory

#OPENCL_LIB="OpenCL"
#OPENCL_LIB_PATH="/usr/local/cuda/lib64

#OPENCL_LIB="OpenCL"
#OPENCL_PATH="${HOME}/Software/pocl-0.14_tds/lib64"

#OPENCL_LIB="amdocl64"
#OPENCL_PATH="${HOME}/Software/ocl_sdks/amd/app_sdk_3.0.130.136/AMDAPPSDK-3.0/lib/x86_64/sdk"

#OPENCL_LIB="intelocl"
#OPENCL_PATH="${HOME}/Software/ocl_sdks/intel/opencl_runtime_16.1.1/opt/intel/opencl-1.2-6.4.0.25/lib64"

#OPENCL_LIB="intelocl_2_1"
#OPENCL_PATH="${HOME}/Software/ocl_sdks/intel/intel_sdk_for_opencl_2017_7.0.0.2511_x64/opt/intel/opencl/exp-runtime-2.1/lib64"

OCL_BUILD_OPTIONS="" #"-cl-fast-relaxed-math"

NUM_ITERATIONS=26 # including warmup below
NUM_WARMUP=1
INTEL_PREFETCH_LEVEL=1 # sets -auto-prefetch-level= for OpenCL compilation

HAM_PATH=thirdparty/ham
CLU_PATH_INCLUDE=thirdparty/CLU.git
CLU_PATH_LIB=thirdparty/CLU/clu_runtime

INCLUDE="-Iinclude -I${HAM_PATH}/include/ -I${OPENCL_INCLUDE_PATH} -I${CLU_PATH_INCLUDE}"
LIB="-lrt -L${OPENCL_LIB_PATH} -l${OPENCL_LIB} ${CLU_PATH_LIB}/libclu_runtime.a"

BUILD_DIR_CPU="bin.cpu"
BUILD_DIR_KNL="bin.knl"
BUILD_DIR_KNC="bin.knc"
BUILD_DIR_KNC="bin.gpu"

FILES=( \
common.cpp \
kernel/commutator_reference.cpp \
)

build()
{
	local BUILD_DIR=$1
	local CONFIG=$2
	
	mkdir -p $BUILD_DIR
	
	for file in "${FILES[@]}"
	do
		local tmp=${file##*/}
		local NAME=${tmp%.*}
		$CC -c $OPTIONS $CONFIG $INCLUDE -o ${BUILD_DIR}/${NAME}.o src/${file} & # NOTE: parallel build
		local OBJS=" $OBJS ${BUILD_DIR}/${NAME}.o"
	done

	# wait for all build jobs
	local FAIL_COUNT=0
	for job in `jobs -p`; do
		# echo $job
		wait $job || let "FAIL_COUNT+=1"
	done
	if (( FAIL_COUNT > 0 )); then
		echo "Failed build targets: $FAIL_COUNT"
	fi

	#echo $OBJS

	$CC $OPTIONS $CONFIG $INCLUDE -o ${BUILD_DIR}/benchmark_ocl $OBJS src/benchmark_ocl.cpp $LIB
}

usage ()
{ 
	echo "Usage and defaults:";
	echo -e "\t-c\t Build CPU variant.";
	echo -e "\t-k\t Build KNL variant.";
	echo -e "\t-a\t Build KNC accelerator variant.";
	echo -e "\t-g\t Build GPU variant.";
	echo -e "\t-i ${NUM_ITERATIONS}\t Number of iterations (including warmups).";
	echo -e "\t-w ${NUM_WARMUP}\t Number of warmup iterations.";
	echo -e "\t-p ${INTEL_PREFETCH_LEVEL}\t Value used for the Intel-specific OpenCL compiler option '-auto-prefetch-level='.";
}

BUILT_SOMETHING=false

# evaluate command line
while getopts ":i:w:p:ckagh" opt; do
	case $opt in
	i) # iterations
		echo "Setting NUM_ITERATIONS to $OPTARG" >&2
		NUM_ITERATIONS=$OPTARG
		;;
	w) # warmup iterations
		echo "Setting NUM_WARMUP to $OPTARG" >&2
		NUM_WARMUP=$OPTARG
		;;
	p) # Prefetch level (Intel only)
		echo "Setting INTEL_PREFETCH_LEVEL to $OPTARG" >&2
		INTEL_PREFETCH_LEVEL=$OPTARG
		;;
	c) # CPU
		echo "Building for CPU" >&2
		BUILT_CPU=true
		;;
	k) # KNL 
		echo "Building for KNL" >&2
		BUILT_KNL=true
		;;
	a) # KNC accelerator
		echo "Building for KNC Accelerator" >&2
		BUILT_KNC=true
		;;
	g) # GPU
		echo "Building for GPU" >&2
		BUILT_GPU=true
		;;
	h) # usage
		usage
		exit 0
		;;
	:) # missing value
		echo "Option -$OPTARG requires an argument."
		usage
		exit 1
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		usage
		exit 1
		;;
  esac
done

if [ "$BUILT_CPU" = "true" ]
then
	build "$BUILD_DIR_CPU" "-DDEVICE_TYPE=CL_DEVICE_TYPE_CPU -DNUM_ITERATIONS=${NUM_ITERATIONS} -DNUM_WARMUP=${NUM_WARMUP} -DINTEL_PREFETCH_LEVEL=${INTEL_PREFETCH_LEVEL} -DVEC_LENGTH=4 -DVEC_LENGTH_AUTO=16 -DOCL_BUILD_OPTIONS=${OCL_BUILD_OPTIONS}"
	BUILT_SOMETHING=true
fi

if [ "$BUILT_KNL" = "true" ]
then
	build "$BUILD_DIR_KNL" "-DDEVICE_TYPE=CL_DEVICE_TYPE_CPU -DNUM_ITERATIONS=${NUM_ITERATIONS} -DNUM_WARMUP=${NUM_WARMUP} -DINTEL_PREFETCH_LEVEL=${INTEL_PREFETCH_LEVEL} -DVEC_LENGTH=8 -DVEC_LENGTH_AUTO=16 -DOCL_BUILD_OPTIONS=${OCL_BUILD_OPTIONS}"
	BUILT_SOMETHING=true
fi

if [ "$BUILT_KNC" = "true" ]
then
	build "$BUILD_DIR_KNC" "-DDEVICE_TYPE=CL_DEVICE_TYPE_ACCELERATOR -DNUM_ITERATIONS=${NUM_ITERATIONS} -DNUM_WARMUP=${NUM_WARMUP} -DINTEL_PREFETCH_LEVEL=${INTEL_PREFETCH_LEVEL} -DVEC_LENGTH=8 -DVEC_LENGTH_AUTO=16 -DOCL_BUILD_OPTIONS=${OCL_BUILD_OPTIONS}"
	BUILT_SOMETHING=true
fi

if [ "$BUILT_GPU" = "true" ]
then
	build "$BUILD_DIR_GPU" "-DDEVICE_TYPE=CL_DEVICE_TYPE_GPU -DNUM_ITERATIONS=${NUM_ITERATIONS} -DNUM_WARMUP=${NUM_WARMUP} -DVEC_LENGTH=8 -DVEC_LENGTH_AUTO=16 -DOCL_BUILD_OPTIONS=${OCL_BUILD_OPTIONS}"
	BUILT_SOMETHING=true
fi

if [ "$BUILT_SOMETHING" = "false" ]
then
	echo "Please use at least one of -c -a -k -g";
	usage
fi

