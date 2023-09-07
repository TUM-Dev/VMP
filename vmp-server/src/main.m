/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <getopt.h>
#include <stdlib.h>

#import "VMPServerMain.h"

// TODO: Move into meson configuration
#define VERSION_MAJOR 0
#define VERSION_MINOR 1
#define VERSION_PATCH 0

#define DEFAULT_PATHS @[ @"~/.config/VMPServer", @"/etc/VMPServer" ]

#define USAGE_MSG                                                                                                      \
	"Usage: VMPServer [OPTION]...\n"                                                                                   \
	"\n"                                                                                                               \
	"  -h, --help\t\t\tPrint this help message\n"                                                                      \
	"  -v, --version\t\t\tPrint version information\n"                                                                 \
	"  -c, --config=PATH\t\tPath to configuration file\n"

static void version(void) { fprintf(stderr, "VMPServer %d.%d.%d\n", VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH); }

static void usage(void) { fputs(USAGE_MSG, stderr); }

int main(int argc, char *argv[]) {
	@autoreleasepool {
		NSRunLoop *runLoop;
		NSString *selectedPath;
		NSArray *paths = DEFAULT_PATHS;

		struct option longopts[] = {{"help", no_argument, NULL, 'h'},
									{"version", no_argument, NULL, 'v'},
									{"config", required_argument, NULL, 'c'},
									{NULL, 0, NULL, 0}};
		int ch;
		while ((ch = getopt_long(argc, argv, "hvc:", longopts, NULL)) != -1) {
			switch (ch) {
			case 'h':
				usage();
				return EXIT_SUCCESS;
			case 'v':
				version();
				return EXIT_SUCCESS;
			case 'c':
				if (optarg) {
					paths = @[ [NSString stringWithUTF8String:optarg] ];
				} else {
					usage();
					return EXIT_FAILURE;
				}
				break;
			default:
				puts("Invalid option");
				usage();
				return EXIT_FAILURE;
			}
		}

		runLoop = [NSRunLoop currentRunLoop];

		for (NSString *path in paths) {
			// Check if file at path exists
			if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
				selectedPath = path;
			}
		}

		if (!selectedPath) {
			NSLog(@"No configuration file found");
			return EXIT_FAILURE;
		}

		// Create configuration from file
		NSError *error;
		VMPServerConfiguration *configuration = [VMPServerConfiguration configurationWithPlist:selectedPath
																					 withError:&error];
		if (!configuration) {
			NSLog(@"Failed to create configuration from file %@: %@", selectedPath, error);
			return EXIT_FAILURE;
		}

		// Create server
		VMPServerMain *server = [VMPServerMain serverWithConfiguration:configuration];
		if (!server) {
			NSLog(@"Failed to create server from configuration: %@", error);
			return EXIT_FAILURE;
		}

		// Start server
		if (![server runWithError:&error]) {
			NSLog(@"Failed to start server: %@", error);
			return EXIT_FAILURE;
		}

		// Run main loop
		[runLoop run];
	}
}