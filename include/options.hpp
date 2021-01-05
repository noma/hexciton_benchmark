// Copyright (c) 2021 Matthias Noack (ma.noack.pr@gmail.com)
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)

#ifndef options_hpp
#define options_hpp

#include <string>
#include <CLI11/CLI11.hpp>

class options {
public:
	options(int* argc_ptr, char** argv_ptr[])
	:  app_(*argv_ptr[0]) // use executable name
	{
		// command line configuration
		app_.set_help_flag("-h,--help", "Print command line options.");
		app_.add_flag("-n,--no_check", no_check_, "Disables correctness check, speeds up benchmark.");
		app_.add_option("-d,--data-file", data_filename_, "Optional output file for benchmark data");
		app_.add_option("-m,--message-file", message_filename_, "Optional output file for program messages.");

		// parse command line
		try {
			app_.parse(*argc_ptr, *argv_ptr);
		} catch(const CLI::ParseError &e) {
			std::exit(app_.exit(e)); // fail hard
		}
	}

	// getters
	const bool& no_check() const { return no_check_; }
	const std::string& data_filename() const { return data_filename_; }
	const std::string& message_filename() const { return message_filename_; }

private:
	CLI::App app_;

	// command line options
	bool no_check_ = false;
	std::string data_filename_;
	std::string message_filename_;
};

#endif // options_hpp
