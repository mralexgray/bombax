#import "BxMessage.h"

@implementation BxMessage

@synthesize data = _data;
@synthesize labels = _labels;
@synthesize kind = _kind;
@synthesize createdDate = _createdDate;

- (id)initWithData:(NSData *)data
              kind:(NSString *)kind
            labels:(NSDictionary *)labels
       createdDate:(NSTimeInterval)createdDate {
    [self init];
    _data = [data retain];
    _kind = [kind copy];
    if (labels != nil) {
        _labels = [labels copy];
    } else {
        _labels = nil;
    }
    _createdDate = createdDate;
    return self;
}

- (id)initWithData:(NSData *)data
              kind:(NSString *)kind
            labels:(NSDictionary *)labels {
    [self initWithData:data
                  kind:kind
                labels:labels
           createdDate:[NSDate timeIntervalSinceReferenceDate]];
    return self;
}

- (id)initWithCoder:(NSCoder *)decoder {
    _kind = [[decoder decodeObjectForKey:@"_kind"] retain];
    _labels = [decoder decodeObjectForKey:@"_labels"];
    if (_labels) {
        [_labels retain];
    }
    _data = [[decoder decodeObjectForKey:@"_data"] retain];
    _createdDate = [decoder decodeDoubleForKey:@"_createdDate"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeObject:_kind
                   forKey:@"_kind"];
    [encoder encodeObject:_labels
                   forKey:@"_labels"];
    [encoder encodeObject:_data
                   forKey:@"_data"];
    [encoder encodeDouble:_createdDate
                   forKey:@"_createdDate"];
}

+ (NSInteger)version {
    return 1;
}

+ (BxMessage *)messageWithData:(NSData *)data
                          kind:(NSString *)kind
                        labels:(NSDictionary *)labels {
    return [[[BxMessage alloc] initWithData:data
                                       kind:kind
                                     labels:labels] autorelease];
}

- (id)copyWithZone:(NSZone *)zone {
    BxMessage *copy = [[BxMessage messageWithData:_data
                                             kind:_kind
                                           labels:_labels] retain];
    return copy;
}


- (void)dealloc {
    [_data release];
    [_kind release];
    if (_labels) {
        [_labels release];
    }
    [super dealloc];
}

@end
