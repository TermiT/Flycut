//
//  PTKeyCodeTranslator.m
//  Chercher
//
//  Created by Finlay Dobbie on Sat Oct 11 2003.
//  Copyright (c) 2003 Cliché Software. All rights reserved.
//

#import "PTKeyCodeTranslator.h"


@implementation PTKeyCodeTranslator

+ (id)currentTranslator
{
    static PTKeyCodeTranslator *current = nil;
    KeyboardLayoutRef currentLayout;
    OSStatus err = KLGetCurrentKeyboardLayout( &currentLayout );
    if (err != noErr) return nil;
    
    if (current == nil) {
        current = [[PTKeyCodeTranslator alloc] initWithKeyboardLayout:currentLayout];
    } else if ([current keyboardLayout] != currentLayout) {
        [current release];
        current = [[PTKeyCodeTranslator alloc] initWithKeyboardLayout:currentLayout];
    }
    return current;
}

- (id)initWithKeyboardLayout:(KeyboardLayoutRef)aLayout
{
    if (self = [super init]) {
        OSStatus err;
        keyboardLayout = aLayout;
        err = KLGetKeyboardLayoutProperty( aLayout, kKLKind, (const void **)&keyLayoutKind );
        if (err != noErr) return nil;

        if (keyLayoutKind == kKLKCHRKind) {
            err = KLGetKeyboardLayoutProperty( keyboardLayout, kKLKCHRData, (const void **)&KCHRData );
            if (err != noErr) return nil;
        } else {
            err = KLGetKeyboardLayoutProperty( keyboardLayout, kKLuchrData, (const void **)&uchrData );
            if (err !=  noErr) return nil;
        }
    }
    
    return self;
}

- (NSString *)translateKeyCode:(short)keyCode {
    if (keyLayoutKind == kKLKCHRKind) {
        UInt32 charCode = KeyTranslate( KCHRData, keyCode, &keyTranslateState );
        char theChar = ((char *)&charCode)[3];
        return [[[NSString alloc] initWithData:[NSData dataWithBytes:&theChar length:1] encoding:NSMacOSRomanStringEncoding] autorelease];
    } else {
        UniCharCount maxStringLength = 4, actualStringLength;
        UniChar unicodeString[4];
        OSStatus err;
        err = UCKeyTranslate( uchrData, keyCode, kUCKeyActionDisplay, 0xFF, LMGetKbdType(), kUCKeyTranslateNoDeadKeysBit, &deadKeyState, maxStringLength, &actualStringLength, unicodeString );
        return [NSString stringWithCharacters:unicodeString length:1];
    }    
}

- (KeyboardLayoutRef)keyboardLayout {
    return keyboardLayout;
}

- (NSString *)description {
    NSString *kind;
    if (keyLayoutKind == kKLKCHRKind)
        kind = @"KCHR";
    else
        kind = @"uchr";
    
    NSString *layoutName;
    KLGetKeyboardLayoutProperty( keyboardLayout, kKLLocalizedName, (const void **)&layoutName );
    return [NSString stringWithFormat:@"PTKeyCodeTranslator layout=%@ (%@)", layoutName, kind];
}

@end
