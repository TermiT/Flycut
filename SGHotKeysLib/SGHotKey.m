//
//  SGHotKey.m
//  SGHotKeyCenter
//
//  Created by Justin Williams on 7/26/09.
//  Copyright 2009 Second Gear. All rights reserved.
//

#import "SGHotKey.h"
#import "SGKeyCombo.h"

@implementation SGHotKey

@synthesize identifier;
@synthesize name;
@synthesize keyCombo;
@synthesize target;
@synthesize action;
@synthesize hotKeyID;

- (void)dealloc {
  [identifier release];
  [name release];
  [keyCombo release];
  [super dealloc];
}

- (id)init {
  return [self initWithIdentifier:nil keyCombo:nil];
}

- (id)initWithIdentifier:(id)theIdentifier keyCombo:(SGKeyCombo *)theCombo {
  if (self = [super init]) {
    self.identifier = theIdentifier;
    self.keyCombo = theCombo;
  }
  
  return self;  
}
- (id)initWithIdentifier:(id)theIdentifier keyCombo:(SGKeyCombo *)theCombo target:(id)theTarget action:(SEL)theAction {
  if (self = [super init]) {
    self.identifier = theIdentifier;
    self.keyCombo = theCombo;
    self.target = theTarget;
    self.action = theAction;
  }
  
  return self;
}

- (BOOL)matchesHotKeyID:(EventHotKeyID)theKeyID {
  return (hotKeyID.id == theKeyID.id) && (hotKeyID.signature == theKeyID.signature);
}

- (void)invoke {
  [self.target performSelector:self.action withObject:self];
}

- (void)setKeyCombo:(SGKeyCombo *)theKeyCombo {
  if (theKeyCombo == nil)
    theKeyCombo = [SGKeyCombo clearKeyCombo];
  
  keyCombo = [theKeyCombo retain];
}

- (NSString *)description {
	return [NSString stringWithFormat: @"<%@: %@, %@>", 
            NSStringFromClass([self class]), 
            self.identifier, 
            self.keyCombo];
}


@end
