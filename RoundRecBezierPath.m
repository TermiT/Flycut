//
//  RoundRecBezierPath.m
//  Jumpcut
//
//  Created by steve on Tue Dec 16 2003.
//  Copyright (c) 2003 Steve Cook. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <http://jumpcut.sourceforge.net/> for details.

#import "RoundRecBezierPath.h"

@implementation NSBezierPath (RoundRecBezierPath)

+(NSBezierPath*)bezierPathWithRoundRectInRect:(NSRect)aRect radius:(float)radius {
// A beautiful means of doing this found on cocoadev.com.
   NSBezierPath *path = [NSBezierPath bezierPath];
   NSRect rect;
   radius = MIN(radius, 0.5f * MIN(NSWidth(aRect), NSHeight(aRect)));
   rect = NSInsetRect(aRect, radius, radius);
   [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMinY(rect)) radius:radius startAngle:180.0 endAngle:270.0];
   [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMinY(rect)) radius:radius startAngle:270.0 endAngle:360.0];
   [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMaxY(rect)) radius:radius startAngle:  0.0 endAngle: 90.0];
   [path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMaxY(rect)) radius:radius startAngle: 90.0 endAngle:180.0];
   [path closePath];

   return path;
}

@end