//
//  NSWindow+TrueCenter.m
//  Flycut
//
//  Flycut by Gennadiy Potapov and contributors. Based on Jumpcut by Steve Cook.
//  Copyright 2011 General Arcade. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <https://github.com/TermiT/Flycut> for details.
//
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
