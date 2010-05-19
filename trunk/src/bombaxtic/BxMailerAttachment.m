#import "BxMailerAttachment.h"
#import "BxUtil.h"

@implementation BxMailerAttachment

@synthesize name = _name;
@synthesize data = _data;
@synthesize mimeType = _mimeType;

- (id)initWithName:(NSString *)name
              data:(NSData *)data
          mimeType:(NSString *)mimeType {
    [super init];
    _name = [name copy];
    _data = [data retain];
    _mimeType = [mimeType copy];
    return self;
}

- (id)initWithName:(NSString *)name
              path:(NSString *)path {
    [super init];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data) {
        NSString *mimeType = [BxUtil mimeTypeForExtension:[path pathExtension]];
        if (mimeType == nil) {
            mimeType = @"application/octet-stream";
        }
        return [self initWithName:name
                             data:data
                         mimeType:mimeType];
    } else {
        return nil;
    }
}

- (void)dealloc {
    [_name release];
    [_data release];
    [_mimeType release];
    [super dealloc];
}
                    


@end
