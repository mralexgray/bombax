#import <Foundation/Foundation.h>

@interface BxArchiveEnvelope : NSObject <NSCoding> {
    NSArray *_messages;
    NSData *_contents;
}

@property (nonatomic, readonly) NSArray *messages;
@property (nonatomic, readonly) NSData *contents;

@end
