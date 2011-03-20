//
//  PTHotKeyCenter.m
//  Protein
//
//  Created by Quentin Carnicelli on Sat Aug 02 2003.
//  Copyright (c) 2003 Quentin D. Carnicelli. All rights reserved.
//

#import "PTHotKeyCenter.h"
#import "PTHotKey.h"
#import "PTKeyCombo.h"
#import <Carbon/Carbon.h>

#if __PROTEIN__
#import "PTNSObjectAdditions.h"
#endif

@interface PTHotKeyCenter (Private)
- (BOOL)_hasCarbonEventSupport;

- (PTHotKey*)_hotKeyForCarbonHotKey: (EventHotKeyRef)carbonHotKey;
- (EventHotKeyRef)_carbonHotKeyForHotKey: (PTHotKey*)hotKey;

- (void)_updateEventHandler;
- (void)_hotKeyDown: (PTHotKey*)hotKey;
- (void)_hotKeyUp: (PTHotKey*)hotKey;
static OSStatus hotKeyEventHandler(EventHandlerCallRef inHandlerRef, EventRef inEvent, void* refCon );
@end

@implementation PTHotKeyCenter

static id _sharedHotKeyCenter = nil;

+ (id)sharedCenter
{
	if( _sharedHotKeyCenter == nil )
	{
		_sharedHotKeyCenter = [[self alloc] init];
		#if __PROTEIN__
			[_sharedHotKeyCenter releaseOnTerminate];
		#endif
	}
	
	return _sharedHotKeyCenter;
}

- (id)init
{
	self = [super init];
	
	if( self )
	{
		mHotKeys = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (void)dealloc
{
	[mHotKeys release];
	[super dealloc];
}

#pragma mark -

- (BOOL)registerHotKey: (PTHotKey*)hotKey
{
	OSStatus err;
	EventHotKeyID hotKeyID;
	EventHotKeyRef carbonHotKey;
	NSValue* key;

	if( [[self allHotKeys] containsObject: hotKey] == YES )
		[self unregisterHotKey: hotKey];
	
	if( [[hotKey keyCombo] isValidHotKeyCombo] == NO )
		return YES;
	
	hotKeyID.signature = 'PTHk';
	hotKeyID.id = (long)hotKey;
	
	err = RegisterEventHotKey(  [[hotKey keyCombo] keyCode],
								[[hotKey keyCombo] modifiers],
								hotKeyID,
								GetEventDispatcherTarget(),
								nil,
								&carbonHotKey );

	if( err )
		return NO;

	key = [NSValue valueWithPointer: carbonHotKey];
	if( hotKey && key )
		[mHotKeys setObject: hotKey forKey: key];

	[self _updateEventHandler];
	return YES;
}

- (void)unregisterHotKey: (PTHotKey*)hotKey
{
	OSStatus err;
	EventHotKeyRef carbonHotKey;
	NSValue* key;

	if( [[self allHotKeys] containsObject: hotKey] == NO )
		return;
	
	carbonHotKey = [self _carbonHotKeyForHotKey: hotKey];
	NSAssert( carbonHotKey != nil, @"" );

	err = UnregisterEventHotKey( carbonHotKey );
	//Watch as we ignore 'err':

	key = [NSValue valueWithPointer: carbonHotKey];
	[mHotKeys removeObjectForKey: key];
	
	[self _updateEventHandler];
	//See that? Completely ignored
}

- (NSArray*)allHotKeys
{
	return [mHotKeys allValues];
}

- (PTHotKey*)hotKeyWithIdentifier: (id)ident
{
	NSEnumerator* hotKeysEnum = [[self allHotKeys] objectEnumerator];
	PTHotKey* hotKey;
	
	if( !ident )
		return nil;
	
	while( (hotKey = [hotKeysEnum nextObject]) != nil )
	{
		if( [[hotKey identifier] isEqual: ident] )
			return hotKey;
	}

	return nil;
}

#pragma mark -

- (BOOL)_hasCarbonEventSupport
{
	return floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_1;
}

- (PTHotKey*)_hotKeyForCarbonHotKey: (EventHotKeyRef)carbonHotKey
{
	NSValue* key = [NSValue valueWithPointer: carbonHotKey];
	return [mHotKeys objectForKey: key];
}

- (EventHotKeyRef)_carbonHotKeyForHotKey: (PTHotKey*)hotKey
{
	NSArray* values;
	NSValue* value;
	
	values = [mHotKeys allKeysForObject: hotKey];
	NSAssert( [values count] == 1, @"Failed to find Carbon Hotkey for PTHotKey" );
	
	value = [values lastObject];
	
	return (EventHotKeyRef)[value pointerValue];
}

- (void)_updateEventHandler
{
	if( [self _hasCarbonEventSupport] == NO ) //Don't use event handler on these systems
		return;

	if( [mHotKeys count] && mEventHandlerInstalled == NO )
	{
		EventTypeSpec eventSpec[2] = {
			{ kEventClassKeyboard, kEventHotKeyPressed },
			{ kEventClassKeyboard, kEventHotKeyReleased }
		};    

		InstallEventHandler( GetEventDispatcherTarget(),
							 (EventHandlerProcPtr)hotKeyEventHandler, 
							 2, eventSpec, nil, nil);
	
		mEventHandlerInstalled = YES;
	}
}

- (void)_hotKeyDown: (PTHotKey*)hotKey
{
	[hotKey invoke];
}

- (void)_hotKeyUp: (PTHotKey*)hotKey
{
}

- (void)sendEvent: (NSEvent*)event
{
	long subType;
	EventHotKeyRef carbonHotKey;
	
	//We only have to intercept sendEvent to do hot keys on old system versions
	if( [self _hasCarbonEventSupport] )
		return;
	
	if( [event type] == NSSystemDefined )
	{
		subType = [event subtype];
		
		if( subType == 6 ) //6 is hot key down
		{
			carbonHotKey= (EventHotKeyRef)[event data1]; //data1 is our hot key ref
			if( carbonHotKey != nil )
			{
				PTHotKey* hotKey = [self _hotKeyForCarbonHotKey: carbonHotKey];
				[self _hotKeyDown: hotKey];
			}
		}
		else if( subType == 9 ) //9 is hot key up
		{
			carbonHotKey= (EventHotKeyRef)[event data1];
			if( carbonHotKey != nil )
			{
				PTHotKey* hotKey = [self _hotKeyForCarbonHotKey: carbonHotKey];
				[self _hotKeyUp: hotKey];
			}
		}
	}
}

- (OSStatus)sendCarbonEvent: (EventRef)event
{
	OSStatus err;
	EventHotKeyID hotKeyID;
	PTHotKey* hotKey;

	NSAssert( [self _hasCarbonEventSupport], @"" );
	NSAssert( GetEventClass( event ) == kEventClassKeyboard, @"Unknown event class" );

	err = GetEventParameter(	event,
								kEventParamDirectObject, 
								typeEventHotKeyID,
								nil,
								sizeof(EventHotKeyID),
								nil,
								&hotKeyID );
	if( err )
		return err;
	

	NSAssert( hotKeyID.signature == 'PTHk', @"Invalid hot key id" );
	NSAssert( hotKeyID.id != nil, @"Invalid hot key id" );

	hotKey = (PTHotKey*)hotKeyID.id;

	switch( GetEventKind( event ) )
	{
		case kEventHotKeyPressed:
			[self _hotKeyDown: hotKey];
		break;

		case kEventHotKeyReleased:
			[self _hotKeyUp: hotKey];
		break;

		default:
			NSAssert( 0, @"Unknown event kind" );
		break;
	}
	
	return noErr;
}

static OSStatus hotKeyEventHandler(EventHandlerCallRef inHandlerRef, EventRef inEvent, void* refCon )
{
	return [[PTHotKeyCenter sharedCenter] sendCarbonEvent: inEvent];
}

@end
