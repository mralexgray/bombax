«OPTIONALHEADERIMPORTLINE»

@implementation «FILEBASENAMEASIDENTIFIER»

- (id)renderWithTransport:(BxTransport *)transport {
    [transport write:@"Hello World!"];
    return self;
}

@end
