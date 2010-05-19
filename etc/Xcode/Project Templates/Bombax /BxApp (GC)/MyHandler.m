#import "MyHandler.h"

@implementation MyHandler

- (id)renderWithTransport:(BxTransport *)transport {
    [transport write:@"Hello World!"];
    return self;
}

@end
