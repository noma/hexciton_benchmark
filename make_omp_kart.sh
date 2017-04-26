#!/bin/bash

# Copyright (c) 2015 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# Usage: make_omp_kart.sh -h

COMPILER=icpc

#VECLIB="VEC_INTEL"
#VECLIB="VEC_VC"
VECLIB="VEC_VCL"
NUM_ITERATIONS=26 # including warmup below
NUM_WARMUP=1

BUILD_DIR_ARG="" # unused if empty, defaults below are used
BUILD_DIR_CPU="bin.cpu"
BUILD_DIR_KNL="bin.knl"
BUILD_DIR_KNC="bin.knc"

usage()
{ 
	echo "Usage and defaults:";
	echo -e "\t-c\t Build CPU variant.";
	echo -e "\t-k\t Build KNL variant.";
	echo -e "\t-a\t Build KNC accelerator variant.";
	echo -e "\t-p\t Optional build path. ";
	echo -e "\t-t ${COMPILER}\t Optional compiler: icpc | CC ";
	echo -e "\t-i ${NUM_ITERATIONS}\t Number of iterations (including warmups).";
	echo -e "\t-w ${NUM_WARMUP}\t Number of warmup iterations.";
	echo -e "\t-v ${VECLIB}\t Vector library: VEC_INTEL | VEC_VC | VEC_VCL";
}

BUILT_SOMETHING=false

# evaluate command line
while getopts ":i:w:v:p:t:ckah" opt; do
	case $opt in
	i) # iterations
		echo "Setting NUM_ITERATIONS to $OPTARG" >&2
		NUM_ITERATIONS=$OPTARG
		;;
	w) # warmup iterations
		echo "Setting NUM_WARMUP to $OPTARG" >&2
		NUM_WARMUP=$OPTARG
		;;
	v) # vec lib
		echo "Setting VECLIB to $OPTARG" >&2
		VECLIB=$OPTARG
		;;
	c) # CPU
		echo "Building for CPU" >&2
		BUILT_CPU=true
		;;
	k) # KNL
		echo "Building for KNL" >&2
		BUILT_KNL=true
		;;
	a) # KNC
		echo "Building for KNC accelerator" >&2
		BUILT_KNC=true
		;;
	p) # build path
		echo "Using build path: $OPTARG" >&2
		BUILD_DIR_ARG=$OPTARG
		;;
	t) # build path
		COMPILER=$OPTARG
		echo "Using compiler: $COMPILER" >&2
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

HAM_PATH=thirdparty/ham
VC_PATH=thirdparty/vc
VECCLASS_PATH=thirdparty/vcl
VECCLASS_PATH_KNC=thirdparty/vcl_KNC
KART_INCLUDE_PATH=thirdparty/kart

if [[ $COMPILER == "CC"  ]]
then
	echo "Building with CC..."
	KART_BUILD_PATH=thirdparty/kart/build_cray
	OPTIONS="-hstd=c++11 -O3 -hvector3 -hfp3 -hipa5 -hintrinsics -hprototype_intrinsics -homp -hPIC -Drestrict=__restrict"
	OPTIONS_CPU="$OPTIONS -DVEC_LENGTH=4"
	OPTIONS_KNL="$OPTIONS -DVEC_LENGTH=8" # -DVC_DOUBLE_V_SIZE=8"
	OPTIONS_KNC="$OPTIONS -DVEC_LENGTH=8"  # -DVC_DOUBLE_V_SIZE=8"
	LIB="-lrt -ldl -dynamic"
else
	echo "Building with $COMPILER..."
	KART_BUILD_PATH=thirdparty/kart/build
	OPTIONS="-std=c++11 -O3 -restrict -qopenmp -qopt-report=5" #-Wall
	#OPTIONS="-std=c++11 -g -O3 -restrict -openmp -qopt-report=5 -DUSE_INITZERO" #-Wall
	OPTIONS_CPU="$OPTIONS -xHost -DVEC_LENGTH=4"  # -DVC_DOUBLE_V_SIZE=4"
	OPTIONS_KNL="$OPTIONS -xmic-avx512 -DVEC_LENGTH=8" # -DVC_DOUBLE_V_SIZE=8"
	OPTIONS_KNC="$OPTIONS -mmic -DVEC_LENGTH=8"  # -DVC_DOUBLE_V_SIZE=8"
	LIB="-lrt"
fi


INCLUDE="-Iinclude -I${HAM_PATH}/include -I${KART_INCLUDE_PATH}/include"
INCLUDE_CPU="$INCLUDE -I${VC_PATH}/include -I${VECCLASS_PATH} -I${BOOST_ROOT}/include"
INCLUDE_KNL="$INCLUDE_CPU"
INCLUDE_KNC="$INCLUDE -I${VC_PATH}/include -I${VECCLASS_PATH_KNC}"

#LIB_CPU="$LIB ${VC_PATH}/lib/libVc.a"
LIB_CPU="$LIB -L${BOOST_ROOT}/lib"
LIB_KNL="$LIB_CPU"
LIB_KNC="$LIB ${VC_PATH}/lib/libVc_KNC.a"

FILES=( \
common.cpp \
kernel/commutator_reference.cpp \
)

# compile
build()
{
	local BUILD_DIR=$1
	local OPTIONS=$2
	local INCLUDE=$3
	local LIB=$4

	echo "Creating build path: $BUILD_DIR" >&2
	mkdir -p $BUILD_DIR
			
	for file in "${FILES[@]}"
	do
		local tmp=${file##*/}
		local NAME=${tmp%.*}
		$COMPILER -c $OPTIONS $INCLUDE -o ${BUILD_DIR}/${NAME}.o src/${file} & # NOTE: parallel build
		local OBJS="$OBJS ${BUILD_DIR}/${NAME}.o"
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

	$COMPILER $OPTIONS $INCLUDE -o ${BUILD_DIR}/benchmark_omp_kart $OBJS src/benchmark_omp_kart.cpp $LIB ${KART_BUILD_PATH}/libkart.a -lboost_system -lboost_filesystem -lboost_program_options
}


if [ "$BUILT_CPU" = "true" ]
then
	build "${BUILD_DIR_ARG:-$BUILD_DIR_CPU}" "$OPTIONS_CPU -DNUM_ITERATIONS=${NUM_ITERATIONS} -DNUM_WARMUP=${NUM_WARMUP} -D${VECLIB}" "$INCLUDE_CPU" "$LIB_CPU"
	BUILT_SOMETHING=true
fi

if [ "$BUILT_KNL" = "true" ]
then
	build "${BUILD_DIR_ARG:-$BUILD_DIR_KNL}" "$OPTIONS_KNL -DNUM_ITERATIONS=${NUM_ITERATIONS} -DNUM_WARMUP=${NUM_WARMUP} -D${VECLIB}" "$INCLUDE_KNL" "$LIB_KNL"
	BUILT_SOMETHING=true
fi

if [ "$BUILT_KNC" = "true" ]
then
	build "${BUILD_DIR_ARG:-$BUILD_DIR_KNC}" "$OPTIONS_KNC -DNUM_ITERATIONS=${NUM_ITERATIONS} -DNUM_WARMUP=${NUM_WARMUP} -D${VECLIB}" "$INCLUDE_KNC" "$LIB_KNC"
	BUILT_SOMETHING=true
fi

if [ "$BUILT_SOMETHING" = "false" ]
then
	echo "Please use at least one of -c -k -a";
	usage
fi

