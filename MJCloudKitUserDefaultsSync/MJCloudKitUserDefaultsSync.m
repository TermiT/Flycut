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

// Things we retain and better release.
static NSString *prefix = nil;
static NSArray *matchList = nil;
static NSTimer *pollCloudKitTimer = nil;
static NSString *databaseContainerIdentifier = nil;
static CKRecordZone *recordZone = nil;
static CKRecordZoneID *recordZoneID = nil;
static CKRecordID *recordID = nil;
static NSMutableArray *changeNotificationHandlers[] = {nil,nil,nil};
static CKServerChangeToken *previousChangeToken = nil;
static NSString *lastUpdateRecordChangeTagReceived = nil;

// Things we don't retain.
static CKDatabase *publicDB;
static CKDatabase *privateDB;

// Status flags.
static BOOL observingIdentityChanges = NO;
static BOOL observingActivity = NO;
static BOOL remoteNotificationsEnabled = YES;

// Strings we use.
static NSString *recordZoneName = @"MJCloudKitUserDefaultsSync";
static NSString *subscriptionID = @"UserDefaultSubscription";
static NSString *recordType = @"UserDefault";
static NSString *recordName = @"UserDefaults";

// Flow controls.
static BOOL refuseUpdateToICloudUntilAfterUpdateFromICloud = NO;
static BOOL oneTimeDeleteZoneFromICloud = NO; // To clear the user's sync data from iCloud for testing first-time scenario.
static dispatch_queue_t syncQueue = nil;
static dispatch_queue_t pollQueue = nil;
static dispatch_queue_t startStopQueue = nil;

@implementation MJCloudKitUserDefaultsSync

+(void) updateToiCloud:(NSNotification*) notificationObject {
	dispatch_async(syncQueue, ^{
		DLog(@"Update to iCloud?");
		if ( refuseUpdateToICloudUntilAfterUpdateFromICloud )
		{
			DLog(@"NO.  Waiting until after update from iCloud");
		}
		else
		{
			if ( nil == privateDB )
			{
				DLog(@"Database has been unset.  Not updating to iCloud");
				return;
			}
			DLog(@"YES.  Updating to iCloud");
			dispatch_suspend(syncQueue);
			[privateDB fetchRecordWithID:recordID completionHandler:^(CKRecord *record, NSError *error) {
				if (error
					&& !( nil != [error.userInfo objectForKey:@"ServerErrorDescription" ]
						 && [(NSString*)[error.userInfo objectForKey:@"ServerErrorDescription" ] isEqualToString:@"Record not found"	] ) ) {
						// Error handling for failed fetch from public database
						DLog(@"CloudKit Fetch failure: %@", error.localizedDescription);
						dispatch_resume(syncQueue);
					}
				else if ( ![[record recordChangeTag] isEqualToString:lastUpdateRecordChangeTagReceived] ) {
					// We won't push our content if there is something we haven't received yet.

					// Pull from iCloud now, pushing afterward.
					[self updateFromiCloud:nil];
					[self updateToiCloud:nil];
					dispatch_resume(syncQueue);
				}
				else {
					DLog(@"Updating to iCloud completion");
					// Modify the record and save it to the database

					BOOL needToReleaseRecord = NO;
					if (error
						&& nil != [error.userInfo objectForKey:@"ServerErrorDescription" ]
						&& [(NSString*)[error.userInfo objectForKey:@"ServerErrorDescription" ] isEqualToString:@"Record not found"	] )
					{
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

							if ( nil != obj )
							{
								obj = [self serialize:obj forKey:key];
								if ( nil == obj )
									skip = YES;
							}

							if ( skip )
							{
							}
							else if ( nil == [record objectForKey: key] )
							{
								DLog(@"Adding %@.", key);
								additions++;
							}
							else if ( ( [obj isKindOfClass:[NSNumber class]] && [(NSNumber*)record[key] intValue] != [(NSNumber*)obj intValue] )
									 || ( [obj isKindOfClass:[NSString class]] && ![(NSString*)obj isEqualToString:(NSString*)record[key]] )
									 || ( [obj isKindOfClass:[NSData class]] && ![(NSData*)obj isEqualToData:(NSData*)record[key]] ) )
							{
								DLog(@"Changing %@.", key);
								modifications++;
							}
							else
							{
								DLog(@"Skipping %@.", key);
								skip = YES;
							}

							if ( !skip )
							{
								if ( !changes )
									changes = [[NSMutableDictionary alloc] init];

								NSMutableArray *fromToTheirs = [[NSMutableArray alloc] init];
								[fromToTheirs addObject:record[key]];
								[fromToTheirs addObject:obj];
								[changes setObject:fromToTheirs forKey:key];

								record[key] = obj;
							}
						}
					}];
					DLog(@"To iCloud: Adding %i keys.  Modifying %i keys.", additions, modifications);

					if ( additions + modifications > 0 )
					{
						[privateDB saveRecord:record completionHandler:^(CKRecord *savedRecord, NSError *saveError) {
							DLog(@"Saving to iCloud.");
							if ( saveError )
							{
								// Error handling for failed save to public database
								DLog(@"CloudKit Save failure: %@", saveError.localizedDescription);

								[privateDB fetchRecordWithID:recordID completionHandler:^(CKRecord *newRecord, NSError *error) {
									if (error) {
										// Error handling for failed fetch from public database
										DLog(@"CloudKit Fetch failure: %@", error.localizedDescription);
										[self completeUpdateToiCloudWithChanges:changes];
									}
									else {
										DLog(@"Updating to iCloud completion");

										[changes enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
											// Add the new remote value and ensure the to, from, and theirs values are all deserialized if necessary.

											NSObject *originalObj = [[NSUserDefaults standardUserDefaults] objectForKey: key];
											id fromObj = [obj firstObject];
											if ( nil != fromObj )
											{
												fromObj = [self deserialize:fromObj forKey:key similarTo:originalObj];
												if ( nil == fromObj )
												{
													// Failed to deserialize.  Put our value in.
													fromObj = originalObj;
												}
											}
											id remoteObj = [newRecord objectForKey:key];
											if ( nil != remoteObj )
											{
												remoteObj = [self deserialize:remoteObj forKey:key similarTo:originalObj];
												if ( nil == remoteObj )
												{
													// Failed to deserialize.  Put our value in.
													remoteObj = [obj lastObject];
												}
											}

											obj[0] = fromObj;
											obj[1] = originalObj;
											[obj addObject:remoteObj];
										}];

										NSDictionary *corrections = [self sendNotificationsFor:MJSyncNotificationConflicts onKeys:changes];

										if ( corrections && [corrections count] )
										{
											[corrections enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
												Boolean skip = NO;
												if ( nil != obj )
												{
													obj = [self serialize:obj forKey:key];
													if ( nil == obj )
														skip = YES;
												}

												if ( !skip )
													newRecord[key] = obj;
											}];
											[corrections release];

											[privateDB saveRecord:newRecord completionHandler:^(CKRecord *savedRecord, NSError *saveError) {
												DLog(@"Saving to iCloud.");
												if ( saveError )
												{
													// If we had a conflict on the conflict resolution, just give up for now.
													DLog(@"CloudKit conflict-resolution Save failure: %@", saveError.localizedDescription);
												}

												[self completeUpdateToiCloudWithChanges:changes];
											}];
										}
										else
											[self completeUpdateToiCloudWithChanges:changes];
									}
								}];
							}
							else
							{
								[self sendNotificationsFor:MJSyncNotificationSaveSuccess onKeys:changes];
								[self completeUpdateToiCloudWithChanges:changes];
							}
						}];
					}
					else
						[self completeUpdateToiCloudWithChanges:changes];

					// If the record wasn't found, so we had to create it, then we own it and better release it.
					if ( needToReleaseRecord )
						[record release];
				}
			}];
		}
	});
}

+(void) completeUpdateToiCloudWithChanges:(NSMutableDictionary*) changes
{
	// Resume before releasing memory, since there's nothing shared about the memory.
	dispatch_resume(syncQueue);

	if ( changes )
	{
		[changes enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
			[obj release];
		}];
		[changes release];
	}
}

+(id) serialize:(id)obj forKey:(NSString*)key
{
	// Only serialize types that need to be.
	if ( [obj isKindOfClass:[NSDictionary class]] )
	{
		NSError *error;
		NSData *data = [NSPropertyListSerialization dataWithPropertyList:obj format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
		if ( data )
			obj = data;
		else
		{
			DLog( @"Error serializing %@ to binary: %@", key, error );
			obj = nil;
		}
	}
	return obj;
}

+(id) deserialize:(id)remoteObj forKey:(NSString*)key similarTo:(id)originalObj
{
	if ( [remoteObj isKindOfClass:[NSData class]]
		&& !(originalObj && [originalObj isKindOfClass:[NSData class]]) )
	{
		NSError *error;
		id deserialized = [NSPropertyListSerialization propertyListWithData:(NSData*)remoteObj options:NSPropertyListImmutable format:nil error:&error];
		if ( deserialized )
			remoteObj = deserialized;
		else if ( originalObj )
		{
			DLog( @"Error deserializing %@ from binary: %@", key, error );
			remoteObj = nil;
		}
		else
		{
			// Keep input remoteObj the same and return as output.
			DLog( @"Error deserializing %@ from binary, but we didn't have a local copy so we assume it wasn't supposed to be deserialized.  We assume this is okay in order to handle storing NSData that doesn't represent a serialized property list. %@", key, error );
		}
	}
	return remoteObj;
}

+(void) updateFromiCloud:(NSNotification*) notificationObject {
	dispatch_async(syncQueue, ^{
		if ( nil == privateDB )
		{
			DLog(@"Database has been unset.  Not updating from iCloud");
			return;
		}
		DLog(@"Updating from iCloud");
		dispatch_suspend(syncQueue);
		[privateDB fetchRecordWithID:recordID completionHandler:^(CKRecord *record, NSError *error) {
			if (error) {
				// Error handling for failed fetch from public database
				DLog(@"CloudKit Fetch failure: %@", error.localizedDescription);
			}
			else {
				DLog(@"Updating from iCloud completion");

				// prevent NSUserDefaultsDidChangeNotification from being posted while we update from iCloud
				[[NSNotificationCenter defaultCenter] removeObserver:self
																name:NSUserDefaultsDidChangeNotification
															  object:nil];

				lastUpdateRecordChangeTagReceived = [[record recordChangeTag] retain];
				DLog(@"Got record -%@-_-%@-_-%@-_-%@-",[[[record recordID] zoneID] zoneName],[[[record recordID] zoneID] ownerName],[[record recordID] recordName],[record recordChangeTag]);

				__block int additions = 0, modifications = 0;
				__block NSMutableDictionary *changes = nil;
				[[record allKeys] enumerateObjectsUsingBlock:^(id key, NSUInteger idx, BOOL *stop) {
					if ( ( nil != prefix && [key hasPrefix:prefix] )
						|| ( nil != matchList && [matchList containsObject:key] ) ) {

						BOOL skip = NO;
						NSObject *obj = [[NSUserDefaults standardUserDefaults] objectForKey: key];
						NSObject *originalObj = obj;

						if ( nil != obj )
						{
							obj = [self serialize:obj forKey:key];
							if ( nil == obj )
								skip = YES;
						}

						if ( skip )
						{
						}
						else if ( nil == obj )
						{
							DLog(@"Adding %@.", key);
							additions++;
						}
						else if ( ( [obj isKindOfClass:[NSNumber class]] && [(NSNumber*)record[key] intValue] != [(NSNumber*)obj intValue] )
								 || ( [obj isKindOfClass:[NSString class]] && ![(NSString*)obj isEqualToString:(NSString*)record[key]] )
								 || ( [obj isKindOfClass:[NSData class]] && ![(NSData*)obj isEqualToData:(NSData*)record[key]] ) )
						{
							DLog(@"Changing %@.", key);
							modifications++;
						}
						else
						{
							DLog(@"Skipping %@.", key);
							skip = YES;
						}
						if ( !skip )
						{
							id remoteObj = [record objectForKey:key];

							if ( nil != remoteObj )
							{
								remoteObj = [self deserialize:remoteObj forKey:key similarTo:originalObj];
								if ( nil == remoteObj )
									skip = YES;
							}

							if ( !skip )
							{
								[[NSUserDefaults standardUserDefaults] setObject:remoteObj forKey:key];
								if ( !changes )
									changes = [[NSMutableDictionary alloc] init];
								[changes setObject:key forKey:key];
							}
						}
					}
				}];
				DLog(@"From iCloud: Adding %i keys.  Modifying %i keys.", additions, modifications);

				if ( additions + modifications > 0 )
				{
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
		}];
	});
}

+(void) setRemoteNotificationsEnabled:(bool) enabled
{
	if ( enabled != remoteNotificationsEnabled )
	{
		bool resume = observingActivity;
		if ( observingActivity )
			[self pause];
		remoteNotificationsEnabled = enabled;
		if ( resume )
			[self resume];
	}
}

+(void) startWithPrefix:(NSString*) prefixToSync withContainerIdentifier:(NSString*) containerIdentifier {
	DLog(@"Starting with prefix");

	if ( !startStopQueue )
	{
		startStopQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.startStopQueue", DISPATCH_QUEUE_SERIAL);
		[startStopQueue retain];
	}

	// If we are already running and add criteria while updating to iCloud, we could push to iCloud before pulling the existing value from iCloud.  Avoid this by dispatching into another thread that will wait pause existing activity and wait for it to stop before adding new criteria.
	dispatch_async(startStopQueue, ^{
		DLog(@"Actually starting with prefix");
		[self commonStartInitialStepsOnContainerIdentifier:containerIdentifier];

		if ( prefix )
			[prefix release];
		prefix = prefixToSync;
		[prefix retain];

		[self attemptToEnable];
	});
}

+(void) startWithKeyMatchList:(NSArray*) keyMatchList withContainerIdentifier:(NSString*) containerIdentifier {
	DLog(@"Starting with match list length %lu atop %lu", (unsigned long)[keyMatchList count], (unsigned long)[matchList count]);

	if ( !startStopQueue )
	{
		startStopQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.startStopQueue", DISPATCH_QUEUE_SERIAL);
		[startStopQueue retain];
	}

	// If we are already running and add criteria while updating to iCloud, we could push to iCloud before pulling the existing value from iCloud.  Avoid this by dispatching into another thread that will wait pause existing activity and wait for it to stop before adding new criteria.
	dispatch_async(startStopQueue, ^{
		DLog(@"Actually starting with match list length %lu atop %lu", (unsigned long)[keyMatchList count], (unsigned long)[matchList count]);
		[self commonStartInitialStepsOnContainerIdentifier:containerIdentifier];

		if ( !matchList )
			matchList = [[NSArray alloc] init];
		NSArray *toRelease = matchList;

		// Add to existing array.
		matchList = [matchList arrayByAddingObjectsFromArray:keyMatchList];
		// Remove duplicates.
		matchList = [[NSSet setWithArray:matchList] allObjects];

		[matchList retain];
		[toRelease release];

		DLog(@"Match list length is now %lu", (unsigned long)[matchList count]);

		[self attemptToEnable];
	});
}

+(void) commonStartInitialStepsOnContainerIdentifier:(NSString*) containerIdentifier {
	[self pause];

	DLog(@"Waiting for sync queue to clear before adding new criteria.");
	if ( !syncQueue )
	{
		syncQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.queue", DISPATCH_QUEUE_SERIAL);
		[syncQueue retain];
	}
	dispatch_sync(syncQueue, ^{
		refuseUpdateToICloudUntilAfterUpdateFromICloud = YES;
		DLog(@"Waited for sync queue to clear before adding new criteria.");
	});

	if ( databaseContainerIdentifier )
		[databaseContainerIdentifier release];
	databaseContainerIdentifier = containerIdentifier;
	[databaseContainerIdentifier retain];
}

+(void) pause {
	if ( !startStopQueue )
	{
		startStopQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.startStopQueue", DISPATCH_QUEUE_SERIAL);
		[startStopQueue retain];
	}

	// pause can be called while already on the desired GDC queue.  We can detect this and only dispatch to the queue if not already on it.  This is needed because we pause the queue to wait for completion on a different asynchronous activity.
	if ( strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(startStopQueue)) )
	{
		dispatch_async(startStopQueue, ^{
			[self pause];
		});
	}
	else
	{
		[self stopObservingActivity];
		[self stopObservingIdentityChanges];
	}
}

+(void) resume {
	if ( !startStopQueue )
	{
		startStopQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.startStopQueue", DISPATCH_QUEUE_SERIAL);
		[startStopQueue retain];
	}
	dispatch_async(startStopQueue, ^{
		[self attemptToEnable];
	});
}

+(void) stopForKeyMatchList:(NSArray*) keyMatchList {
	DLog(@"Stopping match list length %lu from %lu", (unsigned long)[keyMatchList count], (unsigned long)[matchList count]);

	if ( !startStopQueue )
	{
		startStopQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.startStopQueue", DISPATCH_QUEUE_SERIAL);
		[startStopQueue retain];
	}

	dispatch_async(startStopQueue, ^{
		if ( !matchList )
			return;

		NSArray *toRelease = matchList;

		NSMutableArray *mutableList = [[NSMutableArray alloc] initWithArray:matchList];
		[mutableList removeObjectsInArray:keyMatchList];
		matchList = mutableList;

		[toRelease release];

		DLog(@"Match list length is now %lu", (unsigned long)[matchList count]);

		if ( 0 == matchList.count )
			[self stop];
	});
}

+(void) stop {
	DLog(@"Stopping.");

	if ( !startStopQueue )
	{
		startStopQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.startStopQueue", DISPATCH_QUEUE_SERIAL);
		[startStopQueue retain];
	}

	dispatch_async(startStopQueue, ^{
		[self stopObservingActivity];
		[self stopObservingIdentityChanges];
		if ( matchList )
		{
			[matchList release];
			matchList = nil;
		}
		if ( prefix )
		{
			[prefix release];
			prefix = nil;
		}
		if ( databaseContainerIdentifier )
		{
			[databaseContainerIdentifier release];
			databaseContainerIdentifier = nil;
		}
		for ( int type = MJSyncNotificationTypeFirst(); type <= MJSyncNotificationTypeLast(); type++ )
		{
			if ( changeNotificationHandlers[type] )
			{
				[changeNotificationHandlers[type] release];
				changeNotificationHandlers[type] = nil;
			}
		}
		DLog(@"Stopped.");
	});
}

+(void) addNotificationFor:(MJSyncNotificationType)type withSelector:(SEL)aSelector withTarget:(nullable id)aTarget {
	DLog(@"Registering change notification selector.");
	if ( !changeNotificationHandlers[type] )
		changeNotificationHandlers[type] = [[NSMutableArray alloc] init];
	[changeNotificationHandlers[type] addObject:aTarget];
	[changeNotificationHandlers[type] addObject:[NSValue valueWithPointer:aSelector]];
}

+(void) removeNotificationsFor:(MJSyncNotificationType)type forTarget:(nullable id) aTarget {
	DLog(@"Removing change notification selector(s).");
	while ( changeNotificationHandlers[type] )
	{
		NSUInteger index = [changeNotificationHandlers[type] indexOfObjectIdenticalTo:aTarget];
		if ( NSNotFound == index )
			return;
		DLog(@"Removing a change notification selector.");
		[changeNotificationHandlers[type] removeObjectAtIndex:index]; // Target
		[changeNotificationHandlers[type] removeObjectAtIndex:index]; // Selector
	}
}

+(NSDictionary*) sendNotificationsFor:(MJSyncNotificationType)type onKeys:(NSDictionary*) changes {
	DLog(@"Sending change notification selector(s).");
	__block NSMutableDictionary *corrections = nil;
	if (changeNotificationHandlers[type])
	{
		for ( int i = 0 ; i < [changeNotificationHandlers[type] count] ; i+=2 )
		{
			DLog(@"Sending a change notification selector.");
			NSDictionary *currentCorrections = [changeNotificationHandlers[type][i] performSelector:[changeNotificationHandlers[type][i+1] pointerValue] withObject:changes];
			if ( currentCorrections )
			{
				[currentCorrections enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
					if ( !corrections )
						corrections = [[NSMutableDictionary alloc] init];
					[corrections setObject:obj forKey:key];
				}];
				[currentCorrections release];
			}
		}
	}
	return corrections;
}

+(void) identityDidChange:(NSNotification*) notificationObject {
	DLog(@"iCloud Identity Change Detected");
	dispatch_async(startStopQueue, ^{
		[self attemptToEnable];
	});
}

+(void) checkCloudKitUpdates {
	DLog(@"Got checkCloudKitUpdates");
	[self updateFromiCloud:nil];
}

+(void) attemptToEnable {
	dispatch_suspend(startStopQueue);
	DLog(@"Attempting to enable");
	[[CKContainer defaultContainer] accountStatusWithCompletionHandler: ^(CKAccountStatus accountStatus, NSError *error) {
		switch ( accountStatus ) {
			case CKAccountStatusAvailable:  // is iCloud enabled
				DLog(@"iCloud Available");
				[self startObservingActivity];
				break;

			case CKAccountStatusNoAccount:
				DLog(@"No iCloud account");
				[self stopObservingActivity];
				dispatch_resume(startStopQueue);
				break;

			case CKAccountStatusRestricted:
				DLog(@"iCloud restricted");
				[self stopObservingActivity];
				dispatch_resume(startStopQueue);
				break;

			case CKAccountStatusCouldNotDetermine:
				DLog(@"Unable to determine iCloud status");
				[self stopObservingActivity];
				dispatch_resume(startStopQueue);
				break;
		}

		[self startObservingIdentityChanges];
	}];
}

+(void) startObservingActivity {
	DLog(@"Should start observing activity?");
	if ( !observingActivity )
	{
		DLog(@"YES.  Start observing activity.");
		observingActivity = YES;

		// Setup database connections.
		CKContainer *container = [CKContainer containerWithIdentifier:databaseContainerIdentifier];
		publicDB = [container publicCloudDatabase];
		privateDB = [container privateCloudDatabase];

		// Create a zone if needed.
		if ( recordZoneID )
			[recordZoneID release];
		recordZoneID = [[CKRecordZoneID alloc] initWithZoneName:recordZoneName ownerName:CKOwnerDefaultName];
		if ( recordID )
			[recordID release];
		recordID = [[CKRecordID alloc] initWithRecordName:recordName zoneID:recordZoneID];
		if ( recordZone )
			[recordZone release];
		recordZone = [[CKRecordZone alloc] initWithZoneID:recordZoneID];
		DLog(@"Created CKRecordZone.zoneID %@:%@", recordZone.zoneID.zoneName, recordZone.zoneID.ownerName);

		if ( oneTimeDeleteZoneFromICloud )
		{
			observingActivity = NO;
			oneTimeDeleteZoneFromICloud = NO;
			DLog(@"Deleting CKRecordZone one time.");
			CKModifyRecordZonesOperation *deleteOperation = [[CKModifyRecordZonesOperation alloc] initWithRecordZonesToSave:@[] recordZoneIDsToDelete:@[recordZoneID]];
			deleteOperation.modifyRecordZonesCompletionBlock = ^(NSArray *savedRecordZones, NSArray *deletedRecordZoneIDs, NSError *error) {
				if ( nil != error )
				{
					DLog(@"CloudKit Delete Record Zones failure: %@", error.localizedDescription);
				}
				else
				{
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
			if ( nil != error )
			{
				DLog(@"CloudKit Modify Record Zones failure: %@", error.localizedDescription);
				[self stopObservingActivity];
				dispatch_resume(startStopQueue);
			}
			else
			{
				DLog(@"Recorded CKRecordZone.zoneID %@:%@", ((CKRecordZone*)savedRecordZones[0]).zoneID.zoneName, ((CKRecordZone*)savedRecordZones[0]).zoneID.ownerName);
				// Find out when things change
				[self subscribeToDatabase];

				// Pull from iCloud now, pushing afterward.
				// If we push first, we overwrite the sync.
				// If we don't push after the pull, we won't push until something changes.
				[self updateFromiCloud:nil];
				[self updateToiCloud:nil];
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

+(void) subscribeToDatabase {
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

	if ( nil == subscription )
	{
		// CKQuerySubscription was added after the core CloudKit APIs, so on OS versions that don't support it we will poll instead as there appears to be no alternative subscription API.
		DLog(@"Using polling instead.");

		if ( !pollQueue )
		{
			pollQueue = dispatch_queue_create("com.MJCloudKitUserDefaultsSync.poll", DISPATCH_QUEUE_SERIAL);
			[pollQueue retain];
		}

		// Timers attach to the run loop of the process, which isn't present on all processes, so we must dispatch to the main queue to ensure we have a run loop for the timer.
		dispatch_async(dispatch_get_main_queue(), ^{
			NSDate *oneSecondFromNow = [NSDate dateWithTimeIntervalSinceNow:1.0];
			alreadyPolling = NO;
			pollCloudKitTimer = [[NSTimer alloc] initWithFireDate:oneSecondFromNow
												   interval:(1.0)
													 target:self
												   selector:@selector(pollCloudKit:)
												   userInfo:nil
													repeats:YES];
			// Assign it to NSRunLoopCommonModes so that it will still poll while the menu is open.  Using a simple NSTimer scheduledTimerWithTimeInterval: would result in polling that stops while the menu is active.  In the past this was okay but with Universal Clipboard a new clipping an arrive while the user has the menu open.
			[[NSRunLoop currentRunLoop] addTimer:pollCloudKitTimer forMode:NSRunLoopCommonModes];
			dispatch_resume(startStopQueue);
		});
	}
	else
	{
		CKNotificationInfo *notification = [[CKNotificationInfo alloc] init];
		notification.shouldSendContentAvailable = YES;
		subscription.notificationInfo = notification;

		DLog(@"Fetching existing subscription.");
		[privateDB fetchSubscriptionWithID:subscription.subscriptionID completionHandler:^(CKSubscription * _Nullable existingSubscription, NSError * _Nullable error) {
			DLog(@"Fetched existing subscription.");
			if ( nil == existingSubscription )
			{
				DLog(@"No existing subscription. Saving ours.");
				// In the not-yet-subscribed-but-everything-working case, error will contain k/v @"ServerErrorDescription" : @"subscription not found"
				[privateDB saveSubscription:subscription completionHandler:^(CKSubscription * _Nullable subscription, NSError * _Nullable error) {
					DLog(@"Saved subscription.");
					if ( nil != error )
					{
						DLog(@"CloudKit Subscription failure: %@", error.localizedDescription);
						[self stopObservingActivity];
					}
					dispatch_resume(startStopQueue);
				}];
			}
			else
				dispatch_resume(startStopQueue);
			[subscription release];
		}];
	}
}

+(void) stopObservingActivity {
	DLog(@"Should stop observing activity?");
	if ( observingActivity )
	{
		DLog(@"YES.  Stop observing activity.");
		// Switch to the syncQueue so we don't cut them off if active.
		dispatch_sync(syncQueue, ^{
			DLog(@"Stopping observing activity.");
			observingActivity = NO;

			if ( pollCloudKitTimer )
			{
				[pollCloudKitTimer invalidate];
				pollCloudKitTimer = nil;
			}

			if ( previousChangeToken )
			{
				[previousChangeToken release];
				previousChangeToken = nil;
			}

			[privateDB deleteSubscriptionWithID:subscriptionID completionHandler:^(NSString * _Nullable subscriptionID, NSError * _Nullable error) {
				DLog(@"Stopped observing activity.");
				// We check for an existing subscription before saving a new subscription so the result here doesn't matter."
			}];

			if ( recordZone )
			{
				[recordZone release];
				recordZone = nil;
			}
			if ( recordZoneID )
			{
				[recordZoneID release];
				recordZoneID = nil;
			}
			if ( recordID )
			{
				[recordID release];
				recordID = nil;
			}

			// Clear database connections.
			publicDB = privateDB = nil;

			[[NSNotificationCenter defaultCenter] removeObserver:self
															name:NSUserDefaultsDidChangeNotification
														  object:nil];
		});
	}
}

+(void) startObservingIdentityChanges {
	DLog(@"Should start observing identity changes?");
	if ( !observingIdentityChanges )
	{
		DLog(@"YES.  Start observing identity changes.");
		observingIdentityChanges = YES;
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(identityDidChange:)
													 name:NSUbiquityIdentityDidChangeNotification
												   object:nil];
	}
}

+(void) stopObservingIdentityChanges {
	DLog(@"Should stop observing identity changes?");
	if ( observingIdentityChanges )
	{
		DLog(@"YES.  Stop observing identity changes.");
		observingIdentityChanges = NO;
		[[NSNotificationCenter defaultCenter] removeObserver:self
												  name:NSUbiquityIdentityDidChangeNotification
													  object:nil];
	}
}

static bool alreadyPolling = NO;
static CFAbsoluteTime lastPollPokeTime;
+(void)pollCloudKit:(NSTimer *)timer {
	// The fetchRecordChangesCompletionBlock below doesn't get called until after the recordChangedBlock below completes.  The former block provides the change token which the poll uses to identify if changes have happened.  Prevent use of the old change token while processing changes, which would of course detect changes and cause excess evaluation, by setting / checking a flag in a serial queue until the completion block which occurs on a different queue causes it to be cleared in the original serial queue.
	// This is preferable to using a dispatch_suspend / dispatch_resume because it prevents amassing a long queue of serial GCD operations in the event that the CloudKit CKFetchRecordChangesOperation takes more than the polling interval.

	dispatch_async(pollQueue, ^{
		if ( !alreadyPolling )
		{
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
				if ( nil == operationError )
				{
					DLog(@"Polling completion GOOD");
					if ( previousChangeToken )
						[previousChangeToken release];
					previousChangeToken = serverChangeToken;
					[previousChangeToken retain];
					if(clientChangeTokenData)
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
		else if ( CFAbsoluteTimeGetCurrent() - lastPollPokeTime > 600 )
		{
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

+ (void) dealloc {
	DLog(@"Deallocating");
	[self stop];
	DLog(@"Deallocated");
}
@end
