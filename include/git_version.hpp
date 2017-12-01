// Copyright (c) 2017 Matthias Noack <ma.noack.pr@gmail.com>
//
// See accompanying file LICENSE and README for further information.

#ifndef git_version_hpp
#define git_version_hpp

#include <ostream>

extern const char GIT_VERSION_STR[];
extern const char GIT_LOCAL_CHANGES_STR[];

void write_git_version(std::ostream& out);

#endif // git_version_hpp