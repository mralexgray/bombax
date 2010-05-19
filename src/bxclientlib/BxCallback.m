#import "BxCallback.h"

@implementation BxCallback

@synthesize selector = _selector;
@synthesize target = _target;
@synthesize token = _token;

- (id)init {
    _selector = nil;
    _target = nil;
    _token = nil;
    _hasOneArgument = YES;
    return self;
}

- (id)initWithSelector:(SEL)selector
                target:(id)target {
    [self init];
    _selector = selector;
    _target = [target retain];
    return self;
}

- (id)initWithSelector:(SEL)selector
                target:(id)target
                 token:(id)token {
    [self init];
    _selector = selector;
    _target = [target retain];
    _token = [token retain];
    _hasOneArgument = NO;
    return self;
}

+ (BxCallback *)callbackWithSelector:(SEL)selector
                              target:(id)target {
    return [[[BxCallback alloc] initWithSelector:selector
                                          target:target] autorelease];
}

+ (BxCallback *)callbackWithSelector:(SEL)selector
                              target:(id)target
                               token:(id)token {
    return [[[BxCallback alloc] initWithSelector:selector
                                          target:target
                                           token:token] autorelease];
}

- (id)invokeWith:(id)result {
    if (_hasOneArgument) {
        return [_target performSelector:_selector
                             withObject:result];
    } else {
        return [_target performSelector:_selector
                             withObject:_token
                             withObject:result];
    }
}

- (void)dealloc {
    if (_target) {
        [_target release];
    }
    if (_token) {
        [_token release];
    }
    [super dealloc];
}

@end
