//
//  AppController.m
//  Flycut
//
//  Flycut by Gennadiy Potapov and contributors. Based on Jumpcut by Steve Cook.
//  Copyright 2011 General Arcade. All rights reserved.
//
//  This code is open-source software subject to the MIT License; see the homepage
//  at <https://github.com/TermiT/Flycut> for details.
//

// AppController owns and interacts with the FlycutOperator, providing a user
// interface and platform-specific mechanisms.

#import <Cocoa/Cocoa.h>
#import <ApplicationServices/ApplicationServices.h>
#import "BezelWindow.h"
#import "SRRecorderControl.h"
#import "SRKeyCodeTransformer.h"
#import "FlycutOperator.h"
#import "SGHotKey.h"

@class SGHotKey;

@interface AppController : NSObject <NSMenuDelegate, NSApplicationDelegate, FlycutStoreDelegate> {
    BezelWindow					*bezel;
	SGHotKey					*mainHotKey;
	IBOutlet SRRecorderControl	*mainRecorder;
	IBOutlet NSPanel			*prefsPanel;
	IBOutlet NSBox			  *appearancePanel;
	int							mainHotkeyModifiers;
	SRKeyCodeTransformer        *srTransformer;
	BOOL						isBezelDisplayed;
	BOOL						isBezelPinned; // Currently not used
	NSString					*currentKeycodeCharacter;
    NSDateFormatter*            dateFormat;

    NSArray *settingsSyncList;

    FlycutOperator				*flycutOperator;

    // Status item -- the little icon in the menu bar
    NSStatusItem *statusItem;
    NSString *statusItemText;
    NSImage *statusItemImage;
    
    // The menu attatched to same
    IBOutlet NSMenu *jcMenu;
    int jcMenuBaseItemsCount;
    IBOutlet NSSearchField *searchBox;
    NSResponder *menuFirstResponder;
    dispatch_queue_t menuQueue;
    NSRunningApplication *currentRunningApplication;
    NSEvent *menuOpenEvent;
    IBOutlet NSSlider * heightSlider;
    IBOutlet NSSlider * widthSlider;
    // A timer which will let us check the pasteboard;
    // this should default to every .5 seconds but be user-configurable
    NSTimer *pollPBTimer;
    // We want an interface to the pasteboard
    NSPasteboard *jcPasteboard;
    // Track the clipboard count so we only act when its contents change
    NSNumber *pbCount;
    //stores PasteboardCount for internal Flycut pasteboard actions so they don't trigger any events
    NSNumber *pbBlockCount;
    //Preferences
	NSDictionary *standardPreferences;
    int jcDisplayNum;
	BOOL issuedRememberResizeWarning;
	BOOL needBezelUpdate;
	BOOL needMenuUpdate;
}

// Basic functionality
-(void) pollPB:(NSTimer *)timer;
-(void) addClipToPasteboard:(NSString*)pbFullText;
-(void) setPBBlockCount:(NSNumber *)newPBBlockCount;
-(void) hideApp;
-(void) fakeCommandV;
-(IBAction)clearClippingList:(id)sender;
-(IBAction)mergeClippingList:(id)sender;
-(void)controlTextDidChange:(NSNotification *)aNotification;
-(BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector;
-(IBAction)searchItems:(id)sender;

// Hotkey related
-(void)hitMainHotKey:(SGHotKey *)hotKey;

// Bezel related
-(void) updateBezel;
-(void) showBezel;
-(void) hideBezel;
-(void) processBezelKeyDown:(NSEvent *)theEvent;
-(void) processBezelMouseEvents:(NSEvent *)theEvent;
-(void) metaKeysReleased;

// Menu related
-(void) updateMenu;
-(IBAction) processMenuClippingSelection:(id)sender;
-(IBAction) activateAndOrderFrontStandardAboutPanel:(id)sender;

// Preference related
-(IBAction) showPreferencePanel:(id)sender;
-(IBAction) setRememberNumPref:(id)sender;
-(IBAction) setFavoritesRememberNumPref:(id)sender;
-(IBAction) setDisplayNumPref:(id)sender;
-(IBAction) setBezelAlpha:(id)sender;
-(IBAction) setBezelHeight:(id)sender;
-(IBAction) setBezelWidth:(id)sender;
-(IBAction) switchMenuIcon:(id)sender;
-(IBAction) toggleLoadOnStartup:(id)sender;
-(IBAction) toggleMainHotKey:(id)sender;
-(IBAction) toggleICloudSyncSettings:(id)sender;
-(IBAction) toggleICloudSyncClippings:(id)sender;
-(IBAction) setSavePreference:(id)sender;
-(void) setHotKeyPreferenceForRecorder:(SRRecorderControl *)aRecorder;

@end
