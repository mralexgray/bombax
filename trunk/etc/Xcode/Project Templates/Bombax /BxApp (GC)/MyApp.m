#import "MyApp.h"

@implementation MyApp

- (id)setup {
    [self setHandler:@"MyHandlerBxml" forMatch:@"/example"];
    [self setDefaultHandler:@"MyHandler"];
    return self;
}

@end
