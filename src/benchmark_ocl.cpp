// Copyright (c) 2015 Matthias Noack (ma.noack.pr@gmail.com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#include <iostream>

#include <cstring> // memcpy
#include <cmath>
#include <cstddef>
#include <string>
#include <sstream>

#include "noma/ocl/helper.hpp" // noma::ocl::helper
#include "noma/bmt/bmt.hpp" // noma::bmt

#include "common.hpp"
//#include "kernel/kernel.hpp"

#ifndef INTEL_PREFETCH_LEVEL
	#define INTEL_PREFETCH_LEVEL 1
#endif
#ifndef PACKAGES_PER_WG
	#define PACKAGES_PER_WG 4
#endif
#ifndef NUM_SUB_GROUPS
	#define NUM_SUB_GROUPS 2
#endif
#ifndef CHUNK_SIZE
	#define CHUNK_SIZE 16
#endif
#ifndef WARP_SIZE
	#define WARP_SIZE 32
#endif


int main(void)
{
	print_compile_config(std::cerr);
	std::cerr << "VEC_LENGTH_AUTO: " << VEC_LENGTH_AUTO << std::endl;

	// constants
	const size_t dim = DIM;
	const size_t num = NUM;
	const real_t hbar = 1.0 / std::acos(-1.0); // == 1 / Pi
	const real_t dt = 1.0e-3;
	const real_t hdt = dt / hbar;

	real_t deviation = 0.0;

	// allocate memory
	size_t size_hamiltonian = dim * dim;
	size_t size_hamiltonian_byte = sizeof(complex_t) * size_hamiltonian;
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
	std::cout << "name\t" << noma::bmt::statistics::header_string(false) << std::endl;
	
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

	// setup compile options
	const std::string compile_options_common = "-Iinclude -DNUM=" STR(NUM) " -DDIM=" STR(DIM);
	const std::string compile_options_auto = compile_options_common + " -DVEC_LENGTH=" STR(VEC_LENGTH_AUTO) " -DPACKAGES_PER_WG=" STR(PACKAGES_PER_WG);
	const std::string compile_options_manual = compile_options_common + " -DVEC_LENGTH=" STR(VEC_LENGTH) " -DPACKAGES_PER_WG=" STR(PACKAGES_PER_WG);
	const std::string compile_options_gpu = compile_options_common + " -DVEC_LENGTH=2 -DCHUNK_SIZE=" STR(CHUNK_SIZE) " -DNUM_SUB_GROUPS=" STR(NUM_SUB_GROUPS);

	cl_int err = 0;
	// set up OpenCL using noma-ocl
	noma::ocl::config ocl_config("", false);
	noma::ocl::helper ocl_helper(ocl_config);
	// output the used device
	ocl_helper.write_device_info(std::cerr);

	// allocate OpenCL device memory // DONE: replace with create_buffer() from noma::ocl, use C++ interface
	noma::ocl::buffer hamiltonian_ocl = ocl_helper.create_buffer(CL_MEM_READ_ONLY, size_hamiltonian_byte);
	noma::ocl::buffer sigma_in_ocl = ocl_helper.create_buffer(CL_MEM_READ_WRITE, size_sigma_byte);
	noma::ocl::buffer sigma_out_ocl = ocl_helper.create_buffer(CL_MEM_READ_WRITE, size_sigma_byte);

	// function to build and set-up a kernel
	auto prepare_kernel = [&](const std::string& file_name, const std::string& kernel_name, const std::string& compile_options)
	{
		// build kernel
		noma::bmt::duration build_time;
		cl::Program prog;
		{
			noma::bmt::timer t;
			prog = ocl_helper.create_program_from_file(file_name, "", compile_options);
			build_time = t.elapsed();
		}
		
		std::stringstream time_ss;
		time_ss << std::scientific << std::chrono::duration_cast<noma::bmt::seconds>(build_time).count();
		std::cerr << "build_time\t" << kernel_name << "\t" << time_ss.str() << std::endl;
		
		// get kernel from programm using C++ OCL API
		cl::Kernel kernel(prog, kernel_name.c_str(), &err);
		noma::ocl::error_handler(err, "Error creating kernel: '" + kernel_name + "'.");

		// set kernel arguments
		err = kernel.setArg(0, static_cast<cl::Buffer>(sigma_in_ocl));
		noma::ocl::error_handler(err, "kernel.setArg(0)");
		err = kernel.setArg(1, static_cast<cl::Buffer>(sigma_out_ocl));
		noma::ocl::error_handler(err, "kernel.setArg(1)");
		err = kernel.setArg(2, static_cast<cl::Buffer>(hamiltonian_ocl));
		noma::ocl::error_handler(err, "kernel.setArg(2)");
		// GCC bug work-around (#ifdef __GNUC__) & type conversion
		// http://stackoverflow.com/questions/19616610/c11-lambda-doesnt-take-const-variable-by-reference-why
		int32_t num_tmp = static_cast<int32_t>(num);
		err = kernel.setArg(3, num_tmp);
		noma::ocl::error_handler(err, "kernel.setArg(3)");
		int32_t dim_tmp = static_cast<int32_t>(dim);
		err = kernel.setArg(4, dim_tmp);
		noma::ocl::error_handler(err, "kernel.setArg(4)");
		real_t hbar_tmp = static_cast<real_t>(hbar);
		err = kernel.setArg(5, hbar_tmp);
		noma::ocl::error_handler(err, "kernel.setArg(5)");
		auto dt_tmp = dt;
		err = kernel.setArg(6, dt_tmp);
		noma::ocl::error_handler(err, "kernel.setArg(6)");

		return kernel;
	}; // prepare_kernel

	auto write_hamiltonian = [&]()
	{
		err = ocl_helper.queue().enqueueWriteBuffer(hamiltonian_ocl, CL_TRUE, 0, size_hamiltonian_byte, hamiltonian);
		noma::ocl::error_handler(err, "enqueueWriteBuffer(hamiltonian)");
	}; // write_hamiltonian

	// lambda to write data to the device
	auto write_sigma = [&]()
	{
		// write data to device
		err = ocl_helper.queue().enqueueWriteBuffer(sigma_in_ocl, CL_TRUE, 0, size_sigma_byte, sigma_in);
		noma::ocl::error_handler(err, "enqueueWriteBuffer(sigma_in_ocl)");
		err = ocl_helper.queue().enqueueWriteBuffer(sigma_out_ocl, CL_TRUE, 0, size_sigma_byte, sigma_out);
		noma::ocl::error_handler(err, "enqueueWriteBuffer(sigma_out_ocl)");
	}; // write_sigma

	// lambda to get the result from the device and compare it with the reference
	auto read_and_compare_sigma = [&]()
	{
		// read data from device	
		err = ocl_helper.queue().enqueueReadBuffer(sigma_out_ocl, CL_TRUE, 0, size_sigma_byte, sigma_out);
		noma::ocl::error_handler(err, "enqueueReadBuffer(sigma_out_ocl)");
		// compute deviation from reference	(small deviations are expected)
		deviation = compare_matrices(sigma_out, sigma_reference_transformed, dim, num);
		std::cerr << "Deviation:\t" << deviation << std::endl;
	}; // read_and_compare_sigma

	// Lambda to: transform memory, benchmark, compare results
	// NOTE:
	// struct noma::ocl::nd_range
	// {
	//     cl::NDRange offset;
	//     cl::NDRange global;
	//     cl::NDRange local;
	// };
	auto benchmark = [&](const std::string& file_name, const std::string& kernel_name,
	                     const std::string& compile_options, size_t vec_length, const noma::ocl::nd_range& range,
	                     decltype(&transform_matrices_aos_to_aosoa) transformation_sigma,
	                     bool scale_hamiltonian,
	                     decltype(&transform_matrix_aos_to_soa) transformation_hamiltonian)
	{
		initialise_hamiltonian(hamiltonian, dim);
		if (scale_hamiltonian) 
			transform_matrix_scale_aos(hamiltonian, dim, dt / hbar); // pre-scale hamiltonian
		if (transformation_hamiltonian)
			transformation_hamiltonian(hamiltonian, dim);	
		write_hamiltonian();

		initialise_sigma(sigma_in, sigma_out, dim, num);
		std::memcpy(sigma_reference_transformed, sigma_reference, size_sigma_byte);
		// transform memory layout if a transformation is specified
		if (transformation_sigma)
		{
			// transform reference for comparison
			transformation_sigma(sigma_reference_transformed, dim, num, vec_length);
			// tranform sigma
			transformation_sigma(sigma_in, dim, num, vec_length);
		}
		write_sigma();

		cl::Kernel kernel = prepare_kernel(file_name, kernel_name, compile_options);

		// NUM_ITERATIONS includes NUM_WARMUP, while statistics' ctor expects the number of measurements and warmups separately
		noma::bmt::statistics stats(kernel_name, NUM_ITERATIONS-NUM_WARMUP, NUM_WARMUP);

		// benchmark loop
		for (size_t i = 0; i < NUM_ITERATIONS; ++i)
			stats.add(noma::bmt::duration(static_cast<noma::bmt::rep>(ocl_helper.run_kernel_timed(kernel, range))));

		std::cout << stats.string() << std::endl;

		read_and_compare_sigma();
	}; // benchmark

	// build one-dimensional nd_range
	noma::ocl::nd_range nd_range_naive;
	nd_range_naive.global = cl::NDRange(num);
	nd_range_naive.local  = cl::NullRange;
	nd_range_naive.offset = cl::NullRange;

	// BENCHMARK: empty kernel
	benchmark("src/kernel/commutator_ocl_empty.cl", "commutator_ocl_empty",
	          compile_options_common, VEC_LENGTH,
	          nd_range_naive, NO_TRANSFORM, NO_SCALE_HAMILT, NO_TRANSFORM);

	// BENCHMARK: initial kernel
	benchmark("src/kernel/commutator_ocl_initial.cl", "commutator_ocl_initial",
	          compile_options_common, VEC_LENGTH,
	          nd_range_naive, NO_TRANSFORM, NO_SCALE_HAMILT, NO_TRANSFORM);

	// BENCHMARK: refactored initial kernel
	benchmark("src/kernel/commutator_ocl_refactored.cl", "commutator_ocl_refactored",
	          compile_options_auto, VEC_LENGTH,
	          nd_range_naive, NO_TRANSFORM, NO_SCALE_HAMILT, NO_TRANSFORM);

	// BENCHMARK: refactored initial kernel with direct store
	benchmark("src/kernel/commutator_ocl_refactored_direct.cl", "commutator_ocl_refactored_direct",
	          compile_options_auto, VEC_LENGTH,
	          nd_range_naive, NO_TRANSFORM, SCALE_HAMILT, NO_TRANSFORM);

	// BENCHMARK: automatically vectorised kernel with naive NDRange and indexing
	benchmark("src/kernel/commutator_ocl_aosoa_naive.cl", "commutator_ocl_aosoa_naive",
	          compile_options_auto, VEC_LENGTH_AUTO,
	          nd_range_naive, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: automatically vectorised kernel with naive NDRange and indexing and compile time constants
	benchmark("src/kernel/commutator_ocl_aosoa_naive_constants.cl", "commutator_ocl_aosoa_naive_constants",
	          compile_options_auto, VEC_LENGTH_AUTO,
	          nd_range_naive, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: automatically vectorised kernel with naive NDRange and indexing and direct store
	benchmark("src/kernel/commutator_ocl_aosoa_naive_direct.cl", "commutator_ocl_aosoa_naive_direct",
	          compile_options_auto, VEC_LENGTH_AUTO,
	          nd_range_naive, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: automatically vectorised kernel with naive NDRange and indexing, compile time constants, and direct store
	benchmark("src/kernel/commutator_ocl_aosoa_naive_constants_direct.cl", "commutator_ocl_aosoa_naive_constants_direct",
	          compile_options_auto, VEC_LENGTH_AUTO,
	          nd_range_naive, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

		// build two-dimensional nd_range
	noma::ocl::nd_range nd_range_auto_vec;
	nd_range_auto_vec.global = cl::NDRange(VEC_LENGTH_AUTO, num / (VEC_LENGTH_AUTO));
	nd_range_auto_vec.local  = cl::NDRange(VEC_LENGTH_AUTO, PACKAGES_PER_WG);
	nd_range_auto_vec.offset = cl::NullRange;

	// BENCHMARK: automatically vectorised kernel with compiler-friendly NDRange and indexing 
	benchmark("src/kernel/commutator_ocl_aosoa.cl", "commutator_ocl_aosoa",
	          compile_options_auto, VEC_LENGTH_AUTO,
	          nd_range_auto_vec, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: automatically vectorised kernel with compiler-friendly NDRange and indexing, and compile time constants
	benchmark("src/kernel/commutator_ocl_aosoa_constants.cl", "commutator_ocl_aosoa_constants",
	          compile_options_auto, VEC_LENGTH_AUTO,
	          nd_range_auto_vec, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: automatically vectorised kernel with compiler-friendly NDRange and indexing, and direct store
	benchmark("src/kernel/commutator_ocl_aosoa_direct.cl", "commutator_ocl_aosoa_direct",
	          compile_options_auto, VEC_LENGTH_AUTO,
	          nd_range_auto_vec, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: automatically vectorised kernel with compiler-friendly NDRange and indexing, compile time constants, and direct store
	benchmark("src/kernel/commutator_ocl_aosoa_constants_direct.cl", "commutator_ocl_aosoa_constants_direct",
	          compile_options_auto, VEC_LENGTH_AUTO,
	          nd_range_auto_vec, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: automatically vectorised kernel with compiler-friendly NDRange and indexing, compile time constants, direct store, and permuted loops with temporaries
	benchmark("src/kernel/commutator_ocl_aosoa_constants_direct_perm.cl", "commutator_ocl_aosoa_constants_direct_perm",
	          compile_options_auto, VEC_LENGTH_AUTO,
	          nd_range_auto_vec, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

		// build one-dimensional nd_range, divide num by VEC_LENGTH
	noma::ocl::nd_range nd_range_manual_vec;
	nd_range_manual_vec.global = cl::NDRange(num / (VEC_LENGTH));
	nd_range_manual_vec.local  = cl::NullRange;
	nd_range_manual_vec.offset = cl::NullRange;

	// BENCHMARK: manually vectorised kernel
	benchmark("src/kernel/commutator_ocl_manual_aosoa.cl", "commutator_ocl_manual_aosoa",
	          compile_options_manual, VEC_LENGTH,
	          nd_range_manual_vec, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: manually vectorised kernel with compile time constants
	benchmark("src/kernel/commutator_ocl_manual_aosoa_constants.cl", "commutator_ocl_manual_aosoa_constants",
	          compile_options_manual, VEC_LENGTH,
	          nd_range_manual_vec, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: manually vectorised kernel with compile time constants
	benchmark("src/kernel/commutator_ocl_manual_aosoa_constants_prefetch.cl", "commutator_ocl_manual_aosoa_constants_prefetch",
	          compile_options_manual, VEC_LENGTH,
	          nd_range_manual_vec, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: manually vectorised kernel with direct store
	benchmark("src/kernel/commutator_ocl_manual_aosoa_direct.cl", "commutator_ocl_manual_aosoa_direct",
	          compile_options_manual, VEC_LENGTH,
	          nd_range_manual_vec, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: manually vectorised kernel with compile time constants and direct store
	benchmark("src/kernel/commutator_ocl_manual_aosoa_constants_direct.cl", "commutator_ocl_manual_aosoa_constants_direct",
	          compile_options_manual, VEC_LENGTH,
	          nd_range_manual_vec, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: manually vectorised kernel with compile time constants and direct store
	benchmark("src/kernel/commutator_ocl_manual_aosoa_constants_direct_prefetch.cl", "commutator_ocl_manual_aosoa_constants_direct_prefetch",
	          compile_options_manual, VEC_LENGTH,
	          nd_range_manual_vec, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: manually vectorised kernel with compile time constants, direct store, and permuted loops with temporaries
	benchmark("src/kernel/commutator_ocl_manual_aosoa_constants_direct_perm.cl", "commutator_ocl_manual_aosoa_constants_direct_perm",
	          compile_options_manual, VEC_LENGTH,
	          nd_range_manual_vec, &transform_matrices_aos_to_aosoa, SCALE_HAMILT, &transform_matrix_aos_to_soa);

	// BENCHMARK: final GPGPU kernel, optimised for Nvidia K40
	{ // keep things local
	auto ceil_n = [](size_t x, size_t n) { return ((x + n - 1) / n) * n; };
	size_t block_dim_x = ceil_n(dim * dim, WARP_SIZE);
	size_t block_dim_y = NUM_SUB_GROUPS;

	// build two-dimensional nd_range optimised for Nvidia K40
	noma::ocl::nd_range nd_range_gpu;
	nd_range_gpu.global = cl::NDRange((NUM / (block_dim_y * CHUNK_SIZE)) * block_dim_x, block_dim_y);
	nd_range_gpu.local  = cl::NDRange(                                     block_dim_x, block_dim_y);
	nd_range_gpu.offset = cl::NullRange;

	benchmark("src/kernel/commutator_ocl_gpu_final.cl", "commutator_ocl_gpu_final", compile_options_gpu,
	          2, // NOTE: vec_length has a fix value of 2 for this kernel
	          nd_range_gpu, NO_TRANSFORM, SCALE_HAMILT, NO_TRANSFORM);
	}

	delete hamiltonian;
	delete sigma_in;
	delete sigma_out;
	delete sigma_reference;

	return 0;
}
