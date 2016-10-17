#!/bin/bash

# Copyright (c) 2016 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

source ./enqueue_benchmark.sh

RESULT_DIR_SUFFIX="_hsw"
MAKE_ARGS="-c" # "-c -t CC"
CONFIGS="g++.kart clang++.kart icpc.kart"
JOB_SCRIPT_HEADER=jobscript_cray_header_mpp2test.template
JOB_SCRIPT_BODY=jobscript_cray_body.template

create_job "$RESULT_DIR_SUFFIX" "$MAKE_ARGS" "$CONFIGS" "$JOB_SCRIPT_HEADER" "$JOB_SCRIPT_BODY"

