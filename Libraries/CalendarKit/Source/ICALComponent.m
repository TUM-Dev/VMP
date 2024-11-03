/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <assert.h>
#import <libical/ical.h>

#import "CalendarKit/ICALComponent.h"
#import "CalendarKit/ICALError.h"

#import "ICALComponent+Private.h"
#import "ICALProperty+Private.h"

// Make sure that ICALComponentKind is in sync with icalcomponent_kind
// so that we can just cast it.
static_assert(ICAL_XPATCH_COMPONENT == ICALComponentKindXPATCH,
			  "icalcomponent_kind enumeration is not in sync!");

static NSDate *NSDateFromICalTime(struct icaltimetype time) {
	icaltimezone *utcZone = icaltimezone_get_utc_timezone();
	icaltimezone *localZone = (icaltimezone *) time.zone;
	if (!time.zone) {
		return nil;
	}

	icaltimezone_convert_time(&time, localZone, utcZone);
	time_t secondsSinceUNIXEpoch = icaltime_as_timet(time);
	return [NSDate dateWithTimeIntervalSince1970:secondsSinceUNIXEpoch];
}

@implementation ICALComponent (Private)

- (instancetype)initWithHandle:(icalcomponent *)handle {
	self = [super init];
	if (self) {
		_handle = handle;
	}

	return self;
}
- (instancetype)initWithHandle:(icalcomponent *)handle root:(ICALComponent *)root {
	self = [super init];
	if (self) {
		_handle = handle;
		_root = root;
	}

	return self;
}

- (icalcomponent *)handle {
	return _handle;
}

@end

@implementation ICALComponent

+ (instancetype)componentWithData:(NSData *)data error:(NSError **)error {
	return [[ICALComponent alloc] initWithData:data error:error];
}

- (instancetype)initWithData:(NSData *)data error:(NSError **)error {
	NSAssert(data, @"Data is valid");

	NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

	icalcomponent *parsed = icalparser_parse_string([string UTF8String]);
	// Some error occured during parsing
	if (!parsed) {
		if (error) {
			ICALError errorCode = (ICALError) icalerrno;
			NSString *message = [NSString stringWithUTF8String:icalerror_strerror(icalerrno)];
			*error = [NSError errorWithDomain:ICALErrorDomain
										 code:errorCode
									 userInfo:@{NSLocalizedDescriptionKey : message}];
		}
		icalerror_clear_errno();
		return nil;
	}

	return [self initWithHandle:parsed];
}

- (ICALComponentKind)kind {
	return (ICALComponentKind) icalcomponent_isa(_handle);
}

- (NSString *_Nullable)uid {
	const char *uid = icalcomponent_get_uid(_handle);
	if (!uid) {
		return nil;
	}

	return [NSString stringWithUTF8String:uid];
}

- (NSString *_Nullable)summary {
	const char *summary = icalcomponent_get_summary(_handle);
	if (!summary) {
		return nil;
	}

	return [NSString stringWithUTF8String:summary];
}

- (NSString *_Nullable)location {
	const char *location = icalcomponent_get_location(_handle);
	if (!location) {
		return nil;
	}

	return [NSString stringWithUTF8String:location];
}

- (NSDate *_Nullable)startDate {
	struct icaltimetype time = icalcomponent_get_dtstart(_handle);
	return NSDateFromICalTime(time);
}

- (NSDate *_Nullable)endDate {
	struct icaltimetype time = icalcomponent_get_dtend(_handle);
	return NSDateFromICalTime(time);
}

- (NSInteger)numberOfChildren {
	return icalcomponent_count_components(_handle, ICAL_ANY_COMPONENT);
}

- (NSInteger)numberOfProperties {
	return icalcomponent_count_properties(_handle, ICAL_ANY_PROPERTY);
}

- (void)enumerateComponentsUsingBlock:(void (^)(ICALComponent *component, BOOL *stop))block {
	icalcompiter iter = icalcomponent_begin_component(_handle, ICAL_ANY_COMPONENT);

	BOOL stop = NO;

	for (; icalcompiter_deref(&iter) != 0 && stop == NO; icalcompiter_next(&iter)) {
		ICALComponent *cur = [[ICALComponent alloc] initWithHandle:icalcompiter_deref(&iter)
															  root:self];
		block(cur, &stop);
	}
}

- (void)enumeratePropertiesUsingBlock:(void (^)(ICALProperty *property, BOOL *stop))block {
	icalproperty *cur = icalcomponent_get_first_property(_handle, ICAL_ANY_PROPERTY);

	BOOL stop = NO;
	while (cur != 0 && stop == NO) {
		ICALProperty *obj = [[ICALProperty alloc] initWithHandle:cur owner:self];
		block(obj, &stop);
		cur = icalcomponent_get_next_property(_handle, ICAL_ANY_PROPERTY);
	}
}

- (id)copyWithZone:(NSZone *)zone {
	icalcomponent *cloned = icalcomponent_new_clone(_handle);
	return [[ICALComponent alloc] initWithHandle:cloned];
}

- (BOOL)isEqual:(id)other {
	if (self == other) {
		return YES;
	}

	if ([other isKindOfClass:[ICALComponent class]]) {
		ICALComponent *otherComponent = (ICALComponent *) other;

		// Note that 'UID' MUST be specified in the "VEVENT", "VTODO",
		// "VJOURNAL", or "VFREEBUSY" calendar components, but may
		// be absent otherwise.
		const char *selfUID = icalcomponent_get_uid(_handle);
		const char *otherUID = icalcomponent_get_uid([otherComponent handle]);

		if (selfUID != NULL && otherUID != NULL && (strcmp(selfUID, otherUID) == 0)) {
			return YES;
		}
	}

	// FIXME(hugo): Implement for other components as well.

	return NO;
}

- (void)dealloc {
	if (!_root) {
		icalcomponent_free(_handle);
	}
}

@end
