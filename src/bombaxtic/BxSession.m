#import "BxSession.h"
#import "BxUtil.h"

@implementation BxSession

@class BxHandler;

@synthesize handler = _handler;
@synthesize state = _state;
@synthesize cookie = _cookie;
@synthesize ipAddress = _ipAddress;
@synthesize lastActivated = _lastActivated;


- (id)initWithIpAddress:(NSString *)ipAddress
                handler:(BxHandler *)handler {
    _state = [[NSMutableDictionary alloc] initWithCapacity:16];
    _handler = [handler retain];
    _ipAddress = [ipAddress retain];
    _lastActivated = [NSDate timeIntervalSinceReferenceDate];
    _cookie = [[BxUtil randomAlphaNumericString:32] retain];
    return self;
}

- (void)dealloc {
    [_state release];
    [_handler release];
    [_ipAddress release];
    [_cookie release];
    [super dealloc];
}

@end
