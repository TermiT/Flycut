//
//  PTHotKey.h
//  Protein
//
//  Created by Quentin Carnicelli on Sat Aug 02 2003.
//  Copyright (c) 2003 Quentin D. Carnicelli. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "PTKeyCombo.h"

@interface PTHotKey : NSObject
{
	NSString*		mIdentifier;
	NSString*		mName;
	PTKeyCombo*		mKeyCombo;
	id				mTarget;
	SEL				mAction;
}

- (id)initWithIdentifier: (id)identifier keyCombo: (PTKeyCombo*)combo;
- (id)init;

- (void)setIdentifier: (id)ident;
- (id)identifier;

- (void)setName: (NSString*)name;
- (NSString*)name;

- (void)setKeyCombo: (PTKeyCombo*)combo;
- (PTKeyCombo*)keyCombo;

- (void)setTarget: (id)target;
- (id)target;
- (void)setAction: (SEL)action;
- (SEL)action;

- (void)invoke;

@end
