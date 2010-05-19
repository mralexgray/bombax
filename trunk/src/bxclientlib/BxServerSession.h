#import <Foundation/Foundation.h>

@class BxRemoteObjectManager;
@class BxMessageManager;

@interface BxServerSession : NSObject {
    BOOL _isClosed;
    BOOL _sessionValid;
    BOOL _useCompression;
    BxMessageManager *_messageManager;
    BxRemoteObjectManager *_remoteObjectManager;
    NSOperationQueue *_requestQueue;
    NSString *_sessionId;
    NSTimeInterval _timeoutInterval;
    NSURL *_url;
}

- (id)initWithURL:(NSURL *)url;

- (id)clearRequestQueue;

- (id)close;

- (BxMessageManager *)messageManager;

- (id)reinitialize;

- (BxRemoteObjectManager *)remoteObjectManager;

@property (nonatomic, readonly) BOOL isClosed;
@property (nonatomic, readonly) BOOL sessionValid;
@property (nonatomic, assign) BOOL useCompression;
@property (nonatomic, assign) NSTimeInterval timeoutInterval;

@end
