#import <Bombaxtic/BxHandler.h>
#import <Bombaxtic/BxTransport.h>
#import <Bombaxtic/BxUtil.h>
#import "BxStaticFileHandler.h"

static NSString *_staticResourcePath = nil;

@implementation BxStaticFileHandler

+ (void)setStaticResourcePath:(NSString *)path {
    if (_staticResourcePath != nil) {
        [_staticResourcePath release];
    }
    if (path == nil) {
        _staticResourcePath = [[NSString stringWithFormat:@"%@/static",
                                [[NSBundle mainBundle] resourcePath]] copy];
    } else if ([path hasPrefix:@"/"]) {
        _staticResourcePath = [path copy];
    } else {
        _staticResourcePath = [[NSString stringWithFormat:@"%@/%@",
                                [[NSBundle mainBundle] resourcePath],
                                path] copy];
    }
}

+ (NSString *)staticResourcePath {
    if (_staticResourcePath == nil) {
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        NSString *resourcePath = [info objectForKey:@"BxApp Static Resource Path"];
        if ([resourcePath hasPrefix:@"/"]) {
            _staticResourcePath = [resourcePath copy];
        } else if (resourcePath == nil) {
            _staticResourcePath = [[NSString stringWithFormat:@"%@/static",
                                    [[NSBundle mainBundle] resourcePath]] copy];
        } else {
            _staticResourcePath = [[NSString stringWithFormat:@"%@/%@",
                                    [[NSBundle mainBundle] resourcePath],
                                    resourcePath] copy];
        }        
    }
    return [NSString stringWithString:_staticResourcePath];
}

- (id)setup {
    if (_staticResourcePath == nil) {
        [BxStaticFileHandler staticResourcePath];
    }
    return self;
}

- (id)renderWithTransport:(BxTransport *)transport {
    NSString *prefix = [_app _staticPrefix];
    NSString *path;
    if ([transport.requestPath hasPrefix:prefix]) {
        path = [NSString stringWithFormat:@"%@/%@", _staticResourcePath, [transport.requestPath substringFromIndex:[prefix length]]];
    } else {
        path = [NSString stringWithFormat:@"%@/%@", _staticResourcePath, transport.requestPath];
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data != nil) {
        NSString *contentType = [BxUtil extensionForMimeType:[transport.requestPath pathExtension]];
        if (contentType == nil) {
            contentType = @"application/octet-stream";
        }
        [transport setHeader:@"Content-Type"
                       value:contentType];
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path
                                                                               error:NULL];
        NSNumber *size = [attrs objectForKey:NSFileSize];
        [transport setHeader:@"Content-Length"
                       value:[NSString stringWithFormat:@"%llu", [size longLongValue]]];
        [transport writeData:data];
    } else {
        [transport setHttpStatusCode:404];
    }
    return self;
}

@end
