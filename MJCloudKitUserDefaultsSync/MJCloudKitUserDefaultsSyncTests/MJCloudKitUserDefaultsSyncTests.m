//
//  MJCloudKitUserDefaultsSyncTests.m
//  MJCloudKitUserDefaultsSyncTests
//
//  Created by Mark Jerde on 5/1/18.
//  Copyright © 2018 Mark Jerde. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MJCloudKitUserDefaultsSync.h"

@interface MJCloudKitUserDefaultsSyncTests : XCTestCase

@end

@implementation MJCloudKitUserDefaultsSyncTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSetAndRestoreValueThroughCloudKit {

	// Ensure the key is removed from defaults and verify it is gone.
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ckSyncFiveFourThree"];

	XCTAssertEqual(0, [[NSUserDefaults standardUserDefaults] integerForKey:@"ckSyncFiveFourThree"], @"Value not cleared from NSUserDefaults");

	// Create a sync, add a key to defaults, quit sync.
	{
		MJCloudKitUserDefaultsSync *ckSync = [[MJCloudKitUserDefaultsSync alloc] init];

		[ckSync startWithPrefix:@"ckSync"
		withContainerIdentifier:@"iCloud.com.MJCloudKitUserDefaultsSync.tests"];

		// Should sync within two seconds.
		[NSThread sleepForTimeInterval:2.0f];

		XCTAssertEqual(0, [[NSUserDefaults standardUserDefaults] integerForKey:@"ckSyncFiveFourThree"], @"Value not absent in CloudKit.");

		[[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)543 forKey:@"ckSyncFiveFourThree"];

		XCTAssertEqual(543, [[NSUserDefaults standardUserDefaults] integerForKey:@"ckSyncFiveFourThree"], @"Value not set in NSUserDefaults");

		[ckSync release];
		ckSync = nil;
	}

	// Remove the key from defaults and verify it is gone.
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ckSyncFiveFourThree"];

	XCTAssertEqual(0, [[NSUserDefaults standardUserDefaults] integerForKey:@"ckSyncFiveFourThree"], @"Value not cleared from NSUserDefaults");

	// Create a sync, check for key in defaults, quit sync.
	{
		MJCloudKitUserDefaultsSync *ckSync = [[MJCloudKitUserDefaultsSync alloc] init];

		[ckSync startWithPrefix:@"ckSync"
		withContainerIdentifier:@"iCloud.com.MJCloudKitUserDefaultsSync.tests"];

		// Should sync within two seconds.
		[NSThread sleepForTimeInterval:2.0f];

		XCTAssertEqual(543, [[NSUserDefaults standardUserDefaults] integerForKey:@"ckSyncFiveFourThree"], @"Value not loaded from CloudKit.");

		[ckSync release];
		ckSync = nil;
	}

	XCTAssertEqual(543, [[NSUserDefaults standardUserDefaults] integerForKey:@"ckSyncFiveFourThree"], @"Value not persisted after CloudKit.");

	[[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ckSyncFiveFourThree"];

	XCTAssertEqual(0, [[NSUserDefaults standardUserDefaults] integerForKey:@"ckSyncFiveFourThree"], @"Value not absent in CloudKit.");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
