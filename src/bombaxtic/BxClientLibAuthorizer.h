/**
 \brief TBD
 \class BxClientLibAuthorizer
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 2.0
 
 */

#import <Cocoa/Cocoa.h>

@class BxSession;

@protocol BxClientLibAuthorizer

- (BOOL)authorizeBxClientLibClass:(Class)cls
                         instance:(id)instance
                         selector:(SEL)selector
                          session:(BxSession *)session;

- (BOOL)authorizeBxClientLibInit:(Class)cls
                         session:(BxSession *)session;

@end
