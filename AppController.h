//
//  AppController.h
//  Snapback
//
//  Created by Steve Cook on 4/3/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import "BezelWindow.h"
#import "SRRecorderControl.h"
#import "SRKeyCodeTransformer.h"
#import "JumpcutStore.h"

@class PTHotKey;

@interface AppController : NSObject {
    BezelWindow					*bezel;
	PTHotKey					*mainHotKey;
	IBOutlet SRRecorderControl	*mainRecorder;
	IBOutlet NSPanel			*prefsPanel;
	int							mainHotkeyModifiers;
	SRKeyCodeTransformer        *srTransformer;
	BOOL						isBezelDisplayed;
	BOOL						isBezelPinned; // Currently not used
	NSString					*currentKeycodeCharacter;
	int							stackPosition;
	
	// The below were pulled in from JumpcutController
	JumpcutStore				*clippingStore;
	

    // Status item -- the little icon in the menu bar
    NSStatusItem *statusItem;
    // The menu attatched to same
    IBOutlet NSMenu *jcMenu;
    // A timer which will let us check the pasteboard;
    // this should default to every .5 seconds but be user-configurable
    NSTimer *pollPBTimer;
    // We want an interface to the pasteboard
    NSPasteboard *jcPasteboard;
    // Track the clipboard count so we only act when its contents change
    NSNumber *pbCount;
    //stores PasteboardCount for internal Jumpcut pasteboard actions so they don't trigger any events
    NSNumber *pbBlockCount;
    //Preferences
	NSDictionary *standardPreferences;
    int jcDisplayNum;
	BOOL issuedRememberResizeWarning;
}

// Basic functionality
-(void) pollPB:(NSTimer *)timer;
-(BOOL) addClipToPasteboardFromCount:(int)indexInt;
-(void) setPBBlockCount:(NSNumber *)newPBBlockCount;
-(void) hideApp;
-(void) pasteFromStack;
-(void) fakeCommandV;
-(void) stackUp;
-(void) stackDown;
-(IBAction)clearClippingList:(id)sender;

// Stack related
-(BOOL) isValidClippingNumber:(NSNumber *)number;
-(NSString *) clippingStringWithCount:(int)count;
	// Save and load
-(void) saveEngine;
-(void) loadEngineFromPList;

// Hotkey related
-(void)hitMainHotKey:(PTHotKey *)hotKey;

// Bezel related
-(void) showBezel;
-(void) hideBezel;
-(void) processBezelKeyDown:(NSEvent *)theEvent;
-(void) metaKeysReleased;

// Menu related
-(void) updateMenu;
-(IBAction) processMenuClippingSelection:(id)sender;
-(IBAction) activateAndOrderFrontStandardAboutPanel:(id)sender;

// Preference related
-(IBAction) showPreferencePanel:(id)sender;
-(IBAction) setRememberNumPref:(id)sender;
-(IBAction) setDisplayNumPref:(id)sender;
-(IBAction) setBezelAlpha:(id)sender;
-(IBAction) switchMenuIcon:(id)sender;
-(IBAction) toggleLoadOnStartup:(id)sender;
-(IBAction) toggleMainHotKey:(id)sender;
-(void) setHotKeyPreferenceForRecorder:(SRRecorderControl *)aRecorder;

@end
