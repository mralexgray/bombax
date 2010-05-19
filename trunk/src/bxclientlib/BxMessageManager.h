#import <Foundation/Foundation.h>
#import "BxRequestOperationCallback.h"

@class BxServerSession;
@class BxMessage;

@interface BxMessageManager : NSObject <BxRequestOperationCallback> {
    BOOL _keepMessages;
    BOOL *_isValidPtr;
    BxServerSession *_serverSession;
    NSLock *_messageLock;
    NSLock *_observerLock;
    NSMutableArray *_incomingMessages;
    NSMutableArray *_universalObservers;
    NSMutableDictionary *_observers;
    NSTimeInterval _maxCheckInterval;
    NSTimeInterval _lastCheck;
    NSUInteger _maxMessages;
}

- (id)addObserver:(id)observer
         selector:(SEL)selector
             kind:(NSString *)kind;

- (int)clearMessages;

- (int)messageCount;

- (NSArray *)messages;

- (BxMessage *)popMessage;

- (BOOL)removeObserver:(id)observer
                  kind:(NSString *)kind;

- (id)sendSynchronousMessage:(BxMessage *)message
                        error:(NSError **)error;

- (id)sendMessage:(BxMessage *)message;

// callback message:(BxMessage *) error:(NSError *)
- (id)sendMessage:(BxMessage *)message
         callback:(SEL)selector
           target:(id)target;


@property (assign, nonatomic) BOOL keepMessages;
@property (assign, nonatomic) NSUInteger maxMessages;
@property (assign, nonatomic) NSTimeInterval maxCheckInterval;

@end
