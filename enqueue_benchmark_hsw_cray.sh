#!/bin/bash

# Copyright (c) 2016 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

source ./enqueue_benchmark.sh

RESULT_DIR_SUFFIX="_hsw"
MAKE_ARGS="-c -t CC" # use cray compiler # "-c -t CC"
CONFIGS="CC_mpp2.kart g++.kart clang++.kart icpc.kart"
JOB_SCRIPT_HEADER=jobscript_cray_header_mpp2.template
JOB_SCRIPT_BODY=jobscript_cray_body.template
MSUB_ARGS=$@
#echo "MSUB_ARGS=$@"

create_job "$RESULT_DIR_SUFFIX" "$MAKE_ARGS" "$CONFIGS" "$JOB_SCRIPT_HEADER" "$JOB_SCRIPT_BODY" "$MSUB_ARGS"

