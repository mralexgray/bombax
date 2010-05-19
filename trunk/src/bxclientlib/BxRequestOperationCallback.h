#import <Foundation/Foundation.h>

@protocol BxRequestOperationCallback

- (void)requestOperationCallbackWithContents:(NSData *)contents
                                       token:(id)token
                                     request:(NSURLRequest *)request
                                    response:(NSHTTPURLResponse *)response
                                       error:(NSError *)error;

@end
