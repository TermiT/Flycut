/* =============================================================================
FILE:		UKPrefsPanel.h

AUTHORS:	M. Uli Kusterer (UK), (c) Copyright 2003, all rights reserved.

DIRECTIONS:
UKPrefsPanel is ridiculously easy to use: Create a tabless NSTabView,
where the name of each tab is the name for the toolbar item, and the
identifier of each tab is the identifier to be used for the toolbar
item to represent it. Then create image files with the identifier as
their names to be used as icons in the toolbar.

Finally, drag UKPrefsPanel.h into the NIB with the NSTabView,
instantiate a UKPrefsPanel and connect its tabView outlet to your
NSTabView. When you open the window, the UKPrefsPanel will
automatically add a toolbar to the window with all tabs represented by
a toolbar item, and clicking an item will switch between the tab view's
items.


REVISIONS:
2003-08-13	UK	Added auto-save, fixed bug with empty window titles.
2003-07-22  UK  Added Panther stuff, documented.
2003-06-30  UK  Created.
========================================================================== */

/* -----------------------------------------------------------------------------
Headers:
-------------------------------------------------------------------------- */

#import "UKPrefsPanel.h"


@implementation UKPrefsPanel

/* -----------------------------------------------------------------------------
Constructor:
-------------------------------------------------------------------------- */

-(id) init
{
	if( self = [super init] )
	{
		tabView = nil;
		itemsList = [[NSMutableDictionary alloc] init];
		baseWindowName = [@"" retain];
	}
	
	return self;
}


/* -----------------------------------------------------------------------------
Destructor:
-------------------------------------------------------------------------- */

-(void)	dealloc
{
	[itemsList release];
	[baseWindowName release];
	[super dealloc];
}


/* -----------------------------------------------------------------------------
awakeFromNib:
This object and all others in the NIB have been created and hooked up.
Fetch the window name so we can modify it to indicate the current
page, and add our toolbar to the window.

This method is the great obstacle to making UKPrefsPanel an NSTabView
subclass. When the tab view's awakeFromNib method is called, the
individual tabs aren't set up yet, meaning mapTabsToToolbar gives us an
empty toolbar. ... bummer.

If anybody knows how to fix this, you're welcome to tell me.
-------------------------------------------------------------------------- */

-(void)	awakeFromNib
{
	NSString*		wndTitle = nil;
	
	// Generate a string containing the window's title so we can display the original window title plus the selected pane:
	wndTitle = [[tabView window] title];
	if( [wndTitle length] > 0 )
	{
		[baseWindowName release];
		baseWindowName = [[NSString stringWithFormat: @"%@ : ", wndTitle] retain];
	}
	
	
	[tabView selectTabViewItemAtIndex: 0];
	
	// Actually hook up our toolbar and the tabs:
	[self mapTabsToToolbar];
	[[tabView window] setFrame:NSMakeRect([[tabView window] frame].origin.x,
										  [[tabView window] frame].origin.y,
										  [[tabView window] frame].size.width,
										  [[tabView window] frame].size.height)
					   display:YES
					   animate:YES];
	id box = [[[[tabView tabViewItemAtIndex:[tabView indexOfTabViewItem:[tabView selectedTabViewItem]]] view] subviews] objectAtIndex:0];
	// We want to obtain our current contentView height and compare it to box
	if ([box isKindOfClass:[NSBox class]])
	{
		[self resizeToFit:box];
	}
}		


/* -----------------------------------------------------------------------------
mapTabsToToolbar:
Create a toolbar based on our tab control.

Tab title		-   Name for toolbar item.
Tab identifier  -	Image file name and toolbar item identifier.
-------------------------------------------------------------------------- */

-(void) mapTabsToToolbar
{
    // Create a new toolbar instance, and attach it to our document window 
    NSToolbar		*toolbar =[[tabView window] toolbar];
	int				itemCount = 0,
		x = 0;
	NSTabViewItem	*currPage = nil;
	
	if( toolbar == nil )   // No toolbar yet? Create one!
		toolbar = [[[NSToolbar alloc] initWithIdentifier:@"net.sf.Jumpcut.prefsToolbar"] autorelease];
	
    // Set up toolbar properties: Allow customization, give a default display mode, and remember state in user defaults 
    [toolbar setAllowsUserCustomization: YES];
    [toolbar setAutosavesConfiguration: NO];
    [toolbar setDisplayMode: NSToolbarDisplayModeIconAndLabel];
	
	// Set up item list based on Tab View:
	itemCount = [tabView numberOfTabViewItems];
	
	[itemsList removeAllObjects];	// In case we already had a toolbar.
	
	for( x = 0; x < itemCount; x++ )
	{
		NSTabViewItem*		theItem = [tabView tabViewItemAtIndex:x];
		NSString*			theIdentifier = [theItem identifier];
		NSString*			theLabel = [theItem label];
		[itemsList setObject:theLabel forKey:theIdentifier];
	}
    
    // We are the delegate
    [toolbar setDelegate: self];
    
    // Attach the toolbar to the document window 
    [[tabView window] setToolbar: toolbar];
	
	// Set up window title:
	currPage = [tabView selectedTabViewItem];
	if( currPage == nil )
		currPage = [tabView tabViewItemAtIndex:0];
//	[[tabView window] setTitle: [baseWindowName stringByAppendingString: [currPage label]]];
	
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_3
	if( [toolbar respondsToSelector: @selector(setSelectedItemIdentifier:)] )
		[toolbar setSelectedItemIdentifier: [currPage identifier]];
#endif

	// Jam in a flexible space to seperate out our acknowledgements tab
	// sbc
	int foo = [[toolbar items] count] - 1;
	[toolbar insertItemWithItemIdentifier:NSToolbarFlexibleSpaceItemIdentifier atIndex:foo];

}


/* -----------------------------------------------------------------------------
orderFrontPrefsPanel:
IBAction to assign to "Preferences..." menu item.
-------------------------------------------------------------------------- */

-(IBAction)		orderFrontPrefsPanel: (id)sender
{
	[[tabView window] makeKeyAndOrderFront:sender];
}


/* -----------------------------------------------------------------------------
setTabView:
Accessor for specifying the tab view to query.
-------------------------------------------------------------------------- */

-(void)			setTabView: (NSTabView*)tv
{
	tabView = tv;
}


-(NSTabView*)   tabView
{
	return tabView;
}

/* -----------------------------------------------------------------------------
toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:
Create an item with the proper image and name based on our list
of tabs for the specified identifier.
-------------------------------------------------------------------------- */

-(NSToolbarItem *) toolbar: (NSToolbar *)toolbar itemForItemIdentifier: (NSString *) itemIdent willBeInsertedIntoToolbar:(BOOL) willBeInserted
{
    // Required delegate method:  Given an item identifier, this method returns an item 
    // The toolbar will use this method to obtain toolbar items that can be displayed in the customization sheet, or in the toolbar itself 
    NSToolbarItem   *toolbarItem = [[[NSToolbarItem alloc] initWithItemIdentifier: itemIdent] autorelease];
    NSString*		itemLabel;
	
    if( (itemLabel = [itemsList objectForKey:itemIdent]) != nil )
	{
		// Set the text label to be displayed in the toolbar and customization palette 
		[toolbarItem setLabel: itemLabel];
		[toolbarItem setPaletteLabel: itemLabel];
		[toolbarItem setTag:[tabView indexOfTabViewItemWithIdentifier:itemIdent]];
		
		// Set up a reasonable tooltip, and image   Note, these aren't localized, but you will likely want to localize many of the item's properties 
		[toolbarItem setToolTip: itemLabel];
		[toolbarItem setImage: [NSImage imageNamed:itemIdent]];
		
		// Tell the item what message to send when it is clicked 
		[toolbarItem setTarget: self];
		[toolbarItem setAction: @selector(changePanes:)];
    }
	else
	{
		// itemIdent refered to a toolbar item that is not provide or supported by us or cocoa 
		// Returning nil will inform the toolbar this kind of item is not supported 
		toolbarItem = nil;
    }
	
    return toolbarItem;
}


/* -----------------------------------------------------------------------------
toolbarSelectableItemIdentifiers:
Make sure all our custom items can be selected. NSToolbar will
automagically select the appropriate item when it is clicked.
-------------------------------------------------------------------------- */

#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_3
-(NSArray*) toolbarSelectableItemIdentifiers: (NSToolbar*)toolbar
{
	return [itemsList allKeys];
}
#endif


/* -----------------------------------------------------------------------------
changePanes:
Action for our custom toolbar items that causes the window title to
reflect the current pane and the proper pane to be shown in response to
a click.
-------------------------------------------------------------------------- */

-(IBAction)	changePanes: (id)sender
{
	
	[tabView selectTabViewItemAtIndex: [sender tag]];
//	[[tabView window] setTitle: [baseWindowName stringByAppendingString: [sender label]]];
	
	id box = [[[[tabView tabViewItemAtIndex:[sender tag]] view] subviews] objectAtIndex:0];
	// We want to obtain our current contentView height and compare it to box
	if ([box isKindOfClass:[NSBox class]])
	{
		[tabView selectTabViewItemAtIndex: [sender tag]];
		[self resizeToFit:box];
	}
}

-(void) resizeToFit:(NSBox *)box
{
	float sizeDifference = [box frame].size.height - [[[tabView window] contentView] frame].size.height;
	[[tabView window] setFrame:NSMakeRect([[tabView window] frame].origin.x,
										  [[tabView window] frame].origin.y - sizeDifference,
										  [[tabView window] frame].size.width,
										  [[tabView window] frame].size.height + sizeDifference)
					   display:YES
					   animate:YES];
	[box setFrameOrigin:NSMakePoint([box frame].origin.x, 0)];
	[tabView setNeedsDisplay:YES];	
}

/* -----------------------------------------------------------------------------
toolbarDefaultItemIdentifiers:
Return the identifiers for all toolbar items that will be shown by
default.
This is simply a list of all tab view items in order.
-------------------------------------------------------------------------- */

-(NSArray*) toolbarDefaultItemIdentifiers: (NSToolbar *) toolbar
{
	int					itemCount = [tabView numberOfTabViewItems],
	x;
	NSTabViewItem*		theItem = [tabView tabViewItemAtIndex:0];
	//NSMutableArray*	defaultItems = [NSMutableArray arrayWithObjects: [theItem identifier], NSToolbarSeparatorItemIdentifier, nil];
	NSMutableArray*	defaultItems = [NSMutableArray array];
	
	for( x = 0; x < itemCount; x++ )
	{
		theItem = [tabView tabViewItemAtIndex:x];
		
		[defaultItems addObject: [theItem identifier]];
	}
	
	return defaultItems;
}


/* -----------------------------------------------------------------------------
toolbarAllowedItemIdentifiers:
Return the identifiers for all toolbar items that *can* be put in this
toolbar. We allow a couple more items (flexible space, separator lines
									   etc.) in addition to our custom items.
-------------------------------------------------------------------------- */

-(NSArray*) toolbarAllowedItemIdentifiers: (NSToolbar *) toolbar
{
    NSMutableArray*		allowedItems = [[[itemsList allKeys] mutableCopy] autorelease];
	
	[allowedItems addObjectsFromArray: [NSArray arrayWithObjects: NSToolbarSeparatorItemIdentifier,
		NSToolbarSpaceItemIdentifier, NSToolbarFlexibleSpaceItemIdentifier,
		NSToolbarCustomizeToolbarItemIdentifier, nil] ];
	
	return allowedItems;
}


@end
