//
//  NSWindow+ULIZoomEffect.h
//  Stacksmith
//
//  Created by Uli Kusterer on 05.03.11.
//  Copyright 2011 Uli Kusterer. All rights reserved.
//
//	This software is provided 'as-is', without any express or implied
//	warranty. In no event will the authors be held liable for any damages
//	arising from the use of this software.
//
//	Permission is granted to anyone to use this software for any purpose,
//	including commercial applications, and to alter it and redistribute it
//	freely, subject to the following restrictions:
//
//	   1. The origin of this software must not be misrepresented; you must not
//	   claim that you wrote the original software. If you use this software
//	   in a product, an acknowledgment in the product documentation would be
//	   appreciated but is not required.
//
//	   2. Altered source versions must be plainly marked as such, and must not be
//	   misrepresented as being the original software.
//
//	   3. This notice may not be removed or altered from any source
//	   distribution.
//

/*
	This category implements a transition effect where a small thumbnail of the
	window flies from the given rectangle to where the window is then shown,
	like when opening a folder window in Finder, plus a reverse variant for
	ordering out a window.
	
	It also implements another effect where the window just "pops", i.e. seems to
	grow larger for a moment, like the highlight when you use the "Find" command.
 */

#import <AppKit/AppKit.h>


@interface NSWindow (ULIZoomEffect)

-(void)	makeKeyAndOrderFrontWithPopEffect;	// Grab user's attention.

-(void)	makeKeyAndOrderFrontWithZoomEffectFromRect: (NSRect)globalStartPoint;	// Open window related to that rectangle.
-(void)	orderFrontWithZoomEffectFromRect: (NSRect)globalStartPoint;

-(void)	orderOutWithZoomEffectToRect: (NSRect)globalEndPoint;	// Reverse of -orderFrontWithZoomEffectFromRect:

@end