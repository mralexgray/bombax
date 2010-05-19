#import <Foundation/Foundation.h>


@interface BxCallback : NSObject {
    BOOL _hasOneArgument;
    id _target;
    id _token;
    SEL _selector;
}

- (id)initWithSelector:(SEL)selector
                target:(id)target;

- (id)initWithSelector:(SEL)selector
                target:(id)target
                 token:(id)token;

+ (BxCallback *)callbackWithSelector:(SEL)selector
                              target:(id)target;

+ (BxCallback *)callbackWithSelector:(SEL)selector
                              target:(id)target
                               token:(id)token;

- (id)invokeWith:(id)result;

@property (nonatomic, assign) SEL selector;
@property (retain) id target;
@property (retain) id token;

@end
