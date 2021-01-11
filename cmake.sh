#!/bin/bash

# Copyright (c) 2015-2017 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# NOTE:
# Optional environment variables: BUILD_DIR_SUFFIX, BUILD_OPTIONS, CMAKE_OPTIONS

# default values
NUM_ITERATIONS=26 # including warmup below
NUM_WARMUP=1
INTEL_PREFETCH_LEVEL=1 # sets -auto-prefetch-level= for OpenCL compilation
CMAKE_OPTIONS="-DHB_ENABLE_OCL=ON -DHB_ENABLE_OCL_NAIVE_WG_LIMIT=ON -DHB_ENABLE_OMP=OFF -DHB_ENABLE_OMP_KART=OFF"


build()
{
	local ARCHITECTURE=$1
	local BUILD_OPTIONS=$2
	local DIR_NAME=build.${ARCHITECTURE}

	# the right way to check if a variable is set and not null
	# https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
	# http://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_06_02
	if ! [ -z ${BUILD_DIR_SUFFIX:+x} ]
	then
		echo "Using custom BUILD_DIR_SUFFIX '${BUILD_DIR_SUFFIX}'"
		DIR_NAME=build.${ARCHITECTURE}.${BUILD_DIR_SUFFIX}
	fi

	mkdir ${DIR_NAME}
	cd ${DIR_NAME}

	cmake -DCMAKE_BUILD_TYPE=Release ${BUILD_OPTIONS} ${CMAKE_OPTIONS} ..

	if [ "$DEBUG" = "true" ]
	then
		make VERBOSE=1
	else
		make -j
	fi
}

usage ()
{ 
	echo "Usage and defaults:";
	echo -e "\t-c\t Build CPU variant.";
	echo -e "\t-k\t Build KNL variant.";
	echo -e "\t-a\t Build KNC accelerator variant.";
	echo -e "\t-g\t Build GPU variant.";
	echo -e "\t-d\t Enable verbose make for debugging the build process.";
	echo -e "\t-i ${NUM_ITERATIONS}\t Number of iterations (including warmups).";
	echo -e "\t-w ${NUM_WARMUP}\t Number of warmup iterations.";
	echo -e "\t-p ${INTEL_PREFETCH_LEVEL}\t Value used for the Intel-specific OpenCL compiler option '-auto-prefetch-level='.";
}

BUILT_SOMETHING=false

# evaluate command line
while getopts ":i:w:p:ckaghd" opt; do
	case $opt in
	d) #debug
		echo "Running in debug mode."
		DEBUG=true
		;;
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
	build "cpu" "-DNUM_ITERATIONS=${NUM_ITERATIONS} -DNUM_WARMUP=${NUM_WARMUP} -DINTEL_PREFETCH_LEVEL=${INTEL_PREFETCH_LEVEL} -DVEC_LENGTH=4 -DVEC_LENGTH_AUTO=16 -DPACKAGES_PER_WG=4 -DBUILD_OPTIONS=${BUILD_OPTIONS}"
	BUILT_SOMETHING=true
fi

if [ "$BUILT_KNL" = "true" ]
then
	build "knl" "-DNUM_ITERATIONS=${NUM_ITERATIONS} -DNUM_WARMUP=${NUM_WARMUP} -DINTEL_PREFETCH_LEVEL=${INTEL_PREFETCH_LEVEL} -DVEC_LENGTH=8 -DVEC_LENGTH_AUTO=16 -DPACKAGES_PER_WG=4 -DBUILD_OPTIONS=${BUILD_OPTIONS}"
	BUILT_SOMETHING=true
fi

if [ "$BUILT_KNC" = "true" ]
then
	build "knc" "-DNUM_ITERATIONS=${NUM_ITERATIONS} -DNUM_WARMUP=${NUM_WARMUP} -DINTEL_PREFETCH_LEVEL=${INTEL_PREFETCH_LEVEL} -DVEC_LENGTH=8 -DVEC_LENGTH_AUTO=16 -DPACKAGES_PER_WG=4 -DBUILD_OPTIONS=${BUILD_OPTIONS}"
	BUILT_SOMETHING=true
fi

if [ "$BUILT_GPU" = "true" ]
then
	build "gpu" "-DNUM_ITERATIONS=${NUM_ITERATIONS} -DNUM_WARMUP=${NUM_WARMUP} -DVEC_LENGTH=8 -DVEC_LENGTH_AUTO=16 -DPACKAGES_PER_WG=4 -DBUILD_OPTIONS=${BUILD_OPTIONS}"
	BUILT_SOMETHING=true
fi

if [ "$BUILT_SOMETHING" = "false" ]
then
	echo "Please use at least one of -c -a -k -g";
	usage
fi
