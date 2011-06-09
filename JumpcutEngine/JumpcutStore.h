//
//  JumpcutStore.h
//  Jumpcut
//  http://jumpcut.sourceforge.net/
//
//  Created by steve on Sun Dec 21 2003.
//  Copyright (c) 2003-2006 Steve Cook
//  Permission is hereby granted, free of charge, to any person obtaining a 
//  copy of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom the 
//  Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included 
//  in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE  WARRANTIES OF 
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
//  NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, 
//  DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
//  OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR 
//  THE USE OR OTHER DEALINGS IN THE SOFTWARE.

//
// The Jumpcut store is the component that actually holds the strings.
// It deals with everything regarding holding and returning the clippings,
// leaving all UI-related concerns to the other components.

// jcRememberNum and jcDisplayNum are slight misnomers; they're both "remember this many"
// limits, but they represent slightly different things.

// In Jumpcut 0.5, I should go through and fiddle with the nomenclature.

#import <Foundation/Foundation.h>

@interface JumpcutStore : NSObject {

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
-(int) displayLen;
-(int) jcListCount;
-(NSString *) clippingContentsAtPosition:(int)index;
-(NSString *) clippingDisplayStringAtPosition:(int)index;
-(NSString *) clippingTypeAtPosition:(int)index;
-(NSArray *) previousContents:(int)howMany;
-(NSArray *) previousDisplayStrings:(int)howMany;

// Add a clipping
-(void) addClipping:(NSString *)clipping ofType:(NSString *)type;

// Delete a clipping

// Delete all list clippings
-(void) clearList;

// Delete all named clippings
@end
