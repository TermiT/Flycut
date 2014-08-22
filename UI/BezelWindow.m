//
//  BezelWindow.m
//  Jumpcut
//
//  Created by Steve Cook on 4/3/06.
//  Copyright 2006 Steve Cook. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <http://jumpcut.sourceforge.net/> for details.

#import "BezelWindow.h"
#import "DBUserDefaults.h"

static const float lineHeight = 16;

@implementation BezelWindow

- (id)initWithContentRect:(NSRect)contentRect
				styleMask:(NSUInteger)aStyle
  				backing:(NSBackingStoreType)bufferingType
					defer:(BOOL)flag {
    
	self = [super initWithContentRect:contentRect
							styleMask:NSBorderlessWindowMask
							backing:NSBackingStoreBuffered
							defer:NO];
	if ( self )
	{
		[self setOpaque:NO];
		[self setAlphaValue:1.0];
		[self setOpaque:NO];
		[self setHasShadow:NO];
		[self setMovableByWindowBackground:NO];
		[self setBackgroundColor:[self sizedBezelBackgroundWithRadius:25.0 withAlpha:[[DBUserDefaults standardUserDefaults] floatForKey:@"bezelAlpha"]]];
		NSRect textFrame = NSMakeRect(12, 36, self.frame.size.width - 24, self.frame.size.height - 50);
		textField = [[RoundRecTextField alloc] initWithFrame:textFrame];
		[[self contentView] addSubview:textField];
		[textField setEditable:NO];
		//[[textField cell] setScrollable:YES];
		//[[textField cell] setWraps:NO];
		[textField setTextColor:[NSColor whiteColor]];
		[textField setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:.45]];
		[textField setDrawsBackground:YES];
		[textField setBordered:NO];
		[textField setAlignment:NSLeftTextAlignment];
		NSRect charFrame = NSMakeRect(([self frame].size.width - (3 * lineHeight)) / 2, 7, 4 * lineHeight, 1.2 * lineHeight);
		charField = [[RoundRecTextField alloc] initWithFrame:charFrame];
		[[self contentView] addSubview:charField];
		[charField setEditable:NO];
		[charField setTextColor:[NSColor whiteColor]];
		[charField setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:.45]];
		[charField setDrawsBackground:YES];
		[charField setBordered:NO];
		[charField setAlignment:NSCenterTextAlignment];
		_preferencesBtn = [[[NSButton alloc] initWithFrame:NSMakeRect(self.frame.size.width - 36, 10, 16, 16)] retain];
		[self.preferencesBtn setImage:[NSImage imageNamed:@"preferences"]];
		[self.preferencesBtn setBordered:NO];
		[self.preferencesBtn setButtonType:NSMomentaryChangeButton];
		[[self contentView] addSubview:self.preferencesBtn];
		[self setInitialFirstResponder:textField];
		return self;
	}
	return nil;
}


- (void) update  {
    [super update];
    [self setBackgroundColor:[self sizedBezelBackgroundWithRadius:25.0 withAlpha:[[DBUserDefaults standardUserDefaults] floatForKey:@"bezelAlpha"]]];
    NSRect textFrame = NSMakeRect(12, 36, self.frame.size.width - 24, self.frame.size.height - 50);
    [textField setFrame:textFrame];
    NSRect charFrame = NSMakeRect(([self frame].size.width - (3 * lineHeight)) / 2, 7, 4 * lineHeight, 1.2 * lineHeight);
    [charField setFrame:charFrame];
    [self.preferencesBtn setFrame:NSMakeRect(self.frame.size.width - 36, 10, 16, 16)];
}

- (void) setAlpha:(float)newValue
{
	[self setBackgroundColor:[self sizedBezelBackgroundWithRadius:25.0 withAlpha:[[DBUserDefaults standardUserDefaults] floatForKey:@"bezelAlpha"]]];
	[[self contentView] setNeedsDisplay:YES];
}

- (NSString *)title
{
	return title;
}

- (void)setTitle:(NSString *)newTitle
{
	[newTitle retain];
	[title release];
	title = newTitle;
}

- (NSString *)text
{
	return bezelText;
}

- (void)setCharString:(NSString *)newChar
{
	[newChar retain];
	[charString release];
	charString = newChar;
	[charField setStringValue:charString];
}

- (void)setText:(NSString *)newText
{
	[newText retain];
	[bezelText release];
	bezelText = newText;
	[textField setStringValue:bezelText];
}


- (NSColor *)roundedBackgroundWithRect:(NSRect)bgRect withRadius:(float)radius withAlpha:(float)alpha
{
	NSImage *bg = [[NSImage alloc] initWithSize:bgRect.size];
	[bg lockFocus];
	// I'm not at all clear why this seems to work
	NSRect dummyRect = NSMakeRect(0, 0, [bg size].width, [bg size].height);
	NSBezierPath *roundedRec = [NSBezierPath bezierPathWithRoundRectInRect:dummyRect radius:radius];
	[[NSColor colorWithCalibratedWhite:0.1 alpha:alpha] set];
    [roundedRec fill];
	[bg unlockFocus];
	return [NSColor colorWithPatternImage:[bg autorelease]];
}

- (NSColor *)sizedBezelBackgroundWithRadius:(float)radius withAlpha:(float)alpha
{
	return [self roundedBackgroundWithRect:[self frame] withRadius:radius withAlpha:alpha];
}

-(BOOL)canBecomeKeyWindow
{
	return YES;
}

- (void)dealloc
{
	[textField release];
	[charField release];
	[iconView release];
	[super dealloc];
}

- (BOOL)performKeyEquivalent:(NSEvent*) theEvent
{
	if ( [self delegate] )
	{
		[delegate performSelector:@selector(processBezelKeyDown:) withObject:theEvent];
		return YES;
	}
	return NO;
}

- (void)keyDown:(NSEvent *)theEvent {
	if ( [self delegate] )
	{
		[delegate performSelector:@selector(processBezelKeyDown:) withObject:theEvent];
	}
}

- (void)flagsChanged:(NSEvent *)theEvent {
	if ( !    ( [theEvent modifierFlags] & NSCommandKeyMask )
		 && ! ( [theEvent modifierFlags] & NSAlternateKeyMask )
		 && ! ( [theEvent modifierFlags] & NSControlKeyMask )
		 && ! ( [theEvent modifierFlags] & NSShiftKeyMask )
		 && [ self delegate ]
		 )
	{
		[delegate performSelector:@selector(metaKeysReleased)];
	}
}
		
- (id)delegate {
    return delegate;
}

- (void)setDelegate:(id)newDelegate {
    delegate = newDelegate;
}

@end
