#import "BxRemoteObject.h"

@implementation BxRemoteObject

@synthesize _BX_oid;
@synthesize _BX_className;

- (id)initWithOid:(NSString *)oid
        className:(NSString *)className
    objectManager:(BxRemoteObjectManager *)objectManager {
    [self init];
    _BX_oid = [oid retain];
    _BX_className = [className retain];
    _BX_remoteObjectManager = [objectManager retain];
    return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [_BX_remoteObjectManager _signatureForClassName:_BX_className
                                                  selector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [_BX_remoteObjectManager _sendInvocationRequest:_BX_oid
                                         invocation:invocation];
}


- (void)dealloc {
    [_BX_remoteObjectManager _sendReleaseRequest:_BX_oid];
    [_BX_remoteObjectManager release];
    [_BX_className release];
    [_BX_oid release];
    [super dealloc];
}

@end
