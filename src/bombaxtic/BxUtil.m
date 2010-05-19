#import "BxUtil.h"
#import <openssl/bio.h>
#import <openssl/buffer.h>
#import <openssl/evp.h>
#import <openssl/sha.h>

static NSMutableDictionary *_extensionMimeTypes = nil;
static BOOL _hasSeededRandom = NO;

@implementation BxUtil

+ (NSData *)base64DecodeData:(NSData *)data {
    BIO *b64 = BIO_new(BIO_f_base64());
    BIO *bmem = BIO_new_mem_buf((char *) [data bytes], [data length]);
    bmem = BIO_push(b64, bmem);
    NSMutableData *newData = [NSMutableData dataWithCapacity:[data length] * 1.3];
    int len;
    char buf[4096];
    while ((len = BIO_read(bmem, buf, 4096)) > 0) {
        [newData appendBytes:buf
                      length:len];
    }
    BIO_free_all(bmem);
    return newData;
}

+ (NSData *)base64EncodeData:(NSData *)data {
    BIO *bmem;
    BIO *b64;
    b64 = BIO_new(BIO_f_base64());
    bmem = BIO_new(BIO_s_mem());
    b64 = BIO_push(b64, bmem);    
    BIO_write(b64, [data bytes], [data length]);
    BIO_flush(b64);
    void *bytes;
    int len = BIO_get_mem_data(b64, &bytes);
    NSData *newData = [NSData dataWithBytes:bytes
                                     length:len];
    BIO_free_all(b64);
    return newData;
}

+ (NSString *)base64DecodeString:(NSString *)str {
    NSData *data = [str dataUsingEncoding:NSASCIIStringEncoding];
    BIO *b64 = BIO_new(BIO_f_base64());
    BIO *bmem = BIO_new_mem_buf((char *) [data bytes], [data length]);
    bmem = BIO_push(b64, bmem);
    NSMutableData *newData = [NSMutableData dataWithCapacity:[data length] * 1.3];
    int len;
    char buf[4096];
    while ((len = BIO_read(bmem, buf, 4096)) > 0) {
        [newData appendBytes:buf
                      length:len];
    }
    BIO_free_all(bmem);
    return [[[NSString alloc] initWithData:newData
                                  encoding:NSUTF8StringEncoding] autorelease];
}

+ (NSString *)base64EncodeString:(NSString *)str {
    NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
    BIO *bmem;
    BIO *b64;
    b64 = BIO_new(BIO_f_base64());
    bmem = BIO_new(BIO_s_mem());
    b64 = BIO_push(b64, bmem);    
    BIO_write(b64, [data bytes], [data length]);
    BIO_flush(b64);
    void *bytes;
    int len = BIO_get_mem_data(b64, &bytes);
    NSString *newStr = [[[NSString alloc] initWithBytes:bytes
                                                 length:len
                                               encoding:NSUTF8StringEncoding] autorelease];
    BIO_free_all(b64);
    return newStr;
}

+ (void)_setupMimeExtensions {
    if (_extensionMimeTypes == nil) {
        _extensionMimeTypes = [[NSMutableDictionary alloc] initWithCapacity:72];
        [_extensionMimeTypes setObject:@"application/x-javascript"
                                forKey:@"js"];
        [_extensionMimeTypes setObject:@"application/atom-xml"
                                forKey:@"atom"];
        [_extensionMimeTypes setObject:@"application/rss+xml"
                                forKey:@"rss"];
        [_extensionMimeTypes setObject:@"application/java-archive"
                                forKey:@"jar"];
        [_extensionMimeTypes setObject:@"application/java-archive"
                                forKey:@"war"];
        [_extensionMimeTypes setObject:@"application/java-archive"
                                forKey:@"ear"];
        [_extensionMimeTypes setObject:@"application/mac-binhex40"
                                forKey:@"hqx"];
        [_extensionMimeTypes setObject:@"application/msword"
                                forKey:@"doc"];
        [_extensionMimeTypes setObject:@"application/pdf"
                                forKey:@"pdf"];
        [_extensionMimeTypes setObject:@"application/postscript"
                                forKey:@"ps"];
        [_extensionMimeTypes setObject:@"application/postscript"
                                forKey:@"eps"];
        [_extensionMimeTypes setObject:@"application/postscript"
                                forKey:@"ai"];
        [_extensionMimeTypes setObject:@"application/rtf"
                                forKey:@"rtf"];
        [_extensionMimeTypes setObject:@"application/vnd.ms-excel"
                                forKey:@"xls"];
        [_extensionMimeTypes setObject:@"application/vnd.ms-powerpoint"
                                forKey:@"ppt"];
        [_extensionMimeTypes setObject:@"application/vnd.wap.wmlc"
                                forKey:@"wmlc"];
        [_extensionMimeTypes setObject:@"application/vnd.wap.xhtml+xml"
                                forKey:@"xhtml"];
        [_extensionMimeTypes setObject:@"application/vnd.goodle-earth.kml+xml"
                                forKey:@"kml"];
        [_extensionMimeTypes setObject:@"application/vnd.google-earth-kmz"
                                forKey:@"kmz"];
        [_extensionMimeTypes setObject:@"application/x-java-archive-diff"
                                forKey:@"jardiff"];
        [_extensionMimeTypes setObject:@"application/x-java-jnlp-file"
                                forKey:@"jnlp"];
        [_extensionMimeTypes setObject:@"application/x-rar-compressed"
                                forKey:@"rar"];
        [_extensionMimeTypes setObject:@"application/x-shockwave-flash"
                                forKey:@"swf"];
        [_extensionMimeTypes setObject:@"application/x-x509-ca-cert"
                                forKey:@"der"];
        [_extensionMimeTypes setObject:@"application/x-x509-ca-cert"
                                forKey:@"pem"];
        [_extensionMimeTypes setObject:@"application/x-x509-ca-cert"
                                forKey:@"crt"];
        [_extensionMimeTypes setObject:@"application/x-xpinstall"
                                forKey:@"xpi"];
        [_extensionMimeTypes setObject:@"application/zip"
                                forKey:@"zip"];
        [_extensionMimeTypes setObject:@"audio/midi"
                                forKey:@"mid"];
        [_extensionMimeTypes setObject:@"audio/midi"
                                forKey:@"midi"];
        [_extensionMimeTypes setObject:@"audio/mpeg"
                                forKey:@"mp3"];
        [_extensionMimeTypes setObject:@"audio/x-realaudio"
                                forKey:@"ra"];
        [_extensionMimeTypes setObject:@"video/3gpp"
                                forKey:@"3gpp"];
        [_extensionMimeTypes setObject:@"video/3gpp"
                                forKey:@"3gp"];
        [_extensionMimeTypes setObject:@"video/mpeg"
                                forKey:@"mpeg"];
        [_extensionMimeTypes setObject:@"video/mpeg"
                                forKey:@"mpg"];
        [_extensionMimeTypes setObject:@"video/mp4"
                                forKey:@"mp4"];
        [_extensionMimeTypes setObject:@"video/quicktime"
                                forKey:@"mov"];
        [_extensionMimeTypes setObject:@"video/x-flv"
                                forKey:@"flv"];
        [_extensionMimeTypes setObject:@"video/x-mng"
                                forKey:@"mng"];
        [_extensionMimeTypes setObject:@"video/x-ms-asx"
                                forKey:@"asf"];
        [_extensionMimeTypes setObject:@"video/x-ms-asx"
                                forKey:@"asx"];
        [_extensionMimeTypes setObject:@"video/x-ms-wmv"
                                forKey:@"wmv"];
        [_extensionMimeTypes setObject:@"video/x-msvideo"
                                forKey:@"avi"];
        [_extensionMimeTypes setObject:@"text/html"
                                forKey:@"html"];
        [_extensionMimeTypes setObject:@"text/html"
                                forKey:@"htm"];
        [_extensionMimeTypes setObject:@"text/html"
                                forKey:@"shtml"];
        [_extensionMimeTypes setObject:@"text/css"
                                forKey:@"css"];
        [_extensionMimeTypes setObject:@"text/xml"
                                forKey:@"xml"];
        [_extensionMimeTypes setObject:@"text/mathml"
                                forKey:@"mml"];
        [_extensionMimeTypes setObject:@"text/plain"
                                forKey:@"txt"];
        [_extensionMimeTypes setObject:@"text/vnd.sun.j2me.app-descriptor"
                                forKey:@"jad"];
        [_extensionMimeTypes setObject:@"text/vnd.wap.wml"
                                forKey:@"wml"];
        [_extensionMimeTypes setObject:@"text/x-component"
                                forKey:@"htc"];
        [_extensionMimeTypes setObject:@"image/gif"
                                forKey:@"gif"];
        [_extensionMimeTypes setObject:@"image/png"
                                forKey:@"png"];
        [_extensionMimeTypes setObject:@"image/jpeg"
                                forKey:@"jpg"];
        [_extensionMimeTypes setObject:@"image/jpeg"
                                forKey:@"jpeg"];
        [_extensionMimeTypes setObject:@"image/tiff"
                                forKey:@"tiff"];
        [_extensionMimeTypes setObject:@"image/vnd.wap.wbmp"
                                forKey:@"wbmp"];
        [_extensionMimeTypes setObject:@"image/x-icon"
                                forKey:@"icon"];
        [_extensionMimeTypes setObject:@"image/x-jng"
                                forKey:@"jng"];
        [_extensionMimeTypes setObject:@"image/x-ms-bmp"
                                forKey:@"bmp"];
        [_extensionMimeTypes setObject:@"image/svg+xml"
                                forKey:@"svg"];
        [_extensionMimeTypes setObject:@"image/gif"
                                forKey:@"gif"];        
    }
}

+ (NSString *)extensionForMimeType:(NSString *)mimeType {
    [self _setupMimeExtensions];
    NSArray *keys = [_extensionMimeTypes allKeysForObject:mimeType];
    if (keys && [keys count] > 0) {
        return [keys objectAtIndex:0];
    } else {
        return nil;
    }
}

+ (NSString *)mimeTypeForExtension:(NSString *)extension {
    [self _setupMimeExtensions];
    if ([extension hasPrefix:@"."]) {
        extension = [extension substringFromIndex:1];
    }
    NSString *mimeType = [_extensionMimeTypes objectForKey:extension];
    return mimeType;
}

+ (BOOL)isIpAddress:(NSString *)ipAddress
         withinCIDR:(NSString *)cidr {
    // tbd
    return NO;
}

+ (NSString *)randomAlphaNumericString:(NSUInteger)len {
    static char *glyphs = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    if (! _hasSeededRandom) {
        srandom(time(NULL));
    }
    NSMutableString *str = [NSMutableString stringWithCapacity:len];
    for (int i = 0; i < len; i++) {
        char glyph = i == 0 ? glyphs[random() % 52] : glyphs[random() % 62];
        [str appendFormat:@"%c", glyph];
    }
    return str;
}

@end
