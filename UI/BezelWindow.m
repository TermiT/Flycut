//
//  BezelWindow.m
//  Flycut
//
//  Flycut by Gennadiy Potapov and contributors. Based on Jumpcut by Steve Cook.
//  Copyright 2011 General Arcade. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <https://github.com/TermiT/Flycut> for details.
//

#import "BezelWindow.h"

static const float lineHeight = 16;

@implementation BezelWindow

- (id)initWithContentRect:(NSRect)contentRect
				styleMask:(NSUInteger)aStyle
  				backing:(NSBackingStoreType)bufferingType
					defer:(BOOL)flag
			   showSource:(BOOL)showSource {

	self = [super initWithContentRect:contentRect
							styleMask:NSNonactivatingPanelMask | NSBorderlessWindowMask
							backing:NSBackingStoreBuffered
							defer:NO];
	if ( self )
	{
		//set this window to be on top of all other windows
		[self setLevel:NSScreenSaverWindowLevel];

		[self setOpaque:NO];
		[self setAlphaValue:1.0];
		[self setOpaque:NO];
		[self setHasShadow:NO];
		[self setMovableByWindowBackground:NO];
        [self setColor:NO];
		[self setBackgroundColor:[self backgroundColor]];
        showSourceField = showSource;

        if (showSourceField)
        {
            sourceIcon = [[NSImageView alloc] initWithFrame: [self iconFrame]];
            [[self contentView] addSubview:sourceIcon];
            [sourceIcon setEditable:NO];

            sourceFieldBackground = [[RoundRecTextField alloc] initWithFrame:[self sourceFrame]];
            [[self contentView] addSubview:sourceFieldBackground];
            [sourceFieldBackground setEditable:NO];
            [sourceFieldBackground setTextColor:[NSColor whiteColor]];
            [sourceFieldBackground setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:.45]];
            [sourceFieldBackground setDrawsBackground:YES];
            [sourceFieldBackground setBordered:NO];

            sourceFieldApp = [[RoundRecTextField alloc] initWithFrame:[self sourceFrameLeft]];
            [[self contentView] addSubview:sourceFieldApp];
            [sourceFieldApp setEditable:NO];
            [sourceFieldApp setTextColor:[NSColor whiteColor]];
            [sourceFieldApp setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:0]];
            [sourceFieldApp setDrawsBackground:YES];
            [sourceFieldApp setBordered:NO];
            [sourceFieldApp setAlignment:NSLeftTextAlignment];

            NSMutableParagraphStyle *textParagraph = [[NSMutableParagraphStyle alloc] init];
            [textParagraph setLineSpacing:100.0];

            NSDictionary *attrDic = [NSDictionary dictionaryWithObjectsAndKeys:textParagraph, NSParagraphStyleAttributeName, nil];
            NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:@"" attributes:attrDic];
            [sourceFieldApp setAllowsEditingTextAttributes:YES];
            [sourceFieldApp setAttributedStringValue:attrString];

            NSFont *font = [sourceFieldApp font];
            NSFont *newFont = [NSFont fontWithName:[font fontName] size:font.pointSize*3/2];
            [sourceFieldApp setFont:newFont];

            sourceFieldDate = [[RoundRecTextField alloc] initWithFrame:[self sourceFrameRight]];
            [[self contentView] addSubview:sourceFieldDate];
            [sourceFieldDate setEditable:NO];
            [sourceFieldDate setTextColor:[NSColor whiteColor]];
            [sourceFieldDate setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:0]];
            [sourceFieldDate setDrawsBackground:YES];
            [sourceFieldDate setBordered:NO];
            [sourceFieldDate setAlignment:NSRightTextAlignment];
            font = [sourceFieldDate font];
            newFont = [NSFont fontWithName:[font fontName] size:font.pointSize*5/4];
            [sourceFieldDate setFont:newFont];
        }

		NSRect textFrame = [self textFrame];
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

		NSRect charFrame = [self charFrame];
		charField = [[RoundRecTextField alloc] initWithFrame:charFrame];
		[[self contentView] addSubview:charField];
		[charField setEditable:NO];
		[charField setTextColor:[NSColor whiteColor]];
		[charField setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:.45]];
		[charField setDrawsBackground:YES];
		[charField setBordered:NO];
		[charField setAlignment:NSCenterTextAlignment];
        [charField setStringValue:@"Empty"];

		[self setInitialFirstResponder:textField];         
		return self;
	}
	return nil;
}


- (void) update  {
    [super update];
    [self setBackgroundColor:[self backgroundColor]];

    Boolean savedShowSourceField = showSourceField;
    if (nil == sourceText || 0 == sourceText.length)
        showSourceField = false;

    NSRect textFrame = [self textFrame];
    [textField setFrame:textFrame];
    NSRect charFrame = [self charFrame];
    [charField setFrame:charFrame];
    if (showSourceField)
        [sourceFieldBackground setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:.45]];
    else if ( nil != sourceFieldApp )
        [sourceFieldBackground setBackgroundColor:[NSColor colorWithCalibratedWhite:0.1 alpha:0]];
    
    showSourceField = savedShowSourceField;

}

-(NSRect) iconFrame
{
    NSRect frame = [self textFrame];
    frame.origin.y += frame.size.height + 5;
    frame.size.height = 1.8 * lineHeight;
    frame.size.width = frame.size.height;
    return frame;
}

-(NSRect) sourceFrame
{
    NSRect frame = [self textFrame];
    frame.origin.y += frame.size.height + 5;
    frame.size.height = 1.8 * lineHeight;
    frame.origin.x += frame.size.height + 5;
    frame.size.width -= frame.size.height + 5;
    return frame;
}

-(NSRect) sourceFrameLeft
{
    NSRect frame = [self sourceFrame];
    frame.size.width = frame.size.width * 1 / 3 - 5;
    frame.origin.x += 5;
    return frame;
}

-(NSRect) sourceFrameRight
{
    NSRect frame = [self sourceFrame];
    frame.size.height -= 0.3 * lineHeight;
    frame.origin.x += frame.size.width * 1 / 3 + 10;
    frame.size.width = frame.size.width * 2 / 3 - 10;
    return frame;
}

-(NSRect) textFrame
{
    int adjustHeight = 0;
    if (showSourceField) adjustHeight = 1.8 * lineHeight;
    return NSMakeRect(12, 36, self.frame.size.width - 24, self.frame.size.height - 50 - adjustHeight);
}

-(NSRect) charFrame
{
    return NSMakeRect(([self frame].size.width - (3 * lineHeight)) / 2, 7, 4 * lineHeight, 1.2 * lineHeight);
}

-(NSColor*) backgroundColor
{
    return [self sizedBezelBackgroundWithRadius:25.0 withAlpha:[[NSUserDefaults standardUserDefaults] floatForKey:@"bezelAlpha"]];
}

- (void) setAlpha:(float)newValue
{
	[self setBackgroundColor:[self backgroundColor]];
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
    // The Bezel gets slow when newText is huge.  Probably the retain.
    // Since we can't see that much of it anyway, trim to 2000 characters.
    if ([newText length] > 2000)
        newText = [newText substringToIndex:2000];
	[newText retain];
	[bezelText release];
	bezelText = newText;
	[textField setStringValue:bezelText];
}

- (void)setSourceIcon:(NSImage *)newSourceIcon
{
	if (!showSourceField)
		return;
	[newSourceIcon retain];
	[sourceIconImage release];
	sourceIconImage = newSourceIcon;
	[sourceIcon setImage:sourceIconImage];
}

- (void)setSource:(NSString *)newSource
{
	if (!showSourceField)
		return;

	// Ensure that the source will fit in the screen space available, and truncate nicely if need be.
	NSDictionary *attributes = @{NSFontAttributeName: sourceFieldApp.font};
	CGSize size = [newSource sizeWithAttributes:attributes]; // How big is this string when drawn in this font?
	if (size.width >= sourceFieldApp.frame.size.width - 5)
	{
		newSource = [NSString stringWithFormat:@"%@...", newSource];
		do
		{
			newSource = [NSString stringWithFormat:@"%@...", [newSource substringToIndex:[newSource length] - 4]];
			size = [newSource sizeWithAttributes:attributes];
		} while (size.width >= sourceFieldApp.frame.size.width - 5);
	}

	[newSource retain];
	[sourceText release];
	sourceText = newSource;
	[sourceFieldApp setStringValue:sourceText];
}

- (void)setDate:(NSString *)newDate
{
	if (!showSourceField)
		return;
	[newDate retain];
	[dateText release];
	dateText = newDate;
	[sourceFieldDate setStringValue:dateText];
}

- (void)setColor:(BOOL)value
{
    color=value;
}


- (NSColor *)roundedBackgroundWithRect:(NSRect)bgRect withRadius:(float)radius withAlpha:(float)alpha
{
	NSImage *bg = [[NSImage alloc] initWithSize:bgRect.size];
	[bg lockFocus];
	// I'm not at all clear why this seems to work
	NSRect dummyRect = NSMakeRect(0, 0, [bg size].width, [bg size].height);
	NSBezierPath *roundedRec = [NSBezierPath bezierPathWithRoundRectInRect:dummyRect radius:radius];
    if (color)
        [[NSColor colorWithCalibratedRed:0.6 green:0.6 blue:0 alpha:alpha ] set];
    else
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

- (void)scrollWheel:(NSEvent *)theEvent
{
    if ( [self delegate] )
    {
        [delegate performSelector:@selector(processBezelMouseEvents:) withObject:theEvent];
    }
}

 - (void)mouseUp:(NSEvent *)theEvent
{
    if ( [self delegate] )
    {
       [delegate performSelector:@selector(processBezelMouseEvents:) withObject:theEvent];
    }
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
