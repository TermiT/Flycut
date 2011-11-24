//  License Agreement for Source Code provided by Mizage LLC
//
//  This software is supplied to you by Mizage LLC in consideration of your
//  agreement to the following terms, and your use, installation, modification
//  or redistribution of this software constitutes acceptance of these terms. If
//  you do not agree with these terms, please do not use, install, modify or
//  redistribute this software.
//
//  In consideration of your agreement to abide by the following terms, and
//  subject to these terms, Mizage LLC grants you a personal, non-exclusive
//  license, to use, reproduce, modify and redistribute the software, with or
//  without modifications, in source and/or binary forms; provided that if you
//  redistribute the software in its entirety and without modifications, you
//  must retain this notice and the following text and disclaimers in all such
//  redistributions of the software, and that in all cases attribution of Mizage
//  LLC as the original author of the source code shall be included in all such
//  resulting software products or distributions.  Neither the name, trademarks,
//  service marks or logos of Mizage LLC may be used to endorse or promote
//  products derived from the software without specific prior written permission
//  from Mizage LLC. Except as expressly stated in this notice, no other rights
//  or licenses, express or implied, are granted by Mizage LLC herein, including
//  but not limited to any patent rights that may be infringed by your
//  derivative works or by other works in which the software may be
//  incorporated.
//
//  The software is provided by Mizage LLC on an "AS IS" basis. MIZAGE LLC MAKES
//  NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
//  WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
//  PURPOSE, REGARDING THE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
//  COMBINATION WITH YOUR PRODUCTS.
//
//  IN NO EVENT SHALL MIZAGE LLC BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
//  OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION
//  AND/OR DISTRIBUTION OF THE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY
//  OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE,
//  EVEN IF MIZAGE LLC HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


#import <Foundation/Foundation.h>

#import "DBSyncPromptDelegate.h"

@class DBSyncPrompt;

// Fired any time the user defaults change.
extern NSString* const DBUserDefaultsDidChangeNotification;

// Fired when the preferences are updated from Dropbox. You should use this
//  notification to reapply all the preferences in your application.
extern NSString* const DBUserDefaultsDidSyncNotification;


// DBUserDefaults is a class that gives you a partial replacement for 
//  NSUserDefaults that synchronizes data to a folder on Dropbox. This allows
//  a user to have consistent settings for their application across all their
//  Macs.

@interface DBUserDefaults : NSUserDefaults <DBSyncPromptDelegate>
{
  NSLock* deadbolt_; //Used to lock access to the defaults dictionary
  NSMutableDictionary* defaults_; //Stores the user data
}

// Determines if Dropbox sync is possible
+ (BOOL)isDropboxAvailable;

// Determies if Dropbox sync is enabled
+ (BOOL)isDropboxSyncEnabled;

// Informs the user that Dropbox is not installed
- (void)promptDropboxUnavailable;

// Sets the status of the Dropbox sync
- (void)setDropboxSyncEnabled:(BOOL)enabled;

@end

@interface DBUserDefaults (NSUserDefaultsPartialReplacement)

#pragma mark - NSUserDefaults (Partial) Replacement

+ (DBUserDefaults*)standardUserDefaults;
+ (void)resetStandardUserDefaults;

- (id)objectForKey:(NSString*)defaultName;
- (void)setObject:(id)value forKey:(NSString*)defaultName;
- (void)removeObjectForKey:(NSString*)defaultName;

- (NSString*)stringForKey:(NSString*)defaultName;
- (NSArray*)arrayForKey:(NSString*)defaultName;
- (NSDictionary*)dictionaryForKey:(NSString*)defaultName;
- (NSData*)dataForKey:(NSString*)defaultName;
- (NSArray*)stringArrayForKey:(NSString*)defaultName;
- (NSInteger)integerForKey:(NSString*)defaultName;
- (float)floatForKey:(NSString*)defaultName;
- (double)doubleForKey:(NSString*)defaultName;
- (BOOL)boolForKey:(NSString*)defaultName;
- (NSURL*)URLForKey:(NSString*)defaultName AVAILABLE_MAC_OS_X_VERSION_10_6_AND_LATER;

- (void)setInteger:(NSInteger)value forKey:(NSString*)defaultName;
- (void)setFloat:(float)value forKey:(NSString*)defaultName;
- (void)setDouble:(double)value forKey:(NSString*)defaultName;
- (void)setBool:(BOOL)value forKey:(NSString*)defaultName;
- (void)setURL:(NSURL*)url forKey:(NSString*)defaultName AVAILABLE_MAC_OS_X_VERSION_10_6_AND_LATER;

- (void)registerDefaults:(NSDictionary*)registrationDictionary;

- (NSDictionary*)dictionaryRepresentation;

- (BOOL)synchronize;

@end
