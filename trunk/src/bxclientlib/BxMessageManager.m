#import "BxCallback.h"
#import "BxMessage.h"
#import "BxMessageManager.h"
#import "BxRequestOperation.h"
#import "BxServerSession.h"

@implementation BxMessageManager

@synthesize keepMessages = _keepMessages;
@synthesize maxMessages = _maxMessages;
@synthesize maxCheckInterval = _maxCheckInterval;

- (id)init {
    [super init];
    _keepMessages = NO;
    _maxMessages = 0;
    _maxCheckInterval = 10;
    _incomingMessages = [[NSMutableArray alloc] initWithCapacity:32];
    _observers = [[NSMutableDictionary alloc] initWithCapacity:16];
    _universalObservers = [[NSMutableArray alloc] initWithCapacity:8];
    _messageLock = [[NSLock alloc] init];
    _observerLock = [[NSLock alloc] init];
    _lastCheck = 0;
    _isValidPtr = NULL;
    [NSThread detachNewThreadSelector:@selector(_checkerThreadMain:)
                             toTarget:self
                           withObject:nil];
    return self;
}

- (void)_checkerThreadMain:(id)arg {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    @try {
        BOOL *myValidPtr = malloc(sizeof(BOOL));
        *myValidPtr = YES;
        _isValidPtr = myValidPtr;
        _lastCheck = [NSDate timeIntervalSinceReferenceDate];
        while (YES) {
            [NSThread sleepForTimeInterval:_maxCheckInterval];
            if (! *myValidPtr || _serverSession.isClosed) {
                free(myValidPtr);
                break;
            }
            NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
            if (now - _lastCheck > _maxCheckInterval) {
                [_serverSession _waitForOperationQueue];
                if (now - _lastCheck > _maxCheckInterval) {
                    NSURLRequest *request = [_serverSession _createRequest:[NSData data]];
                    BxRequestOperation *operation = [BxRequestOperation operationWithRequest:request
                                                                               serverSession:_serverSession
                                                                                    callback:nil
                                                                                       token:nil];
                    [_serverSession _addRequestOperation:operation];
                }
            }
        }
    } @catch (id exc) {
        NSLog(@"BxClientLib -> Exception while in message checking thread: %@", [exc description]);
    }
    [pool release];
}

- (id)_initWithServerSession:(BxServerSession *)serverSession {
    [self init];
    _serverSession = [serverSession retain];
    return self;
}

- (id)_receiveMessage:(BxMessage *)message {
    _lastCheck = [NSDate timeIntervalSinceReferenceDate];
    if (_keepMessages) {
        [_messageLock lock];
        if (_maxMessages > 0) {
            if ([_incomingMessages count] >= _maxMessages) {
                [_incomingMessages removeObjectsInRange:NSMakeRange(0, ([_incomingMessages count] + 1) - _maxMessages)];
            }
        }
        [_incomingMessages addObject:message];
        [_messageLock unlock];
    }
    [_observerLock lock];
    if (message.kind != nil) {
        NSArray *observers = [_observers objectForKey:message.kind];
        if (observers) {
            for (BxCallback *callback in observers) {
                [callback invokeWith:message];
            }
        }
    }
    for (BxCallback *callback in _universalObservers) {
        [callback invokeWith:message];
    }
    [_observerLock unlock];
    return self;
}

- (void)requestOperationCallbackWithContents:(NSData *)contents
                                       token:(id)token
                                     request:(NSURLRequest *)request
                                    response:(NSHTTPURLResponse *)response
                                       error:(NSError *)error {
    if (token != nil &&
        [token isMemberOfClass:[BxCallback class]]) {
            [token invokeWith:error];
    }
}

- (id)addObserver:(id)observer
         selector:(SEL)selector
                  kind:(NSString *)kind {
    BxCallback *callback = [BxCallback callbackWithSelector:selector
                                                     target:observer];
    [_observerLock lock];
    if (kind == nil) {
        [_universalObservers addObject:callback];
    } else {
        NSMutableArray *callbacks = [_observers objectForKey:kind];
        if (callbacks == nil) {
            callbacks = [NSMutableArray arrayWithCapacity:8];
        }
        [callbacks addObject:callback];
        [_observers setObject:callbacks
                       forKey:kind];
    }
    [_observerLock unlock];
    return self;
}

- (int)clearMessages {
    int messageCount = 0;
    [_messageLock lock];
    messageCount = [_incomingMessages count];
    [_incomingMessages removeAllObjects];
    [_messageLock unlock];
    return messageCount;
}

- (int)messageCount {
    int messageCount = 0;
    [_messageLock lock];
    messageCount = [_incomingMessages count];
    [_messageLock unlock];
    return messageCount;    
}

- (NSArray *)messages {
    NSArray *messageCopy;
    [_messageLock lock];
    messageCopy = [[_incomingMessages copy] autorelease];
    [_messageLock unlock];
    return messageCopy;
}

- (BxMessage *)popMessage {
    BxMessage *message = nil;
    [_messageLock lock];
    if ([_incomingMessages count] > 0) {
        message = [_incomingMessages lastObject];
        [_incomingMessages removeLastObject];
    }
    [_messageLock unlock];
    return message;
}

- (BOOL)removeObserver:(id)observer
                  kind:(NSString *)kind {
    [_observerLock lock];
    BOOL found = NO;
    NSUInteger index = NSNotFound;
    while ((index = [_universalObservers indexOfObject:observer]) != NSNotFound) {
        found = YES;
        [_universalObservers removeObjectAtIndex:index];
    }
    for (NSString *kind in _observers) {
        NSMutableArray *kindObservers = [_observers objectForKey:kind];
        while ((index = [kindObservers indexOfObject:observer]) != NSNotFound) {
            found = YES;
            [kindObservers removeObjectAtIndex:index];
        }
    }
    [_observerLock unlock];
    return found;
}

- (id)sendSynchronousMessage:(BxMessage *)message
                       error:(NSError **)error {
    NSData *messageArchive = [NSKeyedArchiver archivedDataWithRootObject:message];
    NSURLRequest *request = [_serverSession _createRequest:messageArchive];
    NSConditionLock *lock = [[[NSConditionLock alloc] initWithCondition:0] autorelease];
    BxRequestOperation *operation = [BxRequestOperation operationWithRequest:request
                                                               serverSession:_serverSession
                                                                    callback:nil
                                                                       token:lock];
    [operation start];
//    [_serverSession _addRequestOperation:operation];
    [lock lockWhenCondition:0];
    [lock unlock];
    return self;
}

- (id)sendMessage:(BxMessage *)message {
    NSData *messageArchive = [NSKeyedArchiver archivedDataWithRootObject:message];
    NSURLRequest *request = [_serverSession _createRequest:messageArchive];
    BxRequestOperation *operation = [BxRequestOperation operationWithRequest:request
                                                               serverSession:_serverSession
                                                                    callback:nil
                                                                       token:nil];
    [_serverSession _addRequestOperation:operation];
    return self;
}

- (id)sendMessage:(BxMessage *)message
         callback:(SEL)selector
           target:(id)target {
    NSData *messageArchive = [NSKeyedArchiver archivedDataWithRootObject:message];
    NSURLRequest *request = [_serverSession _createRequest:messageArchive];
    BxCallback *callback = [BxCallback callbackWithSelector:selector
                                                     target:target
                                                      token:message];
    BxRequestOperation *operation = [BxRequestOperation operationWithRequest:request
                                                               serverSession:_serverSession
                                                                    callback:self
                                                                       token:callback];
    [_serverSession _addRequestOperation:operation];
    return self;
}


- (void)dealloc {
    [_incomingMessages release];
    [_observers release];
    [_serverSession release];
    [_universalObservers release];
    [_messageLock release];
    [_observerLock release];
    if (_isValidPtr != NULL) {
        *_isValidPtr = NO;
    }
    [super dealloc];
}


@end
