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
-(void) addClipping:(NSString *)clipping ofType:(NSString *)type fromAppLocalizedName:(NSString *)appLocalizedName fromAppBundleURL:(NSString *)bundleURL atTimestamp:(int) timestamp{
    if ([clipping length] == 0) {
        return;
    }
    // Clipping object
    JumpcutClipping * newClipping;
	// Create clipping
    newClipping = [[JumpcutClipping alloc] initWithContents:clipping
												   withType:type
										  withDisplayLength:[self displayLen]
									   withAppLocalizedName:appLocalizedName
										   withAppBundleURL:bundleURL
											  withTimestamp:timestamp];
	
	[self addClipping:newClipping];
	
	[newClipping release];
}

-(void) addClipping:(JumpcutClipping*) clipping{
    if ([jcList containsObject:clipping] && [[[NSUserDefaults standardUserDefaults] valueForKey:@"removeDuplicates"] boolValue]) {
        [jcList removeObject:clipping];
    }
    // Push it onto our recent clippings stack
	[jcList insertObject:clipping atIndex:0];
	// Delete clippings older than jcRememberNum
	while ( [jcList count] > jcRememberNum ) {
		[jcList removeObjectAtIndex:jcRememberNum];
	}
}

-(void) addClipping:(NSString *)clipping ofType:(NSString *)type withPBCount:(int *)pbCount
{
    [self addClipping:clipping ofType:type fromAppLocalizedName:@"PBCount" fromAppBundleURL:nil atTimestamp:0];
}

// Clear remembered and listed
-(void) clearList {
    NSMutableArray *emptyJCList;
    emptyJCList = [[NSMutableArray alloc] init];
    [jcList release];
    jcList = emptyJCList;
}

-(void) mergeList {
    NSString *merge = [[[[jcList reverseObjectEnumerator] allObjects] valueForKey:@"clipContents"] componentsJoinedByString:@"\n"];
    [self addClipping:merge ofType:NSStringFromClass([merge class]) fromAppLocalizedName:@"Merge" fromAppBundleURL:nil atTimestamp:0];
}

-(void) clearItem:(int)index
{
    [jcList removeObjectAtIndex:index];
}

-(void) clippingMoveToTop:(int)index
{
	JumpcutClipping *clipping = [jcList objectAtIndex:index];
	[jcList insertObject:clipping atIndex:0];
	[jcList removeObjectAtIndex:index+1];
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
  
    if ( newDisplayLength > 0 ) {
        jcDisplayLen = newDisplayLength;
        for (JumpcutClipping *aClipping in jcList) {
            [aClipping setDisplayLength:newDisplayLength];
        }
    }
}

-(int) rememberNum
{
    return jcRememberNum;
}

-(int) displayLen
{
    return jcDisplayLen;
}

-(int) jcListCount
{
    return [jcList count];
}

-(JumpcutClipping *) clippingAtPosition:(int)index
{
    if ( index >= [jcList count] ) {
        return nil;
    } else {
        return [[jcList objectAtIndex:index] clipping];
    }
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
    return [self previousDisplayStrings:howMany containing:nil];
}

-(NSArray *) previousDisplayStrings:(int)howMany containing:(NSString*)search
{
    NSRange theRange;
    NSArray *subArray;
    NSMutableArray *returnArray = [[[NSMutableArray alloc] init] autorelease];
    NSEnumerator *enumerator;
    JumpcutClipping *aClipping;

    // If we have a search, do that.  Pretty much a mix of the other two paths below, but separated out to avoid extra processing.
    if (nil != search && search.length > 0) {
        subArray = [jcList copy];
        enumerator = [subArray objectEnumerator];
        int index = 0;
        while ( aClipping = [enumerator nextObject] ) { // Forward enumerator so we find the most recent N matches
            if ([[self clippingContentsAtPosition:index] rangeOfString:search].location != NSNotFound) {
                [returnArray insertObject:[aClipping displayString] atIndex:0];
                howMany--;
                if (0 == howMany)
                    break;
            }
            index++;
        }
        return [[returnArray reverseObjectEnumerator] allObjects]; // Reverse the results since the caller expects the most recent to be last.
    }

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

-(NSArray *) previousIndexes:(int)howMany containing:(NSString*)search // This method is in newest-first order.
{
    NSArray *subArray;
    NSMutableArray *returnArray = [[[NSMutableArray alloc] init] autorelease];
    NSEnumerator *enumerator;
    JumpcutClipping *aClipping;

    // If we have a search, do that.
    if (nil != search && search.length > 0) {
        subArray = [jcList copy];
        enumerator = [subArray objectEnumerator];
        int index = 0;
        while ( aClipping = [enumerator nextObject] ) { // Forward enumerator so we find the most recent N matches
            if ([[self clippingContentsAtPosition:index] rangeOfString:search].location != NSNotFound) {
                [returnArray addObject:[NSNumber numberWithInt:index]];
                howMany--;
                if (0 == howMany)
                    break;
            }
            index++;
        }
    }
    else
    {
        for ( int i = 0 ; i < howMany ; i++ )
            [returnArray addObject:[NSNumber numberWithInt:i]];
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
