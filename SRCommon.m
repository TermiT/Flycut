//
//  SRCommon.m
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

#import "SRCommon.h"
#import "SRKeyCodeTransformer.h"

//#define SRCommon_PotentiallyUsefulDebugInfo

#ifdef	SRCommon_PotentiallyUsefulDebugInfo
#define PUDNSLog(X,...)	NSLog(X,##__VA_ARGS__)
#else
#define PUDNSLog(X,...)	{ ; }
#endif

#pragma mark -
#pragma mark dummy class 

@implementation SRDummyClass @end

#pragma mark -

//---------------------------------------------------------- 
// SRStringForKeyCode()
//---------------------------------------------------------- 
NSString * SRStringForKeyCode( signed short keyCode )
{
    static SRKeyCodeTransformer *keyCodeTransformer = nil;
    if ( !keyCodeTransformer )
        keyCodeTransformer = [[SRKeyCodeTransformer alloc] init];
    return [keyCodeTransformer transformedValue:[NSNumber numberWithShort:keyCode]];
}

//---------------------------------------------------------- 
// SRStringForCarbonModifierFlags()
//---------------------------------------------------------- 
NSString * SRStringForCarbonModifierFlags( unsigned int flags )
{
    NSString *modifierFlagsString = [NSString stringWithFormat:@"%@%@%@%@", 
		( flags & controlKey ? [NSString stringWithFormat:@"%C", KeyboardControlGlyph] : @"" ),
		( flags & optionKey ? [NSString stringWithFormat:@"%C", KeyboardOptionGlyph] : @"" ),
		( flags & shiftKey ? [NSString stringWithFormat:@"%C", KeyboardShiftGlyph] : @"" ),
		( flags & cmdKey ? [NSString stringWithFormat:@"%C", KeyboardCommandGlyph] : @"" )];
	return modifierFlagsString;
}

//---------------------------------------------------------- 
// SRStringForCarbonModifierFlagsAndKeyCode()
//---------------------------------------------------------- 
NSString * SRStringForCarbonModifierFlagsAndKeyCode( unsigned int flags, signed short keyCode )
{
    return [NSString stringWithFormat: @"%@%@", 
        SRStringForCarbonModifierFlags( flags ), 
        SRStringForKeyCode( keyCode )];
}

//---------------------------------------------------------- 
// SRStringForCocoaModifierFlags()
//---------------------------------------------------------- 
NSString * SRStringForCocoaModifierFlags( unsigned int flags )
{
    NSString *modifierFlagsString = [NSString stringWithFormat:@"%@%@%@%@", 
		( flags & NSControlKeyMask ? [NSString stringWithFormat:@"%C", KeyboardControlGlyph] : @"" ),
		( flags & NSAlternateKeyMask ? [NSString stringWithFormat:@"%C", KeyboardOptionGlyph] : @"" ),
		( flags & NSShiftKeyMask ? [NSString stringWithFormat:@"%C", KeyboardShiftGlyph] : @"" ),
		( flags & NSCommandKeyMask ? [NSString stringWithFormat:@"%C", KeyboardCommandGlyph] : @"" )];
	
	return modifierFlagsString;
}

//---------------------------------------------------------- 
// SRStringForCocoaModifierFlagsAndKeyCode()
//---------------------------------------------------------- 
NSString * SRStringForCocoaModifierFlagsAndKeyCode( unsigned int flags, signed short keyCode )
{
    return [NSString stringWithFormat: @"%@%@", 
        SRStringForCocoaModifierFlags( flags ),
        SRStringForKeyCode( keyCode )];
}

//---------------------------------------------------------- 
// SRReadableStringForCarbonModifierFlagsAndKeyCode()
//---------------------------------------------------------- 
NSString * SRReadableStringForCarbonModifierFlagsAndKeyCode( unsigned int flags, signed short keyCode )
{
    NSString *readableString = [NSString stringWithFormat:@"%@%@%@%@%@", 
		( flags & cmdKey ? SRLoc(@"Command + ") : @""),
		( flags & optionKey ? SRLoc(@"Option + ") : @""),
		( flags & controlKey ? SRLoc(@"Control + ") : @""),
		( flags & shiftKey ? SRLoc(@"Shift + ") : @""),
        SRStringForKeyCode( keyCode )];
	return readableString;    
}

//---------------------------------------------------------- 
// SRReadableStringForCocoaModifierFlagsAndKeyCode()
//---------------------------------------------------------- 
NSString * SRReadableStringForCocoaModifierFlagsAndKeyCode( unsigned int flags, signed short keyCode )
{
    NSString *readableString = [NSString stringWithFormat:@"%@%@%@%@%@", 
		(flags & NSCommandKeyMask ? SRLoc(@"Command + ") : @""),
		(flags & NSAlternateKeyMask ? SRLoc(@"Option + ") : @""),
		(flags & NSControlKeyMask ? SRLoc(@"Control + ") : @""),
		(flags & NSShiftKeyMask ? SRLoc(@"Shift + ") : @""),
        SRStringForKeyCode( keyCode )];
	return readableString;
}

//---------------------------------------------------------- 
// SRCarbonToCocoaFlags()
//---------------------------------------------------------- 
unsigned int SRCarbonToCocoaFlags( unsigned int carbonFlags )
{
	unsigned int cocoaFlags = ShortcutRecorderEmptyFlags;
	
	if (carbonFlags & cmdKey) cocoaFlags |= NSCommandKeyMask;
	if (carbonFlags & optionKey) cocoaFlags |= NSAlternateKeyMask;
	if (carbonFlags & controlKey) cocoaFlags |= NSControlKeyMask;
	if (carbonFlags & shiftKey) cocoaFlags |= NSShiftKeyMask;
	if (carbonFlags & NSFunctionKeyMask) cocoaFlags += NSFunctionKeyMask;
	
	return cocoaFlags;
}

//---------------------------------------------------------- 
// SRCocoaToCarbonFlags()
//---------------------------------------------------------- 
unsigned int SRCocoaToCarbonFlags( unsigned int cocoaFlags )
{
	unsigned int carbonFlags = ShortcutRecorderEmptyFlags;
	
	if (cocoaFlags & NSCommandKeyMask) carbonFlags |= cmdKey;
	if (cocoaFlags & NSAlternateKeyMask) carbonFlags |= optionKey;
	if (cocoaFlags & NSControlKeyMask) carbonFlags |= controlKey;
	if (cocoaFlags & NSShiftKeyMask) carbonFlags |= shiftKey;
	if (cocoaFlags & NSFunctionKeyMask) carbonFlags |= NSFunctionKeyMask;
	
	return carbonFlags;
}

//---------------------------------------------------------- 
// SRCharacterForKeyCodeAndCarbonFlags()
//----------------------------------------------------------
NSString *SRCharacterForKeyCodeAndCarbonFlags(signed short keyCode, unsigned int carbonFlags) {
	return SRCharacterForKeyCodeAndCocoaFlags(keyCode, SRCarbonToCocoaFlags(carbonFlags));
}

//---------------------------------------------------------- 
// SRCharacterForKeyCodeAndCocoaFlags()
//----------------------------------------------------------
NSString *SRCharacterForKeyCodeAndCocoaFlags(signed short keyCode, unsigned int cocoaFlags) {
	
	PUDNSLog(@"SRCharacterForKeyCodeAndCocoaFlags, keyCode: %hi, cocoaFlags: %u",
			 keyCode, cocoaFlags);
	
	// Fall back to string based on key code:
#define	FailWithNaiveString SRStringForKeyCode(keyCode)
	
	UCKeyboardLayout        *uchrData;
	void                *KCHRData;
	SInt32              keyLayoutKind;
    KeyboardLayoutRef currentLayout;
    UInt32          keyTranslateState;
	UInt32              deadKeyState;
    OSStatus err = noErr;
    CFLocaleRef locale = CFLocaleCopyCurrent();
	
	CFMutableStringRef resultString;
	
    err = KLGetCurrentKeyboardLayout( &currentLayout );
    if(err != noErr)
		return FailWithNaiveString;
	
    err = KLGetKeyboardLayoutProperty( currentLayout, kKLKind, (const void **)&keyLayoutKind );
    if (err != noErr)
		return FailWithNaiveString;
	
    if (keyLayoutKind == kKLKCHRKind) {
		PUDNSLog(@"KCHR kind key layout");
		err = KLGetKeyboardLayoutProperty( currentLayout, kKLKCHRData, (const void **)&KCHRData );
		if (err != noErr)
			return FailWithNaiveString;
    } else {
		PUDNSLog(@"uchr kind key layout");
		err = KLGetKeyboardLayoutProperty( currentLayout, kKLuchrData, (const void **)&uchrData );
		if (err !=  noErr)
			return FailWithNaiveString;
    }
	
    if (keyLayoutKind == kKLKCHRKind) {
		UInt16 keyc = (UInt16)keyCode;
		keyc |= (1 << 7);
		if (cocoaFlags & NSAlternateKeyMask) keyc |= optionKey;
		if (cocoaFlags & NSShiftKeyMask) keyc |= shiftKey;

		UInt32 charCode = KeyTranslate( KCHRData, keyc, &keyTranslateState );

		charCode = CFSwapInt32BigToHost(charCode);
		PUDNSLog(@"char code: %X", charCode);
		UniChar chars[2];
		CFIndex length = 0;

		// Thanks to Peter Hosey for this particular piece of henious villainy.
		union {
			UInt32 uint32;
			struct { // No, we don't need to conditionally compile these with different orders since we swap the int.
				char reserved1;
				char char1;
				char reserved2;
				char char2;
			} charStruct;
		} charactersUnion;
		charactersUnion.uint32 = charCode;
		if(charactersUnion.charStruct.char1) {
			chars[0] = charactersUnion.charStruct.char1;
			chars[1] = charactersUnion.charStruct.char2;
			length = 2;
		} else {
			chars[0] = charactersUnion.charStruct.char2;
			length = 1;
		}
		CFStringRef temp = CFStringCreateWithCharacters(kCFAllocatorDefault, chars, length); 
		resultString = CFStringCreateMutableCopy(kCFAllocatorDefault, 0,temp);
		if(temp)
			CFRelease(temp);
	} else {
		EventModifiers modifiers = 0;
		if (cocoaFlags & NSAlternateKeyMask)	modifiers |= optionKey;
		if (cocoaFlags & NSShiftKeyMask)		modifiers |= shiftKey;
		UniCharCount maxStringLength = 4, actualStringLength;
		UniChar unicodeString[4];
		err = UCKeyTranslate( uchrData, (UInt16)keyCode, kUCKeyActionDisplay, modifiers, LMGetKbdType(), kUCKeyTranslateNoDeadKeysBit, &deadKeyState, maxStringLength, &actualStringLength, unicodeString );
		CFStringRef temp = CFStringCreateWithCharacters(kCFAllocatorDefault, unicodeString, 1);
		resultString = CFStringCreateMutableCopy(kCFAllocatorDefault, 0,temp);
		if(temp)
			CFRelease(temp);
	}   
	CFStringCapitalize(resultString, locale);
	CFRelease(locale);
	
	PUDNSLog(@"character: -%@-", (NSString *)resultString);
	
	return (NSString *)resultString;
	
}

#pragma mark Animation Easing

// From: http://developer.apple.com/samplecode/AnimatedSlider/ as "easeFunction"
double SRAnimationEaseInOut(double t) {
	// This function implements a sinusoidal ease-in/ease-out for t = 0 to 1.0.  T is scaled to represent the interval of one full period of the sine function, and transposed to lie above the X axis.
	double x = ((sin((t * M_PI) - M_PI_2) + 1.0 ) / 2.0);
//	NSLog(@"SRAnimationEaseInOut: %f. a: %f, b: %f, c: %f, d: %f, e: %f", t, (t * M_PI), ((t * M_PI) - M_PI_2), sin((t * M_PI) - M_PI_2), (sin((t * M_PI) - M_PI_2) + 1.0), x);
	return x;
} 


#pragma mark -
#pragma mark additions

@implementation NSBezierPath( SRAdditions )

//---------------------------------------------------------- 
// + bezierPathWithSRCRoundRectInRect:radius:
//---------------------------------------------------------- 
+ (NSBezierPath*)bezierPathWithSRCRoundRectInRect:(NSRect)aRect radius:(float)radius
{
	NSBezierPath* path = [self bezierPath];
	radius = MIN(radius, 0.5f * MIN(NSWidth(aRect), NSHeight(aRect)));
	NSRect rect = NSInsetRect(aRect, radius, radius);
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMinY(rect)) radius:radius startAngle:180.0 endAngle:270.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMinY(rect)) radius:radius startAngle:270.0 endAngle:360.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(rect), NSMaxY(rect)) radius:radius startAngle:  0.0 endAngle: 90.0];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect), NSMaxY(rect)) radius:radius startAngle: 90.0 endAngle:180.0];
	[path closePath];
	return path;
}

@end

@implementation NSError( SRAdditions )

- (NSString *)localizedDescription
{
	return [[self userInfo] objectForKey:@"NSLocalizedDescription"];
}

- (NSString *)localizedFailureReason
{
	return [[self userInfo] objectForKey:@"NSLocalizedFailureReasonErrorKey"];
}

- (NSString *)localizedRecoverySuggestion
{
	return [[self userInfo] objectForKey:@"NSLocalizedRecoverySuggestionErrorKey"];	
}

- (NSArray *)localizedRecoveryOptions
{
	return [[self userInfo] objectForKey:@"NSLocalizedRecoveryOptionsKey"];
}

@end

@implementation NSAlert( SRAdditions )

//---------------------------------------------------------- 
// + alertWithNonRecoverableError:
//---------------------------------------------------------- 
+ (NSAlert *) alertWithNonRecoverableError:(NSError *)error;
{
	NSString *reason = [error localizedRecoverySuggestion];
	return [self alertWithMessageText:[error localizedDescription]
						defaultButton:[[error localizedRecoveryOptions] objectAtIndex:0U]
					  alternateButton:nil
						  otherButton:nil
			informativeTextWithFormat:(reason ? reason : @"")];
}

@end

static NSMutableDictionary *SRSharedImageCache = nil;

@interface SRSharedImageProvider (Private)
+ (void)_drawSRSnapback:(id)anNSCustomImageRep;
+ (NSValue *)_sizeSRSnapback;
+ (void)_drawSRRemoveShortcut:(id)anNSCustomImageRep;
+ (NSValue *)_sizeSRRemoveShortcut;
+ (void)_drawSRRemoveShortcutRollover:(id)anNSCustomImageRep;
+ (NSValue *)_sizeSRRemoveShortcutRollover;
+ (void)_drawSRRemoveShortcutPressed:(id)anNSCustomImageRep;
+ (NSValue *)_sizeSRRemoveShortcutPressed;

+ (void)_drawARemoveShortcutBoxUsingRep:(id)anNSCustomImageRep opacity:(double)opacity;
@end

@implementation SRSharedImageProvider
+ (NSImage *)supportingImageWithName:(NSString *)name {
//	NSLog(@"supportingImageWithName: %@", name);
	if (nil == SRSharedImageCache) {
		SRSharedImageCache = [[NSMutableDictionary dictionary] retain];
//		NSLog(@"inited cache");
	}
	NSImage *cachedImage = nil;
	if (nil != (cachedImage = [SRSharedImageCache objectForKey:name])) {
//		NSLog(@"returned cached image: %@", cachedImage);
		return cachedImage;
	}
	
//	NSLog(@"constructing image");
	NSSize size;
	NSValue *sizeValue = [self performSelector:NSSelectorFromString([NSString stringWithFormat:@"_size%@", name])];
	size = [sizeValue sizeValue];
//	NSLog(@"size: %@", NSStringFromSize(size));
	
	NSCustomImageRep *customImageRep = [[NSCustomImageRep alloc] initWithDrawSelector:NSSelectorFromString([NSString stringWithFormat:@"_draw%@:", name]) delegate:self];
	[customImageRep setSize:size];
//	NSLog(@"created customImageRep: %@", customImageRep);
	NSImage *returnImage = [[NSImage alloc] initWithSize:size];
	[returnImage addRepresentation:customImageRep];
	[returnImage setScalesWhenResized:YES];
	[SRSharedImageCache setObject:returnImage forKey:name];
	
#ifdef SRCommonWriteDebugImagery
	
	NSData *tiff = [returnImage TIFFRepresentation];
	[tiff writeToURL:[NSURL fileURLWithPath:[[NSString stringWithFormat:@"~/Desktop/m_%@.tiff", name] stringByExpandingTildeInPath]] atomically:YES];

	NSSize sizeQDRPL = NSMakeSize(size.width*4.0,size.height*4.0);
	
//	sizeQDRPL = NSMakeSize(70.0,70.0);
	NSCustomImageRep *customImageRepQDRPL = [[NSCustomImageRep alloc] initWithDrawSelector:NSSelectorFromString([NSString stringWithFormat:@"_draw%@:", name]) delegate:self];
	[customImageRepQDRPL setSize:sizeQDRPL];
//	NSLog(@"created customImageRepQDRPL: %@", customImageRepQDRPL);
	NSImage *returnImageQDRPL = [[NSImage alloc] initWithSize:sizeQDRPL];
	[returnImageQDRPL addRepresentation:customImageRepQDRPL];
	[returnImageQDRPL setScalesWhenResized:YES];
	[returnImageQDRPL setFlipped:YES];
	NSData *tiffQDRPL = [returnImageQDRPL TIFFRepresentation];
	[tiffQDRPL writeToURL:[NSURL fileURLWithPath:[[NSString stringWithFormat:@"~/Desktop/m_QDRPL_%@.tiff", name] stringByExpandingTildeInPath]] atomically:YES];
	
#endif
	
//	NSLog(@"returned image: %@", returnImage);
	return [returnImage autorelease];
}
@end

@implementation SRSharedImageProvider (Private)

#define MakeRelativePoint(x,y)	NSMakePoint(x*hScale, y*vScale)

+ (NSValue *)_sizeSRSnapback {
	return [NSValue valueWithSize:NSMakeSize(14.0,14.0)];
}
+ (void)_drawSRSnapback:(id)anNSCustomImageRep {
	
//	NSLog(@"drawSRSnapback using: %@", anNSCustomImageRep);
	
	NSCustomImageRep *rep = anNSCustomImageRep;
	NSSize size = [rep size];
	[[NSColor whiteColor] setFill];
	double hScale = (size.width/1.0);
	double vScale = (size.height/1.0);
	
	NSBezierPath *bp = [[NSBezierPath alloc] init];
	[bp setLineWidth:hScale];
	
	[bp moveToPoint:MakeRelativePoint(0.0489685, 0.6181513)];
	[bp lineToPoint:MakeRelativePoint(0.4085750, 0.9469318)];
	[bp lineToPoint:MakeRelativePoint(0.4085750, 0.7226146)];
	[bp curveToPoint:MakeRelativePoint(0.8508247, 0.4836237) controlPoint1:MakeRelativePoint(0.4085750, 0.7226146) controlPoint2:MakeRelativePoint(0.8371143, 0.7491841)];
	[bp curveToPoint:MakeRelativePoint(0.5507195, 0.0530682) controlPoint1:MakeRelativePoint(0.8677834, 0.1545071) controlPoint2:MakeRelativePoint(0.5507195, 0.0530682)];
	[bp curveToPoint:MakeRelativePoint(0.7421721, 0.3391942) controlPoint1:MakeRelativePoint(0.5507195, 0.0530682) controlPoint2:MakeRelativePoint(0.7458685, 0.1913146)];
	[bp curveToPoint:MakeRelativePoint(0.4085750, 0.5154130) controlPoint1:MakeRelativePoint(0.7383412, 0.4930328) controlPoint2:MakeRelativePoint(0.4085750, 0.5154130)];
	[bp lineToPoint:MakeRelativePoint(0.4085750, 0.2654000)];
	
	NSAffineTransform *flip = [[NSAffineTransform alloc] init];
//	[flip translateXBy:0.95 yBy:-1.0];
	[flip scaleXBy:0.9 yBy:1.0];
	[flip translateXBy:0.5 yBy:-0.5];
	
	[bp transformUsingAffineTransform:flip];
	
	NSShadow *sh = [[NSShadow alloc] init];
	[sh setShadowColor:[[NSColor blackColor] colorWithAlphaComponent:0.45]];
	[sh setShadowBlurRadius:1.0];
	[sh setShadowOffset:NSMakeSize(0.0,-1.0)];
	[sh set];
	
	[bp fill];
	
}

+ (NSValue *)_sizeSRRemoveShortcut {
	return [NSValue valueWithSize:NSMakeSize(14.0,14.0)];
}
+ (NSValue *)_sizeSRRemoveShortcutRollover { return [self _sizeSRRemoveShortcut]; }
+ (NSValue *)_sizeSRRemoveShortcutPressed { return [self _sizeSRRemoveShortcut]; }
+ (void)_drawARemoveShortcutBoxUsingRep:(id)anNSCustomImageRep opacity:(double)opacity {
	
//	NSLog(@"drawARemoveShortcutBoxUsingRep: %@ opacity: %f", anNSCustomImageRep, opacity);
	
	NSCustomImageRep *rep = anNSCustomImageRep;
	NSSize size = [rep size];
	[[NSColor colorWithCalibratedWhite:0.0 alpha:1-opacity] setFill];
	double hScale = (size.width/14.0);
	double vScale = (size.height/14.0);
	
	[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(0.0,0.0,size.width,size.height)] fill];
	
	[[NSColor whiteColor] setStroke];
	
	NSBezierPath *cross = [[NSBezierPath alloc] init];
	[cross setLineWidth:hScale*1.2];
	
	[cross moveToPoint:MakeRelativePoint(4,4)];
	[cross lineToPoint:MakeRelativePoint(10,10)];
	[cross moveToPoint:MakeRelativePoint(10,4)];
	[cross lineToPoint:MakeRelativePoint(4,10)];
		
	[cross stroke];
}
+ (void)_drawSRRemoveShortcut:(id)anNSCustomImageRep {
	
//	NSLog(@"drawSRRemoveShortcut using: %@", anNSCustomImageRep);
	
	[self _drawARemoveShortcutBoxUsingRep:anNSCustomImageRep opacity:0.75];
}
+ (void)_drawSRRemoveShortcutRollover:(id)anNSCustomImageRep {
	
//	NSLog(@"drawSRRemoveShortcutRollover using: %@", anNSCustomImageRep);
	
	[self _drawARemoveShortcutBoxUsingRep:anNSCustomImageRep opacity:0.65];	
}
+ (void)_drawSRRemoveShortcutPressed:(id)anNSCustomImageRep {
	
//	NSLog(@"drawSRRemoveShortcutPressed using: %@", anNSCustomImageRep);
	
	[self _drawARemoveShortcutBoxUsingRep:anNSCustomImageRep opacity:0.55];
}
@end
