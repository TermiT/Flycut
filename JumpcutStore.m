//
//  JumpcutStore.m
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

#import "JumpcutStore.h"
#import "JumpcutClipping.h"

@implementation JumpcutStore

-(id) init
{
    return [self initRemembering:20
                displaying:10	
                withDisplayLength:40 ];
}

-(id) initRemembering:(int)nowRemembering
        displaying:(int)nowDisplaying
        withDisplayLength:(int)displayLength
{
    [super init];
    jcList = [[NSMutableArray alloc] init];
    [self setRememberNum:nowRemembering];
    [self setDisplayNum:nowDisplaying];
    [self setDisplayLen:displayLength];
    return self;
}

// Add a clipping
-(void) addClipping:(NSString *)clipping ofType:(NSString *)type{
    // Clipping object
    JumpcutClipping * newClipping;
	// Create clipping
    newClipping = [[JumpcutClipping alloc] initWithContents:clipping
												   withType:type
										  withDisplayLength:[self displayLen]];
	// Push it onto our recent clippings stack
	[jcList insertObject:newClipping atIndex:0];
	// Delete clippings older than jcRememberNum
	while ( [jcList count] > jcRememberNum ) {
		[jcList removeObjectAtIndex:jcRememberNum];
	}

    [newClipping release];
}

-(void) addClipping:(NSString *)clipping ofType:(NSString *)type withPBCount:(int *)pbCount
{
    [self addClipping:clipping ofType:type];
}

// Clear remembered and listed
-(void) clearList {
    NSMutableArray *emptyJCList;
    emptyJCList = [[NSMutableArray alloc] init];
    [jcList release];
    jcList = emptyJCList;
}


// Set various values
-(void) setRememberNum:(int)nowRemembering
{
    if ( nowRemembering  > 0 ) {
        jcRememberNum = nowRemembering;
		while ( [jcList count] > jcRememberNum ) {
			[jcList removeObjectAtIndex:jcRememberNum];
		}
    }
}

-(void) setDisplayNum:(int)nowDisplaying
{
    if ( nowDisplaying > 0 ) {
        jcDisplayNum = nowDisplaying;
    }
}

-(void) setDisplayLen:(int)newDisplayLength
{
    NSEnumerator *listEnum = [jcList objectEnumerator];
    JumpcutClipping *aClipping;
    
    if ( newDisplayLength > 0 ) {
        jcDisplayLen = newDisplayLength;
        while ( aClipping = [listEnum nextObject] ) {
            [aClipping setDisplayLength:newDisplayLength];
        }
    }
}

-(int) displayLen
{
    return jcDisplayLen;
}

-(int) jcListCount
{
    return [jcList count];
}

-(NSString *) clippingContentsAtPosition:(int)index
{
	if ( index >= [jcList count] ) {
		return nil;
	} else {
		return [NSString stringWithString:[[jcList objectAtIndex:index] contents]];
	}
}

-(NSString *) clippingDisplayStringAtPosition:(int)index
{
    return [[jcList objectAtIndex:index] displayString];
}

-(NSString *) clippingTypeAtPosition:(int)index
{
    NSString *returnString;
    returnString = [NSString stringWithString:[[jcList objectAtIndex:index] type]];
//    return [[jcList objectAtIndex:index] type];
    return returnString;
}

-(NSArray *) previousContents:(int)howMany
{
    NSRange theRange;
    NSArray *subArray;
    NSMutableArray *returnArray = [[[NSMutableArray alloc] init] autorelease];
    NSEnumerator *enumerator;
    JumpcutClipping *aClipping;
    theRange.location = 0;
    theRange.length = howMany;
    if ( howMany > [jcList count] ) {
        subArray = jcList;
    } else {
        subArray = [jcList subarrayWithRange:theRange];
    }
    enumerator = [subArray reverseObjectEnumerator];
    while ( aClipping = [enumerator nextObject] ) {
        [returnArray insertObject:[aClipping contents] atIndex:0];
    }
    return returnArray;
}

-(NSArray *) previousDisplayStrings:(int)howMany
{
    NSRange theRange;
    NSArray *subArray;
    NSMutableArray *returnArray = [[[NSMutableArray alloc] init] autorelease];
    NSEnumerator *enumerator;
    JumpcutClipping *aClipping;
    theRange.location = 0;
    theRange.length = howMany;
    if ( howMany > [jcList count] ) {
        subArray = jcList;
    } else {
        subArray = [jcList subarrayWithRange:theRange];
    }
    enumerator = [subArray reverseObjectEnumerator];
    while ( aClipping = [enumerator nextObject] ) {
        [returnArray insertObject:[aClipping displayString] atIndex:0];
    }
    return returnArray;
}

-(void) dealloc
{
    // Free preferences
    jcRememberNum = 0;
    jcDisplayNum = 0;
    jcDisplayLen = 0;

    // Free collections
    [jcList release];
   
    [super dealloc];
}

@end
