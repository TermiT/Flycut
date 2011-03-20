//
//  PTKeyCombo.h
//  Protein
//
//  Created by Quentin Carnicelli on Sat Aug 02 2003.
//  Copyright (c) 2003 Quentin D. Carnicelli. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface PTKeyCombo : NSObject <NSCopying>
{
	int	mKeyCode;
	int	mModifiers;
}

+ (id)clearKeyCombo;
+ (id)keyComboWithKeyCode: (int)keyCode modifiers: (int)modifiers;
- (id)initWithKeyCode: (int)keyCode modifiers: (int)modifiers;

- (id)initWithPlistRepresentation: (id)plist;
- (id)plistRepresentation;

- (BOOL)isEqual: (PTKeyCombo*)combo;

- (int)keyCode;
- (int)modifiers;

- (BOOL)isClearCombo;
- (BOOL)isValidHotKeyCombo;

@end

@interface PTKeyCombo (UserDisplayAdditions)

- (NSString*)description;

@end