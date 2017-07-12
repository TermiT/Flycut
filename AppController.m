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

#import "AppController.h"
#import "SGHotKey.h"
#import "SGHotKeyCenter.h"
#import "SRRecorderCell.h"
#import "UKLoginItemRegistry.h"
#import "NSWindow+TrueCenter.h"
#import "NSWindow+ULIZoomEffect.h"

@implementation AppController

- (id)init
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:9],[NSNumber numberWithLong:1179648],nil] forKeys:[NSArray arrayWithObjects:@"keyCode",@"modifierFlags",nil]],
		@"ShortcutRecorder mainHotkey",
		[NSNumber numberWithInt:0],
		@"menuIcon",
		[NSNumber numberWithFloat:.25],
		@"bezelAlpha",
		[NSNumber numberWithBool:YES],
		@"stickyBezel",
		[NSNumber numberWithBool:NO],
		@"wraparoundBezel",
		[NSNumber numberWithBool:NO],// No by default
		@"loadOnStartup",
		[NSNumber numberWithBool:YES], 
		@"menuSelectionPastes",
        // Flycut new options
        [NSNumber numberWithFloat:500.0],
        @"bezelWidth",
        [NSNumber numberWithFloat:320.0],
        @"bezelHeight",
        [NSNumber numberWithBool:NO],
        @"popUpAnimation",
        [NSNumber numberWithBool:YES],
        @"displayClippingSource",
        nil]];
	return [super init];
}

- (void)awakeFromNib
{
	[self buildAppearancesPreferencePanel];

	// We no longer get autosave from ShortcutRecorder, so let's set the recorder by hand
	if ( [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"ShortcutRecorder mainHotkey"] ) {
		[mainRecorder setKeyCombo:SRMakeKeyCombo([[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"ShortcutRecorder mainHotkey"] objectForKey:@"keyCode"] intValue],
												 [[[[NSUserDefaults standardUserDefaults] dictionaryForKey:@"ShortcutRecorder mainHotkey"] objectForKey:@"modifierFlags"] intValue] )
		];
	};

	// Initialize the FlycutOperator
	flycutOperator = [[FlycutOperator alloc] init];
	[flycutOperator awakeFromNib];

    [bezel setColor:NO];
    
	// Set up the bezel window
	[self setupBezel:nil];

	// Set up the bezel date formatter
	dateFormat = [[NSDateFormatter alloc] init];
	[dateFormat setDateFormat:@"EEEE, MMMM dd 'at' h:mm a"];

	// Create our pasteboard interface
    jcPasteboard = [NSPasteboard generalPasteboard];
    [jcPasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    pbCount = [[NSNumber numberWithInt:[jcPasteboard changeCount]] retain];

	// Build the statusbar menu
    statusItem = [[[NSStatusBar systemStatusBar]
            statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusItem setHighlightMode:YES];
    [self switchMenuIconTo: [[NSUserDefaults standardUserDefaults] integerForKey:@"menuIcon"]];
	[statusItem setMenu:jcMenu];
    [jcMenu setDelegate:self];
    jcMenuBaseItemsCount = [[[[jcMenu itemArray] reverseObjectEnumerator] allObjects] count];
    [statusItem setEnabled:YES];

    // If our preferences indicate that we are saving, we may have loaded the dictionary from the
    // saved plist and should update the menu.
	if ( [[NSUserDefaults standardUserDefaults] integerForKey:@"savePreference"] >= 1 ) {
        [self updateMenu];
	}

	// Build our listener timer
    pollPBTimer = [[NSTimer scheduledTimerWithTimeInterval:(1.0)
													target:self
												  selector:@selector(pollPB:)
												  userInfo:nil
												   repeats:YES] retain];
	
    // Finish up
	srTransformer = [[[SRKeyCodeTransformer alloc] init] retain];
    pbBlockCount = [[NSNumber numberWithInt:0] retain];
    [pollPBTimer fire];
    
    // The load-on-startup check can be really slow, so this will be dispatched out so our thread isn't blocked.
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        // This can take five seconds, perhaps more, so do it in the background instead of holding up opening of the preference panel.
        int checkLoginRegistry = [UKLoginItemRegistry indexForLoginItemWithPath:[[NSBundle mainBundle] bundlePath]];
        if ( checkLoginRegistry >= 1 ) {
            [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES]
                                                     forKey:@"loadOnStartup"];
        } else {
            [[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:NO]
                                                     forKey:@"loadOnStartup"];
        }
    });

    [NSApp activateIgnoringOtherApps: YES];
}

-(void)menuWillOpen:(NSMenu *)menu
{
    NSEvent *event = [NSApp currentEvent];
    if([event modifierFlags] & NSAlternateKeyMask) {
        [menu cancelTracking];
        bool disableStore = [self toggleMenuIconDisabled];
        if (!disableStore)
        {
            // Update the pbCount so we don't enable and have it immediately copy the thing the user was trying to avoid.
            // Code copied from pollPB, which is disabled at this point, so the "should be okay" should still be okay.
            
            // Reload pbCount with the current changeCount
            // Probably poor coding technique, but pollPB should be the only thing messing with pbCount, so it should be okay
            [pbCount release];
            pbCount = [[NSNumber numberWithInt:[jcPasteboard changeCount]] retain];
        }
        [flycutOperator setDisableStoreTo:disableStore];
    }
    else
    {
        // We need to do a little trick to get the search box functional.  Figure out what is currently active.
        NSString *currRunningApp = @"";
        NSRunningApplication *currApp = nil;
        for (currApp in [[NSWorkspace sharedWorkspace] runningApplications])
            if ([currApp isActive])
            {
                currRunningApp = [currApp localizedName];
                break;
            }

        if ( [currRunningApp rangeOfString:@"Flycut"].location == NSNotFound )
        {
            // We haven't activated Flycut yet.
            currentRunningApplication = [currApp retain]; // Remember what app we came from.
            menuOpenEvent = [event retain]; // So we can send it again to open the menu.
            [menu cancelTracking]; // Prevent the menu from displaying, since activateIgnoringOtherApps would close it anyway.
            [NSApp activateIgnoringOtherApps: YES]; // Required to make the search field firstResponder any good.
            [self performSelector:@selector(reopenMenu) withObject:nil afterDelay:0.2 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]]; // Because we really do want the menu open.
        }
        else
        {
            // Flycut is now active, so set the first responder once the menu opens.
            [self performSelector:@selector(activateSearchBox) withObject:nil afterDelay:0.2 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
        }
    }
}

-(void)menuDidClose:(NSMenu *)menu
{
    // The method the menu triggers may clear currentRunningApplication, but that method won't be called until after the menu has closed.  Queue a call to the reactivate method that will come up after the method resulting from the menu.
    [self performSelector:@selector(reactivateCurrentRunningApplication) withObject:nil afterDelay:0.0 inModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
}

-(void)reactivateCurrentRunningApplication
{
    // Return focus to application that the menu search box stole from.
    if ( nil != currentRunningApplication )
    {
        // But only if the bezel hasn't opened since the menu closed.  This happens if the bezel hotkey is pressed while the menu is open.  The bezel won't display until the menu closes, but will then display.
        if (!isBezelDisplayed)
            [currentRunningApplication activateWithOptions: NSApplicationActivateIgnoringOtherApps];
        // Paste from the bezel in this scenario works fine, so release and forget this resource in both cases.
        [currentRunningApplication release];
        currentRunningApplication = nil;
    }
}

-(bool)toggleMenuIconDisabled
{
    // Toggles the "disabled" look of the menu icon.  Returns if the icon looks disabled or not, allowing the caller to decide if anything is actually being disabled or if they just wanted the icon to be a status display.
    if (nil == statusItemText)
    {
        statusItemText = [statusItem title];
        statusItemImage = [statusItem image];
        [statusItem setTitle: @""];
        [statusItem setImage: [NSImage imageNamed:@"com.generalarcade.flycut.xout.16.png"]];
        return true;
    }
    else
    {
        [statusItem setTitle: statusItemText];
        [statusItem setImage: statusItemImage];
        statusItemText = nil;
        statusItemImage = nil;
    }
    return false;
}

- (void)reopenMenu
{
    [NSApp sendEvent:menuOpenEvent];
    [menuOpenEvent release];
    menuOpenEvent = nil;
}

- (void)activateSearchBox
{
    menuFirstResponder = [[searchBox window] firstResponder]; // So we can return control to normal menu function if the user presses an arrow key.
    [[searchBox window] makeFirstResponder:searchBox]; // So the search box works.
}

-(IBAction) activateAndOrderFrontStandardAboutPanel:(id)sender
{
    [currentRunningApplication release];
    currentRunningApplication = nil; // So it doesn't get pulled foreground atop the about panel.
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel:sender];
}

-(IBAction) setBezelAlpha:(id)sender
{
	// In a masterpiece of poorly-considered design--because I want to eventually 
	// allow users to select from a variety of bezels--I've decided to create the
	// bezel programatically, meaning that I have to go through AppController as
	// a cutout to allow the user interface to interact w/the bezel.
	[bezel setAlpha:[sender floatValue]];
}

-(IBAction) setBezelWidth:(id)sender
{
    NSSize bezelSize = NSMakeSize([sender floatValue], bezel.frame.size.height);
	NSRect windowFrame = NSMakeRect( 0, 0, bezelSize.width, bezelSize.height);
	[bezel setFrame:windowFrame display:NO];
    [bezel trueCenter];
}

-(IBAction) setBezelHeight:(id)sender
{
    NSSize bezelSize = NSMakeSize(bezel.frame.size.width, [sender floatValue]);
	NSRect windowFrame = NSMakeRect( 0, 0, bezelSize.width, bezelSize.height);
	[bezel setFrame:windowFrame display:NO];
    [bezel trueCenter];
}

-(IBAction) setupBezel:(id)sender
{
    NSRect windowFrame = NSMakeRect(0, 0,
                                    [[NSUserDefaults standardUserDefaults] floatForKey:@"bezelWidth"],
                                    [[NSUserDefaults standardUserDefaults] floatForKey:@"bezelHeight"]);
    bezel = [[BezelWindow alloc] initWithContentRect:windowFrame
                                           styleMask:NSBorderlessWindowMask
                                             backing:NSBackingStoreBuffered
                                               defer:NO
                                          showSource:[[NSUserDefaults standardUserDefaults] boolForKey:@"displayClippingSource"]];

    [bezel trueCenter];
    [bezel setDelegate:self];
}

-(IBAction) switchMenuIcon:(id)sender
{
    [self switchMenuIconTo: [sender indexOfSelectedItem]];
}

-(void) switchMenuIconTo:(int)number
{
    if (number == 1 ) {
        [statusItem setTitle:@""];
        [statusItem setImage:[NSImage imageNamed:@"com.generalarcade.flycut.black.16.png"]];
    } else if (number == 2 ) {
        [statusItem setImage:nil];
        [statusItem setTitle:[NSString stringWithFormat:@"%C",0x2704]];
    } else if ( number == 3 ) {
        [statusItem setImage:nil];
        [statusItem setTitle:[NSString stringWithFormat:@"%C",0x2702]];
    } else {
        [statusItem setTitle:@""];
        [statusItem setImage:[NSImage imageNamed:@"com.generalarcade.flycut.16.png"]];
    }
}

-(IBAction) setRememberNumPref:(id)sender
{
	int choice;
	int newRemember = [sender intValue];
	if ( newRemember < [flycutOperator jcListCount] &&
		 ! issuedRememberResizeWarning &&
		 ! [[NSUserDefaults standardUserDefaults] boolForKey:@"stifleRememberResizeWarning"]
		 ) {
		choice = NSRunAlertPanel(@"Resize Stack", 
								 @"Resizing the stack to a value below its present size will cause clippings to be lost.",
								 @"Resize", @"Cancel", @"Don't Warn Me Again");
		if ( choice == NSAlertAlternateReturn ) {
			// User selected Cancel.  This appears to set the user default to
			// the current clipping count while not updating the clippingStore,
			// resulting in truncation in the future.  This condition dates back
			// to snarkout's original creation of setRememberNumPref on May 17,
			// 2006.
			[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:[flycutOperator jcListCount]]
													 forKey:@"rememberNum"];
			[self updateMenu];
			return;
		} else if ( choice == NSAlertOtherReturn ) {
			[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithBool:YES]
													 forKey:@"stifleRememberResizeWarning"];
		} else {
			issuedRememberResizeWarning = YES;
		}
	}

	// Trim down the number displayed in the menu if it is greater than the new
	// number to remember.
	if ( newRemember < [[NSUserDefaults standardUserDefaults] integerForKey:@"displayNum"] ) {
		[[NSUserDefaults standardUserDefaults] setValue:[NSNumber numberWithInt:newRemember]
												 forKey:@"displayNum"];
	}

	// Set the value.
	[flycutOperator setRememberNum: newRemember];
	[self updateMenu];
}

-(IBAction) setFavoritesRememberNumPref:(id)sender
{
    [flycutOperator switchToFavoritesStore];
    [self setRememberNumPref: sender];
    [flycutOperator restoreStashedStore];
}

-(IBAction) setDisplayNumPref:(id)sender
{
	[self updateMenu];
}

-(NSTextField*) preferencePanelSliderLabelForText:(NSString*)text aligned:(NSTextAlignment)alignment andFrame:(NSRect)frame
{
	NSTextField *newLabel = [[NSTextField alloc] initWithFrame:frame];
	newLabel.editable = NO;
	[newLabel setAlignment:alignment];
	[newLabel setBordered:NO];
	[newLabel setDrawsBackground:NO];
	[newLabel setFont:[NSFont labelFontOfSize:10]];
	[newLabel setStringValue:text];
	return newLabel;
}

-(NSBox*) preferencePanelSliderRowForText:(NSString*)title withTicks:(int)ticks minText:(NSString*)minText maxText:(NSString*)maxText minValue:(double)min maxValue:(double)max frameMaxY:(int)frameMaxY binding:(NSString*)keyPath action:(SEL)action
{
	NSRect panelFrame = [appearancePanel frame];

	if ( frameMaxY < 0 )
		frameMaxY = panelFrame.size.height-8;

	int height = 63;

	NSBox *newRow = [[NSBox alloc] initWithFrame:NSMakeRect(0, frameMaxY-height, panelFrame.size.width-10, height)];
	[newRow setTitlePosition:NSNoTitle];
	[newRow setBorderType:NSNoBorder];

	[newRow addSubview:[self preferencePanelSliderLabelForText:title aligned:NSNaturalTextAlignment andFrame:NSMakeRect(8, 25, 100, 25)]];

	[newRow addSubview:[self preferencePanelSliderLabelForText:minText aligned:NSLeftTextAlignment andFrame:NSMakeRect(113, 0, 151, 25)]];
	[newRow addSubview:[self preferencePanelSliderLabelForText:maxText aligned:NSRightTextAlignment andFrame:NSMakeRect(109+310-151-4, 0, 151, 25)]];

	NSSlider *newControl = [[NSSlider alloc] initWithFrame:NSMakeRect(109, 29, 310, 25)];

	newControl.numberOfTickMarks=ticks;
	[newControl setMinValue:min];
	[newControl setMaxValue:max];

	[self setBinding:@"value" forKey:keyPath andOrAction:action on:newControl];

	[newRow addSubview:newControl];

	return newRow;
}

-(NSBox*) preferencePanelPopUpRowForText:(NSString*)title items:(NSArray*)items frameMaxY:(int)frameMaxY binding:(NSString*)keyPath action:(SEL)action
{
	NSRect panelFrame = [appearancePanel frame];

	if ( frameMaxY < 0 )
		frameMaxY = panelFrame.size.height-8;

	int height = 40;

	NSBox *newRow = [[NSBox alloc] initWithFrame:NSMakeRect(0, frameMaxY-height+5, panelFrame.size.width-10, height)];
	[newRow setTitlePosition:NSNoTitle];
	[newRow setBorderType:NSNoBorder];

	[newRow addSubview:[self preferencePanelSliderLabelForText:title aligned:NSNaturalTextAlignment andFrame:NSMakeRect(8, -2, 100, 25)]];

	NSPopUpButton *newControl = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(109, 4, 150, 25) pullsDown:NO];

	[newControl addItemsWithTitles:items];

	[self setBinding:@"selectedIndex" forKey:keyPath andOrAction:action on:newControl];

	[newRow addSubview:newControl];

	return newRow;
}

-(NSBox*) preferencePanelCheckboxRowForText:(NSString*)title frameMaxY:(int)frameMaxY binding:(NSString*)keyPath action:(SEL)action
{
	NSRect panelFrame = [appearancePanel frame];

	if ( frameMaxY < 0 )
		frameMaxY = panelFrame.size.height-8;

	int height = 40;

	NSBox *newRow = [[NSBox alloc] initWithFrame:NSMakeRect(0, frameMaxY-height+5, panelFrame.size.width-10, height)];
	[newRow setTitlePosition:NSNoTitle];
	[newRow setBorderType:NSNoBorder];

	NSButton *newControl = [[NSButton alloc] initWithFrame:NSMakeRect(8, 4, panelFrame.size.width-20, 25)];

	[newControl setButtonType:NSSwitchButton];
	[newControl setTitle:title];

	[self setBinding:@"value" forKey:keyPath andOrAction:action on:newControl];

	[newRow addSubview:newControl];

	return newRow;
}

-(void)setBinding:(NSString*)binding forKey:(NSString*)keyPath andOrAction:(SEL)action on:(NSControl*)newControl
{
	[newControl bind:binding
			toObject:[NSUserDefaults standardUserDefaults]
		 withKeyPath:keyPath
			 options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES]
												 forKey:@"NSContinuouslyUpdatesValue"]];
	if ( nil != action )
	{
		[newControl setTarget:self];
		[newControl setAction:action];
	}
}

-(void) buildAppearancesPreferencePanel
{
	NSRect screenFrame = [[NSScreen mainScreen] frame];

	int nextYMax = -1;
	NSView *row = [self preferencePanelSliderRowForText:@"Bezel transparency"
											 withTicks:16
											   minText:@"Lighter"
											   maxText:@"Darker"
											  minValue:0.1
											  maxValue:0.9
											 frameMaxY:nextYMax
											   binding:@"bezelAlpha"
												action:@selector(setBezelAlpha:)];
	[appearancePanel addSubview:row];
	nextYMax = row.frame.origin.y;

	row = [self preferencePanelSliderRowForText:@"Bezel width"
									  withTicks:50
										minText:@"Smaller"
										maxText:@"Bigger"
									   minValue:200
									   maxValue:screenFrame.size.width
									  frameMaxY:nextYMax
										binding:@"bezelWidth"
										 action:@selector(setBezelWidth:)];
	[appearancePanel addSubview:row];
	nextYMax = row.frame.origin.y;

	row = [self preferencePanelSliderRowForText:@"Bezel height"
									  withTicks:50
										minText:@"Smaller"
										maxText:@"Bigger"
									   minValue:200
									   maxValue:screenFrame.size.height
									  frameMaxY:nextYMax
										binding:@"bezelHeight"
										 action:@selector(setBezelHeight:)];
	[appearancePanel addSubview:row];
	nextYMax = row.frame.origin.y;

	row = [self preferencePanelPopUpRowForText:@"Menu item icon"
										 items:[NSArray arrayWithObjects:
												@"Flycut icon",
												@"Black Flycut icon",
												@"White scissors",
												@"Black scissors",nil]
									 frameMaxY:nextYMax
									   binding:@"menuIcon"
										action:@selector(switchMenuIcon:)];
	[appearancePanel addSubview:row];
	nextYMax = row.frame.origin.y;

//	row = [self preferencePanelCheckboxRowForText:@"Animate bezel appearance"
//										frameMaxY:nextYMax
//										  binding:@"popUpAnimation"
//										   action:nil];
//	[appearancePanel addSubview:row];
//	nextYMax = row.frame.origin.y;

    row = [self preferencePanelCheckboxRowForText:@"Show clipping source app and time"
                                        frameMaxY:nextYMax
                                          binding:@"displayClippingSource"
                                           action:@selector(setupBezel:)];
    [appearancePanel addSubview:row];
    nextYMax = row.frame.origin.y;
}

-(IBAction) showPreferencePanel:(id)sender
{
    [currentRunningApplication release];
    currentRunningApplication = nil; // So it doesn't get pulled foreground atop the preference panel.
	if ([prefsPanel respondsToSelector:@selector(setCollectionBehavior:)])
		[prefsPanel setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
	[NSApp activateIgnoringOtherApps: YES];
	[prefsPanel makeKeyAndOrderFront:self];
	issuedRememberResizeWarning = NO;
}

-(IBAction)toggleLoadOnStartup:(id)sender {
	if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"loadOnStartup"] ) {
		[UKLoginItemRegistry addLoginItemWithPath:[[NSBundle mainBundle] bundlePath] hideIt:NO];
	} else {
		[UKLoginItemRegistry removeLoginItemWithPath:[[NSBundle mainBundle] bundlePath]];
	}
}

- (void)restoreStashedStoreAndUpdate
{
    if ([flycutOperator restoreStashedStore])
    {
        [bezel setColor:NO];
        [self updateBezel];
    }
}

- (void)pasteFromStack
{
	NSString *content = [flycutOperator getPasteFromStackPosition];
	if ( nil != content ) {
		[self addClipToPasteboard:content];
		[self performSelector:@selector(hideApp) withObject:nil afterDelay:0.2];
		[self performSelector:@selector(fakeCommandV) withObject:nil afterDelay:0.2];
	} else {
		[self performSelector:@selector(hideApp) withObject:nil afterDelay:0.2];
	}
    [self restoreStashedStoreAndUpdate];
}

- (void)moveItemAtStackPositionToTopOfStack
{
	if ( [flycutOperator stackPositionIsInBounds] ) {
		[self pasteIndexAndUpdate: [flycutOperator stackPosition]];
		[self performSelector:@selector(hideApp) withObject:nil afterDelay:0.2];
	} else {
		[self performSelector:@selector(hideApp) withObject:nil afterDelay:0.2];
	}
}

- (void)pasteIndexAndUpdate:(int) position {
    // If there is an active search, we need to map the menu index to the stack position.
    NSString* search = [searchBox stringValue];
    if ( nil != search && 0 != search.length )
    {
        NSArray *mapping = [flycutOperator previousIndexes:[[NSUserDefaults standardUserDefaults] integerForKey:@"displayNum"] containing:search];
        position = [mapping[position] intValue];
    }

    NSString *content = [flycutOperator getPasteFromIndex: position];
    if ( nil != content )
    {
        [self addClipToPasteboard:content];
        [self updateMenu];
	}
}

- (void)metaKeysReleased
{
	if ( ! isBezelPinned ) {
		[self pasteFromStack];
	}
}

-(void)fakeKey:(NSNumber*) keyCode withCommandFlag:(BOOL) setFlag
	/*" +fakeKey synthesizes keyboard events. "*/
{     
    CGEventSourceRef sourceRef = CGEventSourceCreate(kCGEventSourceStateCombinedSessionState);
    if (!sourceRef)
    {
        DLog(@"No event source");
        return;
    }
    CGKeyCode veeCode = (CGKeyCode)[keyCode intValue];
    CGEventRef eventDown = CGEventCreateKeyboardEvent(sourceRef, veeCode, true);
    if ( setFlag )
        CGEventSetFlags(eventDown, kCGEventFlagMaskCommand|0x000008); // some apps want bit set for one of the command keys
    CGEventRef eventUp = CGEventCreateKeyboardEvent(sourceRef, veeCode, false);
    CGEventPost(kCGHIDEventTap, eventDown);
    CGEventPost(kCGHIDEventTap, eventUp);
    CFRelease(eventDown);
    CFRelease(eventUp);
    CFRelease(sourceRef);
}

/*" +fakeCommandV synthesizes keyboard events for Cmd-v Paste shortcut. "*/
-(void)fakeCommandV { [self fakeKey:[srTransformer reverseTransformedValue:@"V"] withCommandFlag:TRUE]; }

/*" +fakeDownArrow synthesizes keyboard events for the down-arrow key. "*/
-(void)fakeDownArrow { [self fakeKey:@125 withCommandFlag:FALSE]; }

/*" +fakeUpArrow synthesizes keyboard events for the up-arrow key. "*/
-(void)fakeUpArrow { [self fakeKey:@126 withCommandFlag:FALSE]; }

// Perform the search and display updated results when the user types.
-(void)controlTextDidChange:(NSNotification *)aNotification
{
    NSString* search = [searchBox stringValue];
    [self updateMenuContaining:search];
}

// Perform the search and display updated results when the search field performs its action.
-(IBAction)searchItems:(id)sender
{
    NSString* search = [searchBox stringValue];
    [self updateMenuContaining:search];
}

// Catch keystrokes in the search field and look for arrows.
-(BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
    if( commandSelector == @selector(moveUp:) )
    {
        [[searchBox window] makeFirstResponder:menuFirstResponder];
        [self fakeUpArrow];
        return YES;    // We handled this command; don't pass it on
    }
    if( commandSelector == @selector(moveDown:) )
    {
        [[searchBox window] makeFirstResponder:menuFirstResponder];
        [self fakeDownArrow];
        return YES;    // We handled this command; don't pass it on
    }

    return NO;    // Default handling of the command
}

-(void)pollPB:(NSTimer *)timer
{
    NSString *type = [jcPasteboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
    if ( [pbCount intValue] != [jcPasteboard changeCount] && ![flycutOperator storeDisabled] ) {
        // Reload pbCount with the current changeCount
        // Probably poor coding technique, but pollPB should be the only thing messing with pbCount, so it should be okay
        [pbCount release];
        pbCount = [[NSNumber numberWithInt:[jcPasteboard changeCount]] retain];
        if ( type != nil ) {
			NSRunningApplication *currRunningApp = nil;
			for (NSRunningApplication *currApp in [[NSWorkspace sharedWorkspace] runningApplications])
				if ([currApp isActive])
					currRunningApp = currApp;
			bool largeCopyRisk = nil != currRunningApp && [[currRunningApp localizedName] rangeOfString:@"Remote Desktop Connection"].location != NSNotFound;

			// Microsoft's Remote Desktop Connection has an issue with large copy actions, which appears to be in the time it takes to transer them over the network.  The copy starts being registered with OS X prior to completion of the transfer, and if the active application changes during the transfer the copy will be lost.  Indicate this time period by toggling the menu icon at the beginning of all RDC trasfers and back at the end.  Apple's Screen Sharing does not demonstrate this problem.
			if (largeCopyRisk)
				[self toggleMenuIconDisabled];

			// In case we need to do a status visual, this will be dispatched out so our thread isn't blocked.
			dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
			dispatch_async(queue, ^{

				// This operation blocks until the transfer is complete, though it was was here before the RDC issue was discovered.  Convenient.
                NSString *contents = [jcPasteboard stringForType:type];

				// Toggle back if dealing with the RDC issue.
				if (largeCopyRisk)
					[self toggleMenuIconDisabled];

				if ( contents == nil || [flycutOperator shouldSkip:contents ofType:[jcPasteboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]]] ) {
                   DLog(@"Contents: Empty or skipped");
               } else if ( ! [pbCount isEqualTo:pbBlockCount] ) {
                   [flycutOperator addClipping:contents ofType:type fromApp:[currRunningApp localizedName] withAppBundleURL:currRunningApp.bundleURL.path target:self clippingAddedSelector:@selector(updateMenu)];
               }
            });
        } 
    }
}

- (void)processBezelKeyDown:(NSEvent *)theEvent {
	int newStackPosition;
	// AppControl should only be getting these directly from bezel via delegation
	if ([theEvent type] == NSKeyDown) {
		if ([theEvent keyCode] == [mainRecorder keyCombo].code ) {
			if ([theEvent modifierFlags] & NSShiftKeyMask) [self stackUp];
			 else [self stackDown];
			return;
		}
		unichar pressed = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
        NSUInteger modifiers = [theEvent modifierFlags];
		switch (pressed) {
			case 0x1B:
				[self hideApp];
				break;
            case 0xD: // Enter or Return
				[self pasteFromStack];
				break;
			case 0x3:
                [self moveItemAtStackPositionToTopOfStack];
                break;
            case 0x2C: // Comma
                if ( modifiers & NSCommandKeyMask ) {
                    [self showPreferencePanel:nil];
                }
                break;
			case NSUpArrowFunctionKey: 
			case NSLeftArrowFunctionKey: 
            case 0x6B: // k
				[self stackUp];
				break;
			case NSDownArrowFunctionKey: 
			case NSRightArrowFunctionKey:
            case 0x6A: // j
				[self stackDown];
				break;
            case NSHomeFunctionKey:
				if ( [flycutOperator setStackPositionToFirstItem] ) {
					[self updateBezel];
				}
				break;
            case NSEndFunctionKey:
				if ( [flycutOperator setStackPositionToLastItem] ) {
					[self updateBezel];
				}
				break;
            case NSPageUpFunctionKey:
				if ( [flycutOperator setStackPositionToTenMoreRecent] ) {
					[self updateBezel];
				}
				break;
			case NSPageDownFunctionKey:
				if ( [flycutOperator setStackPositionToTenLessRecent] ) {
                    [self updateBezel];
                }
				break;
			case NSBackspaceCharacter:
            case NSDeleteCharacter:
                if ( [flycutOperator clearItemAtStackPosition] ) {
                    [self updateBezel];
                    [self updateMenu];
                }
                break;
            case NSDeleteFunctionKey: break;
			case 0x30: case 0x31: case 0x32: case 0x33: case 0x34: 				// Numeral 
			case 0x35: case 0x36: case 0x37: case 0x38: case 0x39:
				// We'll currently ignore the possibility that the user wants to do something with shift.
				// First, let's set the new stack count to "10" if the user pressed "0"
				newStackPosition = pressed == 0x30 ? 9 : [[NSString stringWithCharacters:&pressed length:1] intValue] - 1;
				if ( [flycutOperator setStackPositionTo: newStackPosition] ) {
					[self fillBezel];
				}
				break;
            case 's': case 'S': // Save / Save-and-delete
                {
                    bool success = [flycutOperator saveFromStack];
                    [self performSelector:@selector(hideApp) withObject:nil afterDelay:0.2];
                    [self restoreStashedStoreAndUpdate];

                    if ( success ) {
                        if ( modifiers & NSShiftKeyMask ) {
                            [flycutOperator clearItemAtStackPosition];
                            [self updateBezel];
                            [self updateMenu];
                        }
                    }
                }
                break;
            case 'f':
                [flycutOperator toggleToFromFavoritesStore];
                [bezel setColor:[flycutOperator favoritesStoreIsSelected]];
                [self updateBezel];
                [self hideBezel];
                [self showBezel];
                break;
            case 'F':
                if ( [flycutOperator saveFromStackToFavorites] )
                {
                    [self performSelector:@selector(hideApp) withObject:nil afterDelay:0.2];
                    [self restoreStashedStoreAndUpdate];
                    [self updateBezel];
                    [self updateMenu];
                }

                [self performSelector:@selector(hideApp) withObject:nil afterDelay:0.2];
                break;
            default: // It's not a navigation/application-defined thing, so let's figure out what to do with it.
				DLog(@"PRESSED %d", pressed);
				DLog(@"CODE %ld", (long)[mainRecorder keyCombo].code);
				break;
		}		
    }
}

-(void) processBezelMouseEvents:(NSEvent *)theEvent {
    if (theEvent.type == NSScrollWheel) {
        if (theEvent.deltaY > 0.0f) {
            [self stackUp];
        } else if (theEvent.deltaY < 0.0f) {
            [self stackDown];
        }
    } else if (theEvent.type == NSLeftMouseUp && theEvent.clickCount == 2) {
        [self pasteFromStack];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
	//Create our hot key
	[self toggleMainHotKey:[NSNull null]];
}

- (void) updateBezel
{
	[flycutOperator adjustStackPositionIfOutOfBounds];
	if ([flycutOperator jcListCount] == 0) { // empty
		[bezel setText:@""];
		[bezel setCharString:@"Empty"];
        [bezel setSource:@""];
        [bezel setDate:@""];
        [bezel setSourceIcon:nil];
	}
	else { // normal
		[self fillBezel];
	}
}

- (void) showBezel
{
	if ( [flycutOperator stackPositionIsInBounds] ) {
		[self fillBezel];
	}
	NSRect mainScreenRect = [NSScreen mainScreen].visibleFrame;
	[bezel setFrame:NSMakeRect(mainScreenRect.origin.x + mainScreenRect.size.width/2 - bezel.frame.size.width/2,
							   mainScreenRect.origin.y + mainScreenRect.size.height/2 - bezel.frame.size.height/2,
							   bezel.frame.size.width,
							   bezel.frame.size.height) display:YES];
	if ([bezel respondsToSelector:@selector(setCollectionBehavior:)])
		[bezel setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
//	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"popUpAnimation"])
//		[bezel makeKeyAndOrderFrontWithPopEffect];
//	else
    [bezel makeKeyAndOrderFront:self];
	isBezelDisplayed = YES;
}

- (void) hideBezel
{
	[bezel orderOut:nil];
	[bezel setCharString:@"Empty"];
	isBezelDisplayed = NO;
}

-(void)hideApp
{
	[self hideBezel];
	isBezelPinned = NO;
	[NSApp hide:self];
}

- (void) applicationWillResignActive:(NSApplication *)app; {
	// This should be hidden anyway, but just in case it's not.
	[self hideBezel];
}


- (void)hitMainHotKey:(SGHotKey *)hotKey
{
	if ( ! isBezelDisplayed ) {
		//Do NOT activate the app so focus stays on app the user is interacting with
		//https://github.com/TermiT/Flycut/issues/45
		//[NSApp activateIgnoringOtherApps:YES];
		if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"stickyBezel"] ) {
			isBezelPinned = YES;
		}
		[self showBezel];
	} else {
		[self stackDown];
	}
}

- (IBAction)toggleMainHotKey:(id)sender
{
	if (mainHotKey != nil)
	{
		[[SGHotKeyCenter sharedCenter] unregisterHotKey:mainHotKey];
		[mainHotKey release];
		mainHotKey = nil;
	}
	mainHotKey = [[SGHotKey alloc] initWithIdentifier:@"mainHotKey"
											   keyCombo:[SGKeyCombo keyComboWithKeyCode:[mainRecorder keyCombo].code
																			  modifiers:[mainRecorder cocoaToCarbonFlags: [mainRecorder keyCombo].flags]]];
	[mainHotKey setName: @"Activate Flycut HotKey"]; //This is typically used by PTKeyComboPanel
	[mainHotKey setTarget: self];
	[mainHotKey setAction: @selector(hitMainHotKey:)];
	[[SGHotKeyCenter sharedCenter] registerHotKey:mainHotKey];
}

-(IBAction)clearClippingList:(id)sender {
    int choice;
	
	[NSApp activateIgnoringOtherApps:YES];
    choice = NSRunAlertPanel(@"Clear Clipping List", 
							 @"Do you want to clear all recent clippings?",
							 @"Clear", @"Cancel", nil);
	
    // on clear, zap the list and redraw the menu
    if ( choice == NSAlertDefaultReturn ) {
        [self restoreStashedStoreAndUpdate]; // Only clear the clipping store.  Never the favorites.
        [flycutOperator clearList];
        [self updateMenu];
		if ( [[NSUserDefaults standardUserDefaults] integerForKey:@"savePreference"] >= 1 ) {
			[flycutOperator saveEngine];
		}
		[bezel setText:@""];
    }
}

-(IBAction)mergeClippingList:(id)sender {
    [flycutOperator mergeList];
    [self updateMenu];
}

- (void)updateMenu {
    [self updateMenuContaining:nil];
    // Clear the search box whenever the is reason for updateMenu to be called, since the nil call will produce non-searched results.
    [searchBox setStringValue:@""];
    [[[searchBox cell] cancelButtonCell] performClick:self];
}

- (void)updateMenuContaining:(NSString*)search {
    [jcMenu setMenuChangedMessagesEnabled:NO];
    
    NSArray *returnedDisplayStrings = [flycutOperator previousDisplayStrings:[[NSUserDefaults standardUserDefaults] integerForKey:@"displayNum"] containing:search];
    
    NSArray *menuItems = [[[jcMenu itemArray] reverseObjectEnumerator] allObjects];
    
    NSArray *clipStrings = [[returnedDisplayStrings reverseObjectEnumerator] allObjects];

    // Figure out if the number of menu items is changing and add or remove entries as necessary.
    // If we remove all of them and add all new ones, the menu won't redraw if the count is unchanged, so just reuse them by changing their title.
    int oldItems = [menuItems count]-jcMenuBaseItemsCount;
    int newItems = [clipStrings count];

    if ( oldItems > newItems )
    {
        for ( int i = newItems; i < oldItems; i++ )
            [jcMenu removeItemAtIndex:0];
    }
    else if ( newItems > oldItems )
    {
        for ( int i = oldItems; i < newItems; i++ )
        {
            NSMenuItem *item;
            item = [[NSMenuItem alloc] initWithTitle:@"foo"
                                              action:@selector(processMenuClippingSelection:)
                                       keyEquivalent:@""];
            [item setTarget:self];
            [item setEnabled:YES];
            [jcMenu insertItem:item atIndex:0];
            // Way back in 0.2, failure to release the new item here was causing a quite atrocious memory leak.
            [item release];
        }
    }
	
    // Now set the correct titles for each menu item.
    for(NSString *pbMenuTitle in clipStrings) {
        newItems--;
        NSMenuItem *item = [jcMenu itemAtIndex:newItems];
        item.title = pbMenuTitle;
        [jcMenu itemChanged: item];
	}
}

-(IBAction)processMenuClippingSelection:(id)sender
{
	int index=[[sender menu] indexOfItem:sender];
	[self pasteIndexAndUpdate:index];

	if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"menuSelectionPastes"] ) {
		[self performSelector:@selector(hideApp) withObject:nil];
		[self performSelector:@selector(fakeCommandV) withObject:nil afterDelay:0.2];
	}
}

-(void) setPBBlockCount:(NSNumber *)newPBBlockCount
{
    [newPBBlockCount retain];
    [pbBlockCount release];
    pbBlockCount = newPBBlockCount;
}

-(void)addClipToPasteboard:(NSString*)pbFullText
{
    NSArray *pbTypes;
    pbTypes = [NSArray arrayWithObjects:@"NSStringPboardType",NULL];
    
    [jcPasteboard declareTypes:pbTypes owner:NULL];
	
    [jcPasteboard setString:pbFullText forType:@"NSStringPboardType"];
    [self setPBBlockCount:[NSNumber numberWithInt:[jcPasteboard changeCount]]];
}

-(void) stackDown
{
	if ( [flycutOperator setStackPositionToOneLessRecent] ) {
		[self fillBezel];
	}
}

-(void) fillBezel
{
    FlycutClipping* clipping = [flycutOperator clippingAtStackPosition];
    [bezel setText:[NSString stringWithFormat:@"%@", [clipping contents]]];
    [bezel setCharString:[NSString stringWithFormat:@"%d of %d", [flycutOperator stackPosition] + 1, [flycutOperator jcListCount]]];
    NSString *localizedName = [clipping appLocalizedName];
    if ( nil == localizedName )
        localizedName = @"";
    NSString* dateString = @"";
    if ( [clipping timestamp] > 0)
        dateString = [dateFormat stringFromDate:[NSDate dateWithTimeIntervalSince1970: [clipping timestamp]]];
    NSImage* icon = nil;
    if (nil != [clipping appBundleURL])
        icon = [[NSWorkspace sharedWorkspace] iconForFile:[clipping appBundleURL]];
    [bezel setSource:localizedName];
    [bezel setDate:dateString];
    [bezel setSourceIcon:icon];
}

-(void) stackUp
{
	if ( [flycutOperator setStackPositionToOneMoreRecent] ) {
		[self fillBezel];
	}
}

- (void)setHotKeyPreferenceForRecorder:(SRRecorderControl *)aRecorder {
	if (aRecorder == mainRecorder) {
		[[NSUserDefaults standardUserDefaults] setObject:
			[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[NSNumber numberWithInt:[mainRecorder keyCombo].code],[NSNumber numberWithInt:[mainRecorder keyCombo].flags],nil] forKeys:[NSArray arrayWithObjects:@"keyCode",@"modifierFlags",nil]]
		forKey:@"ShortcutRecorder mainHotkey"];
	}
}

- (BOOL)shortcutRecorder:(SRRecorderControl *)aRecorder isKeyCode:(NSInteger)keyCode andFlagsTaken:(NSUInteger)flags reason:(NSString **)aReason {
	return NO;
}

- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo {
	if (aRecorder == mainRecorder) {
		[self toggleMainHotKey: aRecorder];
		[self setHotKeyPreferenceForRecorder: aRecorder];
	}
	DLog(@"code: %ld, flags: %lu", (long)newKeyCombo.code, (unsigned long)newKeyCombo.flags);
}

- (void)applicationWillTerminate:(NSNotification *)notification {
	[flycutOperator applicationWillTerminate];
	//Unregister our hot key (not required)
	[[SGHotKeyCenter sharedCenter] unregisterHotKey: mainHotKey];
	[mainHotKey release];
	mainHotKey = nil;
	[self hideBezel];
	[[NSDistributedNotificationCenter defaultCenter]
		removeObserver:self
        		  name:@"AppleKeyboardPreferencesChangedNotification"
				object:nil];
	[[NSDistributedNotificationCenter defaultCenter]
		removeObserver:self
				  name:@"AppleSelectedInputSourcesChangedNotification"
				object:nil];
}

- (void) dealloc {
	[bezel release];
	[srTransformer release];
	[super dealloc];
}

@end
