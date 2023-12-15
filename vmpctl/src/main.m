/* vmpctl - A configuration utility for vmpserverd
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPRemoteConnection.h"
#import <Foundation/Foundation.h>

#import <getopt.h>

#define USAGE_MSG                                                                                  \
	"Usage: vmpctl [OPTION]...\n"                                                                  \
	"\n"                                                                                           \
	"  -h, --help\t\t\tPrint this help message\n"                                                  \
	"  -a, --address=ADDRESS\t\tAddress of the server\n"

int main(int argc, const char *argv[]) {
	@autoreleasepool {
		NSString *address;
		NSURL *url;

		struct option longopts[] = {{"help", no_argument, NULL, 'h'},
									{"address", required_argument, NULL, 'a'},
									{NULL, 0, NULL, 0}};

		int ch;
		while ((ch = getopt_long(argc, (char *const *) argv, "ha:", longopts, NULL)) != -1) {
			switch (ch) {
			case 'h':
				fputs(USAGE_MSG, stderr);
				return 0;
			case 'a':
				address = [NSString stringWithUTF8String:optarg];
				break;
			default:
				fputs(USAGE_MSG, stderr);
				return 1;
			}
		}

		if (!address) {
			fputs("vmpctl: error: no address specified\n", stderr);
			return 1;
		}

		url = [NSURL URLWithString:address];
		if (!url) {
			fputs("vmpctl: error: invalid address specified\n", stderr);
			return 1;
		}

		// TODO: This is just a placeholder for basic testing
		VMPRemoteConnection *connection;
		NSError *error;
		NSDictionary *response;

		connection = [VMPRemoteConnection connectionWithAddress:url username:nil password:nil];

		response = [connection configuration:&error];
		if (error) {
			fprintf(stderr, "vmpctl: error: %s\n", [[error localizedDescription] UTF8String]);
			return 1;
		}

		NSLog(@"%@", response);
	}
	return 0;
}
