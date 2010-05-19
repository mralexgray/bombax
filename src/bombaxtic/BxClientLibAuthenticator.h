/**
 \brief TBD
 \class BxClientLibAuthenticator
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 2.0
 
 */

#import <Cocoa/Cocoa.h>

@class BxSession;
@class BxTransport;

@protocol BxClientLibAuthenticator

- (BOOL)authenticateBxClientLibRequest:(BxTransport *)transport
                               session:(BxSession *)session;

@end
