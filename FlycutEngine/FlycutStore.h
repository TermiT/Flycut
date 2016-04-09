//
//  FlycutStore.h
//  Flycut
//
//  Flycut by Gennadiy Potapov and contributors. Based on Jumpcut by Steve Cook.
//  Copyright 2011 General Arcade. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <https://github.com/TermiT/Flycut> for details.
//


#import <Foundation/Foundation.h>
#import "FlycutClipping.h"

@interface FlycutStore : NSObject {

    // Our various listener-related preferences
    int jcRememberNum;		// The max we will allow users to display; 20
    int jcDisplayNum;		// How many the user actually wants to display; defaults to 10
    int jcDisplayLen;		// How many characters to display in the menu; defaults to 37
    
    // hash -- key values to clippings
    // initially we will use PasteboardCount as the key value, but this will not be guaranteed
    // to be unique once we allow for saving. Instead, we should use seconds since day 0 or some such.
    // NSMutableDictionary * jcClippings;

    // array -- stores key values for the last jcRememberNum text pasteboard items
    NSMutableArray *jcList;
}

-(id) initRemembering:(int)nowRemembering
        displaying:(int)nowDisplaying
        withDisplayLength:(int)displayLength;

// Set various values
-(void) setRememberNum:(int)nowRemembering;
-(void) setDisplayNum:(int)nowDisplaying;
-(void) setDisplayLen:(int)newDisplayLength;

// Retrieve various values
-(int) rememberNum;
-(int) displayLen;
-(int) jcListCount;
-(FlycutClipping *) clippingAtPosition:(int)index;
-(NSString *) clippingContentsAtPosition:(int)index;
-(NSString *) clippingDisplayStringAtPosition:(int)index;
-(NSString *) clippingTypeAtPosition:(int)index;
-(NSArray *) previousContents:(int)howMany;
-(NSArray *) previousDisplayStrings:(int)howMany;
-(NSArray *) previousDisplayStrings:(int)howMany containing:(NSString*)search;
-(NSArray *) previousIndexes:(int)howMany containing:(NSString*)search; // This method is in newest-first order.

// Add a clipping
-(void) addClipping:(NSString *)clipping ofType:(NSString *)type fromAppLocalizedName:(NSString *)appLocalizedName fromAppBundleURL:(NSString *)bundleURL atTimestamp:(int) timestamp;
-(void) addClipping:(FlycutClipping*) clipping;

// Delete a clipping
-(void) clearItem:(int)index;

// Delete all list clippings
-(void) clearList;

// Merge all list clippings
-(void) mergeList;

// Move the clipping at index to the top
-(void) clippingMoveToTop:(int)index;

// Delete all named clippings
@end
