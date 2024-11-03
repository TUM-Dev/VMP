#include "CalendarKit/ICALComponent.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSObjCRuntime.h"
#import <dispatch/dispatch.h>

#import "VMPCalendarSync.h"
#import "VMPJournal.h"

@implementation VMPCalendarSync {
	_Atomic(BOOL) _isActive;
	NSURLRequest *_request;
	NSLock *_lock;
	dispatch_queue_t _queue;
	dispatch_source_t _timer;
	short _retryAttempts;
	NSMutableArray<ICALComponent *> *_events;
}

- (instancetype)initWithURL:(NSURL *)url
				   interval:(NSTimeInterval)interval
		  notifyBeforeStart:(NSTimeInterval)threshold {
	self = [super init];

	if (self) {
		_url = url;
		_interval = interval;
		_notifyBeforeStartThreshold = threshold;
		_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
		_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _queue);
		_lock = [NSLock new];
		_request = [NSURLRequest requestWithURL:url];
		_events = [NSMutableArray arrayWithCapacity:32];
		_retryAttempts = 5;

		uint64_t dispatchInterval = (uint64_t) (interval * NSEC_PER_SEC);
		uint64_t leeway = (uint64_t) (dispatchInterval * 0.05); // 5% leeway
		dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, dispatchInterval, leeway);
		dispatch_source_set_event_handler(_timer, ^{
			if (_isActive) {
				[self _sync];
			}
		});
		dispatch_resume(_timer);
		_isActive = YES;
	}

	return self;
}

- (void)_sync {
	short retriesLeft = _retryAttempts;
	NSError *error = nil;
	NSURLResponse *response = nil;
	NSData *data = nil;

	VMPInfo(@"Synchronising calendar with remote (%@)", _url);

retry:
	if (retriesLeft == 0) {
		VMPError(@"Calendar Sync: Number of retries exhausted");
		return;
	}
	retriesLeft--;
	error = nil;
	data = [NSURLConnection sendSynchronousRequest:_request
								 returningResponse:&response
											 error:&error];
	if (!data) {
		VMPError(@"Calendar Sync: Failed to fetch calendar feed with error: %@", error,
				 retriesLeft);
		VMPError(@"Calendar Sync: %d retries left", retriesLeft);
		goto retry;
	}

	// Check if the mimetype is correct
	if (![@"text/calendar" isEqualToString:[response MIMEType]]) {
		VMPError(@"Calendar Sync: Got response '%@' but mimetype is not text/calendar", response);
		VMPError(@"Calendar Sync: %d retries left", retriesLeft);
		goto retry;
	}

	// We can now try to parse the calendar feed using CalendarKit
	VMPDebug(@"Calendar Sync: Parsing returned data from server");
	error = nil;
	ICALComponent *cal = [ICALComponent componentWithData:data error:&error];
	if (!cal) {
		VMPError(@"Calendar Sync: Failed to parse calendar feed: %@", error);
		return;
	}

	NSMutableArray *updatedEvents = [NSMutableArray arrayWithCapacity:[_events count]];
	NSDate *current = [NSDate date];

	[cal enumerateComponentsUsingBlock:^(ICALComponent *comp, BOOL *stop) {
		if ([comp kind] == ICALComponentKindVEVENT) {
			NSDate *endDate = [comp endDate];
			if (!endDate) {
				VMPError(@"Calendar Sync: Failed to retrieve end date from %@", comp);
				return; // skip
			}

			if ([current compare:endDate] != NSOrderedAscending) {
				return; // skip if date is same or in the past
			}

			// Check if we are interested in this event
			if (_filterBlock && !_filterBlock(comp)) {
				return; // skip over this element
			}

			// TODO(hugo): We might want to keep the existing array and only update
			// it (by using a hashset or a min heap), but this might create some edge cases, that I
			// just don't want to bother with right now.
			[updatedEvents addObject:[comp copy]];
		}
	}];

	VMPInfo(@"Calendar Sync: Found %ld events of interest", [updatedEvents count]);

	// Replace existing set with updated events
	[_lock lock];
	_events = updatedEvents;
	[_lock unlock];

	// Check if we have events that are passed the notification threshold
	// Note that we have an error of up to 'interval' so we just notify earlier :P
	NSDate *threshold =
		[[NSDate alloc] initWithTimeIntervalSinceNow:_notifyBeforeStartThreshold + _interval];
	NSMutableArray<ICALComponent *> *eventsToRemove = [NSMutableArray new];
	for (ICALComponent *comp in _events) {
		NSDate *start = [comp startDate];
		if (!start) {
			continue;
		}

		// if threshold is not later in time than start
		if ([threshold compare:start] != NSOrderedDescending) {
			VMPInfo(@"Calendar Sync: Event %@ is passed threshold. Notifying...", comp);
			if (_notificationBlock) {
				_notificationBlock(comp);
			}
			[eventsToRemove addObject:comp];
		}
	}

	VMPDebug(@"Calendar Sync: Removing %ld events after notification", [eventsToRemove count]);
	[_lock lock];
	[_events removeObjectsInArray:eventsToRemove];
	[_lock unlock];
	VMPDebug(@"Calendar Sync: events removed");
}

- (void)start {
	if (NO == _isActive) {
		[_lock lock];
		if (NO == _isActive) {
			dispatch_resume(_timer);
			_isActive = YES;
		}
		[_lock unlock];
	}
}

- (void)stop {
	if (YES == _isActive) {
		[_lock lock];
		if (YES == _isActive) {
			dispatch_suspend(_timer);
			_isActive = NO;
		}
		[_lock unlock];
	}
}

- (void)dealloc {
	dispatch_source_cancel(_timer);
	dispatch_release(_timer);
}

@end
