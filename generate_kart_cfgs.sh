#!/bin/bash

# Copyright (c) 2016 Matthias Noack (ma.noack.pr@gmail.com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

COMPILERS="g++ clang++ icpc CC" # C++ compiler from: GCC, LLVM/clang, Intel, Cray

# ADAPT OPTIONS IF NEEDED
# NOTE: hardcoded to vcl vector library
COMPILER_OPTIONS_ALWAYS_GCC="-c -std=c++11 -O3 -march=native -fopenmp -fabi-version=6 -shared -fPIC -Wall -Drestrict=__restrict"
COMPILER_OPTIONS_DEFAULT_GCC=  "-Iinclude -Ithirdparty/ham/include -Ithirdparty/kart/include -Ithirdparty/vc/include -Ithirdparty/vcl -DKART"
LINKER_OPTIONS_ALWAYS_GCC="-shared -fPIC"
LINKER_OPTIONS_DEFAULT_GCC="-fopenmp"

COMPILER_OPTIONS_ALWAYS_CLANG="-c -std=c++11 -O3 -march=native -fopenmp -shared -fPIC -Wall -Drestrict=__restrict"
COMPILER_OPTIONS_DEFAULT_CLANG="-Iinclude -Ithirdparty/ham/include -Ithirdparty/kart/include -Ithirdparty/vc/include -Ithirdparty/vcl -DKART"
LINKER_OPTIONS_ALWAYS_CLANG="-shared -fPIC"
LINKER_OPTIONS_DEFAULT_CLANG="-fopenmp -lm"

COMPILER_OPTIONS_ALWAYS_INTEL="-c -std=c++11 -O3 -xHost -restrict -qopenmp -shared -fPIC -Wall"
COMPILER_OPTIONS_DEFAULT_INTEL="-Iinclude -Ithirdparty/ham/include -Ithirdparty/kart/include -Ithirdparty/vc/include -Ithirdparty/vcl -DKART"
LINKER_OPTIONS_ALWAYS_INTEL="-shared -fPIC"
LINKER_OPTIONS_DEFAULT_INTEL="-qopenmp"

COMPILER_OPTIONS_ALWAYS_CRAY="-c -hstd=c++11 -O3 -hvector3 -hfp3 -hipa5 -hintrinsics -homp -hshared -hPIC -Wall -Drestrict=__restrict"
COMPILER_OPTIONS_DEFAULT_CRAY="-Iinclude -Ithirdparty/ham/include -Ithirdparty/kart/include -Ithirdparty/vc/include -Ithirdparty/vcl -DKART"
LINKER_OPTIONS_ALWAYS_CRAY="-hshared -hPIC"
LINKER_OPTIONS_DEFAULT_CRAY="-hopenmp"

SOURCE_FILE_EXTENSION="cpp"

# generate kart config file
function write_config {
	# usage:
	local EXE=$1
	local COMPILER_OPTIONS_ALWAYS=$2
	local COMPILER_OPTIONS_DEFAULT=$3
	local LINKER_OPTIONS_ALWAYS=$4
	local LINKER_OPTIONS_DEFAULT=$5

	# compiler section
	echo "[compiler]" > $FILE
	echo "exe=$EXE" >> $FILE
	echo "options-always=$COMPILER_OPTIONS_ALWAYS" >> $FILE
	echo "options-default=$COMPILER_OPTIONS_DEFAULT" >> $FILE
	echo "source-file-extension=$SOURCE_FILE_EXTENSION" >> $FILE
	echo "" >> $FILE
	# linker section
	echo "[linker]" >> $FILE
	echo "exe=$EXE" >> $FILE
	echo "options-always=$LINKER_OPTIONS_ALWAYS" >> $FILE
	echo "options-default=$LINKER_OPTIONS_DEFAULT" >> $FILE
}

# create file to list found compilers, to be used by benchmarks
COMPILER_LIST=kart_compilers
echo -n "" > $COMPILER_LIST

# create one config for each compiler
for compiler in $COMPILERS; do
	FILE=${compiler}.kart
	echo "Generating KART config '$FILE' for $compiler"

	# locate compiler and check if it exists
	EXE=$(which $compiler 2> /dev/null)
	if [ $? -ne 0 ]; then
		echo -e "\tCould not find $compiler - skipping"
		break; # skip loop iteration
	fi
	
	echo -e "\tusing $EXE"

	# use the right executable and options
	case $compiler in
		g++)
			write_config "$EXE" "$COMPILER_OPTIONS_ALWAYS_GCC" "$COMPILER_OPTIONS_DEFAULT_GCC" "$LINKER_OPTIONS_ALWAYS_GCC" "$LINKER_OPTIONS_DEFAULT_GCC"
			;;
		clang++)
			write_config "$EXE" "$COMPILER_OPTIONS_ALWAYS_CLANG" "$COMPILER_OPTIONS_DEFAULT_CLANG" "$LINKER_OPTIONS_ALWAYS_CLANG" "$LINKER_OPTIONS_DEFAULT_CLANG"
			;;
		icpc)
			write_config "$EXE" "$COMPILER_OPTIONS_ALWAYS_INTEL" "$COMPILER_OPTIONS_DEFAULT_INTEL" "$LINKER_OPTIONS_ALWAYS_INTEL" "$LINKER_OPTIONS_DEFAULT_INTEL"
			;;
		CC)
			write_config "$EXE" "$COMPILER_OPTIONS_ALWAYS_CRAY" "$COMPILER_OPTIONS_DEFAULT_CRAY" "$LINKER_OPTIONS_ALWAYS_CRAY" "$LINKER_OPTIONS_DEFAULT_CRAY"
			;;
		*)
			write_config "$EXE" "" "" "" ""
			echo "WARNING: unknown compiler: No options set."
		;;
	esac
	
	# add compiler to list
	echo "$compiler" >> $COMPILER_LIST
done


