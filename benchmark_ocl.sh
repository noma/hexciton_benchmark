#!/bin/bash

# Copyright (c) 2013-2014 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# Usage: benchmark_ocl.sh <result_path>
# This will create the folder <result_path> in results containing result files
# for each run.

RESULT_PATH=./results/$1

mkdir -p $RESULT_PATH


DEVICES=( "$2" ) # -c -a -g = cpu, acc, gpu
#DEVICES=( "-g" ) # for GPUs (usually on a different host)
RUNS=5
ITERATIONS_PER_RUN=25
WARM_UP_ITERATIONS=5
#PREFETCH_LEVELS=( 0 1 2 3 ) # relevant only for Intel OpenCL
PREFETCH_LEVELS=( 0 ) # use this when running with non-Intel OpenCL

for device in "${DEVICES[@]}"
do
	for prefetch in "${PREFETCH_LEVELS[@]}"
	do
		echo "Rebuilding..."
		./make_ocl.sh -p $prefetch -i $ITERATIONS_PER_RUN -w $WARM_UP_ITERATIONS $device

		for i in `seq 1 ${RUNS}`
		do
			case $device in
			-c)
				NAME="cpu"
				;;
			-k)
				NAME="knl"
				;;
			-a)
				NAME="knc"
				;;
			-g)
				NAME="gpu"
				;;
			esac
			
			EXE="bin.${NAME}/benchmark_ocl"
			
			FILE_NAME=${RESULT_PATH}/${NAME}_pf_${prefetch}_run_${i}
			echo "Benchmarking: ${FILE_NAME}"
			echo "bin.${NAME}/benchmark_ocl > $FILE_NAME.data 2> $FILE_NAME.log"
			$EXE > $FILE_NAME.data 2> $FILE_NAME.log
		done
		if [ "$device" = "-g" ]; then break; fi # skip prefetch levels for GPUs
	done
done

