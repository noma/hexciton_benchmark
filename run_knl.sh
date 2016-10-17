#!/bin/bash

# Copyright (c) 2015-2016 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

# Usage: run_knl.sh <executable> [omp_num_threads_value]

# executable
EXE=$1 # NOTE: absolute path

# use optional second argument or 'lscpu' to determine OMP_NUM_THREADS
THREADS=${2:-$(lscpu | grep "^CPU(s):" | tr -s ' ' | cut -d ' ' -f 2)}
echo "run_knl.sh: setting OMP_NUM_THREADS to: $THREADS"

unset KMP_AFFINITY
OMP_NUM_THREADS=$THREADS OMP_PLACES=threads OMP_PROC_BIND=true numactl --membind 1 $EXE

# NOTE: maybe set: KMP_BLOCK_TIME=0 for Intel OMP, see documentation

