/**
 \brief TBD
 \class BxMessage
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 2.0
 
 */

#import <Cocoa/Cocoa.h>

@interface BxMessage : NSObject <NSCoding, NSCopying> {
    NSData *_data;
    NSDictionary *_labels;
    NSString *_kind;
    NSTimeInterval _createdDate;
}

- (id)initWithData:(NSData *)data
              kind:(NSString *)kind
            labels:(NSDictionary *)labels;

+ (BxMessage *)messageWithData:(NSData *)data
                          kind:(NSString *)kind
                        labels:(NSDictionary *)labels;

@property (readonly, nonatomic) NSData *data;
@property (readonly, nonatomic) NSDictionary *labels;
@property (readonly, nonatomic) NSString *kind;
@property (readonly, nonatomic) NSTimeInterval createdDate;

@end
