#!/bin/bash

# Copyright (c) 2013-2014 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# Usage: benchmark_omp_kart.sh <result_path> <-c|-k|-a|"-c -t CC"|"-k -t CC"> <kart-configs...>
# This will create the folder <result_path> in results containing result files
# for each run.

# first argument, create result path
RESULT_PATH=`pwd`/results/$1
mkdir -p $RESULT_PATH

# second argument
MAKE_ARGS=$2 # passed to make_omp_kart.sh
#derive device name
DEV_ARG=${2:0:2} # extract first two characters, i.e. "-k" from "-k -t CC"
case $DEV_ARG in
-c)
	DEVICE="cpu"
	;;
-k)
	DEVICE="knl"
	;;
-a)
	DEVICE="knc"
	;;
esac

# process third argument, copy all specified configs to the result folder
KART_CONFIGS=""
for config in ${@:3}
do
	# copy the config
	cp $config $RESULT_PATH/
	KART_CONFIGS="$KART_CONFIGS ${RESULT_PATH}/$(basename $config)"
done
echo "Copied all KART configs: $KART_CONFIGS"

# edit this if needed
VECLIBS=( "VEC_VCL" ) # "VEC_INTEL" "VEC_VC" "VEC_VCL"
RUNS=20
ITERATIONS_PER_RUN=55
WARM_UP_ITERATIONS=5

# iterate through vector libs
for veclib in "${VECLIBS[@]}"
do
	BIN_PATH=$RESULT_PATH/bin.${DEVICE}_${veclib}
	echo "Rebuilding... $BIN_PATH"
	./make_omp_kart.sh -p $BIN_PATH -v $veclib -i $ITERATIONS_PER_RUN -w $WARM_UP_ITERATIONS $MAKE_ARGS

	# run through all KART configs, use the copies
	for config in $KART_CONFIGS
	do
		export KART_DEFAULT_CONFIG=${config} # NOTE: must be absolute path
		echo "Set KART_DEFAULT_CONFIG to: ${KART_DEFAULT_CONFIG}"
		# perform multiple runs for statistics
		for i in `seq 1 ${RUNS}`
		do
			RUN="./run_${DEVICE}.sh"
			EXE="$BIN_PATH/benchmark_omp_kart"

			FILE_NAME=${RESULT_PATH}/${DEVICE}_${veclib}_$(basename $config)_run_${i}
			echo "Benchmarking: ${FILE_NAME}"
			echo "$RUN $EXE > $FILE_NAME.data 2> $FILE_NAME.log"
			$RUN $EXE > $FILE_NAME.data 2> $FILE_NAME.log
		done
	done
done


