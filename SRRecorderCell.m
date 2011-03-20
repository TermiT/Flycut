//
//  SRRecorderCell.m
//  ShortcutRecorder
//
//  Copyright 2006-2007 Contributors. All rights reserved.
//
//  License: BSD
//
//  Contributors:
//      David Dauer
//      Jesper
//      Jamie Kirkpatrick

#import "SRRecorderCell.h"
#import "SRRecorderControl.h"
#import "CTGradient.h"
#import "SRKeyCodeTransformer.h"
#import "SRValidator.h"

@interface SRRecorderCell (Private)
- (void)_privateInit;
- (void)_createGradient;
- (void)_setJustChanged;
- (void)_startRecordingTransition;
- (void)_endRecordingTransition;
- (void)_transitionTick;
- (void)_startRecording;
- (void)_endRecording;

- (BOOL)_effectiveIsAnimating;
- (BOOL)_supportsAnimation;

- (NSString *)_defaultsKeyForAutosaveName:(NSString *)name;
- (void)_saveKeyCombo;
- (void)_loadKeyCombo;

- (NSRect)_removeButtonRectForFrame:(NSRect)cellFrame;
- (NSRect)_snapbackRectForFrame:(NSRect)cellFrame;

- (unsigned int)_filteredCocoaFlags:(unsigned int)flags;
- (unsigned int)_filteredCocoaToCarbonFlags:(unsigned int)cocoaFlags;
- (BOOL)_validModifierFlags:(unsigned int)flags;

- (BOOL)_isEmpty;
@end

#pragma mark -

@implementation SRRecorderCell

- (id)init
{
    self = [super init];
	
	[self _privateInit];
	
    return self;
}

- (void)dealloc
{
    [validator release];
	
	[keyCharsIgnoringModifiers release];
	[keyChars release];
    
	[recordingGradient release];
	[autosaveName release];
	
	[cancelCharacterSet release];
	
	[super dealloc];
}

#pragma mark *** Coding Support ***

- (id)initWithCoder:(NSCoder *)aDecoder
{
	self = [super initWithCoder: aDecoder];
	
	[self _privateInit];

	if ([aDecoder allowsKeyedCoding]) {
		autosaveName = [[aDecoder decodeObjectForKey: @"autosaveName"] retain];
		
		keyCombo.code = [[aDecoder decodeObjectForKey: @"keyComboCode"] shortValue];
		keyCombo.flags = [[aDecoder decodeObjectForKey: @"keyComboFlags"] unsignedIntValue];
		
		if ([aDecoder containsValueForKey:@"keyChars"]) {
			hasKeyChars = YES;
			keyChars = (NSString *)[aDecoder decodeObjectForKey: @"keyChars"];
			keyCharsIgnoringModifiers = (NSString *)[aDecoder decodeObjectForKey: @"keyCharsIgnoringModifiers"];
		}

		allowedFlags = [[aDecoder decodeObjectForKey: @"allowedFlags"] unsignedIntValue];
		requiredFlags = [[aDecoder decodeObjectForKey: @"requiredFlags"] unsignedIntValue];
		
		allowsKeyOnly = [[aDecoder decodeObjectForKey:@"allowsKeyOnly"] boolValue];
		escapeKeysRecord = [[aDecoder decodeObjectForKey:@"escapeKeysRecord"] boolValue];
		isAnimating = [[aDecoder decodeObjectForKey:@"isAnimating"] boolValue];
		
		style = [[aDecoder decodeObjectForKey:@"style"] shortValue];
	} else {
		autosaveName = [[aDecoder decodeObject] retain];
		
		keyCombo.code = [[aDecoder decodeObject] shortValue];
		keyCombo.flags = [[aDecoder decodeObject] unsignedIntValue];
		
		allowedFlags = [[aDecoder decodeObject] unsignedIntValue];
		requiredFlags = [[aDecoder decodeObject] unsignedIntValue];
	}
	
	allowedFlags |= NSFunctionKeyMask;

	[self _loadKeyCombo];

	return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[super encodeWithCoder: aCoder];
	
	if ([aCoder allowsKeyedCoding]) {
		[aCoder encodeObject:[self autosaveName] forKey:@"autosaveName"];
		[aCoder encodeObject:[NSNumber numberWithShort: keyCombo.code] forKey:@"keyComboCode"];
		[aCoder encodeObject:[NSNumber numberWithUnsignedInt: keyCombo.flags] forKey:@"keyComboFlags"];
	
		[aCoder encodeObject:[NSNumber numberWithUnsignedInt: allowedFlags] forKey:@"allowedFlags"];
		[aCoder encodeObject:[NSNumber numberWithUnsignedInt: requiredFlags] forKey:@"requiredFlags"];
		
		if (hasKeyChars) {
			[aCoder encodeObject:keyChars forKey:@"keyChars"];
			[aCoder encodeObject:keyCharsIgnoringModifiers forKey:@"keyCharsIgnoringModifiers"];
		}
		
		[aCoder encodeObject:[NSNumber numberWithBool: allowsKeyOnly] forKey:@"allowsKeyOnly"];
		[aCoder encodeObject:[NSNumber numberWithBool: escapeKeysRecord] forKey:@"escapeKeysRecord"];
		
		[aCoder encodeObject:[NSNumber numberWithBool: isAnimating] forKey:@"isAnimating"];
		[aCoder encodeObject:[NSNumber numberWithShort:style] forKey:@"style"];
	} else {
		// Unkeyed archiving and encoding is deprecated and unsupported. Use keyed archiving and encoding.
		[aCoder encodeObject: [self autosaveName]];
		[aCoder encodeObject: [NSNumber numberWithShort: keyCombo.code]];
		[aCoder encodeObject: [NSNumber numberWithUnsignedInt: keyCombo.flags]];
		
		[aCoder encodeObject: [NSNumber numberWithUnsignedInt: allowedFlags]];
		[aCoder encodeObject: [NSNumber numberWithUnsignedInt: requiredFlags]];
	}
}

- (id)copyWithZone:(NSZone *)zone
{
    SRRecorderCell *cell;
    cell = (SRRecorderCell *)[super copyWithZone: zone];
	
	cell->recordingGradient = [recordingGradient retain];
	cell->autosaveName = [autosaveName retain];

	cell->isRecording = isRecording;
	cell->mouseInsideTrackingArea = mouseInsideTrackingArea;
	cell->mouseDown = mouseDown;

	cell->removeTrackingRectTag = removeTrackingRectTag;
	cell->snapbackTrackingRectTag = snapbackTrackingRectTag;

	cell->keyCombo = keyCombo;

	cell->allowedFlags = allowedFlags;
	cell->requiredFlags = requiredFlags;
	cell->recordingFlags = recordingFlags;
	
	cell->allowsKeyOnly = allowsKeyOnly;
	cell->escapeKeysRecord = escapeKeysRecord;
	
	cell->isAnimating = isAnimating;
	
	cell->style = style;

	cell->cancelCharacterSet = [cancelCharacterSet retain];
    
	cell->delegate = delegate;
	
    return cell;
}

#pragma mark *** Drawing ***

+ (BOOL)styleSupportsAnimation:(SRRecorderStyle)style {
	return (style == SRGreyStyle);
}

- (BOOL)animates {
	return isAnimating;
}

- (void)setAnimates:(BOOL)an {
	isAnimating = an;
}

- (SRRecorderStyle)style {
	return style;
}

- (void)setStyle:(SRRecorderStyle)nStyle {
	switch (nStyle) {
		case SRGreyStyle:
			style = SRGreyStyle;
			break;
		case SRGradientBorderStyle:
		default:
			style = SRGradientBorderStyle;
			break;
	}
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	if (style == SRGradientBorderStyle) {
		
		NSRect whiteRect = cellFrame;
		NSBezierPath *roundedRect;
		
	// Draw gradient when in recording mode
		if (isRecording)
		{
			roundedRect = [NSBezierPath bezierPathWithSRCRoundRectInRect:cellFrame radius:NSHeight(cellFrame)/2.0];
			
		// Fill background with gradient
			[[NSGraphicsContext currentContext] saveGraphicsState];
			[roundedRect addClip];
			[recordingGradient fillRect:cellFrame angle:90.0];
			[[NSGraphicsContext currentContext] restoreGraphicsState];
			
		// Highlight if inside or down
			if (mouseInsideTrackingArea)
			{
				[[[NSColor blackColor] colorWithAlphaComponent: (mouseDown ? 0.4 : 0.2)] set];
				[roundedRect fill];
			}
			
		// Draw snapback image
			NSImage *snapBackArrow = SRResIndImage(@"SRSnapback");	
			[snapBackArrow dissolveToPoint:[self _snapbackRectForFrame: cellFrame].origin fraction:1.0];
			
		// Because of the gradient and snapback image, the white rounded rect will be smaller
			whiteRect = NSInsetRect(cellFrame, 9.5, 2.0);
			whiteRect.origin.x -= 7.5;
		}
		
	// Draw white rounded box
		roundedRect = [NSBezierPath bezierPathWithSRCRoundRectInRect:whiteRect radius:NSHeight(whiteRect)/2.0];
		[[NSGraphicsContext currentContext] saveGraphicsState];
		[roundedRect addClip];
		[[NSColor whiteColor] set];
		[NSBezierPath fillRect: whiteRect];
		
	// Draw border and remove badge if needed
		if (!isRecording)
		{
			[[NSColor windowFrameColor] set];
			[roundedRect stroke];
			
		// If key combination is set and valid, draw remove image
			if (![self _isEmpty] && [self isEnabled])
			{
				NSString *removeImageName = [NSString stringWithFormat: @"SRRemoveShortcut%@", (mouseInsideTrackingArea ? (mouseDown ? @"Pressed" : @"Rollover") : (mouseDown ? @"Rollover" : @""))];
				NSImage *removeImage = SRResIndImage(removeImageName);
				[removeImage dissolveToPoint:[self _removeButtonRectForFrame: cellFrame].origin fraction:1.0];
			}
		}
		
		[[NSGraphicsContext currentContext] restoreGraphicsState];
		
	// Draw text
		NSMutableParagraphStyle *mpstyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		[mpstyle setLineBreakMode: NSLineBreakByTruncatingTail];
		[mpstyle setAlignment: NSCenterTextAlignment];
		
	// Only the KeyCombo should be black and in a bigger font size
		BOOL recordingOrEmpty = (isRecording || [self _isEmpty]);
		NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys: mpstyle, NSParagraphStyleAttributeName,
			[NSFont systemFontOfSize: (recordingOrEmpty ? [NSFont labelFontSize] : [NSFont smallSystemFontSize])], NSFontAttributeName,
			(recordingOrEmpty ? [NSColor disabledControlTextColor] : [NSColor blackColor]), NSForegroundColorAttributeName, 
			nil];
		
		NSString *displayString;
		
		if (isRecording)
		{
		// Recording, but no modifier keys down
			if (![self _validModifierFlags: recordingFlags])
			{
				if (mouseInsideTrackingArea)
				{
				// Mouse over snapback
					displayString = SRLoc(@"Use old shortcut");
				}
				else
				{
				// Mouse elsewhere
					displayString = SRLoc(@"Type shortcut");
				}
			}
			else
			{
			// Display currently pressed modifier keys
				displayString = SRStringForCocoaModifierFlags( recordingFlags );
				
			// Fall back on 'Type shortcut' if we don't have modifier flags to display; this will happen for the fn key depressed
				if (![displayString length])
				{
					displayString = SRLoc(@"Type shortcut");
				}
			}
		}
		else
		{
		// Not recording...
			if ([self _isEmpty])
			{
				displayString = SRLoc(@"Click to record shortcut");
			}
			else
			{
			// Display current key combination
				displayString = [self keyComboString];
			}
		}
		
	// Calculate rect in which to draw the text in...
		NSRect textRect = cellFrame;
		textRect.size.width -= 6;
		textRect.size.width -= ((!isRecording && [self _isEmpty]) ? 6 : (isRecording ? [self _snapbackRectForFrame: cellFrame].size.width : [self _removeButtonRectForFrame: cellFrame].size.width) + 6);
		textRect.origin.x += 6;
		textRect.origin.y = -(NSMidY(cellFrame) - [displayString sizeWithAttributes: attributes].height/2);
		
	// Finally draw it
		[displayString drawInRect:textRect withAttributes:attributes];
		
    // draw a focus ring...?
		if ( [self showsFirstResponder] )
		{
			[NSGraphicsContext saveGraphicsState];
			NSSetFocusRingStyle(NSFocusRingOnly);
			[[NSBezierPath bezierPathWithSRCRoundRectInRect:cellFrame //NSInsetRect(cellFrame,2,2)
													 radius:NSHeight(cellFrame)/2.0] fill];
			[NSGraphicsContext restoreGraphicsState];
		}
		
	} else {
		
//	NSRect rawCellFrame = cellFrame;
		cellFrame = NSInsetRect(cellFrame,0.5,0.5);
		
		NSRect whiteRect = cellFrame;
		NSBezierPath *roundedRect;
		
		BOOL isVaguelyRecording = isRecording;
		double xanim = 0.0;
		
		if (isAnimatingNow) {
//		NSLog(@"tp: %f; xanim: %f", transitionProgress, xanim);
			xanim = (SRAnimationEaseInOut(transitionProgress));
//		NSLog(@"tp: %f; xanim: %f", transitionProgress, xanim);
		}
		
		double alphaRecording = 1.0; double alphaView = 1.0;
		if (isAnimatingNow && !isAnimatingTowardsRecording) { alphaRecording = 1.0 - xanim; alphaView = xanim; }
		if (isAnimatingNow && isAnimatingTowardsRecording) { alphaView = 1.0 - xanim; alphaRecording = xanim; }
		
		if (isAnimatingNow) {
			//NSLog(@"animation step: %f, effective: %f, alpha recording: %f, view: %f", transitionProgress, xanim, alphaRecording, alphaView);
		}
		
		if (isAnimatingNow && isAnimatingTowardsRecording) {
			isVaguelyRecording = YES;
		}
		
//	NSAffineTransform *transitionMovement = [[NSAffineTransform alloc] init];
		NSAffineTransform *viewportMovement = [[NSAffineTransform alloc] init];
		CTGradient *currRecordingGradient = [recordingGradient gradientWithAlphaComponent:0.3];
	// Draw gradient when in recording mode
		if (isVaguelyRecording)
		{
			if (isAnimatingNow) {
//			[transitionMovement translateXBy:(isAnimatingTowardsRecording ? -(NSWidth(cellFrame)*(1.0-xanim)) : +(NSWidth(cellFrame)*xanim)) yBy:0.0];
				currRecordingGradient = [currRecordingGradient gradientWithAlphaComponent:alphaRecording];
				if (SRAnimationAxisIsY) {
//				[viewportMovement translateXBy:0.0 yBy:(isAnimatingTowardsRecording ? -(NSHeight(cellFrame)*(xanim)) : -(NSHeight(cellFrame)*(1.0-xanim)))];
					[viewportMovement translateXBy:0.0 yBy:(isAnimatingTowardsRecording ? NSHeight(cellFrame)*(xanim) : NSHeight(cellFrame)*(1.0-xanim))];
				} else {
					[viewportMovement translateXBy:(isAnimatingTowardsRecording ? -(NSWidth(cellFrame)*(xanim)) : -(NSWidth(cellFrame)*(1.0-xanim))) yBy:0.0];
				}
			} else {
				if (SRAnimationAxisIsY) {
					[viewportMovement translateXBy:0.0 yBy:NSHeight(cellFrame)];				
				} else {
					[viewportMovement translateXBy:-(NSWidth(cellFrame)) yBy:0.0];
				}
			}
		}
		
		
	// Draw white rounded box
		roundedRect = [NSBezierPath bezierPathWithSRCRoundRectInRect:whiteRect radius:NSHeight(whiteRect)/2.0];
		[[NSColor whiteColor] set];
		[[NSGraphicsContext currentContext] saveGraphicsState];
		[roundedRect fill];
		[[NSColor windowFrameColor] set];
		[roundedRect stroke];
		[roundedRect addClip];
		
//	if (isVaguelyRecording) 
		{
			roundedRect = [viewportMovement transformBezierPath:[NSBezierPath bezierPathWithSRCRoundRectInRect:SRAnimationOffsetRect(cellFrame,cellFrame) radius:NSHeight(cellFrame)/2.0]];
			
		// Fill background with gradient
		//		[currRecordingGradient fillRect:cellFrame angle:90.0];
			
			NSRect snapBackRect = SRAnimationOffsetRect([self _snapbackRectForFrame: cellFrame],cellFrame);
//		NSLog(@"snapbackrect: %@; offset: %@", NSStringFromRect([self _snapbackRectForFrame: cellFrame]), NSStringFromRect(snapBackRect));
			NSPoint correctedSnapBackOrigin = [viewportMovement transformPoint:snapBackRect.origin];
			
			NSRect correctedSnapBackRect = snapBackRect;
//		correctedSnapBackRect.origin.y = NSMinY(whiteRect);
			correctedSnapBackRect.size.height = NSHeight(whiteRect);
			correctedSnapBackRect.size.width *= 1.3;
			correctedSnapBackRect.origin.y -= 5.0;
			correctedSnapBackRect.origin.x -= 1.5;
			
			correctedSnapBackOrigin.x -= 0.5;
			
			correctedSnapBackRect.origin = [viewportMovement transformPoint:correctedSnapBackRect.origin];
			
			NSBezierPath *snapBackButton = [NSBezierPath bezierPathWithRect:correctedSnapBackRect];
			[[[[NSColor windowFrameColor] shadowWithLevel:0.2] colorWithAlphaComponent:alphaRecording] set];
			[snapBackButton stroke];
//		NSLog(@"stroked along path of %@", NSStringFromRect(correctedSnapBackRect));
			[[((mouseDown && mouseInsideTrackingArea) ? ([CTGradient unifiedPressedGradient]) : ([CTGradient unifiedNormalGradient])) gradientWithAlphaComponent:alphaRecording] fillRect:NSInsetRect(correctedSnapBackRect,-([snapBackButton lineWidth]/2.0),-([snapBackButton lineWidth]/2.0)) angle:90];
			/*
		// Highlight if inside or down
			 if (mouseInsideTrackingArea)
			 {
				 [[[NSColor blackColor] colorWithAlphaComponent: alphaRecording*(mouseDown ? 0.15 : 0.1)] set];
				 [snapBackButton fill];
			 }*/
			
		// Draw snapback image
			NSImage *snapBackArrow = SRResIndImage(@"SRSnapback");
			[snapBackArrow dissolveToPoint:correctedSnapBackOrigin fraction:1.0*alphaRecording];
		}
		
	// Draw border and remove badge if needed
		/*	if (!isVaguelyRecording)
		{
			*/	
		// If key combination is set and valid, draw remove image
		if (![self _isEmpty] && [self isEnabled])
		{
			NSString *removeImageName = [NSString stringWithFormat: @"SRRemoveShortcut%@", (mouseInsideTrackingArea ? (mouseDown ? @"Pressed" : @"Rollover") : (mouseDown ? @"Rollover" : @""))];
			NSImage *removeImage = SRResIndImage(removeImageName);
			[removeImage dissolveToPoint:[viewportMovement transformPoint:([self _removeButtonRectForFrame: cellFrame].origin)] fraction:alphaView];
			//NSLog(@"drew removeImage with alpha %f", alphaView);
		}
//	}
		
		
		
	// Draw text
		NSMutableParagraphStyle *mpstyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		[mpstyle setLineBreakMode: NSLineBreakByTruncatingTail];
		[mpstyle setAlignment: NSCenterTextAlignment];
		
		double alphaCombo = alphaView;
		double alphaRecordingText = alphaRecording;
		if (comboJustChanged) {
			alphaCombo = 1.0;
			alphaRecordingText = 0.0;//(alphaRecordingText/2.0);
		}
		
		
		NSString *displayString;
		
		{
	// Only the KeyCombo should be black and in a bigger font size
			BOOL recordingOrEmpty = (isVaguelyRecording || [self _isEmpty]);
			NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys: mpstyle, NSParagraphStyleAttributeName,
				[NSFont systemFontOfSize: (recordingOrEmpty ? [NSFont labelFontSize] : [NSFont smallSystemFontSize])], NSFontAttributeName,
				[(recordingOrEmpty ? [NSColor disabledControlTextColor] : [NSColor blackColor]) colorWithAlphaComponent:alphaRecordingText], NSForegroundColorAttributeName, 
				nil];
		// Recording, but no modifier keys down
			if (![self _validModifierFlags: recordingFlags])
			{
				if (mouseInsideTrackingArea)
				{
				// Mouse over snapback
					displayString = SRLoc(@"Use old shortcut");
				}
				else
				{
				// Mouse elsewhere
					displayString = SRLoc(@"Type shortcut");
				}
			}
			else
			{
			// Display currently pressed modifier keys
				displayString = SRStringForCocoaModifierFlags( recordingFlags );
				
			// Fall back on 'Type shortcut' if we don't have modifier flags to display; this will happen for the fn key depressed
				if (![displayString length])
				{
					displayString = SRLoc(@"Type shortcut");
				}
			}
	// Calculate rect in which to draw the text in...
			NSRect textRect = SRAnimationOffsetRect(cellFrame,cellFrame);
			//NSLog(@"draw record text in rect (preadjusted): %@", NSStringFromRect(textRect));
			textRect.origin.y -= 3.0;
			textRect.origin = [viewportMovement transformPoint:textRect.origin];
			//NSLog(@"draw record text in rect: %@", NSStringFromRect(textRect));
			
			
			
	// Finally draw it
			[displayString drawInRect:textRect withAttributes:attributes];
		}
		
		
		{
	// Only the KeyCombo should be black and in a bigger font size
			NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys: mpstyle, NSParagraphStyleAttributeName,
				[NSFont systemFontOfSize: ([self _isEmpty] ? [NSFont labelFontSize] : [NSFont smallSystemFontSize])], NSFontAttributeName,
				[([self _isEmpty] ? [NSColor disabledControlTextColor] : [NSColor blackColor]) colorWithAlphaComponent:alphaCombo], NSForegroundColorAttributeName, 
				nil];
		// Not recording...
			if ([self _isEmpty])
			{
				displayString = SRLoc(@"Click to record shortcut");
			}
			else
			{
			// Display current key combination
				displayString = [self keyComboString];
			}
	// Calculate rect in which to draw the text in...
			NSRect textRect = cellFrame;
			/*		textRect.size.width -= 6;
			textRect.size.width -= (([self _removeButtonRectForFrame: cellFrame].size.width) + 6);
//		textRect.origin.x += 6;*/
//NSFont *f = [attributes objectForKey:NSFontAttributeName];
//double lineHeight = [[[NSLayoutManager alloc] init] defaultLineHeightForFont:f];
//		textRect.size.height = lineHeight;
			if (!comboJustChanged) {
				//NSLog(@"draw view text in rect (pre-adjusted): %@", NSStringFromRect(textRect));
				textRect.origin = [viewportMovement transformPoint:textRect.origin];
			}
			textRect.origin.y = NSMinY(textRect)-3.0;// - ((lineHeight/2.0)+([f descender]/2.0));
				
				//NSLog(@"draw view text in rect: %@", NSStringFromRect(textRect));
				
	// Finally draw it
				[displayString drawInRect:textRect withAttributes:attributes];
		}
		
		[[NSGraphicsContext currentContext] restoreGraphicsState];
		
    // draw a focus ring...?
		
		if ( [self showsFirstResponder] )
		{
			[NSGraphicsContext saveGraphicsState];
			NSSetFocusRingStyle(NSFocusRingOnly);
			[[NSBezierPath bezierPathWithSRCRoundRectInRect:cellFrame //NSInsetRect(cellFrame,2,2)
													 radius:NSHeight(cellFrame)/2.0] fill];
			[NSGraphicsContext restoreGraphicsState];
		}
		
	}
}

#pragma mark *** Mouse Tracking ***

- (void)resetTrackingRects
{	
	SRRecorderControl *controlView = (SRRecorderControl *)[self controlView];
	NSRect cellFrame = [controlView bounds];
	NSPoint mouseLocation = [controlView convertPoint:[[NSApp currentEvent] locationInWindow] fromView:nil];

	// We're not to be tracked if we're not enabled
	if (![self isEnabled])
	{
		if (removeTrackingRectTag != 0) [controlView removeTrackingRect: removeTrackingRectTag];
		if (snapbackTrackingRectTag != 0) [controlView removeTrackingRect: snapbackTrackingRectTag];
		
		return;
	}
	
	// We're either in recording or normal display mode
	if (!isRecording)
	{
		// Create and register tracking rect for the remove badge if shortcut is not empty
		NSRect removeButtonRect = [self _removeButtonRectForFrame: cellFrame];
		BOOL mouseInside = [controlView mouse:mouseLocation inRect:removeButtonRect];
		
		if (removeTrackingRectTag != 0) [controlView removeTrackingRect: removeTrackingRectTag];
		removeTrackingRectTag = [controlView addTrackingRect:removeButtonRect owner:self userData:nil assumeInside:mouseInside];
		
		if (mouseInsideTrackingArea != mouseInside) mouseInsideTrackingArea = mouseInside;
	}
	else
	{
		// Create and register tracking rect for the snapback badge if we're in recording mode
		NSRect snapbackRect = [self _snapbackRectForFrame: cellFrame];
		BOOL mouseInside = [controlView mouse:mouseLocation inRect:snapbackRect];

		if (snapbackTrackingRectTag != 0) [controlView removeTrackingRect: snapbackTrackingRectTag];
		snapbackTrackingRectTag = [controlView addTrackingRect:snapbackRect owner:self userData:nil assumeInside:mouseInside];	
		
		if (mouseInsideTrackingArea != mouseInside) mouseInsideTrackingArea = mouseInside;
	}
}

- (void)mouseEntered:(NSEvent *)theEvent
{
	NSView *view = [self controlView];

	if ([[view window] isKeyWindow] || [view acceptsFirstMouse: theEvent])
	{
		mouseInsideTrackingArea = YES;
//		[view display];
	}
}

- (void)mouseExited:(NSEvent*)theEvent
{
	NSView *view = [self controlView];
	
	if ([[view window] isKeyWindow] || [view acceptsFirstMouse: theEvent])
	{
		mouseInsideTrackingArea = NO;
//		[view display];
	}
}

- (BOOL)trackMouse:(NSEvent *)theEvent inRect:(NSRect)cellFrame ofView:(SRRecorderControl *)controlView untilMouseUp:(BOOL)flag
{		
	NSEvent *currentEvent = theEvent;
	NSPoint mouseLocation = [controlView convertPoint:[currentEvent locationInWindow] fromView:nil];
	
	NSRect trackingRect = (isRecording ? [self _snapbackRectForFrame: cellFrame] : [self _removeButtonRectForFrame: cellFrame]);
	NSRect leftRect = cellFrame;

	// Determine the area without any badge
	if (!NSEqualRects(trackingRect,NSZeroRect)) leftRect.size.width -= NSWidth(trackingRect) + 4;
		
	do {
        mouseLocation = [controlView convertPoint: [currentEvent locationInWindow] fromView:nil];
		
		switch ([currentEvent type])
		{
			case NSLeftMouseDown:
			{
				// Check if mouse is over remove/snapback image
				if ([controlView mouse:mouseLocation inRect:trackingRect])
				{
					mouseDown = YES;
					[controlView setNeedsDisplayInRect: cellFrame];
				}
				
				break;
			}
			case NSLeftMouseDragged:
			{				
				// Recheck if mouse is still over the image while dragging 
				mouseInsideTrackingArea = [controlView mouse:mouseLocation inRect:trackingRect];
				[controlView setNeedsDisplayInRect: cellFrame];
				
				break;
			}
			default: // NSLeftMouseUp
			{
				mouseDown = NO;
				mouseInsideTrackingArea = [controlView mouse:mouseLocation inRect:trackingRect];

				if (mouseInsideTrackingArea)
				{
					if (isRecording)
					{
						// Mouse was over snapback, just redraw
                        [self _endRecordingTransition];
					}
					else
					{
						// Mouse was over the remove image, reset all
						[self setKeyCombo: SRMakeKeyCombo(ShortcutRecorderEmptyCode, ShortcutRecorderEmptyFlags)];
					}
				}
				else if ([controlView mouse:mouseLocation inRect:leftRect] && !isRecording)
				{
					if ([self isEnabled]) 
					{
                        [self _startRecordingTransition];
					}
					/* maybe beep if not editable?
					 else
					{
						NSBeep();
					}
					 */
				}
				
				// Any click inside will make us firstResponder
				if ([self isEnabled]) [[controlView window] makeFirstResponder: controlView];

				// Reset tracking rects and redisplay
				[self resetTrackingRects];
				[controlView setNeedsDisplayInRect: cellFrame];
				
				return YES;
			}
		}
		
    } while ((currentEvent = [[controlView window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask) untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES]));
	
    return YES;
}

#pragma mark *** Delegate ***

- (id)delegate
{
	return delegate;
}

- (void)setDelegate:(id)aDelegate
{
	delegate = aDelegate;
}

#pragma mark *** Responder Control ***

- (BOOL) becomeFirstResponder;
{
    // reset tracking rects and redisplay
    [self resetTrackingRects];
//    [[self controlView] display];
    
    return YES;
}

- (BOOL)resignFirstResponder;
{
	if (isRecording) {
		[self _endRecordingTransition];
	}
    
    [self resetTrackingRects];
//    [[self controlView] display];
    return YES;
}

#pragma mark *** Key Combination Control ***

- (BOOL) performKeyEquivalent:(NSEvent *)theEvent
{	
	unsigned int flags = [self _filteredCocoaFlags: [theEvent modifierFlags]];
	NSNumber *keyCodeNumber = [NSNumber numberWithUnsignedShort: [theEvent keyCode]];
	BOOL snapback = [cancelCharacterSet containsObject: keyCodeNumber];
	BOOL validModifiers = [self _validModifierFlags: (snapback) ? [theEvent modifierFlags] : flags]; // Snapback key shouldn't interfer with required flags!
    
    // Special case for the space key when we aren't recording...
    if (!isRecording && [[theEvent characters] isEqualToString:@" "]) {
        [self _startRecordingTransition];
        return YES;
    }
	
	// Do something as long as we're in recording mode and a modifier key or cancel key is pressed
	if (isRecording && (validModifiers || snapback)) {
		if (!snapback || validModifiers) {
			BOOL goAhead = YES;
			
			// Special case: if a snapback key has been entered AND modifiers are deemed valid...
			if (snapback && validModifiers) {
				// ...AND we're set to allow plain keys
				if (allowsKeyOnly) {
					// ...AND modifiers are empty, or empty save for the Function key
					// (needed, since forward delete is fn+delete on laptops)
					if (flags == ShortcutRecorderEmptyFlags || flags == (ShortcutRecorderEmptyFlags | NSFunctionKeyMask)) {
						// ...check for behavior in escapeKeysRecord.
						if (!escapeKeysRecord) {
							goAhead = NO;
						}
					}
				}
			}
			
			if (goAhead) {
				
				NSString *character = [[theEvent charactersIgnoringModifiers] uppercaseString];
				
			// accents like "¬¥" or "`" will be ignored since we don't get a keycode
				if ([character length]) {
					NSError *error = nil;
					
				// Check if key combination is already used or not allowed by the delegate
					if ( [validator isKeyCode:[theEvent keyCode] 
								andFlagsTaken:[self _filteredCocoaToCarbonFlags:flags]
										error:&error] ) {
                    // display the error...
						NSAlert *alert = [NSAlert alertWithNonRecoverableError:error];
						[alert setAlertStyle:NSCriticalAlertStyle];
						[alert runModal];
						
					// Recheck pressed modifier keys
						[self flagsChanged: [NSApp currentEvent]];
						
						return YES;
					} else {
					// All ok, set new combination
						keyCombo.flags = flags;
						keyCombo.code = [theEvent keyCode];
						
						hasKeyChars = YES;
						keyChars = [[theEvent characters] retain];
						keyCharsIgnoringModifiers = [[theEvent charactersIgnoringModifiers] retain];
//						NSLog(@"keychars: %@, ignoringmods: %@", keyChars, keyCharsIgnoringModifiers);
//						NSLog(@"calculated keychars: %@, ignoring: %@", SRStringForKeyCode(keyCombo.code), SRCharacterForKeyCodeAndCocoaFlags(keyCombo.code,keyCombo.flags));
						
					// Notify delegate
						if (delegate != nil && [delegate respondsToSelector: @selector(shortcutRecorderCell:keyComboDidChange:)])
							[delegate shortcutRecorderCell:self keyComboDidChange:keyCombo];
						
					// Save if needed
						[self _saveKeyCombo];
						
						[self _setJustChanged];
					}
				} else {
				// invalid character
					NSBeep();
				}
			}
		}
		
		// reset values and redisplay
		recordingFlags = ShortcutRecorderEmptyFlags;
        
        [self _endRecordingTransition];
		
		[self resetTrackingRects];
//		[[self controlView] display];
		
		return YES;
	} else {
		//Start recording when the spacebar is pressed while the control is first responder
		if (([[[self controlView] window] firstResponder] == [self controlView]) &&
			([[theEvent characters] length] && [[theEvent characters] characterAtIndex:0] == 32) &&
			([self isEnabled]))
		{
			[self _startRecordingTransition];
		}
	}
	
	return NO;
}

- (void)flagsChanged:(NSEvent *)theEvent
{
	if (isRecording)
	{
		recordingFlags = [self _filteredCocoaFlags: [theEvent modifierFlags]];
//		[[self controlView] display];
	}
}

#pragma mark -

- (unsigned int)allowedFlags
{
	return allowedFlags;
}

- (void)setAllowedFlags:(unsigned int)flags
{
	allowedFlags = flags;
	
	// filter new flags and change keycombo if not recording
	if (isRecording)
	{
		recordingFlags = [self _filteredCocoaFlags: [[NSApp currentEvent] modifierFlags]];;
	}
	else
	{
		unsigned int originalFlags = keyCombo.flags;
		keyCombo.flags = [self _filteredCocoaFlags: keyCombo.flags];
		
		if (keyCombo.flags != originalFlags && keyCombo.code > ShortcutRecorderEmptyCode)
		{
			// Notify delegate if keyCombo changed
			if (delegate != nil && [delegate respondsToSelector: @selector(shortcutRecorderCell:keyComboDidChange:)])
				[delegate shortcutRecorderCell:self keyComboDidChange:keyCombo];
			
			// Save if needed
			[self _saveKeyCombo];
		}
	}
	
//	[[self controlView] display];
}

- (BOOL)allowsKeyOnly {
	return allowsKeyOnly;
}

- (BOOL)escapeKeysRecord {
	return escapeKeysRecord;
}

- (void)setAllowsKeyOnly:(BOOL)nAllowsKeyOnly escapeKeysRecord:(BOOL)nEscapeKeysRecord {
	allowsKeyOnly = nAllowsKeyOnly;
	escapeKeysRecord = nEscapeKeysRecord;
}

- (unsigned int)requiredFlags
{
	return requiredFlags;
}

- (void)setRequiredFlags:(unsigned int)flags
{
	requiredFlags = flags;
	
	// filter new flags and change keycombo if not recording
	if (isRecording)
	{
		recordingFlags = [self _filteredCocoaFlags: [[NSApp currentEvent] modifierFlags]];
	}
	else
	{
		unsigned int originalFlags = keyCombo.flags;
		keyCombo.flags = [self _filteredCocoaFlags: keyCombo.flags];
		
		if (keyCombo.flags != originalFlags && keyCombo.code > ShortcutRecorderEmptyCode)
		{
			// Notify delegate if keyCombo changed
			if (delegate != nil && [delegate respondsToSelector: @selector(shortcutRecorderCell:keyComboDidChange:)])
				[delegate shortcutRecorderCell:self keyComboDidChange:keyCombo];
			
			// Save if needed
			[self _saveKeyCombo];
		}
	}
	
//	[[self controlView] display];
}

- (KeyCombo)keyCombo
{
	return keyCombo;
}

- (void)setKeyCombo:(KeyCombo)aKeyCombo
{
	keyCombo = aKeyCombo;
	keyCombo.flags = [self _filteredCocoaFlags: aKeyCombo.flags];
	
	hasKeyChars = NO;

	// Notify delegate
	if (delegate != nil && [delegate respondsToSelector: @selector(shortcutRecorderCell:keyComboDidChange:)])
		[delegate shortcutRecorderCell:self keyComboDidChange:keyCombo];
	
	// Save if needed
	[self _saveKeyCombo];
	
//	[[self controlView] display];
}

- (BOOL)canCaptureGlobalHotKeys
{
	return globalHotKeys;
}

- (void)setCanCaptureGlobalHotKeys:(BOOL)inState
{
	globalHotKeys = inState;
}

#pragma mark *** Autosave Control ***

- (NSString *)autosaveName
{
	return autosaveName;
}

- (void)setAutosaveName:(NSString *)aName
{
	if (aName != autosaveName)
	{
		[autosaveName release];
		autosaveName = [aName copy];
	}
}

#pragma mark -

- (NSString *)keyComboString
{
	if ([self _isEmpty]) return nil;
	
	return [NSString stringWithFormat: @"%@%@",
        SRStringForCocoaModifierFlags( keyCombo.flags ),
        SRStringForKeyCode( keyCombo.code )];
}

- (NSString *)keyChars {
	if (!hasKeyChars) return SRStringForKeyCode(keyCombo.code);
	return keyChars;
}

- (NSString *)keyCharsIgnoringModifiers {
	if (!hasKeyChars) return SRCharacterForKeyCodeAndCocoaFlags(keyCombo.code,keyCombo.flags);
	return keyCharsIgnoringModifiers;
}

@end

#pragma mark -

@implementation SRRecorderCell (Private)

- (void)_privateInit
{
    // init the validator object...
    validator = [[SRValidator alloc] initWithDelegate:self];
    
	// Allow all modifier keys by default, nothing is required
	allowedFlags = ShortcutRecorderAllFlags;
	requiredFlags = ShortcutRecorderEmptyFlags;
	recordingFlags = ShortcutRecorderEmptyFlags;
	
	// Create clean KeyCombo
	keyCombo.flags = ShortcutRecorderEmptyFlags;
	keyCombo.code = ShortcutRecorderEmptyCode;
	
	keyChars = nil;
	keyCharsIgnoringModifiers = nil;
	hasKeyChars = NO;
	
	// These keys will cancel the recoding mode if not pressed with any modifier
	cancelCharacterSet = [[NSSet alloc] initWithObjects: [NSNumber numberWithInt:ShortcutRecorderEscapeKey], 
		[NSNumber numberWithInt:ShortcutRecorderBackspaceKey], [NSNumber numberWithInt:ShortcutRecorderDeleteKey], nil];
		
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self selector:@selector(_createGradient) name:NSSystemColorsDidChangeNotification object:nil]; // recreate gradient if needed
	[self _createGradient];

	[self _loadKeyCombo];
}

- (void)_createGradient
{
	NSColor *gradientStartColor = [[[NSColor alternateSelectedControlColor] shadowWithLevel: 0.2] colorWithAlphaComponent: 0.9];
	NSColor *gradientEndColor = [[[NSColor alternateSelectedControlColor] highlightWithLevel: 0.2] colorWithAlphaComponent: 0.9];
	
	CTGradient *newGradient = [CTGradient gradientWithBeginningColor:gradientStartColor endingColor:gradientEndColor];
	
	if (recordingGradient != newGradient)
	{
		[recordingGradient release];
		recordingGradient = [newGradient retain];
	}
	
//	[[self controlView] display];
}

- (void)_setJustChanged {
	comboJustChanged = YES;
}

- (BOOL)_effectiveIsAnimating {
	return (isAnimating && [self _supportsAnimation]);
}

- (BOOL)_supportsAnimation {
	return [[self class] styleSupportsAnimation:style];
}

- (void)_startRecordingTransition {
	if ([self _effectiveIsAnimating]) {
		isAnimatingTowardsRecording = YES;
		isAnimatingNow = YES;
		transitionProgress = 0.0;
		[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(_transitionTick) object:nil];
		[self performSelector:@selector(_transitionTick) withObject:nil afterDelay:(SRTransitionDuration/SRTransitionFrames)];
//	NSLog(@"start recording-transition");
	} else {
		[self _startRecording];
	}
}

- (void)_endRecordingTransition {
	if ([self _effectiveIsAnimating]) {
		isAnimatingTowardsRecording = NO;
		isAnimatingNow = YES;
		transitionProgress = 0.0;
		[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(_transitionTick) object:nil];
		[self performSelector:@selector(_transitionTick) withObject:nil afterDelay:(SRTransitionDuration/SRTransitionFrames)];
//	NSLog(@"end recording-transition");
	} else {
		[self _endRecording];
	}
}

- (void)_transitionTick {
	transitionProgress += (1.0/SRTransitionFrames);
//	NSLog(@"transition tick: %f", transitionProgress);
	if (transitionProgress >= 0.998) {
//		NSLog(@"transition deemed complete");
		isAnimatingNow = NO;
		transitionProgress = 0.0;
		if (isAnimatingTowardsRecording) {
			[self _startRecording];
		} else {
			[self _endRecording];
		}
	} else {
//		NSLog(@"more to do");
		[[self controlView] setNeedsDisplay:YES];
		[[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(_transitionTick) object:nil];
		[self performSelector:@selector(_transitionTick) withObject:nil afterDelay:(SRTransitionDuration/SRTransitionFrames)];
	}
}

- (void)_startRecording;
{
    // Jump into recording mode if mouse was inside the control but not over any image
    isRecording = YES;
    
    // Reset recording flags and determine which are required
    recordingFlags = [self _filteredCocoaFlags: ShortcutRecorderEmptyFlags];
    
/*	[self setFocusRingType:NSFocusRingTypeNone];
	[[self controlView] setFocusRingType:NSFocusRingTypeNone];*/	
	[[self controlView] setNeedsDisplay:YES];
	
    // invalidate the focus ring rect...
    NSView *controlView = [self controlView];
    [controlView setKeyboardFocusRingNeedsDisplayInRect:[controlView bounds]];

    if (globalHotKeys) hotKeyModeToken = PushSymbolicHotKeyMode(kHIHotKeyModeAllDisabled);
}

- (void)_endRecording;
{
    isRecording = NO;
	comboJustChanged = NO;

/*	[self setFocusRingType:NSFocusRingTypeNone];
	[[self controlView] setFocusRingType:NSFocusRingTypeNone];*/	
	[[self controlView] setNeedsDisplay:YES];
	
    // invalidate the focus ring rect...
    NSView *controlView = [self controlView];
    [controlView setKeyboardFocusRingNeedsDisplayInRect:[controlView bounds]];
	
	if (globalHotKeys) PopSymbolicHotKeyMode(hotKeyModeToken);
}

#pragma mark *** Autosave ***

- (NSString *)_defaultsKeyForAutosaveName:(NSString *)name
{
	return [NSString stringWithFormat: @"ShortcutRecorder %@", name];
}

- (void)_saveKeyCombo
{
	NSString *defaultsKey = [self autosaveName];

	if (defaultsKey != nil && [defaultsKey length])
	{
		id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
		
		NSDictionary *defaultsValue = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithShort: keyCombo.code], @"keyCode",
			[NSNumber numberWithUnsignedInt: keyCombo.flags], @"modifierFlags", // cocoa
			[NSNumber numberWithUnsignedInt: SRCocoaToCarbonFlags(keyCombo.flags)], @"modifiers", // carbon, for compatibility with PTKeyCombo
			nil];
		
		if (hasKeyChars) {
			
			NSMutableDictionary *mutableDefaultsValue = [defaultsValue mutableCopy];
			[mutableDefaultsValue setObject:keyChars forKey:@"keyChars"];
			[mutableDefaultsValue setObject:keyCharsIgnoringModifiers forKey:@"keyCharsIgnoringModifiers"];
			
			defaultsValue = [mutableDefaultsValue copy];
			[mutableDefaultsValue release];
			
		}
		
		[values setValue:defaultsValue forKey:[self _defaultsKeyForAutosaveName: defaultsKey]];
	}
}

- (void)_loadKeyCombo
{
	NSString *defaultsKey = [self autosaveName];

	if (defaultsKey != nil && [defaultsKey length])
	{
		id values = [[NSUserDefaultsController sharedUserDefaultsController] values];
		NSDictionary *savedCombo = [values valueForKey: [self _defaultsKeyForAutosaveName: defaultsKey]];
		
		signed short keyCode = [[savedCombo valueForKey: @"keyCode"] shortValue];
		unsigned int flags;
		if ((nil == [savedCombo valueForKey:@"modifierFlags"]) && (nil != [savedCombo valueForKey:@"modifiers"])) { // carbon, for compatibility with PTKeyCombo
			flags = SRCarbonToCocoaFlags([[savedCombo valueForKey: @"modifiers"] unsignedIntValue]);
		} else { // cocoa
			flags = [[savedCombo valueForKey: @"modifierFlags"] unsignedIntValue];
		}
		
		keyCombo.flags = [self _filteredCocoaFlags: flags];
		keyCombo.code = keyCode;
		
		NSString *kc = [savedCombo valueForKey: @"keyChars"];
		hasKeyChars = (nil != kc);
		if (kc) {
			keyCharsIgnoringModifiers = [[savedCombo valueForKey: @"keyCharsIgnoringModifiers"] retain];
			keyChars = [kc retain];
		}
		
		// Notify delegate
		if (delegate != nil && [delegate respondsToSelector: @selector(shortcutRecorderCell:keyComboDidChange:)])
			[delegate shortcutRecorderCell:self keyComboDidChange:keyCombo];
		
//		[[self controlView] display];
	}
}

#pragma mark *** Drawing Helpers ***

- (NSRect)_removeButtonRectForFrame:(NSRect)cellFrame
{	
	if ([self _isEmpty] || ![self isEnabled]) return NSZeroRect;
	
	NSRect removeButtonRect;
	NSImage *removeImage = SRResIndImage(@"SRRemoveShortcut");
	
	removeButtonRect.origin = NSMakePoint(NSMaxX(cellFrame) - [removeImage size].width - 4, (NSMaxY(cellFrame) - [removeImage size].height)/2);
	removeButtonRect.size = [removeImage size];

	return removeButtonRect;
}

- (NSRect)_snapbackRectForFrame:(NSRect)cellFrame
{	
//	if (!isRecording) return NSZeroRect;

	NSRect snapbackRect;
	NSImage *snapbackImage = SRResIndImage(@"SRSnapback");
	
	snapbackRect.origin = NSMakePoint(NSMaxX(cellFrame) - [snapbackImage size].width - 2, (NSMaxY(cellFrame) - [snapbackImage size].height)/2 + 1);
	snapbackRect.size = [snapbackImage size];

	return snapbackRect;
}

#pragma mark *** Filters ***

- (unsigned int)_filteredCocoaFlags:(unsigned int)flags
{
	unsigned int filteredFlags = ShortcutRecorderEmptyFlags;
	unsigned int a = allowedFlags;
	unsigned int m = requiredFlags;

	if (m & NSCommandKeyMask) filteredFlags |= NSCommandKeyMask;
	else if ((flags & NSCommandKeyMask) && (a & NSCommandKeyMask)) filteredFlags |= NSCommandKeyMask;
	
	if (m & NSAlternateKeyMask) filteredFlags |= NSAlternateKeyMask;
	else if ((flags & NSAlternateKeyMask) && (a & NSAlternateKeyMask)) filteredFlags |= NSAlternateKeyMask;
	
	if ((m & NSControlKeyMask)) filteredFlags |= NSControlKeyMask;
	else if ((flags & NSControlKeyMask) && (a & NSControlKeyMask)) filteredFlags |= NSControlKeyMask;
	
	if ((m & NSShiftKeyMask)) filteredFlags |= NSShiftKeyMask;
	else if ((flags & NSShiftKeyMask) && (a & NSShiftKeyMask)) filteredFlags |= NSShiftKeyMask;
	
	if ((m & NSFunctionKeyMask)) filteredFlags |= NSFunctionKeyMask;
	else if ((flags & NSFunctionKeyMask) && (a & NSFunctionKeyMask)) filteredFlags |= NSFunctionKeyMask;
	
	return filteredFlags;
}

- (BOOL)_validModifierFlags:(unsigned int)flags
{
	return (allowsKeyOnly ? YES : (((flags & NSCommandKeyMask) || (flags & NSAlternateKeyMask) || (flags & NSControlKeyMask) || (flags & NSShiftKeyMask) || (flags & NSFunctionKeyMask)) ? YES : NO));	
}

#pragma mark -

- (unsigned int)_filteredCocoaToCarbonFlags:(unsigned int)cocoaFlags
{
	unsigned int carbonFlags = ShortcutRecorderEmptyFlags;
	unsigned filteredFlags = [self _filteredCocoaFlags: cocoaFlags];
	
	if (filteredFlags & NSCommandKeyMask) carbonFlags |= cmdKey;
	if (filteredFlags & NSAlternateKeyMask) carbonFlags |= optionKey;
	if (filteredFlags & NSControlKeyMask) carbonFlags |= controlKey;
	if (filteredFlags & NSShiftKeyMask) carbonFlags |= shiftKey;
	
	// I couldn't find out the equivalent constant in Carbon, but apparently it must use the same one as Cocoa. -AK
	if (filteredFlags & NSFunctionKeyMask) carbonFlags |= NSFunctionKeyMask;
	
	return carbonFlags;
}

#pragma mark *** Internal Check ***

- (BOOL)_isEmpty
{
	return ( ![self _validModifierFlags: keyCombo.flags] || !SRStringForKeyCode( keyCombo.code ) );
}

#pragma mark *** Delegate pass-through ***

- (BOOL) shortcutValidator:(SRValidator *)validator isKeyCode:(signed short)keyCode andFlagsTaken:(unsigned int)flags reason:(NSString **)aReason;
{
    SEL selector = @selector( shortcutRecorderCell:isKeyCode:andFlagsTaken:reason: );
    if ( ( delegate ) && ( [delegate respondsToSelector:selector] ) )
    {
        return [delegate shortcutRecorderCell:self isKeyCode:keyCode andFlagsTaken:flags reason:aReason];
    }
    return NO;
}

@end