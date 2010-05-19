#import "BxFile.h"

@implementation BxFile

@synthesize handle = _handle;
@synthesize formName = _formName;
@synthesize fileName = _fileName;
@synthesize tempFilePath = _tempFilePath;
@synthesize mimeType = _mimeType;
@synthesize length = _length;


- (id)initWithFileName:(NSString *)fileName
              formName:(NSString *)formName
              mimeType:(NSString *)mimeType
          tempFilePath:(NSString *)tempFilePath
                handle:(NSFileHandle *)handle
                length:(NSUInteger)length {
    _fileName = [fileName retain];
    _formName = [formName retain];
    _mimeType = [mimeType retain];
    _tempFilePath = [tempFilePath retain];
    _handle = [handle retain];
    _length = length;
    return self;
}

- (void)dealloc {
    [_fileName release];
    [_handle release];
    [_formName release];
    [_mimeType release];
    [_tempFilePath release];
    [super dealloc];
}

@end
