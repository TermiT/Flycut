//
//  SRValidator.h
//  ShortcutRecorder
//
//  Copyright 2006-2007 Contributors. All rights reserved.
//
//  License: BSD
//
//  Contributors:
//      David Dauer
//      Jesper
//      Jamie Kirkpatrick

#import "SRValidator.h"
#import "SRCommon.h"

@implementation SRValidator

//---------------------------------------------------------- 
// iinitWithDelegate:
//---------------------------------------------------------- 
- (id) initWithDelegate:(id)theDelegate;
{
    self = [super init];
    if ( !self )
        return nil;
    
    [self setDelegate:theDelegate];
    
    return self;
}

//---------------------------------------------------------- 
// isKeyCode:andFlagsTaken:error:
//---------------------------------------------------------- 
- (BOOL) isKeyCode:(signed short)keyCode andFlagsTaken:(unsigned int)flags error:(NSError **)error;
{
    // if we have a delegate, it goes first...
	if ( delegate )
	{
		NSString *delegateReason = nil;
		if ( [delegate shortcutValidator:self 
                               isKeyCode:keyCode 
                           andFlagsTaken:SRCarbonToCocoaFlags( flags )
                                  reason:&delegateReason])
		{
            if ( error )
            {
                NSString *description = [NSString stringWithFormat: 
                    SRLoc(@"The key combination %@ can't be used!"), 
                    SRStringForCarbonModifierFlagsAndKeyCode( flags, keyCode )];
                NSString *recoverySuggestion = [NSString stringWithFormat: 
                    SRLoc(@"The key combination \"%@\" can't be used because %@."), 
                    SRReadableStringForCarbonModifierFlagsAndKeyCode( flags, keyCode ),
                    ( delegateReason && [delegateReason length] ) ? delegateReason : @"it's already used"];
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                    description,
                    @"NSLocalizedDescriptionKey",
                    recoverySuggestion,
                    @"NSLocalizedRecoverySuggestionErrorKey",
                    [NSArray arrayWithObject:@"OK"],
                    @"NSLocalizedRecoveryOptionsErrorKey",
                    nil];
                *error = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:0 userInfo:userInfo];
            }
			return YES;
		}
	}
	
	// then our implementation...
	NSArray *globalHotKeys;
	
	// get global hot keys...
	if ( CopySymbolicHotKeys((CFArrayRef *)&globalHotKeys ) != noErr )
		return YES;
	
	NSEnumerator *globalHotKeysEnumerator = [globalHotKeys objectEnumerator];
	NSDictionary *globalHotKeyInfoDictionary;
	SInt32 gobalHotKeyFlags;
	signed short globalHotKeyCharCode;
	unichar globalHotKeyUniChar;
	unichar localHotKeyUniChar;
	BOOL globalCommandMod = NO, globalOptionMod = NO, globalShiftMod = NO, globalCtrlMod = NO;
	BOOL localCommandMod = NO, localOptionMod = NO, localShiftMod = NO, localCtrlMod = NO;
	
	// Prepare local carbon comparison flags
	if ( flags & cmdKey )       localCommandMod = YES;
	if ( flags & optionKey )    localOptionMod = YES;
	if ( flags & shiftKey )     localShiftMod = YES;
	if ( flags & controlKey )   localCtrlMod = YES;
    
	while (( globalHotKeyInfoDictionary = [globalHotKeysEnumerator nextObject] ))
	{
		// Only check if global hotkey is enabled
		if ( (CFBooleanRef)[globalHotKeyInfoDictionary objectForKey:(NSString *)kHISymbolicHotKeyEnabled] != kCFBooleanTrue )
            continue;
		
        globalCommandMod    = NO;
        globalOptionMod     = NO;
        globalShiftMod      = NO;
        globalCtrlMod       = NO;
        
        globalHotKeyCharCode = [(NSNumber *)[globalHotKeyInfoDictionary objectForKey:(NSString *)kHISymbolicHotKeyCode] unsignedShortValue];
        globalHotKeyUniChar = [[[NSString stringWithFormat:@"%C", globalHotKeyCharCode] uppercaseString] characterAtIndex:0];
        
        CFNumberGetValue((CFNumberRef)[globalHotKeyInfoDictionary objectForKey: (NSString *)kHISymbolicHotKeyModifiers],kCFNumberSInt32Type,&gobalHotKeyFlags);
        
        if ( gobalHotKeyFlags & cmdKey )        globalCommandMod = YES;
        if ( gobalHotKeyFlags & optionKey )     globalOptionMod = YES;
        if ( gobalHotKeyFlags & shiftKey)       globalShiftMod = YES;
        if ( gobalHotKeyFlags & controlKey )    globalCtrlMod = YES;
        
        NSString *localKeyString = SRStringForKeyCode( keyCode );
        if (![localKeyString length]) return YES;
        
        localHotKeyUniChar = [localKeyString characterAtIndex:0];
        
        // compare unichar value and modifier flags
        if ( ( globalHotKeyUniChar == localHotKeyUniChar ) 
             && ( globalCommandMod == localCommandMod ) 
             && ( globalOptionMod == localOptionMod ) 
             && ( globalShiftMod == localShiftMod ) 
             && ( globalCtrlMod == localCtrlMod ) )
        {
            if ( error )
            {
                NSString *description = [NSString stringWithFormat: 
                    SRLoc(@"The key combination %@ can't be used!"), 
                    SRStringForCarbonModifierFlagsAndKeyCode( flags, keyCode )];
                NSString *recoverySuggestion = [NSString stringWithFormat: 
                    SRLoc(@"The key combination \"%@\" can't be used because it's already used by a system-wide keyboard shortcut. (If you really want to use this key combination, most shortcuts can be changed in the Keyboard & Mouse panel in System Preferences.)"), 
                    SRReadableStringForCarbonModifierFlagsAndKeyCode( flags, keyCode )];
                NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                    description,
                    @"NSLocalizedDescriptionKey",
                    recoverySuggestion,
                    @"NSLocalizedRecoverySuggestionErrorKey",
                    [NSArray arrayWithObject:@"OK"],
                    @"NSLocalizedRecoveryOptionsErrorKey",
                    nil];
                *error = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:0 userInfo:userInfo];
            }
            return YES;
        }
	}
	
	// Check menus too
	return [self isKeyCode:keyCode andFlags:flags takenInMenu:[NSApp mainMenu] error:error];
}

//---------------------------------------------------------- 
// isKeyCode:andFlags:takenInMenu:error:
//---------------------------------------------------------- 
- (BOOL) isKeyCode:(signed short)keyCode andFlags:(unsigned int)flags takenInMenu:(NSMenu *)menu error:(NSError **)error;
{
    NSArray *menuItemsArray = [menu itemArray];
	NSEnumerator *menuItemsEnumerator = [menuItemsArray objectEnumerator];
	NSMenuItem *menuItem;
	unsigned int menuItemModifierFlags;
	NSString *menuItemKeyEquivalent;
	
	BOOL menuItemCommandMod = NO, menuItemOptionMod = NO, menuItemShiftMod = NO, menuItemCtrlMod = NO;
	BOOL localCommandMod = NO, localOptionMod = NO, localShiftMod = NO, localCtrlMod = NO;
	
	// Prepare local carbon comparison flags
	if ( flags & cmdKey )       localCommandMod = YES;
	if ( flags & optionKey )    localOptionMod = YES;
	if ( flags & shiftKey )     localShiftMod = YES;
	if ( flags & controlKey )   localCtrlMod = YES;
	
	while (( menuItem = [menuItemsEnumerator nextObject] ))
	{
        // rescurse into all submenus...
		if ( [menuItem hasSubmenu] )
		{
			if ( [self isKeyCode:keyCode andFlags:flags takenInMenu:[menuItem submenu] error:error] ) 
			{
				return YES;
			}
		}
		
		if ( ( menuItemKeyEquivalent = [menuItem keyEquivalent] )
             && ( ![menuItemKeyEquivalent isEqualToString: @""] ) )
		{
			menuItemCommandMod = NO;
			menuItemOptionMod = NO;
			menuItemShiftMod = NO;
			menuItemCtrlMod = NO;
			
			menuItemModifierFlags = [menuItem keyEquivalentModifierMask];
            
			if ( menuItemModifierFlags & NSCommandKeyMask )     menuItemCommandMod = YES;
			if ( menuItemModifierFlags & NSAlternateKeyMask )   menuItemOptionMod = YES;
			if ( menuItemModifierFlags & NSShiftKeyMask )       menuItemShiftMod = YES;
			if ( menuItemModifierFlags & NSControlKeyMask )     menuItemCtrlMod = YES;
			
			NSString *localKeyString = SRStringForKeyCode( keyCode );
			
			// Compare translated keyCode and modifier flags
			if ( ( [[menuItemKeyEquivalent uppercaseString] isEqualToString: localKeyString] ) 
                 && ( menuItemCommandMod == localCommandMod ) 
                 && ( menuItemOptionMod == localOptionMod ) 
                 && ( menuItemShiftMod == localShiftMod ) 
                 && ( menuItemCtrlMod == localCtrlMod ) )
			{
                if ( error )
                {
                    NSString *description = [NSString stringWithFormat: 
                        SRLoc(@"The key combination %@ can't be used!"),
                        SRStringForCarbonModifierFlagsAndKeyCode( flags, keyCode )];
                    NSString *recoverySuggestion = [NSString stringWithFormat: 
                        SRLoc(@"The key combination \"%@\" can't be used because it's already used by the menu item \"%@\"."), 
                        SRReadableStringForCocoaModifierFlagsAndKeyCode( menuItemModifierFlags, keyCode ),
                        [menuItem title]];
                    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                        description,
                        @"NSLocalizedDescriptionKey",
                        recoverySuggestion,
                        @"NSLocalizedRecoverySuggestionErrorKey",
                        [NSArray arrayWithObject:@"OK"],
                        @"NSLocalizedRecoveryOptionsErrorKey",
                        nil];
                    *error = [NSError errorWithDomain:@"NSCocoaErrorDomain" code:0 userInfo:userInfo];
                }
				return YES;
			}
		}
	}
	return NO;    
}

#pragma mark -
#pragma mark accessors

//---------------------------------------------------------- 
//  delegate 
//---------------------------------------------------------- 
- (id) delegate
{
    return delegate; 
}

- (void) setDelegate: (id) theDelegate
{
    delegate = [theDelegate retain];
}

@end

#pragma mark -
#pragma mark default delegate implementation

@implementation NSObject( SRValidation )

//---------------------------------------------------------- 
// shortcutValidator:isKeyCode:andFlagsTaken:reason:
//---------------------------------------------------------- 
- (BOOL) shortcutValidator:(SRValidator *)validator isKeyCode:(signed short)keyCode andFlagsTaken:(unsigned int)flags reason:(NSString **)aReason;
{
    return NO;
}

@end
