//
//  BezelWindow.h
//  Jumpcut
//
//  Created by Steve Cook on 4/3/06.
//  Copyright 2006 Steve Cook. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <http://jumpcut.sourceforge.net/> for details.

#import <Cocoa/Cocoa.h>
#import "RoundRecBezierPath.h"
#import "RoundRecTextField.h"


@interface BezelWindow : NSWindow {
	// "n of n" text in bezel
	NSString			*charString; // Slightly misleading, as this can be longer than one character
	NSString			*title;
	// Clipping text shown in bezel
	NSString			*bezelText;
	NSString			*sourceText;
	NSString			*dateText;
	NSImage			 *sourceIconImage;
	NSImage				*icon;
	Boolean			 showSourceField;
	NSImageView		 *sourceIcon;
	RoundRecTextField	*sourceFieldBackground;
	RoundRecTextField	*sourceFieldApp;
	RoundRecTextField	*sourceFieldDate;
	RoundRecTextField	*textField;
	RoundRecTextField	*charField;
	NSImageView			*iconView;
	id					delegate;
    Boolean             color;
}

- (id)initWithContentRect:(NSRect)contentRect
				styleMask:(NSUInteger)aStyle
				  backing:(NSBackingStoreType)bufferingType
					defer:(BOOL)flag
			   showSource:(BOOL)showSource;

- (NSColor *)roundedBackgroundWithRect:(NSRect)bgRect withRadius:(float)radius withAlpha:(float)alpha;
- (NSColor *)sizedBezelBackgroundWithRadius:(float)radius withAlpha:(float)alpha;

- (NSString *)title;
- (void)setTitle:(NSString *)newTitle;
- (NSString *)text;
- (void)setText:(NSString *)newText;
- (void)setColor:(BOOL)value;
- (void)setCharString:(NSString *)newChar;
- (void)setAlpha:(float)newValue;
- (void)setSource:(NSString *)newSource;
- (void)setDate:(NSString *)newDate;
- (void)setSourceIcon:(NSImage *)newSourceIcon;

- (id)delegate;
- (void)setDelegate:(id)newDelegate;

@end
