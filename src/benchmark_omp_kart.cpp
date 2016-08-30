// Copyright (c) 2015 Matthias Noack (ma.noack.pr@gmail.com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#include <iostream>

#include <cstring> // memcpy
#include <cmath>
#include <sstream>

#include "ham/util/time.hpp" // ham::util::time

#include "common.hpp"
#include "kernel/kernel.hpp"

#include "kart/kart.hpp"

using namespace ham::util;

int main(void)
{
	print_compile_config(std::cerr);

	// constants
	const size_t dim = DIM;
	const size_t num = NUM;
	const real_t hbar = 1.0 / std::acos(-1.0); // == 1 / Pi
	const real_t dt = 1.0e-3; 

	real_t deviation = 0.0;

	// allocate memory
	size_t size_hamiltonian = dim * dim;
	size_t size_sigma = size_hamiltonian * num;
	size_t size_sigma_byte = sizeof(complex_t) * size_sigma;

	complex_t* hamiltonian = allocate_aligned<complex_t>(size_hamiltonian);
	complex_t* sigma_in = allocate_aligned<complex_t>(size_sigma);
	complex_t* sigma_out = allocate_aligned<complex_t>(size_sigma);
	complex_t* sigma_reference = allocate_aligned<complex_t>(size_sigma);
	complex_t* sigma_reference_transformed = allocate_aligned<complex_t>(size_sigma);

	// initialise memory
	initialise_hamiltonian(hamiltonian, dim);
	initialise_sigma(sigma_in, sigma_out, dim, num);

	// print output header
	std::cout << "name\t" << time::statistics::header_string() << std::endl;
	
	// perform reference computation for correctness analysis
	benchmark_kernel(
		[&]() // lambda expression
		{
			commutator_reference(sigma_in, sigma_out, hamiltonian, dim, num, hbar, dt);
		},
		"commutator_reference",
		NUM_ITERATIONS,
		NUM_WARMUP);

	// copy reference results
	std::memcpy(sigma_reference, sigma_out, size_sigma_byte);


	#define SCALAR_ARGUMENTS reinterpret_cast<real_t*>(sigma_in),    \
			 reinterpret_cast<real_t*>(sigma_out),   \
			 reinterpret_cast<real_t*>(hamiltonian), \
			 num, dim, 0.0, 0.0

	#define VECTOR_ARGUMENTS reinterpret_cast<real_vec_t*>(sigma_in),  \
			 reinterpret_cast<real_vec_t*>(sigma_out), \
			 reinterpret_cast<real_t*>(hamiltonian),   \
			 num, dim, 0.0, 0.0


	// Lambda to: transform memory, benchmark, compare results
	auto benchmark = [&](const std::string& file_name,
	                     const std::string& kernel_name,
	                     std::function<void(void*)> kernel_caller,
	                     decltype(&transform_matrices_aos_to_aosoa) transformation_sigma,
	                     bool scale_hamiltonian,
	                     decltype(&transform_matrix_aos_to_soa) transformation_hamiltonian)
	{
		// kart runtime compilation
		auto kernel_prog = kart::program::create_from_file(file_name);
		kart::toolset ts; // create a default toolset
		// add compiler and linker options as needed
		std::stringstream options;
		options << " -DNUM_ITERATIONS=" << NUM_ITERATIONS << " -DNUM_WARMUP=" << NUM_WARMUP;
		#if defined(VEC_INTEL)
		options << " -DVEC_INTEL";
		#elif defined(VEC_VC)
		options << " -DVEC_VC";
		#elif defined(VEC_VCL)
		options << " -DVEC_VCL";
		#else
			out << "NO_VEC_LIB";
		#endif
		ts.compiler_options += options.str(); // append to default initialised options

		time::rep build_time = 0.0;
		{
			time::timer t;
			kernel_prog.build(ts); // build with custom toolset
			build_time = t.elapsed();
		}
		
		std::stringstream time_ss;
		time_ss << std::scientific << build_time;
		std::cout << "build_time\t" << kernel_name << "\t" << time_ss.str() << std::endl;
		
		auto kernel = kernel_prog.get_kernel<void*>(kernel_name); // kernel_caller knows the type
		
		// benchmark kernel as usual
		initialise_hamiltonian(hamiltonian, dim);
		if (scale_hamiltonian) 
			transform_matrix_scale_aos(hamiltonian, dim, dt / hbar); // pre-scale hamiltonian
		if (transformation_hamiltonian)
			transformation_hamiltonian(hamiltonian, dim);	
	
		initialise_sigma(sigma_in, sigma_out, dim, num);
		std::memcpy(sigma_reference_transformed, sigma_reference, size_sigma_byte);
		// transform memory layout if a transformation is specified
		if (transformation_sigma)
		{
			// transform reference for comparison
			transformation_sigma(sigma_reference_transformed, dim, num, VEC_LENGTH);
			// tranform sigma
			transformation_sigma(sigma_in, dim, num, VEC_LENGTH);
		}
		
		benchmark_kernel([&](){ kernel_caller(kernel); },
		                 kernel_name, NUM_ITERATIONS, NUM_WARMUP);
		
		// compute deviation from reference	(small deviations are expected)
		deviation = compare_matrices(sigma_out, sigma_reference_transformed, dim, num);
		std::cerr << "Deviation:\t" << deviation << std::endl;
	};

	auto scalar_caller = [&](void* kernel) 
	                     { 
	                         reinterpret_cast<decltype(commutator_omp_aosoa)*>(kernel)(SCALAR_ARGUMENTS); 
	                     }; 


	auto vector_caller = [&](void* kernel) 
	                     { 
	                         reinterpret_cast<decltype(commutator_omp_manual_aosoa)*>(kernel)(VECTOR_ARGUMENTS); 
	                     }; 


	// BENCHMARK
	benchmark("src/kernel/commutator_omp_empty.cpp",
	          "commutator_omp_empty",
	          scalar_caller,
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);
		
	// BENCHMARK
	benchmark("src/kernel/commutator_omp_aosoa.cpp",
	          "commutator_omp_aosoa",
	          scalar_caller,
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK
	benchmark("src/kernel/commutator_omp_aosoa_constants.cpp",
	          "commutator_omp_aosoa_constants",
	          scalar_caller,
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK
	benchmark("src/kernel/commutator_omp_aosoa_direct.cpp",
	          "commutator_omp_aosoa_direct",
	          scalar_caller,
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK
	benchmark("src/kernel/commutator_omp_aosoa_constants_direct.cpp",
	          "commutator_omp_aosoa_constants_direct",
	          scalar_caller,
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK
	benchmark("src/kernel/commutator_omp_aosoa_constants_direct_perm.cpp",
	          "commutator_omp_aosoa_constants_direct_perm",
	          scalar_caller,
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK
	benchmark("src/kernel/commutator_omp_aosoa_constants_direct_perm2to3.cpp",
	          "commutator_omp_aosoa_constants_direct_perm2to3",
	          scalar_caller,
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK
	benchmark("src/kernel/commutator_omp_aosoa_constants_direct_perm2to5.cpp",
	          "commutator_omp_aosoa_constants_direct_perm2to5",
	          scalar_caller,
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);


	// manually vectorised kernels

	// BENCHMARK: 
	benchmark("src/kernel/commutator_omp_manual_aosoa.cpp",
	          "commutator_omp_manual_aosoa",
	          vector_caller, 
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark("src/kernel/commutator_omp_manual_aosoa_constants.cpp",
	          "commutator_omp_manual_aosoa_constants",
	          vector_caller, 
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark("src/kernel/commutator_omp_manual_aosoa_constants_perm.cpp",
	          "commutator_omp_manual_aosoa_constants_perm",
	          vector_caller, 
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark("src/kernel/commutator_omp_manual_aosoa_direct.cpp",
	          "commutator_omp_manual_aosoa_direct",
	          vector_caller, 
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark("src/kernel/commutator_omp_manual_aosoa_constants_direct.cpp",
	          "commutator_omp_manual_aosoa_constants_direct",
	          vector_caller, 
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark("src/kernel/commutator_omp_manual_aosoa_constants_direct_perm.cpp",
	          "commutator_omp_manual_aosoa_constants_direct_perm",
	          vector_caller, 
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark("src/kernel/commutator_omp_manual_aosoa_constants_direct_unrollhints.cpp",
	          "commutator_omp_manual_aosoa_constants_direct_unrollhints",
	          vector_caller, 
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark("src/kernel/commutator_omp_manual_aosoa_constants_direct_perm_unrollhints.cpp",
	          "commutator_omp_manual_aosoa_constants_direct_perm_unrollhints",
	          vector_caller, 
	          &transform_matrices_aos_to_aosoa,
	          SCALE_HAMILT,
	          &transform_matrix_aos_to_soa);

	delete hamiltonian;
	delete sigma_in;
	delete sigma_out;
	delete sigma_reference;

	return 0;
}

