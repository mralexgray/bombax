#import "BxClientLibClassBinding.h"

@implementation BxClientLibClassBinding

@synthesize cls = _cls;
@synthesize authorizer = _authorizer;
@synthesize instance = _instance;

- (id)init {
    [super init];
    _cls = nil;
    _authorizer = nil;
    _instance = nil;
    return self;
}

- (id)initWithClass:(Class)cls {
    [self init];
    _cls = cls;
    return self;
}

- (id)initWithClass:(Class)cls
         authorizer:(id <BxClientLibAuthorizer>)authorizer {
    [self init];
    _cls = cls;
    _authorizer = [authorizer retain];
    return self;    
}

- (id)initWithInstance:(id)instance {
    [self init];
    _instance = [instance retain];
    return self;
}

- (id)initWithInstance:(id)instance
            authorizer:(id <BxClientLibAuthorizer>)authorizer {
    [self init];
    _instance = [instance retain];
    _authorizer = [authorizer retain];
    return self;
}

+ (BxClientLibClassBinding *)classBindingWithClass:(Class)cls
                                          instance:(id)instance
                                        authorizer:(id <BxClientLibAuthorizer>)authorizer {
    if (cls) {
        if (authorizer) {
            return [[[BxClientLibClassBinding alloc] initWithClass:cls
                                                        authorizer:authorizer] autorelease];
        } else {
            return [[[BxClientLibClassBinding alloc] initWithClass:cls] autorelease];
        }
    } else if (instance) {
        if (authorizer) {
            return [[[BxClientLibClassBinding alloc] initWithInstance:instance
                                                           authorizer:authorizer] autorelease];
        } else {
            return [[[BxClientLibClassBinding alloc] initWithInstance:instance] autorelease];
        }
    } else {
        return nil;
    }
}

- (void)dealloc {
    if (_instance) {
        [_instance release];
    }
    if (_authorizer) {
        [_authorizer release];
    }
    [super dealloc];
}

@end
