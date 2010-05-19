#import <Foundation/Foundation.h>

@class BxRemoteObjectManager;

@interface BxRemoteObject : NSObject {
    BxRemoteObjectManager *_BX_remoteObjectManager;
    NSString *_BX_className;
    NSString *_BX_oid;
}

- (id)initWithOid:(NSString *)oid
        className:(NSString *)className
    objectManager:(BxRemoteObjectManager *)objectManager;

@property (readonly, nonatomic) NSString *_BX_className;
@property (readonly, nonatomic) NSString *_BX_oid;

@end
