//
//  NSWindow+TrueCenter.m
//  Jumpcut
//
//  Created by Gennadii Potapov on 4/8/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NSWindow+TrueCenter.h"

@implementation NSWindow (TrueCenter)

- (void)trueCenter {
    NSRect frame = [self frame];
    NSRect screen = [[self screen] frame];
    frame.origin.x = (screen.size.width - frame.size. width) / 2;
    frame.origin.y = (screen.size.height - frame.size.height) / 2;
    [self setFrameOrigin:frame.origin];
}

@end
