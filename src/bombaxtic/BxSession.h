/**
 \brief TBD
 \class BxSession
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 2.0
 
 */

#import <Cocoa/Cocoa.h>

@class BxClientLibHandler;

@interface BxSession : NSObject {
    BxClientLibHandler *_handler;
    NSMutableDictionary *_remotedObjects;
    NSMutableDictionary *_state;
    NSString *_cookie;
    NSString *_ipAddress;
    NSTimeInterval _lastActivated;
}

@property (readonly) BxClientLibHandler *handler;
@property (readonly) NSMutableDictionary *state;
@property (readonly) NSString *cookie;
@property (readonly) NSString *ipAddress;
@property (readonly, nonatomic) NSTimeInterval lastActivated;

@end
