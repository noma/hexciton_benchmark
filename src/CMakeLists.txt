# Copyright (c) 2017 Matthias Noack <ma.noack.pr@gmail.com>
#
# See accompanying file LICENSE and README for further information.

# git version source file (avoids recompilation as compared to a define)
include(GetGitRevisionDescription)
get_git_head_revision(GIT_REFSPEC GIT_SHA1)
set(GIT_VERSION "${GIT_SHA1}")
git_describe(GIT_DESCRIBE)
git_get_exact_tag(GIT_EXACT_TAG)
git_local_changes(GIT_LOCAL_CHANGES)
set(GIT_LOCAL_CHANGES "${GIT_LOCAL_CHANGES}")
# generate git version source file from template
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/git_version.cpp.in" "${CMAKE_CURRENT_BINARY_DIR}/git_version.cpp" @ONLY)

# generate compiler version header (uses CMAKE_CXX_COMPILER_ID and CMAKE_CXX_COMPILER_VERSION)
configure_file("${CMAKE_CURRENT_SOURCE_DIR}/compiler_version.cpp.in" "${CMAKE_CURRENT_BINARY_DIR}/compiler_version.cpp" @ONLY)

# common properties for all targets
set(COMMON_SRC compiler_version.cpp git_version.cpp common.cpp kernel/commutator_reference.cpp)
set(COMMON_LIB_DEPS noma_debug noma_memory noma_bmt noma_typa cli11_library)
set(COMMON_COMPILE_FLAGS "-DDEVICE_TYPE=${DEVICE_TYPE} -DNUM_ITERATIONS=${NUM_ITERATIONS} -DNUM_WARMUP=${NUM_WARMUP} -DINTEL_PREFETCH_LEVEL=${INTEL_PREFETCH_LEVEL} -DVEC_LENGTH=${VEC_LENGTH} -DVEC_LENGTH_AUTO=${VEC_LENGTH_AUTO} -DPACKAGES_PER_WG=${PACKAGES_PER_WG} -DDIM=7")

set(OCL_COMPILE_FLAGS "-DOCL_BUILD_OPTIONS=\"${OCL_BUILD_OPTIONS}\" -DVEC_NONE")
set(OMP_COMPILE_FLAGS "-O3 -march=native -DVEC_VCL")

set(OMP_KERNEL_SRC kernel/commutator_omp_empty.cpp
                   kernel/commutator_omp_aosoa.cpp
                   kernel/commutator_omp_aosoa_constants.cpp
                   kernel/commutator_omp_aosoa_direct.cpp
                   kernel/commutator_omp_aosoa_constants_direct.cpp
                   kernel/commutator_omp_aosoa_constants_direct_perm.cpp
                   kernel/commutator_omp_aosoa_constants_direct_perm2to3.cpp
                   kernel/commutator_omp_aosoa_constants_direct_perm2to5.cpp
                   kernel/commutator_omp_manual_aosoa.cpp
                   kernel/commutator_omp_manual_aosoa_constants.cpp
                   kernel/commutator_omp_manual_aosoa_constants_perm.cpp
                   kernel/commutator_omp_manual_aosoa_direct.cpp
                   kernel/commutator_omp_manual_aosoa_constants_direct.cpp
                   kernel/commutator_omp_manual_aosoa_constants_direct_perm.cpp
                   kernel/commutator_omp_manual_aosoa_constants_direct_unrollhints.cpp
                   kernel/commutator_omp_manual_aosoa_constants_direct_perm_unrollhints.cpp)

# OpenCL Benchmark
if (HB_ENABLE_OCL)
	add_executable(benchmark_ocl benchmark_ocl.cpp ${COMMON_SRC})
	target_link_libraries(benchmark_ocl ${COMMON_LIB_DEPS} noma_ocl)

	set_target_properties(benchmark_ocl PROPERTIES
			CXX_STANDARD 11
			CXX_STANDARD_REQUIRED YES
			CXX_EXTENSIONS NO
			)
		
	set_target_properties(benchmark_ocl PROPERTIES COMPILE_FLAGS "${COMMON_COMPILE_FLAGS} ${OCL_COMPILE_FLAGS}")
endif ()

# OpenMP Benchmark
if (HB_ENABLE_OMP)
	add_executable(benchmark_omp benchmark_omp.cpp ${COMMON_SRC} ${OMP_KERNEL_SRC})
	target_link_libraries(benchmark_omp ${COMMON_LIB_DEPS} vlc_library OpenMP::OpenMP_CXX)

	set_target_properties(benchmark_omp PROPERTIES
			CXX_STANDARD 11
			CXX_STANDARD_REQUIRED YES
			CXX_EXTENSIONS NO
			)

	set_target_properties(benchmark_omp PROPERTIES COMPILE_FLAGS "${COMMON_COMPILE_FLAGS} ${OMP_COMPILE_FLAGS}")
endif ()

# OpenMP Benchmark with KART
if (HB_ENABLE_OMP_KART)
	add_executable(benchmark_omp_kart benchmark_omp_kart.cpp ${COMMON_SRC})
	target_link_libraries(benchmark_omp_kart ${COMMON_LIB_DEPS} vlc_library OpenMP::OpenMP_CXX kart)

	set_target_properties(benchmark_omp_kart PROPERTIES
			CXX_STANDARD 11
			CXX_STANDARD_REQUIRED YES
			CXX_EXTENSIONS NO
			)

	set_target_properties(benchmark_omp_kart PROPERTIES COMPILE_FLAGS "${COMMON_COMPILE_FLAGS} ${OMP_COMPILE_FLAGS}")
endif ()