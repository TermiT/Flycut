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
	XCTAssertEqual(0, 1, @"Please see UNIT_TEST_MEMORY_LEAKS in MJCloudKitUserDefaultsSync.m for unit test since this framework requires entitlements.");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
