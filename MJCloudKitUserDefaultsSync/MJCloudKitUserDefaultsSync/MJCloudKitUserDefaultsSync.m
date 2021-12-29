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


#import "MJCloudKitUserDefaultsSync.h"
#import <CloudKit/CloudKit.h>

// String constants we use.
static NSString *const recordZoneName = @"MJCloudKitUserDefaultsSync";
static NSString *const subscriptionID = @"UserDefaultSubscription";
static NSString *const recordType = @"UserDefault";
static NSString *const recordName = @"UserDefaults";

@interface MJCloudKitUserDefaultsSync_NotificationHander : NSObject
@end
@implementation MJCloudKitUserDefaultsSync_NotificationHander {
	SEL selector;
	id target;
}

- (instancetype)initWithSelector:(nonnull SEL)aSelector
					  withTarget:(nonnull id)aTarget
{
	self = [super init];
	if (self) {
		// Don't retain these.  If somebody wants to be notified by us, they better remove those notifications before they dealloc.
		selector = aSelector;
		target = aTarget;
	}
	return self;
}

- (bool)isTarget:(id)aTarget {
	return target == aTarget;
}

- (id)performWithObject:(id)anObject {
	return [target
			performSelector:selector
			withObject:anObject];
}

@end

@implementation MJCloudKitUserDefaultsSync {

	// Things we retain and better release.
	NSString *prefix; // Released in stop from dealloc.
	NSArray *matchList; // Released in stop from dealloc.
	NSTimer *pollCloudKitTimer; // Released in stopObservingActivity from stop from dealloc.
	NSTimer *monitorSubscriptionTimer; // Released in stopObservingActivity from stop from dealloc.
	NSString *databaseContainerIdentifier; // Released in stop from dealloc.
	CKRecordZone *recordZone; // Released in stop from dealloc.
	CKRecordZoneID *recordZoneID; // Released in stop from dealloc.
	CKRecordID *recordID; // Released in stop from dealloc.
	NSMutableArray<MJCloudKitUserDefaultsSync_NotificationHander *> *changeNotificationHandlers[3]; // Released in stop from dealloc.
	CKServerChangeToken *previousChangeToken; // Released in stopObservingActivity from stop from dealloc.
	NSString *lastUpdateRecordChangeTagReceived; // Released in stop from dealloc.

	// Things we don't retain.
	CKDatabase *publicDB;
	CKDatabase *privateDB;
	id<MJCloudKitUserDefaultsSyncDelegate> delegate;

	// Status flags and state.
	BOOL observingIdentityChanges;
	BOOL observingActivity;
	BOOL remoteNotificationsEnabled;
	bool alreadyPolling;
	CFAbsoluteTime lastPollPokeTime;

	// Flow controls.
	BOOL refuseUpdateToICloudUntilAfterUpdateFromICloud;
	BOOL oneTimeDeleteZoneFromICloud; // To clear the user's sync data from iCloud for testing first-time scenario.
	// The GCD queues are all released in dealloc.
	dispatch_queue_t syncQueue;
	dispatch_queue_t pollQueue;
	dispatch_queue_t startStopQueue;

	// Count user actions so we can provide completion when all user actions are complete.
	dispatch_queue_t userActionsCountingQueue;
	int pendingUserActions;
	NSMutableArray *completionsWhenNoPendingUserActions;

	// Diagnostic information.
	BOOL productionMode;
	CFAbsoluteTime lastResubscribeTime;
	int resubscribeCount;
	CFAbsoluteTime lastReceiveTime;
}

#if UNIT_TEST_MEMORY_LEAKS
// MJCloudKitUserDefaultsSync requires CloudKit entitlements and user logged in for testing, so rather than take the time to wrap that up in xctest it is currently just here controlled by "#if UNIT_TEST_MEMORY_LEAKS", so as to piggyback on existing app configuration.

#define XCTAssertEqual(expression1, expression2, ...) \
{ if ( expression1 != expression2 )   [NSException raise:@"XCTAssertEqualFailure" format:@"Values of %@ and %@ not equal (%i and %i): %@",@#expression1,@#expression2,expression1,expression2,__VA_ARGS__]; }

+ (void)testSetRestoreAndClearValueThroughCloudKit {
	NSLog(@"Testing set, restore, and clear value through CloudKit.");

	NSString *containerIdentifier = @"iCloud.com.mark-a-jerde.Flycut";
	NSTimeInterval sleepInterval = 2.0f;
	NSNumber *correctValue = [NSNumber numberWithInt:543];
	NSNumber *incorrectValue = [NSNumber numberWithInt:144];
	NSNumber *clearedValue = [NSNumber numberWithInt:0];

	dispatch_semaphore_t sema = dispatch_semaphore_create(0);

	// Ensure the key is invalid in defaults.
	[[NSUserDefaults standardUserDefaults] setObject:incorrectValue forKey:@"ckSyncFiveFourThree"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	XCTAssertEqual([incorrectValue intValue],
				   [(NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"ckSyncFiveFourThree"] intValue],
				   @"Value not invalid in NSUserDefaults");

	// Create a sync, ensure key is clear, quit sync.
	{
		MJCloudKitUserDefaultsSync *ckSync = [[MJCloudKitUserDefaultsSync alloc] init];

		[ckSync startWithPrefix:@"ckSync"
		withContainerIdentifier:containerIdentifier];

		// Ensure it gets up and running before we continue.
		[ckSync finishPendingAPICallsWithCompletionHandler:^{
			dispatch_semaphore_signal(sema);
		}];
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

		// Should sync within two seconds.
		[NSThread sleepForTimeInterval:sleepInterval];

		DLog(@"Clear value.");

		// MJCloudKitUserDefaultsSync does not yet support removing objects, so set it to zero.
		[[NSUserDefaults standardUserDefaults] setObject:clearedValue
												  forKey:@"ckSyncFiveFourThree"];
		//[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ckSyncFiveFourThree"];
		[[NSUserDefaults standardUserDefaults] synchronize];

		XCTAssertEqual([clearedValue intValue],
					   [(NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"ckSyncFiveFourThree"] intValue],
					   @"Value not cleared in NSUserDefaults");

		// Should sync within two seconds.
		[NSThread sleepForTimeInterval:sleepInterval];

		// Ensure stop completes before we move on.
		[ckSync stopWithCompletionHandler:^{
			dispatch_semaphore_signal(sema);
		}];
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

		DLog(@"Clear value release.");
		[ckSync release];
		ckSync = nil;
		DLog(@"Clear value release done.");
	}

	// Create a sync, add a key to defaults, quit sync.
	{
		MJCloudKitUserDefaultsSync *ckSync = [[MJCloudKitUserDefaultsSync alloc] init];

		[ckSync startWithPrefix:@"ckSync"
		withContainerIdentifier:containerIdentifier];

		// Ensure it gets up and running before we continue.
		[ckSync finishPendingAPICallsWithCompletionHandler:^{
			dispatch_semaphore_signal(sema);
		}];
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

		// Should sync within two seconds.
		[NSThread sleepForTimeInterval:sleepInterval];

		XCTAssertEqual([clearedValue intValue],
					   [(NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"ckSyncFiveFourThree"] intValue],
					   @"Value not absent in CloudKit.");

		[[NSUserDefaults standardUserDefaults] setObject:correctValue forKey:@"ckSyncFiveFourThree"];
		[[NSUserDefaults standardUserDefaults] synchronize];

		XCTAssertEqual([correctValue intValue],
					   [(NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"ckSyncFiveFourThree"] intValue],
					   @"Value not set in NSUserDefaults");

		// Should sync within two seconds.
		[NSThread sleepForTimeInterval:sleepInterval];

		// Ensure stop completes before we move on.
		dispatch_semaphore_t sema = dispatch_semaphore_create(0);
		[ckSync stopWithCompletionHandler:^{
			dispatch_semaphore_signal(sema);
		}];
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
		dispatch_release(sema);

		[ckSync release];
		ckSync = nil;
	}

	NSLog(@"Local clear start.");
	// Remove the key from defaults and verify it is gone.
	// MJCloudKitUserDefaultsSync does not yet support removing objects, so set it to zero.
	[[NSUserDefaults standardUserDefaults] setObject:clearedValue
											  forKey:@"ckSyncFiveFourThree"];
	//[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ckSyncFiveFourThree"];
	[[NSUserDefaults standardUserDefaults] synchronize];

	XCTAssertEqual([clearedValue intValue],
				   [(NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"ckSyncFiveFourThree"]  intValue],
				   @"Value not cleared from NSUserDefaults");
	NSLog(@"Local clear checked.");

	// Wait to ensure notifications are handled before a new sync is created.
	[NSThread sleepForTimeInterval:sleepInterval];

	// Create a sync, check for key in defaults, quit sync.
	{
		NSLog(@"Local clear remote start.");
		MJCloudKitUserDefaultsSync *ckSync = [[MJCloudKitUserDefaultsSync alloc] init];

		[ckSync startWithPrefix:@"ckSync"
		withContainerIdentifier:containerIdentifier];

		// Ensure it gets up and running before we continue.
		[ckSync finishPendingAPICallsWithCompletionHandler:^{
			dispatch_semaphore_signal(sema);
		}];
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

		// Should sync within two seconds.
		[NSThread sleepForTimeInterval:sleepInterval];

		NSLog(@"Local clear remote check.");
		XCTAssertEqual([correctValue intValue],
					   [(NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"ckSyncFiveFourThree"]  intValue],
					   @"Value not loaded from CloudKit after local clear.");

		NSLog(@"Local clear remote release.");

		// Ensure stop completes before we move on.
		dispatch_semaphore_t sema = dispatch_semaphore_create(0);
		[ckSync stopWithCompletionHandler:^{
			dispatch_semaphore_signal(sema);
		}];
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
		dispatch_release(sema);

		[ckSync release];
		ckSync = nil;
	}

	XCTAssertEqual([correctValue intValue],
				   [(NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"ckSyncFiveFourThree"] intValue],
				   @"Value not persisted after CloudKit.");

	// Create a sync, remove key from defaults, quit sync.
	{
		MJCloudKitUserDefaultsSync *ckSync = [[MJCloudKitUserDefaultsSync alloc] init];

		[ckSync startWithPrefix:@"ckSync"
		withContainerIdentifier:containerIdentifier];

		// Ensure it gets up and running before we continue.
		[ckSync finishPendingAPICallsWithCompletionHandler:^{
			dispatch_semaphore_signal(sema);
		}];
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);

		// Should sync within two seconds.
		[NSThread sleepForTimeInterval:sleepInterval];

		XCTAssertEqual([correctValue intValue],
					   [(NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"ckSyncFiveFourThree"] intValue],
					   @"Value not loaded from CloudKit before clear.");

		// MJCloudKitUserDefaultsSync does not yet support removing objects, so set it to zero.
		[[NSUserDefaults standardUserDefaults] setObject:clearedValue
												  forKey:@"ckSyncFiveFourThree"];
		//[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ckSyncFiveFourThree"];
		[[NSUserDefaults standardUserDefaults] synchronize];

		XCTAssertEqual([clearedValue intValue],
					   [(NSNumber *)[[NSUserDefaults standardUserDefaults] objectForKey:@"ckSyncFiveFourThree"] intValue],
					   @"Value not cleared from NSUserDefaults");

		// Should sync within two seconds.
		[NSThread sleepForTimeInterval:sleepInterval];

		// Ensure stop completes before we move on.
		dispatch_semaphore_t sema = dispatch_semaphore_create(0);
		[ckSync stopWithCompletionHandler:^{
			dispatch_semaphore_signal(sema);
		}];
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
		dispatch_release(sema);

		[ckSync release];
		ckSync = nil;
	}

	dispatch_release(sema);

	NSLog(@"Completed testing set, restore, and clear value through CloudKit.");
}
#endif

+ (nullable instancetype)sharedSync {
	static MJCloudKitUserDefaultsSync *sharedMJCloudKitUserDefaultsSync = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
#if UNIT_TEST_MEMORY_LEAKS
		// Run ten times for leak checking.  Each run should create, use, and clean-up several instances of this class.
		NSLog(@"Testing for function and leaks.");
		for ( int i = 0 ; i < 10 ; i++ ) {
			[MJCloudKitUserDefaultsSync testSetRestoreAndClearValueThroughCloudKit];
		}
		NSLog(@"Completed testing for function and leaks.");
#endif

		sharedMJCloudKitUserDefaultsSync = [[self alloc] init];
	});
	return sharedMJCloudKitUserDefaultsSync;
}

- (nonnull instancetype)init {
	self = [super init];
	if (self) {
		// Status flags.
		observingIdentityChanges = NO;
		observingActivity = NO;
		remoteNotificationsEnabled = YES;

		// Flow controls.
		refuseUpdateToICloudUntilAfterUpdateFromICloud = NO;
		oneTimeDeleteZoneFromICloud = NO; // To clear the user's sync data from iCloud for testing first-time scenario.

		// Status flags and state.
		alreadyPolling = NO;

		// Diagnostic information.
		productionMode = NO;
	}
	return self;
}

- (void)createUserActionsCountingQueue {
	if ( !userActionsCountingQueue ) {
		userActionsCountingQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.userActionsCounting", DISPATCH_QUEUE_SERIAL);
	}
}

- (void)finishPendingAPICallsWithCompletionHandler:(void (^)(void))completionHandler {
	[self createUserActionsCountingQueue];

	dispatch_sync(userActionsCountingQueue, ^{
		if ( !completionsWhenNoPendingUserActions )
			completionsWhenNoPendingUserActions = [[NSMutableArray alloc] init];
		[completionsWhenNoPendingUserActions addObject:completionHandler];
		
		[self executeCompletionsIfNoPendingUserActions];
	});
}

- (void)incrementUserActions {
	[self createUserActionsCountingQueue];

	dispatch_sync(userActionsCountingQueue, ^{
		pendingUserActions++;
	});
}

- (void)decrementUserActions {
	[self createUserActionsCountingQueue];

	dispatch_sync(userActionsCountingQueue, ^{
		if ( pendingUserActions > 0 ) {
			pendingUserActions--;

			[self executeCompletionsIfNoPendingUserActions];
		}
		else {
			NSLog(@"User Actions Underflow. This indicates a missing incrementUserActions call.");
		}
	});
}

- (void)executeCompletionsIfNoPendingUserActions {
	if ( 0 == pendingUserActions
		&& [completionsWhenNoPendingUserActions count] > 0 ) {
		for ( int i = 0 ; i < completionsWhenNoPendingUserActions.count ; i++ ) {
			((void (^)(void))completionsWhenNoPendingUserActions[i])();
		}
		[completionsWhenNoPendingUserActions release];
		completionsWhenNoPendingUserActions = nil;
	}
}

- (void)updateToiCloud:(NSNotification *)notificationObject {
	dispatch_async(syncQueue, ^{
		DLog(@"Update to iCloud?");
		if ( refuseUpdateToICloudUntilAfterUpdateFromICloud ) {
			DLog(@"NO.  Waiting until after update from iCloud");
		}
		else {
			// Store local and retain our DB since we are going to suspend a queue and only resume in the completion handler for a call to this DB.
			CKDatabase *db = [privateDB retain];
			if ( nil == db ) {
				DLog(@"Database has been unset.  Not updating to iCloud");
				return;
			}
			DLog(@"YES.  Updating to iCloud");
			dispatch_suspend(syncQueue);
			[db fetchRecordWithID:recordID completionHandler:^(CKRecord *record, NSError *error) {
				if (error
					&& !( nil != [error.userInfo objectForKey:@"ServerErrorDescription" ]
						 && [(NSString *)[error.userInfo objectForKey:@"ServerErrorDescription" ] isEqualToString:@"Record not found"	] ) ) {
						// Error handling for failed fetch from public database
						DLog(@"CloudKit Fetch failure: %@", error.localizedDescription);
						dispatch_resume(syncQueue);
						[db release];
					}
				else if ( ![[record recordChangeTag] isEqualToString:lastUpdateRecordChangeTagReceived] ) {
					// We won't push our content if there is something we haven't received yet.

					// Pull from iCloud now, pushing afterward.
					[self updateFromiCloud:nil];
					[self updateToiCloud:nil];
					dispatch_resume(syncQueue);
					[db release];
				}
				else {
					DLog(@"Updating to iCloud completion");
					// Modify the record and save it to the database

					BOOL needToReleaseRecord = NO;
					if (error
						&& nil != [error.userInfo objectForKey:@"ServerErrorDescription" ]
						&& [(NSString *)[error.userInfo objectForKey:@"ServerErrorDescription" ] isEqualToString:@"Record not found"	] ) {

						DLog(@"Updating to iCloud completion creation");
						record = [[CKRecord alloc] initWithRecordType:recordType recordID:recordID];
						needToReleaseRecord = YES;
					}

					NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
					NSDictionary *dict = [defaults dictionaryRepresentation];

					__block int additions = 0, modifications = 0;
					__block NSMutableDictionary *changes = nil;
					// Maybe we could compare record and dict, creating an array of only the items which are not identical in both.
					[dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
						if ( ( nil != prefix && [key hasPrefix:prefix] )
							|| ( nil != matchList && [matchList containsObject:key] ) ) {
							Boolean skip = NO;

							if ( nil != obj ) {
								obj = [MJCloudKitUserDefaultsSync serialize:obj forKey:key];
								if ( nil == obj )
									skip = YES;
							}

							if ( skip ) {
							}
							else if ( nil == [record objectForKey:key] ) {
								DLog(@"Adding %@.", key);
								additions++;
							}
							else if ( ( [obj isKindOfClass:[NSNumber class]] && [(NSNumber *)record[key] intValue] != [(NSNumber *)obj intValue] )
									 || ( [obj isKindOfClass:[NSString class]] && ![(NSString *)obj isEqualToString:(NSString *)record[key]] )
									 || ( [obj isKindOfClass:[NSData class]] && ![(NSData *)obj isEqualToData:(NSData *)record[key]] ) ) {
								DLog(@"Changing %@.", key);
								modifications++;
							}
							else {
								DLog(@"Skipping %@.", key);
								skip = YES;
							}

							if ( !skip ) {
								if ( !changes )
									changes = [[NSMutableDictionary alloc] init];

								NSMutableArray *fromToTheirs = [[NSMutableArray alloc] init];
								NSObject *from = record[key];
								if ( !from ) from = obj; // There is no from, so the to is the from.
								[fromToTheirs addObject:from];
								[fromToTheirs addObject:obj];
								[changes setObject:fromToTheirs forKey:key];

								record[key] = obj;
							}
						}
					}];
					DLog(@"To iCloud: Adding %i keys.  Modifying %i keys.", additions, modifications);

					if ( additions + modifications > 0 ) {
						[db saveRecord:record completionHandler:^(CKRecord *savedRecord, NSError *saveError) {
							DLog(@"Saving to iCloud.");
							if ( saveError ) {
								// Error handling for failed save to public database
								DLog(@"CloudKit Save failure: %@", saveError.localizedDescription);

								[db fetchRecordWithID:recordID completionHandler:^(CKRecord *newRecord, NSError *error) {
									if (error) {
										// Error handling for failed fetch from public database
										DLog(@"CloudKit Fetch failure: %@", error.localizedDescription);
										[self completeUpdateToiCloudWithChanges:changes];
										[db release];
									}
									else {
										DLog(@"Updating to iCloud completion");

										[changes enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
											// Add the new remote value and ensure the to, from, and theirs values are all deserialized if necessary.

											NSObject *originalObj = [[NSUserDefaults standardUserDefaults] objectForKey:key];
											id fromObj = [obj firstObject];
											if ( nil != fromObj ) {
												fromObj = [MJCloudKitUserDefaultsSync deserialize:fromObj forKey:key similarTo:originalObj];
												if ( nil == fromObj ) {
													// Failed to deserialize.  Put our value in.
													fromObj = originalObj;
												}
											}
											id remoteObj = [newRecord objectForKey:key];
											if ( nil != remoteObj ) {
												remoteObj = [MJCloudKitUserDefaultsSync deserialize:remoteObj forKey:key similarTo:originalObj];
												if ( nil == remoteObj ) {
													// Failed to deserialize.  Put our value in.
													remoteObj = [obj lastObject];
												}
											}

											obj[0] = fromObj;
											obj[1] = originalObj;
											[obj addObject:remoteObj];
										}];

										NSDictionary *corrections = [self sendNotificationsFor:MJSyncNotificationConflicts onKeys:changes];

										if ( [corrections count] ) {
											[corrections enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
												Boolean skip = NO;
												if ( nil != obj ) {
													obj = [MJCloudKitUserDefaultsSync serialize:obj forKey:key];
													if ( nil == obj )
														skip = YES;
												}

												if ( !skip )
													newRecord[key] = obj;
											}];
											[corrections release];

											[db saveRecord:newRecord completionHandler:^(CKRecord *savedRecord, NSError *saveError) {
												DLog(@"Saving to iCloud.");
												if ( saveError ) {
													// If we had a conflict on the conflict resolution, just give up for now.
													DLog(@"CloudKit conflict-resolution Save failure: %@", saveError.localizedDescription);
												}
												else {
													// Save counts as receive, since we have seen what we put in there.
													[self updateLastRecordReceived:savedRecord];

												}

												[self completeUpdateToiCloudWithChanges:changes];
												[db release];
											}];
										}
										else {
											[self completeUpdateToiCloudWithChanges:changes];
											[db release];
										}
									}
								}];
							}
							else
							{
								// Save counts as receive, since we have seen what we put in there.
								[self updateLastRecordReceived:savedRecord];

								[self sendNotificationsFor:MJSyncNotificationSaveSuccess onKeys:changes];
								[self completeUpdateToiCloudWithChanges:changes];
								[db release];
							}
						}];
					}
					else {
						[self completeUpdateToiCloudWithChanges:changes];
						[db release];
					}

					// If the record wasn't found, so we had to create it, then we own it and better release it.
					if ( needToReleaseRecord )
						[record release];
				}
			}];
		}
	});
}

- (void)completeUpdateToiCloudWithChanges:(NSMutableDictionary *)changes {
	// Resume before releasing memory, since there's nothing shared about the memory.
	dispatch_resume(syncQueue);

	[changes enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
		[obj release];
	}];
	[changes release];
}

+ (id)serialize:(id)obj
		 forKey:(NSString *)key {
	// Only serialize types that need to be.
	if ( [obj isKindOfClass:[NSDictionary class]] ) {
		NSError *error;
		NSData *data = [NSPropertyListSerialization dataWithPropertyList:obj format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
		if ( data )
			obj = data;
		else {
			DLog( @"Error serializing %@ to binary: %@", key, error );
			obj = nil;
		}
	}
	return obj;
}

+ (id)deserialize:(id)remoteObj
		   forKey:(NSString *)key
		similarTo:(id)originalObj {
	if ( [remoteObj isKindOfClass:[NSData class]]
		&& !(originalObj && [originalObj isKindOfClass:[NSData class]]) ) {
		NSError *error;
		id deserialized = [NSPropertyListSerialization propertyListWithData:(NSData *)remoteObj options:NSPropertyListImmutable format:nil error:&error];
		if ( deserialized )
			remoteObj = deserialized;
		else if ( originalObj ) {
			DLog( @"Error deserializing %@ from binary: %@", key, error );
			remoteObj = nil;
		}
		else {
			// Keep input remoteObj the same and return as output.
			DLog( @"Error deserializing %@ from binary, but we didn't have a local copy so we assume it wasn't supposed to be deserialized.  We assume this is okay in order to handle storing NSData that doesn't represent a serialized property list. %@", key, error );
		}
	}
	return remoteObj;
}

- (void)updateFromiCloud:(NSNotification *)notificationObject {
	dispatch_async(syncQueue, ^{
		// Store local and retain our DB since we are going to suspend a queue and only resume in the completion handler for a call to this DB.
		CKDatabase *db = [privateDB retain];
		if ( nil == db ) {
			DLog(@"Database has been unset.  Not updating from iCloud");
			return;
		}
		DLog(@"Updating from iCloud");
		dispatch_suspend(syncQueue);
		[db fetchRecordWithID:recordID completionHandler:^(CKRecord *record, NSError *error) {
			if (error) {
				// Error handling for failed fetch from public database
				DLog(@"CloudKit Fetch failure: %@", error.localizedDescription);
			}
			else {
				[self updateLastRecordReceived:record];

				DLog(@"Updating from iCloud completion");

				// prevent NSUserDefaultsDidChangeNotification from being posted while we update from iCloud
				[[NSNotificationCenter defaultCenter] removeObserver:self
																name:NSUserDefaultsDidChangeNotification
															  object:nil];

				DLog(@"Got record -%@-_-%@-_-%@-_-%@-",[[[record recordID] zoneID] zoneName],[[[record recordID] zoneID] ownerName],[[record recordID] recordName],[record recordChangeTag]);

				__block int additions = 0, modifications = 0;
				__block NSMutableDictionary *changes = nil;
				[[record allKeys] enumerateObjectsUsingBlock:^(id key, NSUInteger idx, BOOL *stop) {
					if ( ( nil != prefix && [key hasPrefix:prefix] )
						|| ( nil != matchList && [matchList containsObject:key] ) ) {

						BOOL skip = NO;
						NSObject *obj = [[NSUserDefaults standardUserDefaults] objectForKey:key];
						NSObject *originalObj = obj;

						if ( nil != obj ) {
							obj = [MJCloudKitUserDefaultsSync serialize:obj forKey:key];
							if ( nil == obj )
								skip = YES;
						}

						if ( skip ) {
						}
						else if ( nil == obj ) {
							DLog(@"Adding %@.", key);
							additions++;
						}
						else if ( ( [obj isKindOfClass:[NSNumber class]] && [(NSNumber *)record[key] intValue] != [(NSNumber *)obj intValue] )
								 || ( [obj isKindOfClass:[NSString class]] && ![(NSString *)obj isEqualToString:(NSString *)record[key]] )
								 || ( [obj isKindOfClass:[NSData class]] && ![(NSData *)obj isEqualToData:(NSData *)record[key]] ) ) {
							DLog(@"Changing %@.", key);
							modifications++;
						}
						else {
							DLog(@"Skipping %@.", key);
							skip = YES;
						}
						if ( !skip ) {
							id remoteObj = [record objectForKey:key];

							if ( nil != remoteObj ) {
								remoteObj = [MJCloudKitUserDefaultsSync deserialize:remoteObj forKey:key similarTo:originalObj];
								if ( nil == remoteObj )
									skip = YES;
							}

							if ( !skip ) {
								[[NSUserDefaults standardUserDefaults] setObject:remoteObj forKey:key];
								if ( !changes )
									changes = [[NSMutableDictionary alloc] init];
								[changes setObject:key forKey:key];
							}
						}
					}
				}];
				DLog(@"From iCloud: Adding %i keys.  Modifying %i keys.", additions, modifications);

				if ( additions + modifications > 0 ) {
					DLog(@"Synchronizing defaults.");
					[[NSUserDefaults standardUserDefaults] synchronize];

					[self sendNotificationsFor:MJSyncNotificationChanges onKeys:changes];

					[changes release];
				}

				// enable NSUserDefaultsDidChangeNotification notifications again
				[[NSNotificationCenter defaultCenter] addObserver:self
														 selector:@selector(updateToiCloud:)
															 name:NSUserDefaultsDidChangeNotification
														   object:nil];

				refuseUpdateToICloudUntilAfterUpdateFromICloud = NO;
			}
			dispatch_resume(syncQueue);
			[db release];
		}];
	});
}

- (void)setDelegate:(nonnull id<MJCloudKitUserDefaultsSyncDelegate>)newDelegate {
	delegate = newDelegate;
}

- (void)setRemoteNotificationsEnabled:(bool)enabled {
	if ( enabled != remoteNotificationsEnabled ) {
		bool resume = observingActivity;
		if ( observingActivity )
			[self pause];
		remoteNotificationsEnabled = enabled;
		if ( resume )
			[self resume];
	}
}

- (void)startWithPrefix:(nonnull NSString *)prefixToSync
withContainerIdentifier:(nonnull NSString *)containerIdentifier {
	[self incrementUserActions];

	DLog(@"Starting with prefix");

	if ( !startStopQueue ) {
		startStopQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.startStopQueue", DISPATCH_QUEUE_SERIAL);
	}

	// Since we are going GCD async.
	prefixToSync = [prefixToSync retain];
	containerIdentifier = [containerIdentifier retain];

	// If we are already running and add criteria while updating to iCloud, we could push to iCloud before pulling the existing value from iCloud.  Avoid this by dispatching into another thread that will wait pause existing activity and wait for it to stop before adding new criteria.
	dispatch_async(startStopQueue, ^{
		DLog(@"Actually starting with prefix");

		if ( nil == prefixToSync || [prefixToSync isEqualToString:prefix] ) {
			DLog(@"Starting no new prefix.  No action will be taken.");
			return;
		}

		[self commonStartInitialStepsOnContainerIdentifier:containerIdentifier];
		[containerIdentifier release];

		[prefix release];
		prefix = prefixToSync; // Already retained before we went to GCD async.

		[self attemptToEnable];
	});
}

- (void)startWithKeyMatchList:(nonnull NSArray *)keyMatchList
	  withContainerIdentifier:(nonnull NSString *)containerIdentifier {
	[self incrementUserActions];

	DLog(@"Starting with match list length %lu atop %lu", (unsigned long)[keyMatchList count], (unsigned long)[matchList count]);

	if ( !startStopQueue ) {
		startStopQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.startStopQueue", DISPATCH_QUEUE_SERIAL);
	}

	// Since we are going GCD async.
	keyMatchList = [keyMatchList retain];
	containerIdentifier = [containerIdentifier retain];

	// If we are already running and add criteria while updating to iCloud, we could push to iCloud before pulling the existing value from iCloud.  Avoid this by dispatching into another thread that will wait pause existing activity and wait for it to stop before adding new criteria.
	dispatch_async(startStopQueue, ^{
		DLog(@"Actually starting with match list length %lu atop %lu", (unsigned long)[keyMatchList count], (unsigned long)[matchList count]);

		if ( nil == keyMatchList || 0 == [keyMatchList count] ) {
			DLog(@"Starting no new keys.  No action will be taken.");
			return;
		}

		if ( !matchList )
			matchList = [[NSArray alloc] init];

		// Add to existing array.
		NSArray *newList = [matchList arrayByAddingObjectsFromArray:keyMatchList];
		[keyMatchList release];
		// Remove duplicates.
		newList = [[NSSet setWithArray:newList] allObjects];

		if ( [newList count] == [matchList count] ) {
			DLog(@"Starting no additional new keys.  No action will be taken.");
			return;
		}

		[self commonStartInitialStepsOnContainerIdentifier:containerIdentifier];
		[containerIdentifier release];

		// Install new array.
		NSArray *toRelease = matchList;
		matchList = [newList retain];
		[toRelease release];

		DLog(@"Match list length is now %lu", (unsigned long)[matchList count]);

		[self attemptToEnable];
	});
}

- (void)commonStartInitialStepsOnContainerIdentifier:(NSString *)containerIdentifier {
	[self pause];

	DLog(@"Waiting for sync queue to clear before adding new criteria.");
	if ( !syncQueue ) {
		syncQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.queue", DISPATCH_QUEUE_SERIAL);
	}
	dispatch_sync(syncQueue, ^{
		refuseUpdateToICloudUntilAfterUpdateFromICloud = YES;
		DLog(@"Waited for sync queue to clear before adding new criteria.");
	});

	[databaseContainerIdentifier release];
	databaseContainerIdentifier = [containerIdentifier retain];
}

- (void)pause {
	if ( !startStopQueue ) {
		startStopQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.startStopQueue", DISPATCH_QUEUE_SERIAL);
	}

	// pause can be called while already on the desired GDC queue.  We can detect this and only dispatch to the queue if not already on it.  This is needed because we pause the queue to wait for completion on a different asynchronous activity.
	if ( strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(startStopQueue)) ) {
		dispatch_async(startStopQueue, ^{
			[self pause];
		});
	}
	else {
		// Question: Rather than stopping observing here, and later enabling again, would it be better to just set a flag for updateTo / updateFrom to do nothing?  The latter would require something to ensure that we notice changes that happened while paused, so the idea is non-trivial.
		[self stopObservingActivity];
		[self stopObservingIdentityChanges];
	}
}

- (void)resume {
	if ( !startStopQueue ) {
		startStopQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.startStopQueue", DISPATCH_QUEUE_SERIAL);
	}
	dispatch_async(startStopQueue, ^{
		[self attemptToEnable];
	});
}

- (void)stopForKeyMatchList:(nonnull NSArray *)keyMatchList {
	[self incrementUserActions];

	DLog(@"Stopping match list length %lu from %lu", (unsigned long)[keyMatchList count], (unsigned long)[matchList count]);

	if ( !startStopQueue ) {
		startStopQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.startStopQueue", DISPATCH_QUEUE_SERIAL);
	}

	// Since we are going GCD async.
	keyMatchList = [keyMatchList retain];

	dispatch_async(startStopQueue, ^{
		if ( !matchList )
			return;

		NSArray *toRelease = matchList;

		NSMutableArray *mutableList = [[NSMutableArray alloc] initWithArray:matchList];
		[mutableList removeObjectsInArray:keyMatchList];
		[keyMatchList release];
		matchList = mutableList;

		[toRelease release];

		DLog(@"Match list length is now %lu", (unsigned long)[matchList count]);

		if ( 0 == matchList.count )
			[self stopWithCompletionHandler:^{
				[self decrementUserActions];
			}];
		else
			[self decrementUserActions];
	});
}

- (void)stop {
	[self stopWithCompletionHandler:nil];
}

- (void)stopWithCompletionHandler:(void (^)(void))completionHandler {
	DLog(@"Stopping.");

	if ( !startStopQueue ) {
		startStopQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.startStopQueue", DISPATCH_QUEUE_SERIAL);
	}

	dispatch_async(startStopQueue, ^{
		[self stopObservingActivity];
		[self stopObservingIdentityChanges];

		[self releaseClearObject:&matchList];
		[self releaseClearObject:&prefix];
		[self releaseClearObject:&databaseContainerIdentifier];

		for ( int type = MJSyncNotificationTypeFirst(); type <= MJSyncNotificationTypeLast(); type++ ) {
			// Collection contents are retained and released by the collection, so no need to release contents here.
			[self releaseClearObject:&(changeNotificationHandlers[type])];
		}

		[self releaseClearObject:&lastUpdateRecordChangeTagReceived];
		DLog(@"Stopped.");

		if ( completionHandler ) completionHandler();
	});
}

- (void)addNotificationFor:(MJSyncNotificationType)type
			  withSelector:(nonnull SEL)aSelector
				withTarget:(nonnull id)aTarget {
	DLog(@"Registering change notification selector.");
	if ( !changeNotificationHandlers[type] )
		changeNotificationHandlers[type] = [[NSMutableArray alloc] init];
	
	MJCloudKitUserDefaultsSync_NotificationHander *notification = [[MJCloudKitUserDefaultsSync_NotificationHander alloc] initWithSelector:aSelector withTarget:aTarget];
	[changeNotificationHandlers[type] addObject:notification];
	[notification release];
}

- (void)removeNotificationsFor:(MJSyncNotificationType)type
					 forTarget:(nonnull id)aTarget {
	DLog(@"Removing change notification selector(s).");
	for ( int i = 0 ; i < [changeNotificationHandlers[type] count] ; i++ ) {
		if ( [changeNotificationHandlers[type][i] isTarget:aTarget] ) {
			DLog(@"Removing a change notification selector.");
			[changeNotificationHandlers[type] removeObjectAtIndex:i];
			i--;
		}
	}
}

- (NSDictionary *)sendNotificationsFor:(MJSyncNotificationType)type
								onKeys:(NSDictionary *)changes {
	DLog(@"Sending change notification selector(s).");
	__block NSMutableDictionary *corrections = nil;
	if ( changeNotificationHandlers[type] ) {
		for ( int i = 0 ; i < [changeNotificationHandlers[type] count] ; i++ ) {
			DLog(@"Sending a change notification selector.");
			NSDictionary *currentCorrections = [changeNotificationHandlers[type][i] performWithObject:changes];

			[currentCorrections enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
				if ( !corrections )
					corrections = [[NSMutableDictionary alloc] init];
				[corrections setObject:obj forKey:key];
			}];
			[currentCorrections release];
		}
	}
	return corrections;
}

- (void)identityDidChange:(NSNotification *)notificationObject {
	DLog(@"iCloud Identity Change Detected");
	dispatch_async(startStopQueue, ^{
		[self attemptToEnable];
	});
}

- (void)checkCloudKitUpdates {
	DLog(@"Got checkCloudKitUpdates");
	if ( observingActivity ) {
		[self updateFromiCloud:nil];
	}
}

- (void)attemptToEnable {
	dispatch_suspend(startStopQueue);
	DLog(@"Attempting to enable");
	[[CKContainer defaultContainer] accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError *error) {
		switch ( accountStatus ) {
			case CKAccountStatusAvailable:  // is iCloud enabled
				DLog(@"iCloud Available");
				[self startObservingActivity];
				break;

			case CKAccountStatusNoAccount:
				DLog(@"No iCloud account");
				if ( [delegate respondsToSelector:@selector(notifyCKAccountStatusNoAccount)] )
					[delegate notifyCKAccountStatusNoAccount];
				[self stopObservingActivity];
				dispatch_resume(startStopQueue);

				[self decrementUserActions];
				break;

			case CKAccountStatusRestricted:
				DLog(@"iCloud restricted");
				[self stopObservingActivity];
				dispatch_resume(startStopQueue);

				[self decrementUserActions];
				break;

			case CKAccountStatusCouldNotDetermine:
				DLog(@"Unable to determine iCloud status");
				[self stopObservingActivity];
				dispatch_resume(startStopQueue);

				[self decrementUserActions];
				break;
		}

		[self startObservingIdentityChanges];
	}];
}

- (void)startObservingActivity {
	DLog(@"Should start observing activity?");
	if ( !observingActivity ) {
		DLog(@"YES.  Start observing activity.");
		observingActivity = YES;

		// Setup database connections.
		CKContainer *container = [CKContainer containerWithIdentifier:databaseContainerIdentifier];
		int environmentValue = ((NSNumber *)[[container valueForKey:@"containerID"] valueForKey:@"environment"]).intValue;
		productionMode = (1 == environmentValue);
		publicDB = [container publicCloudDatabase];
		privateDB = [container privateCloudDatabase];

		// Create a record zone ID.
		[recordZoneID release];
		recordZoneID = [[CKRecordZoneID alloc] initWithZoneName:recordZoneName ownerName:CKOwnerDefaultName];

		// Create a record ID.
		[recordID release];
		recordID = [[CKRecordID alloc] initWithRecordName:recordName zoneID:recordZoneID];

		// Create a record zone.
		[recordZone release];
		recordZone = [[CKRecordZone alloc] initWithZoneID:recordZoneID];

		DLog(@"Created CKRecordZone.zoneID %@:%@", recordZone.zoneID.zoneName, recordZone.zoneID.ownerName);

		if ( oneTimeDeleteZoneFromICloud ) {
			observingActivity = NO;
			oneTimeDeleteZoneFromICloud = NO;
			DLog(@"Deleting CKRecordZone one time.");
			CKModifyRecordZonesOperation *deleteOperation = [[CKModifyRecordZonesOperation alloc] initWithRecordZonesToSave:@[] recordZoneIDsToDelete:@[recordZoneID]];
			deleteOperation.modifyRecordZonesCompletionBlock = ^(NSArray *savedRecordZones, NSArray *deletedRecordZoneIDs, NSError *error) {
				if ( nil != error ) {
					DLog(@"CloudKit Delete Record Zones failure: %@", error.localizedDescription);
				}
				else {
					DLog(@"Deleted CKRecordZone.");
				}
				[self startObservingActivity];
			};
			[privateDB addOperation:deleteOperation];
			[deleteOperation release];
			return;
		}
		CKModifyRecordZonesOperation *operation = [[CKModifyRecordZonesOperation alloc] initWithRecordZonesToSave:@[recordZone] recordZoneIDsToDelete:@[]];
		operation.modifyRecordZonesCompletionBlock = ^(NSArray *savedRecordZones, NSArray *deletedRecordZoneIDs, NSError *error) {
			if ( nil != error ) {
				DLog(@"CloudKit Modify Record Zones failure: %@", error.localizedDescription);
				[self stopObservingActivity];
				dispatch_resume(startStopQueue);
			}
			else {
				DLog(@"Recorded CKRecordZone.zoneID %@:%@", ((CKRecordZone *)savedRecordZones[0]).zoneID.zoneName, ((CKRecordZone *)savedRecordZones[0]).zoneID.ownerName);
				// Find out when things change
				[self subscribeToDatabase];

				// Pull from iCloud now, pushing afterward.
				// If we push first, we overwrite the sync.
				// If we don't push after the pull, we won't push until something changes.
				[self updateFromiCloud:nil];
				[self updateToiCloud:nil];

				[self decrementUserActions];
			}

		};
		[privateDB addOperation:operation];
		[operation release];

		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(updateToiCloud:)
													 name:NSUserDefaultsDidChangeNotification
												   object:nil];
	}
}

- (void)subscribeToDatabase {
	DLog(@"Subscribing to database.");
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"TRUEPREDICATE" ];
	CKQuerySubscription *subscription =
#if TARGET_IPHONE_SIMULATOR
	nil; // Simulator doesn't support remote notifications.
#else // TARGET_IPHONE_SIMULATOR
	remoteNotificationsEnabled ?
	[[CKQuerySubscription alloc] initWithRecordType:recordType
										  predicate:predicate
									 subscriptionID:subscriptionID
											options:CKQuerySubscriptionOptionsFiresOnRecordCreation | CKQuerySubscriptionOptionsFiresOnRecordUpdate | CKQuerySubscriptionOptionsFiresOnRecordDeletion]
	: nil;
#endif // TARGET_IPHONE_SIMULATOR

	if ( nil == subscription ) {
		// CKQuerySubscription was added after the core CloudKit APIs, so on OS versions that don't support it we will poll instead as there appears to be no alternative subscription API.
		DLog(@"Using polling instead.");

		if ( !pollQueue ) {
			pollQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.poll", DISPATCH_QUEUE_SERIAL);
		}

		// Start a timer to poll for changes, if there isn't a timer for this already.
		if ( nil == pollCloudKitTimer ) {
			alreadyPolling = NO;
			[self setStartRepeatingTimer:&pollCloudKitTimer
							WithInterval:(1.0)
								selector:@selector(pollCloudKit:)];
		}
		dispatch_resume(startStopQueue);
	}
	else {
		CKNotificationInfo *notification = [[CKNotificationInfo alloc] init];
		notification.shouldSendContentAvailable = YES;
		subscription.notificationInfo = notification;
		[notification release]; // Since notificationInfo is a copy property.

		DLog(@"Fetching existing subscription.");
		[privateDB fetchSubscriptionWithID:subscription.subscriptionID completionHandler:^(CKSubscription * _Nullable existingSubscription, NSError * _Nullable error) {
			DLog(@"Fetched existing subscription.");
			if ( nil == existingSubscription ) {
				DLog(@"No existing subscription. Saving ours.");
				// In the not-yet-subscribed-but-everything-working case, error will contain k/v @"ServerErrorDescription" : @"subscription not found"
				[privateDB saveSubscription:subscription completionHandler:^(CKSubscription * _Nullable subscription, NSError * _Nullable error) {
					DLog(@"Saved subscription.");
					if ( nil != error ) {
						DLog(@"CloudKit Subscription failure: %@", error.localizedDescription);
						[self stopObservingActivity];
					}
					dispatch_resume(startStopQueue);
				}];
			}
			else {
				dispatch_resume(startStopQueue);
			}

			[subscription release];

			// Start a timer to make sure the subscription keeps working, if there isn't a timer for this already.
			[self setStartRepeatingTimer:&monitorSubscriptionTimer
							WithInterval:(60.0)
								selector:@selector(monitorSubscription:)];
		}];
	}
}

- (void)setStartRepeatingTimer:(NSTimer **)timer
				  WithInterval:(NSTimeInterval)ti
					  selector:(SEL)s {
	if ( nil == *timer ) {
		// Timers attach to the run loop of the process, which isn't present on all processes, so we must dispatch to the main queue to ensure we have a run loop for the timer.
		dispatch_async(dispatch_get_main_queue(), ^{
			// Check nil again in case there was a race.
			if ( nil == *timer ) {
				NSDate *oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
				*timer = [[NSTimer alloc] initWithFireDate:oneSecondFromNow
												  interval:ti
													target:self
												  selector:s
												  userInfo:nil
												   repeats:YES];
				// Assign it to NSRunLoopCommonModes so that it will still poll while the menu is open.  Using a simple NSTimer scheduledTimerWithTimeInterval: would result in polling that stops while the menu is active.  In the past this was okay but with Universal Clipboard a new clipping can arrive while the user has the menu open.
				[[NSRunLoop currentRunLoop] addTimer:*timer forMode:NSRunLoopCommonModes];
			}
		});
	}
}

- (void)stopReleaseClearTimer:(NSTimer **)timer {
	[*timer invalidate];
	[self releaseClearObject:timer];
}

- (void)releaseClearObject:(NSObject **)object {
	[*object release];
	*object = nil;
}

- (void)monitorSubscription:(NSTimer *)timer {
	[privateDB fetchSubscriptionWithID:subscriptionID completionHandler:^(CKSubscription * _Nullable existingSubscription, NSError * _Nullable error) {
		BOOL noSubscription = (nil == existingSubscription);
		if ( observingActivity && noSubscription )
			dispatch_async(startStopQueue, ^{
				dispatch_suspend(startStopQueue);
				lastResubscribeTime = CFAbsoluteTimeGetCurrent();
				resubscribeCount++;
				[self subscribeToDatabase];
			});
	}];
}

- (void)stopObservingActivity {
	DLog(@"Should stop observing activity?");
	if ( observingActivity ) {
		DLog(@"YES.  Stop observing activity.");
		// Switch to the syncQueue so we don't cut them off if active.
		dispatch_sync(syncQueue, ^{
			DLog(@"Stopping observing activity.");
			observingActivity = NO;

			[self stopReleaseClearTimer:&pollCloudKitTimer];
			[self stopReleaseClearTimer:&monitorSubscriptionTimer];
			[self releaseClearObject:&previousChangeToken];

			[privateDB deleteSubscriptionWithID:subscriptionID completionHandler:^(NSString * _Nullable subscriptionID, NSError * _Nullable error) {
				DLog(@"Stopped observing activity.");
				// We check for an existing subscription before saving a new subscription so the result here doesn't matter."
			}];

			[self releaseClearObject:&recordZone];
			[self releaseClearObject:&recordZoneID];
			[self releaseClearObject:&recordID];

			// Clear database connections.
			publicDB = privateDB = nil;

			[[NSNotificationCenter defaultCenter] removeObserver:self
															name:NSUserDefaultsDidChangeNotification
														  object:nil];
		});
	}
}

- (void)startObservingIdentityChanges {
	DLog(@"Should start observing identity changes?");
	if ( !observingIdentityChanges ) {
		DLog(@"YES.  Start observing identity changes.");
		observingIdentityChanges = YES;
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(identityDidChange:)
													 name:NSUbiquityIdentityDidChangeNotification
												   object:nil];
	}
}

- (void)stopObservingIdentityChanges {
	DLog(@"Should stop observing identity changes?");
	if ( observingIdentityChanges ) {
		DLog(@"YES.  Stop observing identity changes.");
		observingIdentityChanges = NO;
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:NSUbiquityIdentityDidChangeNotification
													  object:nil];
	}
}

- (void)pollCloudKit:(NSTimer *)timer {
	// The fetchRecordChangesCompletionBlock below doesn't get called until after the recordChangedBlock below completes.  The former block provides the change token which the poll uses to identify if changes have happened.  Prevent use of the old change token while processing changes, which would of course detect changes and cause excess evaluation, by setting / checking a flag in a serial queue until the completion block which occurs on a different queue causes it to be cleared in the original serial queue.
	// This is preferable to using a dispatch_suspend / dispatch_resume because it prevents amassing a long queue of serial GCD operations in the event that the CloudKit CKFetchRecordChangesOperation takes more than the polling interval.

	dispatch_async(pollQueue, ^{
		if ( !alreadyPolling ) {
			DLog(@"Polling");
			alreadyPolling = YES;
			lastPollPokeTime = CFAbsoluteTimeGetCurrent();

			// CKFetchRecordChangesOperation is OS X 10.10 to 10.12, but CKQuerySubscription is 10.12+ so for code exclusive to our pre-CKQuerySubscription support we can use things that were deprecated when CKQuerySubscription was added.
			// We will have to revisit this ^ since Push Notifications is only allowed if distributed through the App Store and CKQuerySubscription depends on Push Notifications.

			CKFetchRecordChangesOperation *operation = [[CKFetchRecordChangesOperation alloc] initWithRecordZoneID:recordZone.zoneID previousServerChangeToken:previousChangeToken];

			operation.recordChangedBlock = ^(CKRecord *record) {
				DLog(@"Polling got record change");
				// Only check updates if the timer is still valid, since it could be invalidated while we were contacting iCloud.
				if ( !timer.isValid )
					return;
				[self checkCloudKitUpdates];
			};

			operation.fetchRecordChangesCompletionBlock = ^(CKServerChangeToken * _Nullable serverChangeToken, NSData * _Nullable clientChangeTokenData, NSError * _Nullable operationError) {
				DLog(@"Polling completion");
				// Only complete if the timer is still valid, since it could be invalidated while we were contacting iCloud.
				if ( !timer.isValid )
					return;
				if ( nil == operationError ) {
					DLog(@"Polling completion GOOD");

					[previousChangeToken release];
					previousChangeToken = [serverChangeToken retain];

					[clientChangeTokenData release];
				}

				// Back to the pollQueue to clear the flag since we are now on a different queue.
				dispatch_async(pollQueue, ^{
					alreadyPolling = NO;
				});
			};

			[privateDB addOperation:operation];
			[operation release];
		}
		else if ( CFAbsoluteTimeGetCurrent() - lastPollPokeTime > 600 ) {
			// If it has been more than ten minutes without a poll response, send another one to try to wake up iCloud since it seems to be slow to realize when we come back online.
			// Would be better if we didn't send this while offline.
			lastPollPokeTime = CFAbsoluteTimeGetCurrent();

			DLog(@"Poking");
			CKFetchRecordChangesOperation *operation = [[CKFetchRecordChangesOperation alloc] initWithRecordZoneID:recordZone.zoneID previousServerChangeToken:previousChangeToken];

			operation.recordChangedBlock = ^(CKRecord *record) { DLog(@"Poke got record change"); };

			operation.fetchRecordChangesCompletionBlock = ^(CKServerChangeToken * _Nullable serverChangeToken, NSData * _Nullable clientChangeTokenData, NSError * _Nullable operationError) { DLog(@"Poke completion"); };

			[privateDB addOperation:operation];
			[operation release];
		}
	});
}

- (void)updateLastRecordReceived:(CKRecord *)record {
	[lastUpdateRecordChangeTagReceived release];
	lastUpdateRecordChangeTagReceived = [[record recordChangeTag] retain];
}

- (nullable NSString *)diagnosticData {
	NSString *lastPollPoke = [MJCloudKitUserDefaultsSync cfAbsoluteTimeToString:lastPollPokeTime];
	NSString *lastReceive = [MJCloudKitUserDefaultsSync cfAbsoluteTimeToString:lastReceiveTime];
	NSString *lastResubscribe = [MJCloudKitUserDefaultsSync cfAbsoluteTimeToString:lastResubscribeTime];
	return [NSString stringWithFormat:@"Observing Activity: %@\nObserving Identity: %@\nRemote Notifications Enabled: %@\nProduction: %@\nToken: %@\nLast Poll: %@\nLast Record: %@\nLast Receive: %@\nLast Resubscribe: %@\nResubscribe count:%i",
			observingActivity ? @"YES" : @"NO",
			observingIdentityChanges ? @"YES" : @"NO",
			remoteNotificationsEnabled ? @"YES" : @"NO",
			(productionMode ? @"YES" : @"NO"),
			previousChangeToken ? previousChangeToken : @"n/a",
			lastPollPoke ? lastPollPoke : @"n/a",
			lastUpdateRecordChangeTagReceived ? lastUpdateRecordChangeTagReceived : @"n/a",
			lastReceive ? lastReceive : @"n/a",
			lastResubscribe ? lastResubscribe : @"n/a",
			resubscribeCount];
}

+ (NSString *)cfAbsoluteTimeToString:(CFAbsoluteTime)value {
	if ( 0 == value )
		return nil; // In our case, we know that the uninitialized value will never be the value assigned, so return nil for that.

	CFStringRef dateString = nil;
	CFDateRef cfDate = CFDateCreate(kCFAllocatorDefault, value);
	CFDateFormatterRef dateFormatter = CFDateFormatterCreate(kCFAllocatorDefault, CFLocaleCopyCurrent(), kCFDateFormatterFullStyle, kCFDateFormatterFullStyle);
	dateString = CFDateFormatterCreateStringWithDate(kCFAllocatorDefault, dateFormatter, cfDate);
	CFRelease(dateFormatter);
	CFRelease(cfDate);

	if ( !dateString )
		return nil;

	return [NSString stringWithFormat:@"%@",dateString];
}

- (void)dealloc {
	DLog(@"Deallocating");

	[self stop];

	// Complete all queues before completing dealloc.
	dispatch_semaphore_t sema = dispatch_semaphore_create(0);
	if ( startStopQueue )
		dispatch_async(startStopQueue, ^{
			dispatch_semaphore_signal(sema);
		});
	if ( pollQueue )
		dispatch_async(pollQueue, ^{
			dispatch_semaphore_signal(sema);
		});
	if ( syncQueue )
		dispatch_async(syncQueue, ^{
			dispatch_semaphore_signal(sema);
		});
	if ( startStopQueue )
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
	if ( pollQueue )
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
	if ( syncQueue )
		dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
	dispatch_release(sema);

	// Release all queues after they are all completed.
	if ( syncQueue ) {
		dispatch_release(syncQueue);
		syncQueue = nil;
	}
	if ( pollQueue ) {
		dispatch_release(pollQueue);
		pollQueue = nil;
	}
	if ( startStopQueue ) {
		dispatch_release(startStopQueue);
		startStopQueue = nil;
	}
	if ( userActionsCountingQueue ) {
		dispatch_release(userActionsCountingQueue);
		userActionsCountingQueue = nil;
	}
	
	[completionsWhenNoPendingUserActions release];
	completionsWhenNoPendingUserActions = nil;

	[super dealloc];
	DLog(@"Deallocated");
}
@end

