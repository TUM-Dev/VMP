/* CalendarKit - An ObjC wrapper around libical
 * Copyright (C) 2024 Hugo Melder
 *
 * SPDX-License-Identifier: MIT
 */

#import <Foundation/Foundation.h>

// Class reference to avoid cyclic dependency
@class ICALProperty;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, ICALComponentKind) {
	ICALComponentKindPlaceholder,
	/// Used to select all components
	ICALComponentKindAny,
	ICALComponentKindXROOT,
	/// MIME attached data, returned by parser
	ICALComponentKindXATTACH,
	ICALComponentKindVEVENT,
	ICALComponentKindVTODO,
	ICALComponentKindVJOURNAL,
	ICALComponentKindVCALENDAR,
	ICALComponentKindVAGENDA,
	ICALComponentKindVFREEBUSY,
	ICALComponentKindVALARM,
	ICALComponentKindXAUDIOALARM,
	ICALComponentKindXDISPLAYALARM,
	ICALComponentKindXEMAILALARM,
	ICALComponentKindXPROCEDUREALARM,
	ICALComponentKindVTIMEZONE,
	ICALComponentKindXSTANDARD,
	ICALComponentKindXDAYLIGHT,
	ICALComponentKindX,
	ICALComponentKindVSCHEDULE,
	ICALComponentKindVQUERY,
	ICALComponentKindVREPLY,
	ICALComponentKindVCAR,
	ICALComponentKindVCOMMAND,
	ICALComponentKindXLICINVALID,
	ICALComponentKindXLICMIMEPART,
	ICALComponentKindVAVAILABILITY,
	ICALComponentKindXAVAILABLE,
	ICALComponentKindVPOLL,
	ICALComponentKindVVOTER,
	ICALComponentKindXVOTE,
	ICALComponentKindVPATCH,
	ICALComponentKindXPATCH
};

@interface ICALComponent : NSObject <NSCopying> {
	void *_handle;
	ICALComponent *_Nullable _root;
}

+ (instancetype)componentWithData:(NSData *)data error:(NSError **)error;

- (instancetype)initWithData:(NSData *)data error:(NSError **)error;

- (ICALComponentKind)kind;

- (NSString *_Nullable)uid;

- (NSString *_Nullable)summary;

- (NSString *_Nullable)location;

/**
 * @brief Converts 'dtstart' into a timezone-independent date
 *
 * Note that we convert the date into UTC from the local time zone.
 * Be aware of any side-effects (e.g. you should not use this, if the event is recurring).
 * Returns nil if timezone conversion fails.
 */
- (NSDate *_Nullable)startDate;

/**
 * @brief Converts 'dtend' into a timezone-independent date
 *
 * Note that we convert the date into UTC from the local time zone.
 * Be aware of any side-effects (e.g. you should not use this, if the event is recurring).
 * Returns nil if timezone conversion fails.
 */
- (NSDate *_Nullable)endDate;

- (id)copyWithZone:(NSZone *)zone;

- (NSInteger)numberOfChildren;
- (NSInteger)numberOfProperties;

- (void)enumerateComponentsUsingBlock:(void (^)(ICALComponent *component, BOOL *stop))block;
- (void)enumeratePropertiesUsingBlock:(void (^)(ICALProperty *property, BOOL *stop))block;

@end

NS_ASSUME_NONNULL_END
