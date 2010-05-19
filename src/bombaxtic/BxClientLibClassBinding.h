/**
 \brief TBD
 \class BxClientLibClassBinding
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 2.0
 
 */

#import <Cocoa/Cocoa.h>
#import <Bombaxtic/BxClientLibAuthorizer.h>

@interface BxClientLibClassBinding : NSObject {
    Class _cls;
    id <BxClientLibAuthorizer> _authorizer;
    id _instance;
}

+ (BxClientLibClassBinding *)classBindingWithClass:(Class)cls
                                          instance:(id)instance
                                        authorizer:(id <BxClientLibAuthorizer>)authorizer;
    
@property (readonly, nonatomic) Class cls;
@property (readonly, nonatomic) id <BxClientLibAuthorizer> authorizer;
@property (readonly, nonatomic) id instance;

@end
