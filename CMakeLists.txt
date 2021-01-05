# Copyright (c) 2017 Matthias Noack <ma.noack.pr@gmail.com>
#
# See accompanying file LICENSE and README for further information.

cmake_minimum_required(VERSION 3.1.0 FATAL_ERROR)

project(hexciton_benchmark)

# test compiler versions
if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
	if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "4.9.0")
		message(FATAL_ERROR "GCC version 4.9.0 or higher required.")
	endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "Clang")
	if(CMAKE_CXX_COMPILER_VERSION VERSION_LESS "3.3.0")
		message(FATAL_ERROR "Clang version 3.3.0 or higher required.")
	endif()
	execute_process( 
		COMMAND bash -c "echo -n $(dirname $(which g++))/.."
		OUTPUT_VARIABLE GCC_PATH
	)
	message(WARNING "Clang detected, setting '--gcc-toolchain=${GCC_PATH}' option, make sure version is >=4.9.0.")
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} --gcc-toolchain=${GCC_PATH}")
else()
	message(WARNING "Using untested compiler, full C++11 compliance including the standard library is required. When using LLVM/Clang or Intel with a GNU standard library, make sure the used GCC installation is at least version 4.9.0")
endif()

# location of all thirdparty components
set(THIRDPARTY_DIR ${PROJECT_SOURCE_DIR}/thirdparty)

# search for additional cmake modules
# modified cmake modules
list(APPEND CMAKE_MODULE_PATH "${THIRDPARTY_DIR}/cmake/Modules/")
# git version hash
list(APPEND CMAKE_MODULE_PATH "${THIRDPARTY_DIR}/cmake/rpavlik/")

# set output directory
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR})
message(STATUS "CMAKE_BINARY_DIR: " ${CMAKE_BINARY_DIR})

# project wide include dirs
include_directories(${PROJECT_SOURCE_DIR}/include)

# misc. helpers
add_subdirectory(thirdparty/misc/ ${CMAKE_CURRENT_BINARY_DIR}/build.noma_misc)
# benchmark timer
add_subdirectory(thirdparty/bmt/ ${CMAKE_CURRENT_BINARY_DIR}/build.noma_bmt)
# type parser library
add_subdirectory(thirdparty/typa/ ${CMAKE_CURRENT_BINARY_DIR}/build.noma_typa)
# OpenCL helper library
add_subdirectory(thirdparty/ocl/ ${CMAKE_CURRENT_BINARY_DIR}/build.noma_ocl)

# CLI11 (header only)
add_library(cli11_library INTERFACE)
target_include_directories (cli11_library INTERFACE "thirdparty/CLI11/include")

# see CMakeLists.txt in src
add_subdirectory(src)

