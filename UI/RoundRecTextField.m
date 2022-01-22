//
//  RoundRecTextField.m
//  Flycut
//
//  Flycut by Gennadiy Potapov and contributors. Based on Jumpcut by Steve Cook.
//  Copyright 2011 General Arcade. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <https://github.com/TermiT/Flycut> for details.
//
//

#import "RoundRecTextField.h"
#import "RoundRecBezierPath.h"

@implementation RoundRecTextField

// We may want to make this a more flexible class sometime by taking radius as an argument.

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
		_background = [[NSView alloc] initWithFrame:frame];
		[self addSubview:_background];

		[_background setWantsLayer:YES];
		[_background.layer setCornerRadius:8];

		_background.translatesAutoresizingMaskIntoConstraints = NO;
		[NSLayoutConstraint activateConstraints:@[
			[_background.topAnchor constraintEqualToAnchor:self.topAnchor],
			[_background.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
			[_background.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
			[_background.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
		]];

		_textField = [[NSTextField alloc] initWithFrame:frame];
		[self addSubview:_textField];
		[_textField setDrawsBackground:NO];

		// Set 8px leading and trailing padding.
		_textField.translatesAutoresizingMaskIntoConstraints = NO;
		[NSLayoutConstraint activateConstraints:@[
			[_textField.topAnchor constraintEqualToAnchor:self.topAnchor],
			[_textField.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
			[_textField.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:8],
			[_textField.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-8],
		]];
    }
    return self;
}

@end
