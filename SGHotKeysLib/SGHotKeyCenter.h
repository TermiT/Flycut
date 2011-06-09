//
//  SGHotKeyCenter.h
//  SGHotKeyCenter
//
//  Created by Justin Williams on 7/26/09.
//  Copyright 2009 Second Gear. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class SGHotKey;

@interface SGHotKeyCenter : NSObject {
  NSMutableDictionary *hotKeys; // Keys are NSValue of EventHotKeyRef
  BOOL eventHandlerInstalled;
  BOOL hasInited;
}

+ (SGHotKeyCenter *)sharedCenter;

- (BOOL)registerHotKey:(SGHotKey *)theHotKey;
- (void)unregisterHotKey:(SGHotKey *)theHotKey;

- (NSArray *)allHotKeys;
- (SGHotKey *)hotKeyWithIdentifier:(id)theIdentifier;

@end
