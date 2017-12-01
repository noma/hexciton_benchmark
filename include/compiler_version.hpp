// Copyright (c) 2017 Matthias Noack <ma.noack.pr@gmail.com>
//
// See accompanying file LICENSE and README for further information.

#ifndef compiler_version_hpp
#define compiler_version_hpp

#include <ostream>

extern const char COMPILER_ID_STR[];
extern const char COMPILER_VERSION_STR[];

void write_compiler_version(std::ostream& out);

#endif // compiler_version_hpp