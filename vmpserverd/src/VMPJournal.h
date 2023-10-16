/* vmp-server - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

void VMPDebug(NSString *format, ...);
void VMPInfo(NSString *format, ...);
void VMPWarn(NSString *format, ...);
void VMPError(NSString *format, ...);
void VMPCritical(NSString *format, ...);

#define VMP_ASSERT(condition, string, ...)                                                         \
	if (!(condition)) {                                                                            \
		VMPCritical(string, ##__VA_ARGS__);                                                        \
		abort();                                                                                   \
	}

/**
	@brief Journal priority types

	The priority types are compatible
	with the "Syslog message severities"
	defined in RFC 5424.
*/
typedef enum VMPJournalType {
	/// System is unusable
	kVMPJournalTypeEmergency = 0,

	/// Action must be taken immediately
	kVMPJournalTypeAlert = 1,

	/// Critical conditions
	kVMPJournalTypeCritical = 2,

	/// Error conditions
	kVMPJournalTypeError = 3,

	/// Warning conditions
	kVMPJournalTypeWarning = 4,

	/// Normal but significant condition
	kVMPJournalTypeNotice = 5,

	/// Informational messages
	kVMPJournalTypeInfo = 6,

	/// Debug-level messages
	kVMPJournalTypeDebug = 7
} VMPJournalType;

/**
	@brief Systemd Journal class

	This class is used to log messages to the systemd journal.
	It is just a wrapper around the sd_journal_* functions, but
	provides a more convenient interface for logging Objective-C
	strings and NSError objects.

	The default journal is used by the VMP_* macros, and can be
	accessed via the +defaultJournal method.

	Additionally, the fields SUBSYSTEM and BUNDLE_IDENTIFIER are
	automatically added to each log entry.

	For more information on the systemd journal, see
	the systemd-journal man page.
*/
@interface VMPJournal : NSObject

/**
	@brief The subsystem name

	A subsystem name can be used to identify and filter logs.

	If set, the subsystem name is present as SUBSYSTEM
	in the systemd journal entries.
*/
@property (nonatomic, readonly) NSString *subsystem;

+ (VMPJournal *)defaultJournal;
+ (VMPJournal *)journalWithSubsystem:(NSString *)subsystem;

- (instancetype)initWithSubsystem:(NSString *)subsystem;

- (void)message:(NSString *)message withPriority:(VMPJournalType)priority;
- (void)error:(NSError *)error withPriority:(VMPJournalType)priority;

@end