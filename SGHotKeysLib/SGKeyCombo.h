//
//  SGKeyCombo.h
//  SGHotKeyCenter
//
//  Created by Justin Williams on 7/26/09.
//  Copyright 2009 Second Gear. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SGKeyCombo : NSObject {
  NSInteger keyCode;
  NSInteger modifiers;
}

@property (nonatomic, assign) NSInteger keyCode;
@property (nonatomic, assign) NSInteger modifiers;

+ (id)clearKeyCombo;
+ (id)keyComboWithKeyCode:(NSInteger)theKeyCode modifiers:(NSInteger)theModifiers;
- (id)initWithKeyCode:(NSInteger)theKeyCode modifiers:(NSInteger)theModifiers;

- (id)initWithPlistRepresentation:(id)thePlist;
- (id)plistRepresentation;

- (BOOL)isEqual:(SGKeyCombo *)theCombo;

- (BOOL)isClearCombo;
- (BOOL)isValidHotKeyCombo;

@end

@interface SGKeyCombo (UserDisplayAdditions)
- (NSString *)description;
- (NSString *)keyCodeString;
- (NSUInteger)modifierMask;
@end

