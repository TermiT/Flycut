//
//  FlycutClipping.h
//  Flycut
//
//  Flycut by Gennadiy Potapov and contributors. Based on Jumpcut by Steve Cook.
//  Copyright 2011 General Arcade. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <https://github.com/TermiT/Flycut> for details.
//

#import <Foundation/Foundation.h>

@interface FlycutClipping : NSObject {
// What must a clipping hold?
// The text
    NSString * clipContents;
// The text type
    NSString * clipType;
// The display length
    int clipDisplayLength;
// The display string
    NSString * clipDisplayString;
// Does it have a name?
    BOOL clipHasName;
// The app name it came from
    NSString * appLocalizedName;
// The the bunle URL of the app it came from
    NSString * appBundleURL;
// The time
    int clipTimestamp;
}

-(id) initWithContents:(NSString *)contents withType:(NSString *)type withDisplayLength:(int)displayLength withAppLocalizedName:(NSString *)localizedName withAppBundleURL:(NSString *)bundleURL withTimestamp:(int)timestamp;
/* -(id) initWithCoder:(NSCoder *)coder;
-(void) decodeWithCoder:(NSCoder *)coder; */
-(NSString *) description;

// set values
-(void) setContents:(NSString *)newContents setDisplayLength:(int)newDisplayLength;
-(void) setContents:(NSString *)newContents;
-(void) setType:(NSString *)newType;
-(void) setDisplayLength:(int)newDisplayLength;
-(void) setHasName:(BOOL)newHasName;

// Retrieve values
-(FlycutClipping *) clipping;
-(NSString *) contents;
-(int) displayLength;
-(NSString *) displayString;
-(NSString *) type;
-(NSString *) appLocalizedName;
-(NSString *) appBundleURL;
-(int) timestamp;
-(BOOL) hasName;

// Additional functions
-(void) resetDisplayString;

@end
