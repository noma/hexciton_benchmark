// Copyright (c) 2015 Matthias Noack (ma.noack.pr@gmail.com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#include <iostream>

#include <cstring> // memcpy
#include <cmath>

#include "noma/bmt/bmt.hpp" // noma::bmt

#include "common.hpp"
#include "kernel/kernel.hpp"
#include "options.hpp"

int main(int argc, char* argv[])
{
	// command line parsing
	options cli(&argc, &argv);

	std::unique_ptr<std::ofstream> data_file;
	std::unique_ptr<std::ofstream> message_file;

	if (!cli.data_filename().empty()) {
		data_file.reset(new std::ofstream(cli.data_filename()));
	}

	if (!cli.message_filename().empty()) {
		message_file.reset(new std::ofstream(cli.message_filename()));
	}

	// use output files if specified, or standard streams otherwise
	std::ostream& data_stream = data_file ? *data_file : std::cout;
	std::ostream& message_stream = message_file ? *message_file : std::cerr;

	print_compile_config(message_stream);

	// constants
	const size_t dim = DIM;
	const size_t num = NUM;
	const real_t hbar = 1.0 / std::acos(-1.0); // == 1 / Pi
	const real_t dt = 1.0e-3; 

	// allocate memory
	size_t size_hamiltonian = dim * dim;
	size_t size_sigma = size_hamiltonian * num;
	size_t size_sigma_byte = sizeof(complex_t) * size_sigma;

	complex_t* hamiltonian = allocate_aligned<complex_t>(size_hamiltonian);
	complex_t* sigma_in = allocate_aligned<complex_t>(size_sigma);
	complex_t* sigma_out = allocate_aligned<complex_t>(size_sigma);
	complex_t* sigma_reference = cli.no_check() ? nullptr : allocate_aligned<complex_t>(size_sigma);
	complex_t* sigma_reference_transformed = cli.no_check() ? nullptr : allocate_aligned<complex_t>(size_sigma);

	// initialise memory
	initialise_hamiltonian(hamiltonian, dim);
	initialise_sigma(sigma_in, sigma_out, dim, num);

	// print output header
	data_stream << noma::bmt::statistics::header_string(true) << '\t' << "result_deviation" << std::endl;

	if (!cli.no_check()) {
		// perform reference computation for correctness analysis
		benchmark_kernel(
			[&]() // lambda expression
			{
				commutator_reference(sigma_in, sigma_out, hamiltonian, dim, num, hbar, dt);
			},
			"commutator_reference",
			cli.runs(),
			cli.warmup_runs(),
			data_stream);

			data_stream << '\t' << std::scientific << 0.0 << std::endl; // zero deviation for reference

		// copy reference results
		std::memcpy(sigma_reference, sigma_out, size_sigma_byte);
	}

	// Lambda to: transform memory, benchmark, compare results
	auto benchmark = [&](std::function<void()> kernel,
	                     std::string name,
	                     decltype(&transform_matrices_aos_to_aosoa) transformation_sigma,
	                     bool scale_hamiltonian,
	                     decltype(&transform_matrix_aos_to_soa) transformation_hamiltonian)
	{
		initialise_hamiltonian(hamiltonian, dim);
		if (scale_hamiltonian) 
			transform_matrix_scale_aos(hamiltonian, dim, dt / hbar); // pre-scale hamiltonian
		if (transformation_hamiltonian)
			transformation_hamiltonian(hamiltonian, dim);	
	
		initialise_sigma(sigma_in, sigma_out, dim, num);
		if(!cli.no_check()) {
			std::memcpy(sigma_reference_transformed, sigma_reference, size_sigma_byte);
		}

		// transform memory layout if a transformation is specified
		if (transformation_sigma)
		{
			if(!cli.no_check()) {
				// transform reference for comparison
				transformation_sigma(sigma_reference_transformed, dim, num, VEC_LENGTH);
			}
			// transform sigma
			transformation_sigma(sigma_in, dim, num, VEC_LENGTH);
		}
		
		benchmark_kernel(kernel, name, cli.runs(), cli.warmup_runs(), data_stream);

		// append deviation column
		data_stream << '\t';
		if (cli.no_check()) {
			data_stream << "NA";
		} else {
			// compute deviation from reference	(small deviations are expected)
			real_t deviation = compare_matrices(sigma_out, sigma_reference_transformed, dim, num);
			data_stream << std::scientific << deviation;
		}
		data_stream << std::endl;
	};
	
	
#define SCALAR_ARGUMENTS reinterpret_cast<real_t*>(sigma_in),    \
			 reinterpret_cast<real_t*>(sigma_out),   \
			 reinterpret_cast<real_t*>(hamiltonian), \
			 num, dim, 0.0, 0.0

	// BENCHMARK
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_empty( SCALAR_ARGUMENTS );
		},
		"commutator_omp_empty",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);
	
	// BENCHMARK
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_aosoa( SCALAR_ARGUMENTS );
		},
		"commutator_omp_aosoa",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_aosoa_constants( SCALAR_ARGUMENTS );
		},
		"commutator_omp_aosoa_constants",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_aosoa_direct( SCALAR_ARGUMENTS );
		},
		"commutator_omp_aosoa_direct",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_aosoa_constants_direct( SCALAR_ARGUMENTS );
		},
		"commutator_omp_aosoa_constants_direct",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_aosoa_constants_direct_perm( SCALAR_ARGUMENTS );
		},
		"commutator_omp_aosoa_constants_direct_perm",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_aosoa_constants_direct_perm2to3( SCALAR_ARGUMENTS );
		},
		"commutator_omp_aosoa_constants_direct_perm2to3",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_aosoa_constants_direct_perm2to5( SCALAR_ARGUMENTS );
		},
		"commutator_omp_aosoa_constants_direct_perm2to5",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);		
		

	// manually vectorised kernels

#define VECTOR_ARGUMENTS reinterpret_cast<real_vec_t*>(sigma_in),  \
			 reinterpret_cast<real_vec_t*>(sigma_out), \
			 reinterpret_cast<real_t*>(hamiltonian),   \
			 num, dim, 0.0, 0.0
	// BENCHMARK: 
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_manual_aosoa( VECTOR_ARGUMENTS );
		},
		"commutator_omp_manual_aosoa",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_manual_aosoa_constants( VECTOR_ARGUMENTS );
		},
		"commutator_omp_manual_aosoa_constants",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_manual_aosoa_constants_perm( VECTOR_ARGUMENTS );
		},
		"commutator_omp_manual_aosoa_constants_perm",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_manual_aosoa_direct( VECTOR_ARGUMENTS );
		},
		"commutator_omp_manual_aosoa_direct",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_manual_aosoa_constants_direct( VECTOR_ARGUMENTS );
		},
		"commutator_omp_manual_aosoa_constants_direct",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_manual_aosoa_constants_direct_perm( VECTOR_ARGUMENTS );
		},
		"commutator_omp_manual_aosoa_constants_direct_perm",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: 
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_manual_aosoa_constants_direct_unrollhints( VECTOR_ARGUMENTS );
		},
		"commutator_omp_manual_aosoa_constants_direct_unrollhints",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);		
		
	// BENCHMARK: 
	benchmark(
		[&]() // lambda expression
		{
			commutator_omp_manual_aosoa_constants_direct_perm_unrollhints( VECTOR_ARGUMENTS );
		},
		"commutator_omp_manual_aosoa_constants_direct_perm_unrollhints",
		&transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);		
		


	delete hamiltonian;
	delete sigma_in;
	delete sigma_out;

	if (!cli.no_check()) {
		delete sigma_reference;
		delete sigma_reference_transformed;
	}

	return 0;
}

