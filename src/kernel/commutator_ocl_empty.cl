// Copyright (c) 2015 Matthias Noack (ma.noack.pr@gmail.com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#include "kernel/common.cl"

__kernel
void commutator_ocl_empty(__global real_2_t const* restrict sigma_in, 
                            __global real_2_t* restrict sigma_out, 
                            __global real_2_t const* restrict hamiltonian, 
                            const int num, const int dim,
                            const real_t hbar, const real_t dt)
{

}
