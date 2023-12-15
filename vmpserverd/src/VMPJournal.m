/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#include <Foundation/NSDictionary.h>
#import <systemd/sd-journal.h>

#import "VMPJournal.h"

// Generated project configuration
#include "../build/config.h"

#define ANSI_COLOR_FAINT "\x1b[2m" // Faint
#define ANSI_COLOR_CYAN "\x1b[36m"
#define ANSI_COLOR_GREEN "\x1b[32m"
#define ANSI_COLOR_YELLOW "\x1b[33m"
#define ANSI_COLOR_RED "\x1b[1;31m"		// Bold Red
#define ANSI_COLOR_MAGENTA "\x1b[1;35m" // Bold Magenta
#define ANSI_COLOR_RESET "\x1b[0m"

#define LOG_PREAMBLE                                                                               \
	va_list args;                                                                                  \
	va_start(args, format);                                                                        \
	NSString *message = [[NSString alloc] initWithFormat:format arguments:args];                   \
	va_end(args);

#define SEND_LOG(prefix, color, type, msg, f)                                                      \
	do {                                                                                           \
		NSString *date;                                                                            \
		date = [[NSDate date] description];                                                        \
		fprintf(stderr, "%s [ %s%s\x1b[0m ] %s\n", [date UTF8String], color, prefix,               \
				[msg UTF8String]);                                                                 \
		[[VMPJournal defaultJournal] message:msg withPriority:type fields:f];                      \
	} while (0);

void VMPDebug(NSString *format, ...) {
#ifdef DEBUG
	LOG_PREAMBLE

	NSString *date;
	date = [[NSDate date] description];

	fprintf(stderr, "%s [ %s%s\x1b[0m ]  \x1b[2m%s\x1b[0m\n", [date UTF8String], ANSI_COLOR_CYAN,
			"DEBUG", [message UTF8String]);
	[[VMPJournal defaultJournal] message:message withPriority:kVMPJournalTypeDebug fields:nil];
#endif
}

void VMPInfo(NSString *format, ...) {
	LOG_PREAMBLE
	SEND_LOG("INFO", ANSI_COLOR_GREEN, kVMPJournalTypeInfo, message, nil);
}

void VMPWarn(NSString *format, ...) {
	LOG_PREAMBLE
	SEND_LOG("WARN", ANSI_COLOR_YELLOW, kVMPJournalTypeWarning, message, nil);
}

void VMPError(NSString *format, ...) {
	LOG_PREAMBLE
	SEND_LOG("ERROR", ANSI_COLOR_RED, kVMPJournalTypeError, message, nil);
}

void VMPCritical(NSString *format, ...) {
	LOG_PREAMBLE
	SEND_LOG("CRITICAL", ANSI_COLOR_MAGENTA, kVMPJournalTypeCritical, message, nil);
}

void VMPGStreamerLoggingBridge(GstDebugCategory *category, GstDebugLevel level, const gchar *file,
							   const gchar *function, gint line, GObject *object,
							   GstDebugMessage *message, gpointer user_data) {
	if (level < GST_LEVEL_WARNING) {
		return;
	}

	NSString *wrappedMessage;
	NSDictionary *f = @{
		@"GST_FILE" : [NSString stringWithUTF8String:file],
		@"GST_FUNCTION" : [NSString stringWithUTF8String:function],
		@"GST_LINE" : [NSString stringWithFormat:@"%d", line]
	};

	switch (level) {
	case GST_LEVEL_ERROR:
		wrappedMessage = [NSString stringWithUTF8String:gst_debug_message_get(message)];
		SEND_LOG("ERROR (GST)", ANSI_COLOR_RED, kVMPJournalTypeError, wrappedMessage, f);
		break;
	case GST_LEVEL_WARNING:
		wrappedMessage = [NSString stringWithUTF8String:gst_debug_message_get(message)];
		SEND_LOG("WARN (GST)", ANSI_COLOR_YELLOW, kVMPJournalTypeError, wrappedMessage, f);
		break;
	default:
		break;
	}
}

@interface VMPJournal ()
@property (nonatomic, readwrite) NSString *subsystem;
@end

// Helper category to convert an array of NSStrings to an array of iovecs
// required by sd_journal_sendv
@interface NSMutableArray (VMPJournal)
- (const struct iovec *)UTF8StringIOVec;
@end

@implementation NSMutableArray (VMPJournal)
- (const struct iovec *)UTF8StringIOVec {
	struct iovec *iovec = malloc(sizeof(struct iovec) * [self count]);
	if (iovec == NULL) {
		return NULL;
	}

	for (int i = 0; i < [self count]; i++) {
		NSString *string = [self objectAtIndex:i];
		iovec[i].iov_base = (void *) [string UTF8String];
		iovec[i].iov_len = [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	}
	return iovec;
}
@end

@implementation VMPJournal {
	NSMutableArray<NSString *> *_defaultFields;
}

// defaultJournal is a singleton
static VMPJournal *defaultJournal = nil;

+ (VMPJournal *)defaultJournal {
	if (defaultJournal == nil) {
		defaultJournal = [[VMPJournal alloc] init];
	}
	return defaultJournal;
}

+ (VMPJournal *)journalWithSubsystem:(NSString *)subsystem {
	return [[VMPJournal alloc] initWithSubsystem:subsystem];
}

- (instancetype)initWithSubsystem:(NSString *)subsystem {
	self = [super init];
	if (self) {
		_subsystem = subsystem;
		_defaultFields = [self _createJournalFields];
	}
	return self;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		_subsystem = @"default";
	}
	return self;
}

- (NSMutableArray<NSString *> *)_createJournalFields {
	NSMutableArray<NSString *> *fields = [[NSMutableArray alloc] init];

	[fields addObject:[NSString stringWithFormat:@"GS_SUBSYSTEM=%@", self.subsystem]];
	// Add bundle identifier from config.h
	[fields addObject:[NSString stringWithFormat:@"GS_BUNDLE_IDENTIFIER=%s", BUNDLE_IDENTIFIER]];
	return fields;
}

- (void)message:(NSString *)message
	withPriority:(VMPJournalType)priority
		  fields:(NSDictionary<NSString *, NSString *> *)fields {
	NSMutableArray<NSString *> *f = [NSMutableArray arrayWithArray:_defaultFields];

	if (fields != nil) {
		for (NSString *key in fields) {
			[f addObject:[NSString stringWithFormat:@"%@=%@", key, [fields objectForKey:key]]];
		}
	}

	[f addObject:[NSString stringWithFormat:@"PRIORITY=%d", priority]];
	[f addObject:[NSString stringWithFormat:@"MESSAGE=%@", message]];

	const struct iovec *vec = [f UTF8StringIOVec];
	if (vec == NULL) {
		return;
	}

	sd_journal_sendv(vec, [fields count]);
	free((void *) vec);
}

- (void)error:(NSError *)error withPriority:(VMPJournalType)priority {
	[self message:[error description] withPriority:priority fields:nil];
}

@end