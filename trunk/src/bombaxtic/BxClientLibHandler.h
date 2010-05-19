/**
 \brief TBD
 \class BxClientLibHandler
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 2.0
 
 */

#import <Cocoa/Cocoa.h>
#import <Bombaxtic/BxHandler.h>
#import "BxClientLibAuthenticator.h"
#import "BxClientLibAuthorizer.h"

@class BxHandler;
@class BxMessage;
@class BxSession;

@interface BxClientLibHandler : BxHandler {
    NSTimeInterval _sessionTimeout;
    id <BxClientLibAuthenticator> _authenticator;
    NSLock *_classNameMapLock;
    NSLock *_globalMessageObserversLock;
    NSLock *_messageObserversLock;
    NSLock *_pendingMessagesLock;
    NSLock *_sessionsLock;
    NSLock *_sessionCallbacksLock;
    NSMutableArray *_sessions; // sessions
    NSMutableDictionary *_classNameMap;
    NSMutableDictionary *_globalMessageObservers; // kind or NSNull -> BxCallback
    NSMutableDictionary *_messageObservers; // session -> NSDictionary = (map via NSNull) kind -> BxCallback
    NSMutableDictionary *_pendingMessages; // session ->
    NSMutableArray *_sessionCallbacks;
}

+ (BxClientLibHandler *)addGlobalMessageObserver:(id)observer
                                        selector:(SEL)selector
                                            kind:(NSString *)kind;

// message:session
+ (BxClientLibHandler *)addMessageObserver:(id)observer
                                  selector:(SEL)selector
                                   session:(BxSession *)session
                                      kind:(NSString *)kind;

+ (BxClientLibHandler *)addNewSessionCallback:(SEL)selector
                                       target:(id)target;

+ (BxClientLibHandler *)bindClass:(Class)cls;

+ (BxClientLibHandler *)bindClass:(Class)cls
                       authorizer:(id <BxClientLibAuthorizer>)authorizer;

+ (BxClientLibHandler *)bindClass:(Class)cls
                     forClassName:(NSString *)className;

+ (BxClientLibHandler *)bindClass:(Class)cls
                     forClassName:(NSString *)className
                       authorizer:(id <BxClientLibAuthorizer>)authorizer;

+ (BxClientLibHandler *)bindInstance:(id)instance;

+ (BxClientLibHandler *)bindInstance:(id)instance
                          authorizer:(id <BxClientLibAuthorizer>)authorizer;

+ (BxClientLibHandler *)bindInstance:(id)instance
                        forClassName:(NSString *)className;

+ (BxClientLibHandler *)bindInstance:(id)instance
                        forClassName:(NSString *)className
                          authorizer:(id <BxClientLibAuthorizer>)authorizer;


+ (BxClientLibHandler *)broadcastMessage:(BxMessage *)message;

+ (BxClientLibHandler *)removeAuthenticator;

+ (BxClientLibHandler *)removeGlobalMessageObserver:(id)observer
                                               kind:(NSString *)kind;

+ (BxClientLibHandler *)removeMessageObserver:(id)observer
                                      session:(BxSession *)session
                                         kind:(NSString *)kind;

+ (BxClientLibHandler *)removeNewSessionCallback:(SEL)selector
                                          target:(id)target;

+ (BxClientLibHandler *)sendMessage:(BxMessage *)message
                          toSession:(BxSession *)session;

+ (BxClientLibHandler *)sendMessage:(BxMessage *)message
                          toSession:(BxSession *)session
                           callback:(SEL)selector
                             target:(id)target;

+ (BxClientLibHandler *)setAuthenticator:(id <BxClientLibAuthenticator>)authenticator;

+ (BxClientLibHandler *)setSessionTimeout:(NSTimeInterval)sessionTimeout;

+ (BxClientLibHandler *)unbindClass:(Class)cls;

+ (BxClientLibHandler *)unbindInstance:(id)instance;

@end
