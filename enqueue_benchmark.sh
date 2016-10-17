#!/bin/bash

# Copyright (c) 2016 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

function create_job {
	local RESULT_DIR_SUFFIX=$1
	local MAKE_ARGS=$2
	local CONFIGS=$3
	local JOB_SCRIPT_HEADER=$4
	local JOB_SCRIPT_BODY=$5

	local RESULT_DIR=$(date +%Y-%m-%d_%H%M%S)${RESULT_DIR_SUFFIX}
	local WORKING_DIR=$(pwd)/results/$RESULT_DIR
	local JOB_SCRIPT=$WORKING_DIR/jobscript_cray.sh

	echo "Result path: $WORKING_DIR"

	mkdir -p $WORKING_DIR

	# build a job script
	cat $JOB_SCRIPT_HEADER >  $JOB_SCRIPT
	echo ""                >> $JOB_SCRIPT
	cat $JOB_SCRIPT_BODY   >> $JOB_SCRIPT

	# replace placeholders in jobscript
	sed -i "s%STDOUT_TEMPLATE%${WORKING_DIR}/stdout%g" $JOB_SCRIPT
	sed -i "s%STDERR_TEMPLATE%${WORKING_DIR}/stderr%g" $JOB_SCRIPT
	
	sed -i "s%RESULT_DIR_TEMPLATE%${RESULT_DIR}%g" $JOB_SCRIPT
	sed -i "s%MAKE_ARGS_TEMPLATE%${MAKE_ARGS}%g" $JOB_SCRIPT
	sed -i "s%CONFIGS_TEMPLATE%${CONFIGS}%g" $JOB_SCRIPT
	
	msub $JOB_SCRIPT
	
#	# works only on KNL, msub --version: Version: moab client 9.0.2 (revision 2016072918, changeset f87b286e1b2ee995c616f2c945c5c35844737ab0)
#	msub -F "${RESULT_DIR} ${MAKE_ARGS} ${CONFIGS}" $JOB_SCRIPT
#	# works only on HSW, msub --version: Version: moab client 9.0.1.h5 (revision 2016040719, changeset 2351bac9c38faedd2030c964bab66856628e33d6)
#	msub -F "\"${RESULT_DIR} ${MAKE_ARGS} ${CONFIGS}\"" $JOB_SCRIPT
}

