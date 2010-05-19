#import "BxRequestOperation.h"
#import "BxMessage.h"
#import "BxMessageManager.h"
#import "BxServerSession.h"
#import "BxRequestOperationCallback.h"
#import "BxArchiveEnvelope.h"

@implementation BxRequestOperation

- (id)initWithRequest:(NSURLRequest *)request
        serverSession:(BxServerSession *)serverSession
             callback:(NSObject <BxRequestOperationCallback>*)callback
                token:(id)token {
    [super init];
    _request = [request retain];
    _serverSession = [serverSession retain];
    if (callback) {
        _callback = [callback retain];
    } else {
        _callback = nil;
    }
    if (token) {
        _token = [token retain];
//        if ([_token isMemberOfClass:[NSLock class]]) {
//            [_token lock];
//        }
    } else {
        _token = nil;
    }             
    return self;
}

+ (BxRequestOperation *)operationWithRequest:(NSURLRequest *)request
                               serverSession:(BxServerSession *)serverSession
                                    callback:(NSObject <BxRequestOperationCallback>*)callback
                                       token:(id)token {
    return [[[BxRequestOperation alloc] initWithRequest:request
                                          serverSession:serverSession
                                               callback:callback
                                                  token:token] autorelease];
}

- (void)main {
    if (! [self isCancelled]) {
        NSHTTPURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:_request
                                             returningResponse:&response
                                                         error:&error];
        NSLog(@"data=%@ datalen=%d error=%@", data, [data length], error); // xxx
        
        if ([response statusCode] == 409) {
            [_serverSession _invalidateSession];
            error = [NSError errorWithDomain:@"BxClientLib"
                                        code:100
                                    userInfo:[NSDictionary dictionaryWithObject:@"The BxClientLib session has timed out or is otherwise invalid"
                                                                         forKey:NSLocalizedDescriptionKey]];
        }
        if (! error && [data length] > 0) {
            BxArchiveEnvelope *envelope = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            if (envelope.messages) {
                BxMessageManager *messageManager = [_serverSession messageManager];
                for (BxMessage *message in envelope.messages) {
                    [messageManager _receiveMessage:message];
                }
            }
            if (_callback) {
                [_callback requestOperationCallbackWithContents:envelope.contents
                                                          token:_token
                                                        request:_request
                                                       response:response
                                                          error:error];
            }
        } else if (_callback) {
            [_callback requestOperationCallbackWithContents:data
                                                      token:_token
                                                    request:_request
                                                   response:response
                                                      error:error];
        }
    }
    if (_token && [_token isMemberOfClass:[NSConditionLock class]]) {
        [_token lock];
        [_token unlockWithCondition:1];
    }
}


- (void)dealloc {
    [_serverSession release];
    [_request release];
    if (_callback) {
        [_callback release];
    }
    if (_token) {
        if ([_token isMemberOfClass:[NSLock class]] && [_token tryLock] == NO) {
            [_token unlock];
        }
        [_token release];
    }
    [super dealloc];
}

@end
