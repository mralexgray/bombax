/**
 \brief TBD
 \class BxArchiveEnvelope
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 2.0
 
 */

#import <Cocoa/Cocoa.h>

@interface BxArchiveEnvelope : NSObject <NSCoding> {
    NSArray *_messages;
    NSData *_contents;
}

@property (nonatomic, readonly) NSArray *messages;
@property (nonatomic, readonly) NSData *contents;

@end
