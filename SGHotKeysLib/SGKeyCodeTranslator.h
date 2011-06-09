//
//  SGKeyCodeTranslator.h
//  SGHotKeyCenter
//
//  Created by Justin Williams on 7/26/09.
//  Copyright 2009 Second Gear. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <Carbon/Carbon.h>
#include <CoreServices/CoreServices.h>


@interface SGKeyCodeTranslator : NSObject {
  TISInputSourceRef keyboardLayout;
  const UCKeyboardLayout *keyboardLayoutData;
  NSUInteger keyTranslateState;
  UInt32 deadKeyState;
}

@property (nonatomic, assign) TISInputSourceRef keyboardLayout;

+ (id)currentTranslator;

- (id)initWithKeyboardLayout:(TISInputSourceRef)theLayout;
- (NSString *)translateKeyCode:(short)theKeyCode;

@end
