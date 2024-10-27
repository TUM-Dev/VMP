/* vmpserverd - A virtual multimedia processor
 * Copyright (C) 2023 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import "VMPConfigModel.h"
#import "VMPJournal.h"
#import "VMPModelCommon.h"

@implementation VMPConfigModel

- (id)initWithPropertyList:(id)propertyList error:(NSError **)error {
	VMP_ASSERT([propertyList isKindOfClass:[NSDictionary class]],
			   @"propertyList is not a dictionary");

	self = [super init];
	if (self) {
		NSMutableArray *mountpoints, *channels;
		NSArray *plistMountpoints, *plistChannels;

		SET_PROPERTY(_name, @"name");
		SET_PROPERTY(_profileDirectory, @"profileDirectory");
		SET_PROPERTY(_scratchDirectory, @"scratchDirectory");
		SET_PROPERTY(_rtspAddress, @"rtspAddress");
		SET_PROPERTY(_rtspPort, @"rtspPort");
		SET_PROPERTY(_httpPort, @"httpPort");
		SET_PROPERTY(_httpAuth, @"httpAuth");
		SET_PROPERTY(_httpUsername, @"httpUsername");
		SET_PROPERTY(_httpPassword, @"httpPassword");
		SET_PROPERTY(_gstDebug, @"gstDebug");

		SET_PROPERTY(plistMountpoints, @"mountpoints");
		SET_PROPERTY(plistChannels, @"channels");

		mountpoints = [NSMutableArray arrayWithCapacity:[plistMountpoints count]];
		channels = [NSMutableArray arrayWithCapacity:[plistChannels count]];

		for (NSDictionary *mountpoint in plistMountpoints) {
			VMPConfigMountpointModel *model =
				[[VMPConfigMountpointModel alloc] initWithPropertyList:mountpoint error:error];
			if (!model) {
				return nil;
			}
			[mountpoints addObject:model];
		}
		for (NSDictionary *channel in plistChannels) {
			VMPConfigChannelModel *model =
				[[VMPConfigChannelModel alloc] initWithPropertyList:channel error:error];
			if (!model) {
				return nil;
			}
			[channels addObject:model];
		}

		_mountpoints = [mountpoints copy];
		_channels = [channels copy];
	}

	return self;
}

- (NSArray *)propertyListMountpoints {
	NSMutableArray *exportedMountpoints;

	exportedMountpoints = [NSMutableArray arrayWithCapacity:[_mountpoints count]];

	for (VMPConfigMountpointModel *mountpoint in _mountpoints) {
		[exportedMountpoints addObject:[mountpoint propertyList]];
	}

	return [exportedMountpoints copy];
}

- (NSArray *)propertyListChannels {
	NSMutableArray *exportedChannels;

	exportedChannels = [NSMutableArray arrayWithCapacity:[_channels count]];

	for (VMPConfigChannelModel *channel in _channels) {
		[exportedChannels addObject:[channel propertyList]];
	}

	return [exportedChannels copy];
}

- (id)propertyList {
	VMP_ASSERT(_name, @"name is nil");
	VMP_ASSERT(_rtspAddress, @"rtspAddress is nil");
	VMP_ASSERT(_rtspPort, @"rtspPort is nil");
	VMP_ASSERT(_httpPort, @"httpPort is nil");
	VMP_ASSERT(_httpAuth, @"httpAuth is nil");
	VMP_ASSERT(_httpUsername, @"httpUsername is nil");
	VMP_ASSERT(_httpPassword, @"httpPassword is nil");
	VMP_ASSERT(_gstDebug, @"gstDebug is nil");
	VMP_ASSERT(_mountpoints, @"mountpoints is nil");
	VMP_ASSERT(_channels, @"channels is nil");

	return @{
		@"name" : _name,
		@"rtspAddress" : _rtspAddress,
		@"rtspPort" : _rtspPort,
		@"httpPort" : _httpPort,
		@"httpUsername" : _httpUsername,
		@"httpPassword" : _httpPassword,
		@"gstDebug" : _gstDebug,
		@"mountpoints" : [self propertyListMountpoints],
		@"channels" : [self propertyListChannels],
	};
}

@end