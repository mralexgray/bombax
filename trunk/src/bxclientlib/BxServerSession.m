#import "BxServerSession.h"
#import "BxRequestOperation.h"
#import "BxMessageManager.h"
#import "BxRemoteObjectManager.h"
#import "BxArchiveEnvelope.h"

@implementation BxServerSession

@synthesize sessionValid = _sessionValid;
@synthesize timeoutInterval = _timeoutInterval;
@synthesize useCompression = _useCompression;
@synthesize isClosed = _isClosed;

NSString *_BX_CLIENTLIB_PROTOCOL = @"1.0";


- (NSURLRequest *)_createRequest:(NSData *)data {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_url
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                                       timeoutInterval:_timeoutInterval];
    if (_useCompression) {
        
    }
    [request setHTTPBody:data];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"%ld", [data length]] forHTTPHeaderField:@"Content-Length"];
    [request setValue:_BX_CLIENTLIB_PROTOCOL forHTTPHeaderField:@"BxClientLib-Protocol"];
    if (_useCompression) {
        [request setValue:@"LZMA" forHTTPHeaderField:@"BxClientLib-Compression"];
    }
    return request;
}

- (id)_invalidateSession {
    _sessionValid = NO;
    return self;
}

- (id)_addRequestOperation:(BxRequestOperation *)operation {
    if (_isClosed) {
        [NSException raise:@"BxServerSession Closed"
                    format:@"This BxServerSession has already been closed. No new operations may be added."];
    }
    [_requestQueue addOperation:operation];
    return self;
}

- (id)_waitForOperationQueue {
    [_requestQueue waitUntilAllOperationsAreFinished];
    return self;
}

- (id)init {
    [super self];
    [BxArchiveEnvelope class]; // xxx without this unarchiving doesn't work
    _remoteObjectManager = nil;
    _messageManager = nil;
    _requestQueue = [[NSOperationQueue alloc] init];
    [_requestQueue setMaxConcurrentOperationCount:1];
    _sessionValid = YES;
    _timeoutInterval = 60;
    _useCompression = NO;
    _isClosed = NO;
    return self;
}

- (id)initWithURL:(NSURL *)url {
    [self init];
    _url = [url retain];
    return self;
}

- (id)clearRequestQueue {
    [_requestQueue cancelAllOperations];
    return self;
}

- (id)close {
    [_requestQueue cancelAllOperations];
    if (_remoteObjectManager) {
        [_remoteObjectManager _sendReleaseAllRequest];
        [_requestQueue waitUntilAllOperationsAreFinished];
    }
    return self;
}

- (BxMessageManager *)messageManager {
    if (! _messageManager) {
        _messageManager = [[BxMessageManager alloc] _initWithServerSession:self];
    }
    return _messageManager;
}

- (id)reinitialize {
    if (_messageManager) {
        [_messageManager release];
    }
    if (_remoteObjectManager) {
        [_remoteObjectManager release];
    }
    // remove the cookie
}

- (BxRemoteObjectManager *)remoteObjectManager {
    if (! _remoteObjectManager) {
        _remoteObjectManager = [[BxRemoteObjectManager alloc] _initWithServerSession:self];
    }
    return _remoteObjectManager;
}

- (void)requestOperationCallbackWithContents:(NSData *)contents
                                       token:(id)token
                                     request:(NSURLRequest *)request
                                    response:(NSHTTPURLResponse *)response
                                       error:(NSError *)error {
    // tbd
}

- (void)dealloc {
    [_url release];
    [_requestQueue cancelAllOperations];
    [_requestQueue release];
    if (_remoteObjectManager) {
        [_remoteObjectManager release];
    }
    if (_messageManager) {
        [_messageManager release];
    }
    [super dealloc];
}

@end
