//
//  NSWindow+ULIZoomEffect.m
//  Stacksmith
//
//  Created by Uli Kusterer on 05.03.11.
//  Copyright 2011 Uli Kusterer. All rights reserved.
//
//	This software is provided 'as-is', without any express or implied
//	warranty. In no event will the authors be held liable for any damages
//	arising from the use of this software.
//
//	Permission is granted to anyone to use this software for any purpose,
//	including commercial applications, and to alter it and redistribute it
//	freely, subject to the following restrictions:
//
//	   1. The origin of this software must not be misrepresented; you must not
//	   claim that you wrote the original software. If you use this software
//	   in a product, an acknowledgment in the product documentation would be
//	   appreciated but is not required.
//
//	   2. Altered source versions must be plainly marked as such, and must not be
//	   misrepresented as being the original software.
//
//	   3. This notice may not be removed or altered from any source
//	   distribution.
//

// -----------------------------------------------------------------------------
//	Headers:
// -----------------------------------------------------------------------------

#import "NSWindow+ULIZoomEffect.h"


// On 10.6 and lower, these 10.7 methods/symbols aren't declared, so we declare
//	them here and call them conditionally when available:
//	Otherwise 10.7's built-in animations get in the way of ours, which are cooler
//	because they can come from a certain rectangle and thus convey information.

#ifndef MAC_OS_X_VERSION_10_7
#define MAC_OS_X_VERSION_10_7 1070
#endif

#if MAC_OS_X_VERSION_MAX_ALLOWED < MAC_OS_X_VERSION_10_7

enum {
    NSWindowAnimationBehaviorDefault = 0,
    NSWindowAnimationBehaviorNone = 2,
    NSWindowAnimationBehaviorDocumentWindow = 3,
    NSWindowAnimationBehaviorUtilityWindow = 4,
    NSWindowAnimationBehaviorAlertPanel = 5
};

typedef NSInteger	NSWindowAnimationBehavior;

@interface NSWindow (ULITenSevenAnimationBehaviour)

-(void)							setAnimationBehavior: (NSWindowAnimationBehavior)animBehaviour;
-(NSWindowAnimationBehavior)	animationBehavior;

@end

#endif // MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_6


// -----------------------------------------------------------------------------
//	ULIQuicklyAnimatingWindow:
// -----------------------------------------------------------------------------

// Window we use for our animations on which we can adjust the animation duration easily:

@interface ULIQuicklyAnimatingWindow : NSWindow
{
	CGFloat		mAnimationResizeTime;
}

@property (assign) CGFloat		animationResizeTime;

- (NSTimeInterval)animationResizeTime:(NSRect)newFrame;

@end


@implementation ULIQuicklyAnimatingWindow

@synthesize animationResizeTime = mAnimationResizeTime;

-(id)	initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag screen:(NSScreen *)screen
{
	if(( self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag screen: screen] ))
	{
		mAnimationResizeTime = 0.2;
	}
	
	return self;
}


-(id)	initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag
{
	if(( self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag] ))
	{
		mAnimationResizeTime = 0.2;
	}
	
	return self;
}


- (NSTimeInterval)animationResizeTime:(NSRect)newFrame
{
#if 0 && DEBUG
	// Only turn this on temporarily for debugging. Otherwise it'll trigger for
	//	 menu items that include the shift key, which is *not* what you want.
	return ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) ? (mAnimationResizeTime * 10.0) : mAnimationResizeTime;
#else
	return mAnimationResizeTime;
#endif
}

@end


// -----------------------------------------------------------------------------
//	NSWindow (ULIZoomEffect)
// -----------------------------------------------------------------------------

@implementation NSWindow (ULIZoomEffect)

// Calculate a sensible default start rect for the animation, depending on what
//	screen it is. We don't want the zoom to come from another screen by accident.

-(NSRect)	uli_startRectForScreen: (NSScreen*)theScreen
{
	NSRect			screenBox = NSZeroRect;
	NSScreen	*	menuBarScreen = [[NSScreen screens] objectAtIndex: 0];
	if( theScreen == nil || menuBarScreen == theScreen )
	{
		// Use menu bar screen:
		screenBox = [menuBarScreen frame];
		
		// Take a rect in the upper left, which should be the menu bar:
		//	(Like Finder in ye olde days)
		screenBox.origin.y += screenBox.size.height -16;
		screenBox.size.height = 16;
		screenBox.size.width = 16;
	}
	else
	{
		// On all other screens, pick a box in the center:
		screenBox = [theScreen frame];
		screenBox.origin.y += truncf(screenBox.size.height /2) -8;
		screenBox.origin.x += truncf(screenBox.size.width /2) -8;
		screenBox.size.height = 16;
		screenBox.size.width = 16;
	}
	
	return screenBox;
}


// Create a "screen shot" of the given window which we use for our fake window
//	that we can animate.

-(NSImage*)	uli_imageWithSnapshotForceActive: (BOOL)doForceActive
{
	NSDisableScreenUpdates();
	BOOL	wasVisible = [self isVisible];
	
	if( doForceActive )
		[self makeKeyAndOrderFront: nil];
	else
		[self orderFront: nil];
	
    // snag the image
	CGImageRef windowImage = CGWindowListCreateImage(CGRectNull, kCGWindowListOptionIncludingWindow, [self windowNumber], kCGWindowImageBoundsIgnoreFraming);
    
	if( !wasVisible )
		[self orderOut: nil];
	NSEnableScreenUpdates();
	
    // little bit of error checking
    if(CGImageGetWidth(windowImage) <= 1)
	{
        CGImageRelease(windowImage);
        return nil;
    }
    
    // Create a bitmap rep from the window and convert to NSImage...
    NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage: windowImage];
    NSImage *image = [[NSImage alloc] initWithSize: NSMakeSize(CGImageGetWidth(windowImage),CGImageGetHeight(windowImage))];
    [image addRepresentation: bitmapRep];
    [bitmapRep release];
    CGImageRelease(windowImage);
    
    return [image autorelease];
}


// Create a borderless window that shows and contains the given image:

-(ULIQuicklyAnimatingWindow*)	uli_animationWindowForZoomEffectWithImage: (NSImage*)snapshotImage
{
	NSRect			myFrame = [self frame];
	myFrame.size = [snapshotImage size];
	ULIQuicklyAnimatingWindow	*	animationWindow = [[ULIQuicklyAnimatingWindow alloc] initWithContentRect: myFrame styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
	[animationWindow setOpaque: NO];
	
	if( [animationWindow respondsToSelector: @selector(setAnimationBehavior:)] )
		[animationWindow setAnimationBehavior: NSWindowAnimationBehaviorNone];
	
	NSImageView	*	imageView = [[NSImageView alloc] initWithFrame: NSMakeRect(0,0,myFrame.size.width,myFrame.size.height)];
	[imageView setImageScaling: NSImageScaleAxesIndependently];
	[imageView setImageFrameStyle: NSImageFrameNone];
	[imageView setImageAlignment: NSImageAlignCenter];
	[imageView setImage: snapshotImage];
	[imageView setAutoresizingMask: NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin | NSViewMaxYMargin | NSViewWidthSizable | NSViewHeightSizable];
	[[animationWindow contentView] addSubview: imageView];
	
	[imageView release];
	
	[animationWindow setHasShadow: YES];
	[animationWindow display];
	
	return animationWindow;
}


// Effect like the "Find" highlight does, to grab user's attention (e.g when
//	bringing a window to front that was already visible but might have been
//	covered by other windows.

-(void)	makeKeyAndOrderFrontWithPopEffect
{
	BOOL						haveAnimBehaviour = [NSWindow instancesRespondToSelector: @selector(animationBehavior)];
	NSWindowAnimationBehavior	oldAnimationBehaviour = haveAnimBehaviour ? [self animationBehavior] : 0;
	if( haveAnimBehaviour )
		[self setAnimationBehavior: NSWindowAnimationBehaviorNone];	// Prevent system animations from interfering.
	
	NSImage		*	snapshotImage = [self uli_imageWithSnapshotForceActive: YES];
	NSRect			myFrame = [self frame];
	NSRect			poppedFrame = NSInsetRect(myFrame, -20, -20);
	myFrame.size = snapshotImage.size;
	ULIQuicklyAnimatingWindow	*	animationWindow = [self uli_animationWindowForZoomEffectWithImage: snapshotImage];
	[animationWindow setAnimationResizeTime: 0.025];
	[animationWindow setFrame: myFrame display: YES];
	[animationWindow orderFront: nil];
	[animationWindow setFrame: poppedFrame display: YES animate: YES];
	[animationWindow setFrame: myFrame display: YES animate: YES];
	
	NSDisableScreenUpdates();
	[animationWindow close];
	
	[self makeKeyAndOrderFront: nil];
	NSEnableScreenUpdates();
    
	if( haveAnimBehaviour )
		[self setAnimationBehavior: oldAnimationBehaviour];
}


// Zoom the window out from a given rect, to indicate what it belongs to:
// If the rect is tiny, we'll use a default starting rectangle.

-(void)	makeKeyAndOrderFrontWithZoomEffectFromRect: (NSRect)globalStartPoint
{
	if( globalStartPoint.size.width < 1 || globalStartPoint.size.height < 1 )
		globalStartPoint = [self uli_startRectForScreen: [self screen]];
	
	BOOL						haveAnimBehaviour = [NSWindow instancesRespondToSelector: @selector(animationBehavior)];
	NSWindowAnimationBehavior	oldAnimationBehaviour = haveAnimBehaviour ? [self animationBehavior] : 0;
	if( haveAnimBehaviour )
		[self setAnimationBehavior: NSWindowAnimationBehaviorNone];	// Prevent system animations from interfering.
	
	NSImage		*	snapshotImage = [self uli_imageWithSnapshotForceActive: YES];
	NSRect			myFrame = [self frame];
	myFrame.size = snapshotImage.size;
	NSWindow	*	animationWindow = [self uli_animationWindowForZoomEffectWithImage: snapshotImage];
	[animationWindow setFrame: globalStartPoint display: YES];
	[animationWindow orderFront: nil];
	[animationWindow setFrame: myFrame display: YES animate: YES];
	
	NSDisableScreenUpdates();
	[animationWindow close];
	
	[self makeKeyAndOrderFront: nil];
	NSEnableScreenUpdates();
    
	if( haveAnimBehaviour )
		[self setAnimationBehavior: oldAnimationBehaviour];
}


// Same as -makeKeyAndOrderFrontWithZoomEffectFromRect: But doesn't make the window key:

-(void)	orderFrontWithZoomEffectFromRect: (NSRect)globalStartPoint
{
	if( globalStartPoint.size.width < 1 || globalStartPoint.size.height < 1 )
		globalStartPoint = [self uli_startRectForScreen: [self screen]];
	
	BOOL						haveAnimBehaviour = [NSWindow instancesRespondToSelector: @selector(animationBehavior)];
	NSWindowAnimationBehavior	oldAnimationBehaviour = haveAnimBehaviour ? [self animationBehavior] : 0;
	if( haveAnimBehaviour )
		[self setAnimationBehavior: NSWindowAnimationBehaviorNone];	// Prevent system animations from interfering.
	
    NSImage		*	snapshotImage = [self uli_imageWithSnapshotForceActive: NO];
	NSRect			myFrame = [self frame];
	myFrame.size = snapshotImage.size;
	NSWindow	*	animationWindow = [self uli_animationWindowForZoomEffectWithImage: snapshotImage];
	[animationWindow setFrame: globalStartPoint display: YES];
	[animationWindow orderFront: nil];
	[animationWindow setFrame: myFrame display: YES animate: YES];
	
	NSDisableScreenUpdates();
	[animationWindow close];
	
	[self orderFront: nil];
	NSEnableScreenUpdates();
    
	if( haveAnimBehaviour )
		[self setAnimationBehavior: oldAnimationBehaviour];
}


// The reverse of -makeKeyAndOrderFrontWithZoomEffectFromRect:

-(void)	orderOutWithZoomEffectToRect: (NSRect)globalEndPoint
{
	if( globalEndPoint.size.width < 1 || globalEndPoint.size.height < 1 )
		globalEndPoint = [self uli_startRectForScreen: [self screen]];
	
	BOOL						haveAnimBehaviour = [NSWindow instancesRespondToSelector: @selector(animationBehavior)];
	NSWindowAnimationBehavior	oldAnimationBehaviour = haveAnimBehaviour ? [self animationBehavior] : 0;
	if( haveAnimBehaviour )
		[self setAnimationBehavior: NSWindowAnimationBehaviorNone];	// Prevent system animations from interfering.
	
    NSImage		*	snapshotImage = [self uli_imageWithSnapshotForceActive: NO];
	NSRect			myFrame = [self frame];
	myFrame.size = snapshotImage.size;
	NSWindow	*	animationWindow = [self uli_animationWindowForZoomEffectWithImage: snapshotImage];
	[animationWindow setFrame: myFrame display: YES];
	
	NSDisableScreenUpdates();
	[animationWindow orderFront: nil];
	[self orderOut: nil];
	NSEnableScreenUpdates();
	
	[animationWindow setFrame: globalEndPoint display: YES animate: YES];
	
	[animationWindow close];
    
	if( haveAnimBehaviour )
		[self setAnimationBehavior: oldAnimationBehaviour];
}

@end