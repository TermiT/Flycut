// Created by Gennadiy Potapov

#import "DBUserDefaultsController.h"
#import "DBUserDefaults.h"

@implementation DBUserDefaultsController


- (id)init
{
    self = [super init];
    if (self) {
        
    }
    return self;
}


- (NSUserDefaults *)defaults {
    return [DBUserDefaults standardUserDefaults];
}

- (void)dealloc
{
    [super dealloc];
}

@end
