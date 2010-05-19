#import "BxRemoteObjectManager.h"
#import "BxRemoteObject.h"
#import "BxServerSession.h"
#import "BxRequestOperation.h"

enum BxRemoteObjectRequestType_enum {
    BxRemoteObjectRequestTypeInit,
    BxRemoteObjectRequestTypeInitWithSigs,
    BxRemoteObjectRequestTypeInvoke,
    BxRemoteObjectRequestTypeRelease,
    BxRemoteObjectRequestTypeReleaseAll
} typedef BxRemoteObjectRequestType;


@implementation BxRemoteObjectManager

- (id)_initWithServerSession:(BxServerSession *)serverSession {
    [self init];
    _serverSession = [serverSession retain];
    _instanceOids = [[NSMutableDictionary alloc] initWithCapacity:32];
    _classSignatures = [[NSMutableDictionary alloc] initWithCapacity:32];
    _requestResponseContents = [[NSMutableDictionary alloc] initWithCapacity:16];
    _instanceLock = [[NSLock alloc] init];
    _signatureLock = [[NSLock alloc] init];
    return self;
}

- (NSMethodSignature *)_signatureForClassName:(NSString *)className
                                     selector:(SEL)selector {
    [_signatureLock lock];
    NSString *signatureStr = [_classSignatures objectForKey:className];
    [_signatureLock unlock];
    if (signatureStr) {
        return [NSMethodSignature signatureWithObjCTypes:[signatureStr UTF8String]];
    } else {
        return nil;
    }
}

- (id)_sendInvocationRequest:(NSString *)oid
                  invocation:(NSInvocation *)invocation {
    if (_serverSession.isClosed) {
        return nil;
    }
    [_instanceLock lock];
    BxRemoteObject *remoteObject = [_instanceOids objectForKey:oid];
    [_instanceLock unlock];
    if (remoteObject) {
        [_signatureLock lock];
        NSString *signatureStr = [_classSignatures objectForKey:remoteObject._BX_className];
        [_signatureLock unlock];
        if (! signatureStr) {
            return nil;
        }
        NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:[signatureStr UTF8String]];;
        NSMutableData *data = [NSMutableData dataWithCapacity:512];
        NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:data] autorelease];
        [archiver encodeInt32:BxRemoteObjectRequestTypeInvoke
                       forKey:@"cmd"];
        [archiver encodeObject:oid
                        forKey:@"oid"];
        [archiver encodeObject:NSStringFromSelector([invocation selector])
                        forKey:@"selector"];
        [archiver encodeObject:signatureStr
                        forKey:@"signature"];
        for (int i = 2; i < [signature numberOfArguments]; i++) {
            char argType = [signature getArgumentTypeAtIndex:i][0];
            NSString *argName = [NSString stringWithFormat:@"arg%d", i - 1];
            if (argType == '@') {  // object
                NSObject *x;
                [invocation getArgument:&x atIndex:i];
                if ([x conformsToProtocol:@protocol(NSCoding)]) {
                    [archiver encodeObject:x forKey:argName];
                }
            } else if (argType == '*') {  // c string
                uint8_t x[65336];
                [invocation getArgument:x atIndex:i];
                x[65535] = 0;
                [archiver encodeBytes:x
                               length:strlen((char *) x)
                               forKey:argName];
            } else if (argType == 'd') {  // double
                double x;
                [invocation getArgument:&x atIndex:i];
                [archiver encodeDouble:x forKey:argName];
            } else if (argType == 'f') {  // float
                float x;
                [invocation getArgument:&x atIndex:i];
                [archiver encodeFloat:x forKey:argName];
            } else if (argType == 'i' || argType == 's' || argType == 'l' ||
                       argType == 'c' || argType == 'C' || argType == 'I' ||
                       argType == 'S' || argType == 'L' || argType == 'B') {  // int
                int x;
                [invocation getArgument:&x atIndex:i];
                [archiver encodeInt32:x forKey:argName];
            } else if (argType == 'q' || argType == 'Q') {  // long long
                long long x;
                [invocation getArgument:&x atIndex:i];
                [archiver encodeInt64:x forKey:argName];
            } else {
                // other type, unsupported
            }            
        }
        
        [archiver finishEncoding];
        NSURLRequest *request = [_serverSession _createRequest:data];
        [_requestResponseContents setObject:[NSNull null]
                                     forKey:request];
        NSLock *lock = [[[NSLock alloc] init] autorelease];
        BxRequestOperation *operation = [BxRequestOperation operationWithRequest:request
                                                                   serverSession:_serverSession
                                                                        callback:self
                                                                           token:lock];
        [_serverSession _addRequestOperation:operation];
        [lock lock];
        [lock unlock];
        
        id contents = [_requestResponseContents objectForKey:request];
        if (contents == nil) {
            return self;
        } else if ([contents isKindOfClass:[NSError class]]) {
            [NSException raise:@"Error invoking remote object"
                        format:[contents localizedDescription]];
        } else {
            NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:contents] autorelease];
            int blank = 0;
            [invocation setReturnValue:&blank]; // test
            char returnType = [signature methodReturnType][0];
            if (returnType == '@') {  // object
                NSObject *x = [unarchiver decodeObjectForKey:@"result"];
                if (x) {
                    [invocation setReturnValue:&x];
                }
            } else if (returnType == '*') {  // c string
                NSUInteger len = 0;
                uint8_t *x = (uint8_t *) [unarchiver decodeBytesForKey:@"result"
                                            returnedLength:&len];
                [invocation setReturnValue:&x];
            } else if (returnType == 'd') {  // double
                double x = [unarchiver decodeDoubleForKey:@"result"];
                [invocation setReturnValue:&x];
            } else if (returnType == 'f') {  // float
                float x = [unarchiver decodeFloatForKey:@"result"];
                [invocation setReturnValue:&x];
            } else if (returnType == 'i' || returnType == 's' || returnType == 'l' ||
                       returnType == 'c' || returnType == 'C' || returnType == 'I' ||
                       returnType == 'S' || returnType == 'L' || returnType == 'B') {  // int
                int x = [unarchiver decodeInt32ForKey:@"result"];
                [invocation setReturnValue:&x];  // tbd: test this works for char...
            } else if (returnType == 'q' || returnType == 'Q') {  // long long
                long long x = [unarchiver decodeInt64ForKey:@"result"];
                [invocation setReturnValue:&x];
            } else {
                // other type, unsupported
            }            
            return self;
        }
    }
    return nil;
}

- (id)_sendInitRequest:(NSString *)className {    
    if (_serverSession.isClosed) {
        return nil;
    }
    NSMutableData *data = [NSMutableData dataWithCapacity:512];
    NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:data] autorelease];
    [_signatureLock lock];
    NSDictionary *signatures = [_classSignatures objectForKey:className];
    [_signatureLock unlock];
    if (signatures) {
        [archiver encodeInt32:BxRemoteObjectRequestTypeInit
                       forKey:@"cmd"];
    } else {
        [archiver encodeInt32:BxRemoteObjectRequestTypeInitWithSigs
                       forKey:@"cmd"];
    }
    [archiver encodeObject:className
                    forKey:@"className"];
    [archiver finishEncoding];
    NSURLRequest *request = [_serverSession _createRequest:data];
    [_requestResponseContents setObject:[NSNull null]
                                 forKey:request];
    NSLock *lock = [[[NSLock alloc] init] autorelease];
    BxRequestOperation *operation = [BxRequestOperation operationWithRequest:request
                                                               serverSession:_serverSession
                                                                    callback:self
                                                                       token:lock];
    [_serverSession _addRequestOperation:operation];
    [lock lock];
    [lock unlock];
    
    id contents = [_requestResponseContents objectForKey:request];
    if (contents == nil) {
        return self;
    } else if ([contents isKindOfClass:[NSError class]]) {
        [NSException raise:@"Error initializing remote object"
                    format:[contents localizedDescription]];
    } else { // contents is data
        NSKeyedUnarchiver *unarchiver = [[[NSKeyedUnarchiver alloc] initForReadingWithData:contents] autorelease];
        NSString *oid = [unarchiver decodeObjectForKey:@"oid"];
        BxRemoteObject *remoteObject = [[BxRemoteObject alloc] initWithOid:oid
                                                                 className:className
                                                             objectManager:self];
        [_instanceLock lock];
        [_instanceOids setObject:remoteObject
                          forKey:oid];
        [_instanceLock unlock];
        if (signatures) {
            signatures = [unarchiver decodeObjectForKey:@"signatures"];
            [_signatureLock lock];
            [_classSignatures setObject:signatures
                                 forKey:className];
            [_signatureLock unlock];
        }
        return remoteObject;
    }
    return nil;
}

- (id)_sendReleaseRequest:(NSString *)oid {
    if (_serverSession.isClosed) {
        return self;
    }
    [_instanceLock lock];
    BxRemoteObject *remoteObject = [_instanceOids objectForKey:oid];
    if (remoteObject) {
        [_instanceOids removeObjectForKey:oid];
    }
    [_instanceLock unlock];
    if (remoteObject) {
        NSMutableData *data = [NSMutableData dataWithCapacity:512];
        NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:data] autorelease];
        [archiver encodeInt32:BxRemoteObjectRequestTypeRelease
                       forKey:@"cmd"];
        [archiver encodeObject:oid
                        forKey:@"oid"];
        [archiver finishEncoding];
        NSURLRequest *request = [_serverSession _createRequest:data];
        BxRequestOperation *operation = [BxRequestOperation operationWithRequest:request
                                                                   serverSession:_serverSession
                                                                        callback:self
                                                                           token:nil];
        [_serverSession _addRequestOperation:operation];        
    }
    return self;
}

- (id)_sendReleaseAllRequest {
    if (_serverSession.isClosed) {
        return self;
    }
    [_instanceLock lock];
    BOOL hasAnyInstances = [_instanceOids count];
    [_instanceOids removeAllObjects];
    [_instanceLock unlock];
    if (! hasAnyInstances) {
        return self;
    }
    NSMutableData *data = [NSMutableData dataWithCapacity:512];
    NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:data] autorelease];
    [archiver encodeInt32:BxRemoteObjectRequestTypeReleaseAll
                   forKey:@"cmd"];
    [archiver finishEncoding];
    NSURLRequest *request = [_serverSession _createRequest:data];
    BxRequestOperation *operation = [BxRequestOperation operationWithRequest:request
                                                               serverSession:_serverSession
                                                                    callback:self
                                                                       token:nil];
    [_serverSession _addRequestOperation:operation];        
    return self;
}

- (void)requestOperationCallbackWithContents:(NSData *)contents
                                       token:(id)token
                                     request:(NSURLRequest *)request
                                    response:(NSHTTPURLResponse *)response
                                       error:(NSError *)error {
    id result = [_requestResponseContents objectForKey:request];
    if (result) {
        if (error) {
            [_requestResponseContents setObject:error
                                         forKey:request];
        } else {
            [_requestResponseContents setObject:contents
                                         forKey:request];
        }
    }
}

- (id)createRemoteInstance:(NSString *)className {
    return [self _sendInitRequest:className];
}

                                        
- (void)dealloc {
    // ideally this sends a message to close all the connections...
    [_instanceLock release];
    [_signatureLock release];
    [_instanceOids release];
    [_classSignatures release];
    [_serverSession release];
    [_requestResponseContents release];
    [super dealloc];
}

@end
