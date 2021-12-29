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

/**
 Returns the shared sync object.

 @return The shared sync object.
 */
+ (nullable instancetype)sharedSync;

/**
 Initializes a UserDefaults / CloudKit sync object initialized in a non-started state.

 @return The instance this message was sent to.
 */
- (nonnull instancetype)init;

/**
 Sets the receiver’s delegate to a given object.

 @param newDelegate The delegate for the receiver.
 */
- (void)setDelegate:(nonnull id<MJCloudKitUserDefaultsSyncDelegate>)newDelegate;

/**
 Informs the sync if remote notifications are supported and reloads the CloudKit monitor as appropriate based on this.  Remote notifications support is required for use of CKQuerySubscription.  Without this it will revert to polling.

 Specify true if configuring UNUserNotificationCenter for notifications and specify false if not configuring UNUserNotificationCenter (such as if on iOS < 10.0) or if there was a failure to register for remote notifications through UNUserNotificationCenter (didFailToRegisterForRemoteNotificationsWithError).

 @param enabled Condition of remote notifications being supported.
 */
- (void)setRemoteNotificationsEnabled:(bool)enabled;

/**
 Initiates sync of all user defaults pairs with keys beginning with the specified prefix.

 @param prefixToSync The prefix that the key of any pair to sync will begin with.
 @param containerIdentifier The CloudKit container identifier to use.  See CloudKit Quick Start (https://developer.apple.com/library/content/documentation/DataManagement/Conceptual/CloudKitQuickStart/EnablingiCloudandConfiguringCloudKit/EnablingiCloudandConfiguringCloudKit.html) for more detail on these.
 */
- (void)startWithPrefix:(nonnull NSString *)prefixToSync
withContainerIdentifier:(nonnull NSString *)containerIdentifier;

/**
 Initiates sync of all user defaults pairs with keys contained in the specified match list.

 This may be called to add additional keys while sync is already in effect.

 @param keyMatchList The list of keys of pairs that should sync.
 @param containerIdentifier The CloudKit container identifier to use.  See CloudKit Quick Start (https://developer.apple.com/library/content/documentation/DataManagement/Conceptual/CloudKitQuickStart/EnablingiCloudandConfiguringCloudKit/EnablingiCloudandConfiguringCloudKit.html) for more detail on these.
 */
- (void)startWithKeyMatchList:(nonnull NSArray *)keyMatchList
	  withContainerIdentifier:(nonnull NSString *)containerIdentifier;

/**
 Causes sync to check for updates from iCloud.  Should be called in response to the application receiving a notification from CloudKit that the subscription has seen activity (NSApplicationDelegate - (void)application:(NSApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo).
 */
- (void)checkCloudKitUpdates;

/**
 Stops sync of all user defaults pairs with keys contained in the specified match list.

 @param keyMatchList The list of keys of pairs that should be removed from sync.
 */
- (void)stopForKeyMatchList:(nonnull NSArray *)keyMatchList;


/**
 Adds an entry to the instance's notification table for a specific event type with an observer and a notification selector.

 Use of aSelector per event type:

 MJSyncNotificationChanges - Selector receives dictionary of key/value pairs changed (loaded from iCloud).  Dictionary reference returned will be ignored.

 MJSyncNotificationConflicts - Selector receives dictionary of key/value pairs that had conflicts.  Dictionary reference returned will contain key/value pairs to override remote (iCloud) pairs.  Local changes will be lost for any conflicting pairs that are not present in the returned dictionary reference.

 MJSyncNotificationSaveSuccess - Selector receives dictionary of key/value pairs saved (saved from iCloud).  Dictionary reference returned will be ignored.

 @param type The type of event to be notified for.
 @param aSelector Selector that specifies the message the receiver sends observer to notify it of the sync event. The method specified by aSelector must have one and only one argument (an reference to NSDictionary) and must return a reference to NSDictionary (may be nil).
 @param aTarget Object registering as an observer.
 */
- (void)addNotificationFor:(MJSyncNotificationType)type
			  withSelector:(nonnull SEL)aSelector
				withTarget:(nonnull id)aTarget;

/**
 Provides an string with diagnostic information that can be used to identify sync status and state.

 @return The diagnostic information string.
 */
- (nullable NSString *)diagnosticData;

@end
