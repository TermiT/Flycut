//
//  FlycutClipping.m
//  Flycut
//
//  Flycut by Gennadiy Potapov and contributors. Based on Jumpcut by Steve Cook.
//  Copyright 2011 General Arcade. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <https://github.com/TermiT/Flycut> for details.
//


#import "FlycutClipping.h"

@implementation FlycutClipping

-(id) init
{
    [self initWithContents:@""
                  withType:@""
         withDisplayLength:40
      withAppLocalizedName:@""
          withAppBundleURL:nil
             withTimestamp:0];
    return self;
}

-(id) initWithContents:(NSString *)contents withType:(NSString *)type withDisplayLength:(int)displayLength withAppLocalizedName:(NSString *)localizedName withAppBundleURL:(NSString*)bundleURL withTimestamp:(NSInteger)timestamp
{
    [super init];
    clipContents = [[[NSString alloc] init] retain];
    clipDisplayString = [[[NSString alloc] init] retain];
    clipType = [[[NSString alloc] init] retain];

    [self setContents:contents setDisplayLength:displayLength];
    [self setType:type];
    [self setAppLocalizedName:localizedName];
    [self setAppBundleURL:bundleURL];
    [self setTimestamp:timestamp];
    [self setHasName:false];
    
    return self;
}

/* - (id)initWithCoder:(NSCoder *)coder
{
    NSString * newContents;
    int newDisplayLength;
    NSString *newType;
    BOOL newHasName;
    if ( self = [super init]) {
        newContents = [NSString stringWithString:[coder decodeObject]];
        [coder decodeValueOfObjCType:@encode(int) at:&newDisplayLength];
        newType = [NSString stringWithString:[coder decodeObject]];
        [coder decodeValueOfObjCType:@encode(BOOL) at:&newHasName];
        [self 	     setContents:newContents
                setDisplayLength:newDisplayLength];
        [self setType:newType];
        [self setHasName:newHasName];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    int codeDisplayLength = [self displayLength];
    BOOL codeHasName = [self hasName];
    [coder encodeObject:[self contents]];
    [coder encodeValueOfObjCType:@encode(int) at:&codeDisplayLength];
    [coder encodeObject:[self type]];
    [coder encodeValueOfObjCType:@encode(BOOL) at:&codeHasName];
} */

-(void) setContents:(NSString *)newContents setDisplayLength:(int)newDisplayLength
{
    id old = clipContents;
    [newContents retain];
    clipContents = newContents;
    [old release];
    if ( newDisplayLength  > 0 ) {
        clipDisplayLength = newDisplayLength;
    }
   [self resetDisplayString];
}

-(void) setContents:(NSString *)newContents
{
    id old = clipContents;
    [newContents retain];
    clipContents = newContents;
    [old release];
    [self resetDisplayString];
}

-(void) setType:(NSString *)newType
{
    id old = clipType;
    [newType retain];
    clipType = newType;
    [old release];
}

-(void) setDisplayLength:(int)newDisplayLength
{
    if ( newDisplayLength  > 0 ) {
        clipDisplayLength = newDisplayLength;
        [self resetDisplayString];
    }
}

-(void) setAppLocalizedName:(NSString *)new
{
    id old = appLocalizedName;
    [new retain];
    appLocalizedName = new;
    [old release];
}

-(void) setAppBundleURL:(NSString *)new
{
    id old = appBundleURL;
    [new retain];
    appBundleURL = new;
    [old release];
}

-(void) setTimestamp:(NSInteger)newTimestamp
{
    clipTimestamp = newTimestamp;
}

-(void) setHasName:(BOOL)newHasName
{
        clipHasName = newHasName;
}

-(void) resetDisplayString
{
    NSString *newDisplayString;

	// We're resetting the display string, so release the old one.
    [clipDisplayString release];

    // First, trim newlines/whitespace
    newDisplayString = [clipContents stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    // We want to replace newlines with spaces
    newDisplayString = [[newDisplayString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" "];

    // shorten it if it's too long
    if ( [newDisplayString length] > clipDisplayLength ) {
        newDisplayString = [[NSString stringWithString:[newDisplayString substringToIndex: clipDisplayLength]] stringByAppendingString:@"…"];
    }

    [newDisplayString retain];
    clipDisplayString = newDisplayString;
}

-(NSString *) description
{
    NSString *description = [[super description] stringByAppendingString:@": "];
    description = [description stringByAppendingString:[self displayString]];   
    return description;
}

-(FlycutClipping *) clipping
{
    return self;
}

-(NSString *) contents
{
//    NSString *returnClipContents;
//    returnClipContents = [NSString stringWithString:clipContents];
//    return returnClipContents;
    return clipContents;
}

-(NSString *) appLocalizedName
{
    return appLocalizedName;
}

-(NSString *) appBundleURL
{
    return appBundleURL;
}

-(NSInteger) timestamp
{
    return clipTimestamp;
}

-(int) displayLength
{
    return clipDisplayLength;
}

-(NSString *) type
{
    return clipType;
}

-(NSString *) displayString
{
    // QUESTION
    // Why doesn't the below work?
    // NSString *returnClipDisplayString;
    // returnClipDisplayString = [NSString stringWithString:clipDisplayString];
    // return returnClipDisplayString;
    return clipDisplayString;
}

-(BOOL) hasName
{
    return clipHasName;
}

- (BOOL)isEqual:(id)other {
    if (other == self)
        return YES;
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
    FlycutClipping * otherClip = (FlycutClipping *)other;
    return ([self.type isEqualToString:otherClip.type] &&
            [self.displayString isEqualToString:otherClip.displayString] &&
            (self.displayLength == otherClip.displayLength) &&
            [self.contents isEqualToString:otherClip.contents]);
}



-(void) dealloc
{
    [clipContents release];
    [clipType release];
    [appLocalizedName release];
    [appBundleURL release];
    clipDisplayLength = 0;
    [clipDisplayString release];
    clipHasName = 0;
    [super dealloc];
}
@end
