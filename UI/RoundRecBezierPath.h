//
//  RoundRecBezierPath.h
//  Flycut
//
//  Flycut by Gennadiy Potapov and contributors. Based on Jumpcut by Steve Cook.
//  Copyright 2011 General Arcade. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <https://github.com/TermiT/Flycut> for details.
//

#import <AppKit/AppKit.h>
#import <AppKit/NSBezierPath.h>

@interface NSBezierPath (RoundRecBezierPath)

+(NSBezierPath*)bezierPathWithRoundRectInRect:(NSRect)aRect radius:(float)radius;

@end
