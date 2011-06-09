//
//  SGKeyCodeTranslator.m
//  SGHotKeyCenter
//
//  Created by Justin Williams on 7/26/09.
//  Copyright 2009 Second Gear. All rights reserved.
//

#import "SGKeyCodeTranslator.h"


@implementation SGKeyCodeTranslator

@synthesize keyboardLayout;

+ (id)currentTranslator {
  static SGKeyCodeTranslator *currentTranslator = nil;
  TISInputSourceRef currentKeyboardLayout = TISCopyCurrentKeyboardInputSource();
  
  if (currentTranslator == nil) {
    currentTranslator = [[SGKeyCodeTranslator alloc] initWithKeyboardLayout:currentKeyboardLayout];
  } else if ([currentTranslator keyboardLayout] != currentKeyboardLayout) {
    [currentTranslator release];
    currentTranslator = [[SGKeyCodeTranslator alloc] initWithKeyboardLayout:currentKeyboardLayout];
  }
  
  return currentTranslator;
}

- (id)initWithKeyboardLayout:(TISInputSourceRef)theLayout {
  if ((self = [super init]) != nil) {
    keyboardLayout = theLayout;
    CFDataRef uchr = TISGetInputSourceProperty(keyboardLayout, kTISPropertyUnicodeKeyLayoutData);
    keyboardLayoutData = (const UCKeyboardLayout *)CFDataGetBytePtr(uchr);
  }  
  
  return self;
}


- (NSString *)translateKeyCode:(short)keyCode {
  UniCharCount maxStringLength = 4, actualStringLength;
  UniChar unicodeString[4];
  
  UCKeyTranslate(keyboardLayoutData, 
                           keyCode, 
                           kUCKeyActionDisplay, 
                           0, 
                           LMGetKbdType(), 
                           kUCKeyTranslateNoDeadKeysBit, 
                           &deadKeyState, 
                           maxStringLength, 
                           &actualStringLength, 
                           unicodeString);
  
  return [NSString stringWithCharacters:unicodeString length:1];
}

@end
