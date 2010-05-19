#import "BxHandler.h"
#import <Bombaxtic/BxApp.h>
#import <Bombaxtic/BxTransport.h>

@implementation BxHandler

@synthesize state = _state;
@synthesize app = _app;

- (id)initWithApp:(BxApp *)app {
    _state = [[NSMutableDictionary alloc] initWithCapacity:32];
    _app = app;
    [self init];
    return self;
}

- (id)setup {
    return self;
}

- (id)renderWithTransport:(BxTransport *)transport {
    
    return self;
}

- (void)dealloc {
    [_state release];
    [super dealloc];
}

@end
