#import <Foundation/Foundation.h>
#import "BxRequestOperationCallback.h"

@class BxServerSession;

@interface BxRequestOperation : NSOperation {
    BxServerSession *_serverSession;
    NSObject *_token;
    NSObject <BxRequestOperationCallback> *_callback;
    NSURLRequest *_request;
}

- (id)initWithRequest:(NSURLRequest *)request
        serverSession:(BxServerSession *)serverSession
             callback:(NSObject <BxRequestOperationCallback>*)callback
                token:(id)token;

+ (BxRequestOperation *)operationWithRequest:(NSURLRequest *)request
                               serverSession:(BxServerSession *)serverSession
                                    callback:(NSObject <BxRequestOperationCallback>*)callback
                                       token:(id)token;


@end
