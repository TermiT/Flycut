
// Created by Gennadiy Potapov


#import <Foundation/Foundation.h>
#import <AppKit/NSUserDefaultsController.h>

@interface DBUserDefaultsController : NSUserDefaultsController {
  @private
}

- (NSUserDefaults *)defaults;

@end
