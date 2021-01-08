// Copyright (c) 2015 Matthias Noack (ma.noack.pr@gmail.com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#include "common.hpp"

#ifdef KART
extern "C" {
#endif
void commutator_omp_aosoa_direct(real_t const* __restrict sigma_in,
                                 real_t* __restrict sigma_out,
                                 real_t const* __restrict hamiltonian,
                                 const int num, const int dim,
                                 const real_t hbar, const real_t dt)
{
	// OpenCL work-groups are mapped to threads
	#pragma omp parallel for
	for (int group_id = 0; group_id < (num / VEC_LENGTH); ++group_id)
	{
		// OpenCL work-items inside a group are mapped to SIMD lanes
		#pragma vector aligned
		#pragma omp simd
		for (int local_id = 0; local_id < VEC_LENGTH; ++local_id)
		{
			// number of package to process == get_global_id(0)
			// number of packages in WG: (WG_SIZE / VEC_LENGTH) 
			#define package_id (group_id * VEC_LENGTH * 2 * dim * dim)
			#define sigma_id local_id

			#define sigma_real(i, j) (package_id + 2 * VEC_LENGTH * (dim * (i) + (j)) + (sigma_id))
			#define sigma_imag(i, j) (package_id + 2 * VEC_LENGTH * (dim * (i) + (j)) + VEC_LENGTH + (sigma_id))

			#define ham_real(i, j) ((i) * dim + (j))
			#define ham_imag(i, j) (dim * dim + (i) * dim + (j))

			// compute commutator: (hamiltonian * sigma_in[sigma_id] - sigma_in[sigma_id] * hamiltonian)
			int i, j, k;
			for (i = 0; i < dim; ++i)
			{
				for (j = 0; j < dim; ++j)
				{
					for (k = 0; k < dim; ++k)
					{
						sigma_out[sigma_imag(i, j)] -= hamiltonian[ham_real(i, k)] * sigma_in[sigma_real(k, j)];
						sigma_out[sigma_imag(i, j)] += sigma_in[sigma_real(i, k)] * hamiltonian[ham_real(k, j)];
						sigma_out[sigma_imag(i, j)] += hamiltonian[ham_imag(i, k)] * sigma_in[sigma_imag(k, j)];
						sigma_out[sigma_imag(i, j)] -= sigma_in[sigma_imag(i, k)] * hamiltonian[ham_imag(k, j)];
						sigma_out[sigma_real(i, j)] += hamiltonian[ham_real(i, k)] * sigma_in[sigma_imag(k, j)];
						sigma_out[sigma_real(i, j)] -= sigma_in[sigma_real(i, k)] * hamiltonian[ham_imag(k, j)];
						sigma_out[sigma_real(i, j)] += hamiltonian[ham_imag(i, k)] * sigma_in[sigma_real(k, j)];
						sigma_out[sigma_real(i, j)] -= sigma_in[sigma_imag(i, k)] * hamiltonian[ham_real(k, j)];
					}
				}
			}
		}
	}
}

#ifdef KART
} // extern "C"
#endif

