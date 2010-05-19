#import <Foundation/Foundation.h>
#import "BxRequestOperationCallback.h"

@class BxServerSession;

@interface BxRemoteObjectManager : NSObject <BxRequestOperationCallback> {
    BxServerSession *_serverSession;
    NSLock *_instanceLock;
    NSLock *_signatureLock;
    NSMutableDictionary *_instanceOids;
    NSMutableDictionary *_classSignatures;
    NSMutableDictionary *_requestResponseContents;
}

- (id)createRemoteInstance:(NSString *)className;

@end
