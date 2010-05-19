#import "BxArchiveEnvelope.h"


@implementation BxArchiveEnvelope

@synthesize contents = _contents;
@synthesize messages = _messages;

- (id)initWithCoder:(NSCoder *)decoder {
    _contents = [decoder decodeObjectForKey:@"data"];
    if (_contents) {
        [_contents retain];
    }
    _messages = [decoder decodeObjectForKey:@"messages"];
    if (_messages) {
        [_messages retain];
    }
    return self;
}

- (id)initWithContents:(NSData *)data
              messages:(NSArray *)messages {
    _contents = data ? [data retain] : nil;
    _messages = messages ? [messages retain] : nil;
    return self;
}


- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_contents
                   forKey:@"data"];
    [encoder encodeObject:_messages
                   forKey:@"messages"];
}

- (void)dealloc {
    if (_contents) {
        [_contents release];
    }
    if (_messages) {
        [_messages release];
    }
    [super dealloc];
}

@end
