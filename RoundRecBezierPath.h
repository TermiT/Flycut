//
//  RoundRecBezierPath.h
//  Jumpcut
//
//  Created by steve on Tue Dec 16 2003.
//  Copyright (c) 2003 Steve Cook. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <http://jumpcut.sourceforge.net/> for details.

#import <AppKit/AppKit.h>
#import <AppKit/NSBezierPath.h>

@interface NSBezierPath (RoundRecBezierPath)

+(NSBezierPath*)bezierPathWithRoundRectInRect:(NSRect)aRect radius:(float)radius;

@end
