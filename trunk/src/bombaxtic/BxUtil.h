/**
 \brief TBD
 \class BxUtil
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 2.0
 
 */

#import <Cocoa/Cocoa.h>

@interface BxUtil : NSObject {
}

+ (NSData *)base64DecodeData:(NSData *)data;

+ (NSData *)base64EncodeData:(NSData *)data;

+ (NSString *)base64DecodeString:(NSString *)str;

+ (NSString *)base64EncodeString:(NSString *)str;

+ (NSString *)extensionForMimeType:(NSString *)mimeType;

+ (NSString *)mimeTypeForExtension:(NSString *)extension;

//+ (BOOL)isIpAddress:(NSString *)ipAddress
//         withinCIDR:(NSString *)cidr;

+ (NSString *)randomAlphaNumericString:(NSUInteger)len;


// tbd: compression

@end
