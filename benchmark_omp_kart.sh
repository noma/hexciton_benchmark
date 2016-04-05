#!/bin/bash

# Copyright (c) 2013-2014 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# Usage: benchmark_omp_kart.sh <result_path>
# This will create the folder <result_path> in results containing result files
# for each run.

RESULT_PATH=./results/$1

mkdir -p $RESULT_PATH

#DEVICES=( "-c" "-a" )  # -c -a = cpu, acc(mic)
DEVICES=( "-c" )  # -c -a = cpu, acc(mic)
VECLIBS=( "VEC_INTEL") # "VEC_INTEL" "VEC_VC" "VEC_VCL"
RUNS=20
ITERATIONS_PER_RUN=55
WARM_UP_ITERATIONS=5

for device in "${DEVICES[@]}"
do
	for veclib in "${VECLIBS[@]}"
	do
		echo "Rebuilding..."
		./make_omp_kart.sh -v $veclib -i $ITERATIONS_PER_RUN -w $WARM_UP_ITERATIONS $device

		for i in `seq 1 ${RUNS}`
		do
			case $device in
			-c)
				NAME="cpu"
				RUN="./run_host.sh"
				EXE="bin/benchmark_omp_kart"
				;;
			-a)
				NAME="mic"
				RUN="./run_mic.sh"
				EXE="bin.mic/benchmark_omp_kart"
				;;
			esac
			FILE_NAME=${RESULT_PATH}/${NAME}_${veclib}_run_${i}
			echo "Benchmarking: ${FILE_NAME}"
			echo "$RUN $EXE > $FILE_NAME.data 2> $FILE_NAME.log"
			$RUN $EXE > $FILE_NAME.data 2> $FILE_NAME.log
		done
	done
done

