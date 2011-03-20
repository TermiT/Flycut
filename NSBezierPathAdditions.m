//
//  NSBezierPathAdditions.m
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

#import "NSBezierPathAdditions.h"

@implementation NSBezierPath (Additions)

+ (NSBezierPath*)bezierPathWithRoundRectInRect:(NSRect)aRect radius:(float)radius
{
	NSBezierPath* path = [self bezierPath];
	radius = MIN(radius, 0.5f * MIN(NSWidth(aRect), NSHeight(aRect)));
	NSRect rect = NSInsetRect(aRect, radius, radius);
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMinY(rect)) radius:radius startAngle:180.0 endAngle:270.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMinY(rect)) radius:radius startAngle:270.0 endAngle:360.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMaxY(rect)) radius:radius startAngle:  0.0 endAngle: 90.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMaxY(rect)) radius:radius startAngle: 90.0 endAngle:180.0];
	[path closePath];
	return path;
}

@end
