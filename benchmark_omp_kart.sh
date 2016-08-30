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

DEVICES=( "$2" )  # -c -k -a = cpu, knl, knc
VECLIBS=( "VEC_INTEL" "VEC_VCL" ) # "VEC_INTEL" "VEC_VC" "VEC_VCL"
KART_CONFIGS=( "intel_16.0.3.kart" "gcc_6.1.0.kart" "clang_3.8.1.kart" )

RUNS=25
ITERATIONS_PER_RUN=105
WARM_UP_ITERATIONS=5

for device in "${DEVICES[@]}"
do
	for veclib in "${VECLIBS[@]}"
	do
		echo "Rebuilding..."
		./make_omp_kart.sh -v $veclib -i $ITERATIONS_PER_RUN -w $WARM_UP_ITERATIONS $device

		for config in "${KART_CONFIGS[@]}"
		do
			export KART_DEFAULT_CONFIG=`pwd`/${config}
			echo "Set KART_DEFAULT_CONFIG to: ${KART_DEFAULT_CONFIG}"
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
				esac

				RUN="./run_${NAME}.sh"
				EXE="bin.${NAME}/benchmark_omp_kart"

				FILE_NAME=${RESULT_PATH}/${NAME}_${veclib}_${config}_run_${i}
				echo "Benchmarking: ${FILE_NAME}"
				echo "$RUN $EXE > $FILE_NAME.data 2> $FILE_NAME.log"
				$RUN $EXE > $FILE_NAME.data 2> $FILE_NAME.log
			done
		done
	done
done

