//
//  FlycutStore.m
//  Flycut
//
//  Flycut by Gennadiy Potapov and contributors. Based on Jumpcut by Steve Cook.
//  Copyright 2011 General Arcade. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <https://github.com/TermiT/Flycut> for details.
//
//

#import "FlycutStore.h"
#import "FlycutClipping.h"

@implementation FlycutStore

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
	insertionJournal = [[NSMutableArray alloc] init];
	deletionJournal = [[NSMutableArray alloc] init];
    [self setRememberNum:nowRemembering];
    [self setDisplayNum:nowDisplaying];
    [self setDisplayLen:displayLength];
    return self;
}

-(int) indexOfClipping:(NSString *)clipping ofType:(NSString *)type fromAppLocalizedName:(NSString *)appLocalizedName fromAppBundleURL:(NSString *)bundleURL atTimestamp:(int) timestamp{
	if ([clipping length] == 0) {
		return -1;
	}
	// Clipping object
	FlycutClipping * newClipping;
	// Create clipping
	newClipping = [[FlycutClipping alloc] initWithContents:clipping
												  withType:type
										 withDisplayLength:[self displayLen]
									  withAppLocalizedName:appLocalizedName
										  withAppBundleURL:bundleURL
											 withTimestamp:timestamp];

	int result = [self indexOfClipping: newClipping];

	[newClipping release];

	return result;
}

-(int) indexOfClipping:(FlycutClipping*) clipping{
	return [self indexOfClipping:clipping afterIndex:-1];
}

-(int) indexOfClipping:(FlycutClipping*) clipping afterIndex:(int) after{
	NSUInteger index = [jcList indexOfObject:clipping
									 inRange:NSMakeRange(after + 1, [jcList count] - (after + 1) )];
	if ( NSNotFound == index ) {
		return -1;
	}
	return (int)index;
}

// Add a clipping
-(bool) addClipping:(NSString *)clipping ofType:(NSString *)type fromAppLocalizedName:(NSString *)appLocalizedName fromAppBundleURL:(NSString *)bundleURL atTimestamp:(int) timestamp{
    if ([clipping length] == 0) {
        return NO;
    }
    // Clipping object
    FlycutClipping * newClipping;
	// Create clipping
    newClipping = [[FlycutClipping alloc] initWithContents:clipping
												   withType:type
										  withDisplayLength:[self displayLen]
									   withAppLocalizedName:appLocalizedName
										   withAppBundleURL:bundleURL
											  withTimestamp:timestamp];
	
	[self addClipping:newClipping];
	
	[newClipping release];
	return YES;
}

-(bool) removeDuplicates{
	return [[[NSUserDefaults standardUserDefaults] valueForKey:@"removeDuplicates"] boolValue];
}

-(void) addClipping:(FlycutClipping*) clipping{
	[self insertClipping:clipping atIndex:0];
}

-(void) insertClipping:(FlycutClipping*) clipping atIndex:(int) index{
	[self delegateBeginUpdates];

	int moveFromIndex = -1;
	if ([jcList containsObject:clipping] && [self removeDuplicates]) {
		moveFromIndex = (int)[jcList indexOfObject:clipping];
        [jcList removeObject:clipping];
    }

    // Push it onto our recent clippings stack
	if ( index < [jcList count] ) {
		[jcList insertObject:clipping atIndex:index];
	}
	else {
		// If the index is beyond the current count then just append it and disregard requested index.
		// This doesn't alter the remember number and the jcList is self-growing so it is fine to append.
		index = [jcList count];
		[jcList addObject:clipping];
	}
	if ( moveFromIndex >= 0 )
		[self delegateMoveClippingAtIndex:moveFromIndex toIndex:index];
	else
		[self delegateInsertClippingAtIndex:index];

	// Delete clippings older than jcRememberNum
	while ( [jcList count] > jcRememberNum ) {
		[self delegateWillDeleteClippingAtIndex:jcRememberNum];
		[jcList removeObjectAtIndex:jcRememberNum];
		[self delegateDeleteClippingAtIndex:(jcRememberNum-1)]; // -1 for before-add indexing
	}

	[self delegateEndUpdates];
}

-(void) addClipping:(NSString *)clipping ofType:(NSString *)type withPBCount:(int *)pbCount
{
    [self addClipping:clipping ofType:type fromAppLocalizedName:@"PBCount" fromAppBundleURL:nil atTimestamp:0];
}

// Clear remembered and listed
-(void) clearList {
    [self delegateBeginUpdates];

    for ( int i = (int)[jcList count] ; i > 0 ; i-- )
	{
		[self delegateWillDeleteClippingAtIndex:(i-1)];
        [self delegateDeleteClippingAtIndex:(i-1)];
	}

    NSMutableArray *emptyJCList;
    emptyJCList = [[NSMutableArray alloc] init];
    [jcList release];
    jcList = emptyJCList;

    [self delegateEndUpdates];
}

-(void) mergeList {
    NSString *merge = [[[[jcList reverseObjectEnumerator] allObjects] valueForKey:@"clipContents"] componentsJoinedByString:@"\n"];
    [self addClipping:merge ofType:NSStringFromClass([merge class]) fromAppLocalizedName:@"Merge" fromAppBundleURL:nil atTimestamp:0];
}

-(void) clearItem:(int)index
{
    [self delegateBeginUpdates];

	[self delegateWillDeleteClippingAtIndex:index];
    [jcList removeObjectAtIndex:index];
    [self delegateDeleteClippingAtIndex:index];

    [self delegateEndUpdates];
}

-(void) clippingMoveToTop:(int)index
{
	[self clippingMoveFrom:index To:0];
}

-(void) clippingMoveFrom:(int)index To:(int)toIndex
{
	[self delegateBeginUpdates];

	FlycutClipping *clipping = [jcList objectAtIndex:index];
	[jcList insertObject:clipping atIndex:toIndex];
	[jcList removeObjectAtIndex:index+1];
	[self delegateMoveClippingAtIndex:index toIndex:toIndex];

	[self delegateEndUpdates];
}

// Set various values
-(void) setRememberNum:(int)nowRemembering
{
    if ( nowRemembering  > 0 ) {
        jcRememberNum = nowRemembering;

		if ( [jcList count] > jcRememberNum ) {
			[self delegateBeginUpdates];

			while ( [jcList count] > jcRememberNum ) {
				[self delegateWillDeleteClippingAtIndex:jcRememberNum];
				[jcList removeObjectAtIndex:jcRememberNum];
				[self delegateDeleteClippingAtIndex:jcRememberNum];
			}
			[self delegateEndUpdates];
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
        for (FlycutClipping *aClipping in jcList) {
            [aClipping setDisplayLength:newDisplayLength];
        }
    }
}

-(void) clearModifiedSinceLastSaveStore
{
	modifiedSinceLastSaveStore = NO;
	insertionJournalCountLastSave = [insertionJournal count];
	deletionJournalCountLastSave = [deletionJournal count];
}

-(void) pruneJournals
{
	[self clearInsertionJournalCount:insertionJournalCountLastSave];
	[self clearDeletionJournalCount:deletionJournalCountLastSave];
}

-(void) clearInsertionJournalCount:(NSUInteger)count
{
	while ( count-- > 0 )
	{
		[insertionJournal removeLastObject];
		if ( insertionJournalCountLastSave > 0 )
			insertionJournalCountLastSave--;
	}
}

-(void) clearDeletionJournalCount:(NSUInteger)count
{
	while ( count-- > 0 )
	{
		[deletionJournal removeLastObject];
		if ( deletionJournalCountLastSave > 0 )
			deletionJournalCountLastSave--;
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

-(bool) modifiedSinceLastSaveStore
{
	return modifiedSinceLastSaveStore;
}

-(NSArray *) insertionJournal
{
	return insertionJournal;
}

-(NSArray *) deletionJournal
{
	return deletionJournal;
}

-(FlycutClipping *) clippingAtPosition:(int)index
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
    FlycutClipping *aClipping;
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
    FlycutClipping *aClipping;

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
    FlycutClipping *aClipping;

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

-(void) delegateBeginUpdates
{
	if ( self.delegate && [self.delegate respondsToSelector:@selector(beginUpdates)] )
		[self.delegate beginUpdates];
}

-(void) delegateEndUpdates
{
	if ( self.delegate && [self.delegate respondsToSelector:@selector(endUpdates)] )
		[self.delegate endUpdates];
}

-(void) delegateInsertClippingAtIndex:(int)index
{
	[insertionJournal insertObject:[jcList objectAtIndex:index] atIndex:0];
	if ( [insertionJournal count] > jcRememberNum )
		[self clearInsertionJournalCount:( [insertionJournal count] - jcRememberNum )];

	modifiedSinceLastSaveStore = YES;
	if ( self.delegate && [self.delegate respondsToSelector:@selector(insertClippingAtIndex:)] )
		[self.delegate insertClippingAtIndex:index];
}

-(void) delegateWillDeleteClippingAtIndex:(int)index
{
	[deletionJournal insertObject:[jcList objectAtIndex:index] atIndex:0];
	if ( [deletionJournal count] > jcRememberNum )
		[self clearDeletionJournalCount:( [deletionJournal count] - jcRememberNum )];

	if ( self.deleteDelegate && [self.deleteDelegate respondsToSelector:@selector(willDeleteClippingFromStore:AtIndex:)] )
		[self.deleteDelegate willDeleteClippingFromStore:self AtIndex:index];
}

-(void) delegateDeleteClippingAtIndex:(int)index
{
	modifiedSinceLastSaveStore = YES;
	if ( self.delegate && [self.delegate respondsToSelector:@selector(deleteClippingAtIndex:)] )
		[self.delegate deleteClippingAtIndex:index];
}

-(void) delegateReloadClippingAtIndex:(int)index
{
	modifiedSinceLastSaveStore = YES;
	if ( self.delegate && [self.delegate respondsToSelector:@selector(reloadClippingAtIndex:)] )
		[self.delegate reloadClippingAtIndex:index];
}

-(void) delegateMoveClippingAtIndex:(int)index toIndex:(int)newIndex
{
	modifiedSinceLastSaveStore = YES;
	if ( self.delegate && [self.delegate respondsToSelector:@selector(moveClippingAtIndex:toIndex:)] )
		[self.delegate moveClippingAtIndex:index toIndex:newIndex];
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
