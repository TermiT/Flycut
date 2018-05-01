//
//  MJCloudKitUserDefaultsSync.m
//
//  Created by Mark Jerde (http://github.com/MarkJerde)
//  Copyright (C) 2017 by Mark Jerde
//
//  Based on MKiCloudSync by Mugunth Kumar (@mugunthkumar)
//  Portions Copyright (C) 2011-2020 by Steinlogic

//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

//  As a side note, you might also consider
//	1) tweeting about this mentioning @mark_a_jerde
//	2) A paypal donation to mark.a.jerde@gmail.com
//	3) tweeting about this mentioning @mugunthkumar for his original contributions
//	4) A paypal donation to mugunth.kumar@gmail.com

#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#   define DLog(...)
#endif

// ALog always displays output regardless of the DEBUG setting
#define ALog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

#import <Foundation/Foundation.h>

//! Project version number for MJCloudKitUserDefaultsSync.
FOUNDATION_EXPORT double MJCloudKitUserDefaultsSyncVersionNumber;

//! Project version string for MJCloudKitUserDefaultsSync.
FOUNDATION_EXPORT const unsigned char MJCloudKitUserDefaultsSyncVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <MJCloudKitUserDefaultsSync/PublicHeader.h>


@protocol MJCloudKitUserDefaultsSyncDelegate <NSObject>
@optional
// notifyCKAccountStatusNoAccount is called when:
// * Not signed in to iCloud
// * iCloud Drive is not enabled
// * other?
- (void)notifyCKAccountStatusNoAccount;
@end

typedef NS_ENUM(NSUInteger, MJSyncNotificationType) {
	MJSyncNotificationChanges = 0,
	MJSyncNotificationConflicts,
	MJSyncNotificationSaveSuccess
};
static inline MJSyncNotificationType MJSyncNotificationTypeFirst() { return MJSyncNotificationChanges; }
static inline MJSyncNotificationType MJSyncNotificationTypeLast() { return MJSyncNotificationSaveSuccess; }

@interface MJCloudKitUserDefaultsSync : NSObject

+ (nullable instancetype)sharedSync;

- (nonnull instancetype)init;

- (void)setDelegate:(nonnull id<MJCloudKitUserDefaultsSyncDelegate>)newDelegate;
- (void)setRemoteNotificationsEnabled:(bool)enabled;
- (void)startWithPrefix:(nonnull NSString *)prefixToSync
withContainerIdentifier:(nonnull NSString *)containerIdentifier;
- (void)startWithKeyMatchList:(nonnull NSArray *)keyMatchList
	  withContainerIdentifier:(nonnull NSString *)containerIdentifier;
- (void)stopForKeyMatchList:(nonnull NSArray *)keyMatchList;
- (void)addNotificationFor:(MJSyncNotificationType)type;

@end
