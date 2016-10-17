#!/bin/bash

#PBS -A # account for cpu time
#PBS -N hexciton_benchmark_knl # job name
#PBS -q sysq # queue
#PBS -l nodes=1:ppn=68 
#PBS -l os=CLE_quad_flat 
#PBS -l walltime=04:00:00
#PBS -o STDOUT_TEMPLATE # standard out file
#PBS -e STDERR_TEMPLATE # standard error file
#PBS -j oe # join error into output


# NOTE: This is a template, use with enqueue_benchmark_knl.sh
# USAGE: msub -F "result_dir config_list.." jobscript_cray_knl.sh
# e.g. msub -F "2015-10-17_tds_c g++.kart clang++.kart icpc.kart" jobscript_cray_knl.sh

RESULT_DIR=$1
WORKING_DIR=${PBS_O_WORKDIR}/results/${RESULT_DIR}
CONFIGS=${@:2} # second and following arguments

# copy job script
cp $PBS_O_WORKDIR/jobscript_cray_knl.sh $WORKING_DIR/jobscript_cray_knl.sh
# copy what the batch system made of the job script
cp $PBS_O_WORKDIR/$0 $WORKING_DIR/jobscript_batchsystem.sh

# cray compiler
module switch cce/8.5.3

# intel compiler
module load intel/17.0.0.098

# gcc
export PATH=$HOME/Software/gcc-6.2.0/bin:$PATH
export LD_LIBRARY_PATH=$HOME/Software/gcc-6.2.0/lib64:$LD_LIBRARY_PATH
export LD_LIBRARY_PATH=$HOME/Software/gcc-6.2.0/lib/:$LD_LIBRARY_PATH

# clang
export PATH=$HOME/Software/llvm_3.9.0/bin:$PATH
export LD_LIBRARY_PATH=$HOME/Software/llvm_3.9.0/lib:$LD_LIBRARY_PATH

echo "Results are in: $WORKING_DIR"
echo "Using configs: $CONFIGS"

# one process using all hardware threads on a KNL node
aprun -n 1 -N 1 -cc none ./benchmark_omp_kart.sh $RESULT_DIR -k $CONFIGS

# use cray build
## Boost cray build
#export BOOST_ROOT=$HOME/Software/boost_1_61_0_cce_8.5.1_gnu_5.3.0
#export LD_LIBRARY_PATH=$HOME/Software/boost_1_61_0_cce_8.5.1_gnu_5.3.0/lib

#aprun -n 1 -N 1 -cc none ./benchmark_omp_kart.sh $RESULT_DIR "-k -t CC" $CONFIGS

