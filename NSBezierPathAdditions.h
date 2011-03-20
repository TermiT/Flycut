//
//  NSBezierPathAdditions.h
//  ShortcutRecorder
//
//  Copyright 2006 Contributors. All rights reserved.
//
//  License: BSD
//
//  Contributors:
//      http://www.cocoadev.com/index.pl?RoundedRectangles
//
//  Revisions:
//      2006-03-12 Created.

#import <Cocoa/Cocoa.h>

@interface NSBezierPath (Additions)
+ (NSBezierPath*)bezierPathWithRoundRectInRect:(NSRect)aRect radius:(float)radius;
@end