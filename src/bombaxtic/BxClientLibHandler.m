#import <Bombaxtic/BxHandler.h>
#import <Bombaxtic/BxApp.h>
#import <Bombaxtic/BxTransport.h>
#import <Bombaxtic/BxSession.h>
#import <Bombaxtic/BxMessage.h>
#import "BxArchiveEnvelope.h"
#import "BxClientLibClassBinding.h"
#import "BxClientLibHandler.h"
#import "BxCallback.h"

@implementation BxClientLibHandler

extern BxApp * _BX_bxApp;

NSString *_BX_CLIENTLIB_PROTOCOL = @"1.0";

- (id)initWithApp:(BxApp *)app {
    [super initWithApp:app];
    _classNameMapLock = [[NSLock alloc] init];
    _globalMessageObserversLock = [[NSLock alloc] init];
    _messageObserversLock = [[NSLock alloc] init];
    _pendingMessagesLock = [[NSLock alloc] init];
    _sessionsLock = [[NSLock alloc] init];
    _sessionCallbacksLock = [[NSLock alloc] init];
    _sessions = [[NSMutableArray alloc] initWithCapacity:64];
    _classNameMap = [[NSMutableDictionary alloc] initWithCapacity:16];
    _globalMessageObservers = [[NSMutableDictionary alloc] initWithCapacity:16];
    _messageObservers = [[NSMutableDictionary alloc] initWithCapacity:16];
    _pendingMessages = [[NSMutableDictionary alloc] initWithCapacity:32];
    _sessionCallbacks = [[NSMutableArray alloc] initWithCapacity:4];
    _sessionTimeout = 1800;
    return self;
}

- (id)renderWithTransport:(BxTransport *)transport {
    NSLog(@"Rendering...");
    NSString *clientProtocol = [transport.serverVars objectForKey:@"HTTP_BXCLIENTLIB_PROTOCOL"];
    if (! clientProtocol || [transport.rawPostData length] == 0) {
        [transport setHttpStatusCode:400];
        return self;
    }
    BxSession *currentSession = nil;
    NSString *ipAddress = [transport.serverVars objectForKey:@"REMOTE_ADDR"];
    NSString *sessionCookie = [transport.cookies objectForKey:@"BxClientLib-SessionCookie"];
    if (sessionCookie) {
        NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];
        [_sessionsLock lock];
        int count = [_sessions count];
        for (int i = count - 1; i >= 0; i--) {
            BxSession *session = [_sessions objectAtIndex:i];
            if (session.lastActivated + _sessionTimeout > currentTime) {
                [_sessions removeObjectAtIndex:i];
                continue;
            }
            if ([session.ipAddress isEqualToString:ipAddress] &&
                [session.cookie isEqualToString:sessionCookie]) {
                currentSession = [session retain];
                break;
            }
        }
        [_sessionsLock unlock];
        if (currentSession == nil) {
            [transport setPersistentCookie:@"BxClientLib-SessionCookie"
                                     value:@""
                                    maxAge:0];
            // todo remove all the session cookie related stuff like _pendingMessages
            [transport setHttpStatusCode:409];
            return self;
        }
    } else {
        currentSession = [[BxSession alloc] initWithIpAddress:ipAddress
                                                      handler:self];
        [_sessionsLock lock];
        [_sessions addObject:currentSession];
        [_sessionsLock unlock];
        [transport setPersistentCookie:@"BxClientLib-SessionCookie"
                                 value:currentSession.cookie
                                maxAge:_sessionTimeout];
        
        [_sessionCallbacksLock lock];
        for (BxCallback *callback in _sessionCallbacks) {
            [callback invokeWith:currentSession];
        }
        [_sessionCallbacksLock unlock];
    }
    
    [[NSKeyedUnarchiver alloc] initForReadingWithData:transport.rawPostData];
    NSObject *obj = [NSKeyedUnarchiver unarchiveObjectWithData:transport.rawPostData];
    NSLog(@"Object: %@", obj);
    if (obj == nil) {
        [transport setHttpStatusCode:400];
    } else if ([obj isKindOfClass:[BxMessage class]]) {
        BxMessage *message = (BxMessage *) obj;
        NSLog(@"Message: %@ %@", message.kind, [[[NSString alloc] initWithData:message.data
                                                                   encoding:NSUTF8StringEncoding] autorelease]);
        [_globalMessageObserversLock lock];
        NSArray *observers = [_globalMessageObservers objectForKey:[NSNull null]];
        if (observers) {
            for (BxCallback *callback in observers) {
                [callback invokeWith:message];
            }
        }
        if (message.kind) {
            observers = [_globalMessageObservers objectForKey:message.kind];
            if (observers) {
                for (BxCallback *callback in observers) {
                    [callback invokeWith:message];
                }
            }
        }
        [_globalMessageObserversLock unlock];

        [_messageObserversLock lock]; // todo: make this more fine grained... a lock per session for example...
        NSDictionary *kindMap = [_messageObservers objectForKey:currentSession];
        if (kindMap) {
            observers = [kindMap objectForKey:[NSNull null]];
            if (observers) {
                for (BxCallback *callback in observers) {
                    [callback invokeWith:message];
                }
            }
            if (message.kind) {
                observers = [kindMap objectForKey:message.kind];
                if (observers) {
                    for (BxCallback *callback in observers) {
                        [callback invokeWith:message];
                    }
                }
            }
        }
        [_messageObserversLock unlock];
        
        [_pendingMessagesLock lock];
        NSMutableArray *messages = [_pendingMessages objectForKey:currentSession.cookie];
        BxArchiveEnvelope *envelope;
        if (messages) {
            envelope = [[BxArchiveEnvelope alloc] initWithContents:nil
                                                          messages:[[messages copy] autorelease]];
            [messages removeAllObjects];
        } else {
            envelope = [[BxArchiveEnvelope alloc] initWithContents:nil
                                                          messages:nil];
        }
        [_pendingMessagesLock unlock];
//        NSMutableData *data = [NSMutableData data];
//        NSKeyedArchiver *archiver = [[[NSKeyedArchiver alloc] initForWritingWithMutableData:data] autorelease];
//        [archiver setOutputFormat:NSPropertyListXMLFormat_v1_0];
//        [archiver encodeRootObject:envelope];
//        [archiver finishEncoding];
//        NSLog(@"%@", [[[NSString alloc] initWithData:data
//                                            encoding:NSUTF8StringEncoding] autorelease]);
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:envelope];
        [envelope release];
        NSLog(@"data: %@ len:%d", data, [data length]);
        BxArchiveEnvelope *newEnvelope = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        NSLog(@"New Envelope: %@", newEnvelope);
        [transport writeData:data];
    } else {
        // this is a remote invocation... but what then?
    }
    
    
    if (currentSession) {
        [currentSession release];
    }
    return self;
}

- (void)dealloc {
    // not likely to reach here...
    [_classNameMapLock release];
    [_globalMessageObserversLock release];
    [_messageObserversLock release];
    [_pendingMessagesLock release];
    [_sessionsLock release];
    [_sessionCallbacksLock release];
    [_sessions release];
    [_classNameMap release];
    [_globalMessageObservers release];
    [_messageObservers release];
    [_pendingMessages release];
    [_sessionCallbacks release];
    [super dealloc];
}

+ (BxClientLibHandler *)_singleton {
    Class handlerClass = [self class];
    NSString *className = NSStringFromClass(handlerClass);
    return [_BX_bxApp handlerInstanceForClassName:className];
}

- (BxClientLibHandler *)_addNewSessionCallback:(SEL)selector
                                        target:(id)target {
    BxCallback *callback = [BxCallback callbackWithSelector:selector
                                                     target:target];
    [_sessionCallbacksLock lock];
    [_sessionCallbacks addObject:callback];
    [_sessionCallbacksLock unlock];
    return self;
}

+ (BxClientLibHandler *)addNewSessionCallback:(SEL)selector
                                       target:(id)target {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _addNewSessionCallback:selector
                                      target:target];
}

- (BxClientLibHandler *)_removeNewSessionCallback:(SEL)selector
                                           target:(id)target {
    [_sessionCallbacksLock lock];
    for (int i = [_sessionCallbacks count] - 1; i >= 0; i--) {
        BxCallback *callback = [_sessionCallbacks objectAtIndex:i];
        if ([callback.target isEqual:target] &&
            callback.selector == selector) {
            [_sessionCallbacks removeObjectAtIndex:i];
            break;
        }
    }
    [_sessionCallbacksLock unlock];
    return self;
}

+ (BxClientLibHandler *)removeNewSessionCallback:(SEL)selector
                                          target:(id)target {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _removeNewSessionSelector:selector
                                         target:target];
}

- (BxClientLibHandler *)_addGlobalMessageObserver:(id)observer
                                         selector:(SEL)selector
                                             kind:(NSString *)kind {
    BxCallback *callback = [BxCallback callbackWithSelector:selector
                                                     target:observer
                                                      token:nil];
    [_globalMessageObserversLock lock];
    id key = kind;
    if (kind == nil) {
        key = [NSNull null];
    }
    NSMutableArray *observers = [_globalMessageObservers objectForKey:key];
    if (! observers) {
        observers = [NSMutableArray arrayWithCapacity:16];
        [_globalMessageObservers setObject:observers
                                    forKey:key];
    }
    [observers addObject:callback];
    [_globalMessageObserversLock unlock];
    return self;
}

+ (BxClientLibHandler *)addGlobalMessageObserver:(id)observer
                                        selector:(SEL)selector
                                            kind:(NSString *)kind {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _addGlobalMessageObserver:observer
                                       selector:selector
                                           kind:kind];
}


// message:session
- (BxClientLibHandler *)_addMessageObserver:(id)observer
                                   selector:(SEL)selector
                                    session:(BxSession *)session
                                       kind:(NSString *)kind {
    BxCallback *callback = [BxCallback callbackWithSelector:selector
                                                     target:observer
                                                      token:session];
    [_messageObserversLock lock];
    NSMutableDictionary *kindMap = [_messageObservers objectForKey:session];
    if (! kindMap) {
        kindMap = [NSMutableDictionary dictionaryWithCapacity:16];
        [_messageObservers setObject:kindMap
                              forKey:session];
    }
    id key = kind;
    if (kind == nil) {
        key = [NSNull null];
    }
    NSMutableArray *observers = [kindMap objectForKey:key];
    if (! observers) {
        observers = [NSMutableArray arrayWithCapacity:16];
        [kindMap setObject:observers
                    forKey:key];
    }
    [observers addObject:callback];
    [_messageObserversLock unlock];
    return self;
}

+ (BxClientLibHandler *)addMessageObserver:(id)observer
                                  selector:(SEL)selector
                                   session:(BxSession *)session
                                      kind:(NSString *)kind {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _addMessageObserver:observer
                                 selector:selector
                                  session:session
                                     kind:kind];
}

- (BxClientLibHandler *)_bindClass:(Class)cls {
    NSString *className = NSStringFromClass(cls);
    [_classNameMapLock lock];
    [_classNameMap setObject:[BxClientLibClassBinding classBindingWithClass:cls
                                                                   instance:nil
                                                                 authorizer:nil]
                      forKey:className];
    [_classNameMapLock unlock];
    return self;
}

+ (BxClientLibHandler *)bindClass:(Class)cls {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _bindClass:cls];
}

- (BxClientLibHandler *)_bindClass:(Class)cls
                        authorizer:(id <BxClientLibAuthorizer>)authorizer {
    NSString *className = NSStringFromClass(cls);
    [_classNameMapLock lock];
    [_classNameMap setObject:[BxClientLibClassBinding classBindingWithClass:cls
                                                                   instance:nil
                                                                 authorizer:authorizer]
                      forKey:className];
    [_classNameMapLock unlock];
    return self;
}

+ (BxClientLibHandler *)bindClass:(Class)cls
                       authorizer:(id <BxClientLibAuthorizer>)authorizer {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _bindClass:cls
                      authorizer:authorizer];
}
    
- (BxClientLibHandler *)_bindClass:(Class)cls
                      forClassName:(NSString *)className {
    [_classNameMapLock lock];
    [_classNameMap setObject:[BxClientLibClassBinding classBindingWithClass:cls
                                                                   instance:nil
                                                                 authorizer:nil]
                      forKey:className];
    [_classNameMapLock unlock];
    return self;
}

+ (BxClientLibHandler *)bindClass:(Class)cls
                     forClassName:(NSString *)className {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _bindClass:cls
                    forClassName:className];
}
    

- (BxClientLibHandler *)_bindClass:(Class)cls
                      forClassName:(NSString *)className
                        authorizer:(id <BxClientLibAuthorizer>)authorizer {
    [_classNameMapLock lock];
    [_classNameMap setObject:[BxClientLibClassBinding classBindingWithClass:cls
                                                                   instance:nil
                                                                 authorizer:authorizer]
                      forKey:className];
    [_classNameMapLock unlock];
    return self;
}

+ (BxClientLibHandler *)bindClass:(Class)cls
                     forClassName:(NSString *)className
                       authorizer:(id <BxClientLibAuthorizer>)authorizer {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _bindClass:cls
                    forClassName:className
                      authorizer:authorizer];
}
    
- (BxClientLibHandler *)_bindInstance:(id)instance {
    NSString *className = NSStringFromClass([instance class]);
    [_classNameMapLock lock];
    [_classNameMap setObject:[BxClientLibClassBinding classBindingWithClass:nil
                                                                   instance:instance
                                                                 authorizer:nil]
                      forKey:className];
    [_classNameMapLock unlock];
    return self;
}

+ (BxClientLibHandler *)bindInstance:(id)instance {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _bindInstance:instance];
}    
    
- (BxClientLibHandler *)_bindInstance:(id)instance
                           authorizer:(id <BxClientLibAuthorizer>)authorizer {
    NSString *className = NSStringFromClass([instance class]);
    [_classNameMapLock lock];
    [_classNameMap setObject:[BxClientLibClassBinding classBindingWithClass:nil
                                                                   instance:instance
                                                                 authorizer:authorizer]
                      forKey:className];
    [_classNameMapLock unlock];
    return self;
}

+ (BxClientLibHandler *)bindInstance:(id)instance
                          authorizer:(id <BxClientLibAuthorizer>)authorizer {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _bindInstance:instance
                         authorizer:authorizer];
}

- (BxClientLibHandler *)_bindInstance:(id)instance
                         forClassName:(NSString *)className {
    [_classNameMapLock lock];
    [_classNameMap setObject:[BxClientLibClassBinding classBindingWithClass:nil
                                                                   instance:instance
                                                                 authorizer:nil]
                      forKey:className];
    [_classNameMapLock unlock];
    return self;
}

+ (BxClientLibHandler *)bindInstance:(id)instance
                        forClassName:(NSString *)className {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _bindInstance:instance
                       forClassName:className];
}

- (BxClientLibHandler *)_bindInstance:(id)instance
                         forClassName:(NSString *)className
                           authorizer:(id <BxClientLibAuthorizer>)authorizer {
    [_classNameMapLock lock];
    [_classNameMap setObject:[BxClientLibClassBinding classBindingWithClass:nil
                                                                   instance:instance
                                                                 authorizer:authorizer]
                      forKey:className];
    [_classNameMapLock unlock];
    return self;
}

+ (BxClientLibHandler *)bindInstance:(id)instance
                        forClassName:(NSString *)className
                          authorizer:(id <BxClientLibAuthorizer>)authorizer {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _bindInstance:instance
                       forClassName:className
                         authorizer:authorizer];
}

- (BxClientLibHandler *)_broadcastMessage:(BxMessage *)message {
    [_pendingMessagesLock lock];
    [_sessionsLock lock];
    for (BxSession *session in _sessions) {
        NSMutableArray *messages = [_pendingMessages objectForKey:session.cookie];
        if (! messages) {
            messages = [NSMutableArray arrayWithCapacity:4];
            [_pendingMessages setObject:messages
                                 forKey:session.cookie];
        }
        [messages addObject:message];
    }
    [_sessionsLock unlock];
    [_pendingMessagesLock unlock];
    return self;
}

+ (BxClientLibHandler *)broadcastMessage:(BxMessage *)message {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _broadcastMessage:message];
}

- (BxClientLibHandler *)_removeAuthenticator {
    if (_authenticator) {
        [_authenticator release];
        _authenticator = nil;
    }
    return self;
}

+ (BxClientLibHandler *)removeAuthenticator {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _removeAuthenticator];
}

- (BxClientLibHandler *)_removeGlobalMessageObserver:(id)observer
                                                kind:(NSString *)kind {
    [_globalMessageObserversLock lock];
    if (kind) {
        NSMutableArray *observers = [_globalMessageObservers objectForKey:kind];
        if (observers) {
            [observers removeObject:observer];
        }
    } else {
        NSArray *keys = [_globalMessageObservers allKeys];
        for (NSString *key in keys) {
            NSMutableArray *observers = [_globalMessageObservers objectForKey:key];
            [observers removeObject:observer];
        }
    }
    [_globalMessageObserversLock unlock];
    return self;
}

+ (BxClientLibHandler *)removeGlobalMessageObserver:(id)observer
                                               kind:(NSString *)kind {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _removeGlobalMessageObserver:observer
                                              kind:kind];
}

- (BxClientLibHandler *)_removeMessageObserver:(id)observer
                                       session:(BxSession *)session
                                          kind:(NSString *)kind {

    [_messageObserversLock lock];
    NSMutableDictionary *kindMap = [_messageObservers objectForKey:session];
    if (kindMap) {
        if (kind) {
            NSMutableArray *observers = [kindMap objectForKey:kind];
            if (observers) {
                [observers removeObject:observer];
            }
        } else {
            NSArray *keys = [kindMap allKeys];
            for (NSString *key in keys) {
                NSMutableArray *observers = [kindMap objectForKey:key];
                [observers removeObject:observer];
            }
        }
    }
    [_messageObserversLock unlock];
    return self;
}

+ (BxClientLibHandler *)removeMessageObserver:(id)observer
                                      session:(BxSession *)session
                                         kind:(NSString *)kind {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _removeMessageObserver:observer
                                     session:session
                                        kind:kind];
}

- (BxClientLibHandler *)_sendMessage:(BxMessage *)message
                           toSession:(BxSession *)session {
    [_pendingMessagesLock lock];
    NSMutableArray *messages = [_pendingMessages objectForKey:session.cookie];
    if (! messages) {
        messages = [NSMutableArray arrayWithCapacity:4];
        [_pendingMessages setObject:messages
                             forKey:session.cookie];
    }
    [messages addObject:message];
    [_pendingMessagesLock unlock];
    return self;
}

+ (BxClientLibHandler *)sendMessage:(BxMessage *)message
                          toSession:(BxSession *)session {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _sendMessage:message
                         toSession:session];
}

- (BxClientLibHandler *)_sendMessage:(BxMessage *)message
                           toSession:(BxSession *)session
                            callback:(SEL)selector
                              target:(id)target {
    BxCallback *callback = [BxCallback callbackWithSelector:selector
                                                     target:target
                                                      token:message];
    [_pendingMessagesLock lock];
    NSMutableArray *messages = [_pendingMessages objectForKey:session.cookie];
    if (! messages) {
        messages = [NSMutableArray arrayWithCapacity:4];
        [_pendingMessages setObject:callback  // xxx note that the token is the message
                             forKey:session.cookie];
    }
    [messages addObject:message];
    [_pendingMessagesLock unlock];
    return self;
}

+ (BxClientLibHandler *)sendMessage:(BxMessage *)message
                          toSession:(BxSession *)session
                           callback:(SEL)selector
                             target:(id)target {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _sendMessage:message
                         toSession:session
                          callback:selector
                            target:target];
}

- (BxClientLibHandler *)_setAuthenticator:(id <BxClientLibAuthenticator>)authenticator {
    if (_authenticator) {
        [_authenticator release];
    }
    _authenticator = [authenticator retain];
    return self;
}

+ (BxClientLibHandler *)setAuthenticator:(id <BxClientLibAuthenticator>)authenticator {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _setAuthenticator:authenticator];
}

- (BxClientLibHandler *)_setSessionTimeout:(NSTimeInterval)sessionTimeout {
    _sessionTimeout = sessionTimeout;
    return self;
}

+ (BxClientLibHandler *)setSessionTimeout:(NSTimeInterval)sessionTimeout {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _setSessionTimeout:sessionTimeout];
}

- (BxClientLibHandler *)_unbindClass:(Class)cls {
    NSArray *classNames = [_classNameMap allKeys];
    for (NSString *className in classNames) {
        BxClientLibClassBinding *binding = [_classNameMap objectForKey:className];
        if (binding.cls == cls) {
            [_classNameMap removeObjectForKey:className];
            break;
        }
    }
    return self;
}

+ (BxClientLibHandler *)unbindClass:(Class)cls {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _unbindClass:cls];
}

- (BxClientLibHandler *)_unbindInstance:(id)instance {
    [_classNameMapLock lock];
    NSArray *classNames = [_classNameMap allKeys];
    for (NSString *className in classNames) {
        BxClientLibClassBinding *binding = [_classNameMap objectForKey:className];
        if (binding.instance == instance) {
            [_classNameMap removeObjectForKey:className];
            break;
        }
    }
    [_classNameMapLock unlock];
    return self;
}

+ (BxClientLibHandler *)unbindInstance:(id)instance {
    BxClientLibHandler *singleton = [self _singleton];
    return [singleton _unbindInstance:instance];
}

@end
