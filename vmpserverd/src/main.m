/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <getopt.h>
#include <gst/gst.h>
#include <stdlib.h>

// Generated project configuration
#include "../build/config.h"

#import "VMPJournal.h"
#import "VMPServerMain.h"

#define DEFAULT_PATHS                                                                              \
	@[ @"~/.config/vmpserverd/config.plist", @"/usr/share/vmpserverd/config.plist" ]

#define USAGE_MSG                                                                                  \
	"Usage: vmpserverd [OPTION]...\n"                                                              \
	"\n"                                                                                           \
	"  -h, --help\t\t\tPrint this help message\n"                                                  \
	"  -v, --version\t\t\tPrint version information\n"                                             \
	"  -c, --config=PATH\t\tPath to configuration file\n"

static void version(void) {
	fprintf(stderr, "%s %d.%d.%d\n", PROJECT_NAME, MAJOR_VERSION, MINOR_VERSION, PATCH_VERSION);
}

static void usage(void) { fputs(USAGE_MSG, stderr); }

int main(int argc, char *argv[]) {
	// Initialize the GStreamer library
	gst_init(&argc, &argv);

	@autoreleasepool {
		NSRunLoop *runLoop;
		NSString *selectedPath;
		NSError *error;
		NSArray<NSString *> *paths = DEFAULT_PATHS;
		NSDictionary *plist;
		VMPConfigModel *configuration;

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
				break;
			}
		}

		if (!selectedPath) {
			VMPCritical(@"No configuration file found");
			return EXIT_FAILURE;
		}

		plist = [NSDictionary dictionaryWithContentsOfFile:selectedPath];
		if (!plist) {
			VMPCritical(@"Failed to read plist at path '%@'", selectedPath);
			return EXIT_FAILURE;
		}

		// Create configuration from file
		configuration = [[VMPConfigModel alloc] initWithPropertyList:plist error:&error];
		if (!configuration) {
			VMPCritical(@"Failed to create configuration from file %@: %@", selectedPath, error);
			return EXIT_FAILURE;
		}

		// Create server
		VMPServerMain *server = [VMPServerMain serverWithConfiguration:configuration error:&error];
		if (!server) {
			VMPCritical(@"Failed to create server from configuration: %@", error);
			return EXIT_FAILURE;
		}

		// Start server
		if (![server runWithError:&error]) {
			VMPCritical(@"Failed to start server: %@", error);
			return EXIT_FAILURE;
		}

		// Run main loop
		[runLoop run];
	}
}