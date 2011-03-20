//
//  JumpcutClipping.h
//  Jumpcut
//  http://jumpcut.sourceforge.net/
//
//  Created by steve on Sun Jan 12 2003.
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

#import <Foundation/Foundation.h>

@interface JumpcutClipping : NSObject {
// What must a clipping hold?
// The text
    NSString * clipContents;
// The text type
    NSString * clipType;
// The display length
    int clipDisplayLength;
// The display string
    NSString * clipDisplayString;
// Does it have a name?
    BOOL clipHasName;
}

-(id) initWithContents:(NSString *)contents withType:(NSString *)type withDisplayLength:(int)displayLength;
/* -(id) initWithCoder:(NSCoder *)coder;
-(void) decodeWithCoder:(NSCoder *)coder; */
-(NSString *) description;

// set values
-(void) setContents:(NSString *)newContents setDisplayLength:(int)newDisplayLength;
-(void) setContents:(NSString *)newContents;
-(void) setType:(NSString *)newType;
-(void) setDisplayLength:(int)newDisplayLength;
-(void) setHasName:(BOOL)newHasName;

// Retrieve values
-(NSString *) contents;
-(int) displayLength;
-(NSString *) displayString;
-(NSString *) type;
-(BOOL) hasName;

// Additional functions
-(void) resetDisplayString;

@end
