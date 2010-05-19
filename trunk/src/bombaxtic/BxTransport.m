#import "BxTransport.h"
#import <pthread.h>
#import <Bombaxtic/BxFile.h>

@implementation BxTransport

@synthesize serverVars = _serverVars;
@synthesize isClosed = _isClosed;
@synthesize queryVars = _queryVars;
@synthesize postVars = _postVars;
@synthesize cookies = _cookies;
@synthesize rawPostData = _rawPostData;
@synthesize uploadedFiles = _uploadedFiles;
@synthesize state = _state;
@synthesize requestPath = _requestPath;

// from fcgiapp.c with name change

typedef struct FCGX_Params {
    FCGX_ParamArray vec;    /* vector of strings */
    int length;		    /* number of string vec can hold */
    char **cur;		    /* current item in vec; *cur == NULL */
} FCGX_Params;


-(id)initWithRequest:(FCGX_Request *)request {
    _request = request;
    FCGX_Params *params = (FCGX_Params *) _request->paramsPtr;
    _state = [[NSMutableDictionary alloc] initWithCapacity:32];
    _serverVars = [[NSMutableDictionary alloc] initWithCapacity:params->length];
    _queryVars = [[NSMutableDictionary alloc] initWithCapacity:4];
    _cookies = [[NSMutableDictionary alloc] initWithCapacity:4];
    _outboundCookies = [[NSMutableArray alloc] initWithCapacity:4];
    _postVars = [[NSMutableDictionary alloc] initWithCapacity:4];
    _uploadedFiles = [[NSMutableArray alloc] initWithCapacity:0];
    _outboundHeaders = [[NSMutableDictionary alloc] initWithCapacity:1];
    _rawPostData = nil;
    _hasWrittenHeaders = NO;
    _isClosed = NO;
    [_outboundHeaders setObject:@"text/html" forKey:@"Content-Type"];
    
    for (int i = 0; i < params->length; i++) {
        char *str = params->vec[i];
        if (str == NULL) {
            break;
        }
        int len = strlen(str);
        for (int j = 0; j < len; j++) {
            if (str[j] == '=') {
                if (memcmp("QUERY_STRING", str, j)) {
                    NSString *key = [[[NSString alloc] initWithBytes:str
                                                              length:j
                                                            encoding:NSUTF8StringEncoding] autorelease];
                    NSString *value = [[[NSString alloc] initWithBytes:&str[j + 1]
                                                                length:len - j - 1
                                                              encoding:NSUTF8StringEncoding] autorelease];
                    [_serverVars setObject:value forKey:key];                    
                } else {
                    char *qstr = &str[j + 1];
                    char *part;
                    // this will clobber QUERY_STRING
                    while ((part = strsep(&qstr, "&")) != NULL) {
                        int plen = strlen(part);
                        for (int k = 0; k < plen; k++) {
                            if (part[k] == '+') {
                                part[k] = ' ';
                            }
                        }
                        for (int k = 0; k < plen; k++) {
                            if (part[k] == '=') {
                                NSString *key = [[[[NSString alloc] initWithBytes:part
                                                                           length:k
                                                                         encoding:NSUTF8StringEncoding] autorelease] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                                NSString *value = [[[[NSString alloc] initWithBytes:&part[k + 1]
                                                                             length:plen - k - 1
                                                                           encoding:NSUTF8StringEncoding] autorelease] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                                [_queryVars setObject:value forKey:key];
                                break;
                            } else if (k == plen - 1) {
                                NSString *key = [[[[NSString alloc] initWithBytes:part
                                                                           length:plen
                                                                         encoding:NSUTF8StringEncoding] autorelease] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                                [_queryVars setObject:@"" forKey:key];
                            }
                        }                                
                    }
                }
                break;
            }
        }
    }
        
    if ([@"POST" isEqualToString:[_serverVars objectForKey:@"REQUEST_METHOD"]]) {
        NSString *contentLengthStr = [_serverVars objectForKey:@"CONTENT_LENGTH"];
        int contentLength;
        char *buffer;
        NSMutableData *content = nil;
        if (contentLengthStr == nil) {
            buffer = malloc(65536);
            int result;
            while ((result = FCGX_GetStr(buffer, 65535, _request->in)) > 0) {
                if (content != nil) {
                    if (result == 65535) {
                        content = [NSMutableData dataWithCapacity:262144];
                    } else {
                        content = [NSMutableData dataWithCapacity:result + 1];
                    }
                }
                [content appendBytes:buffer length:result];
            }
            if (result < 0) {
                // error
            }
            if (content == nil) {
                content = [NSMutableData dataWithCapacity:1];
            }
            contentLength = [content length];
            [content appendBytes:"" length:1];
        } else {
            contentLength = [contentLengthStr intValue];
            buffer = malloc(contentLength + 1);
            contentLength = FCGX_GetStr(buffer, contentLength, _request->in);
            if (contentLength < 0) {
                // error
            }
        }
        NSString *contentType = [_serverVars objectForKey:@"CONTENT_TYPE"];
        if ([@"application/x-www-form-urlencoded" isEqualToString:contentType]) {
            buffer[contentLength] = 0;
            char *part;
            while ((part = strsep(&buffer, "&")) != NULL) {
                int plen = strlen(part);
                for (int i = 0; i < plen; i++) {
                    if (part[i] == '=') {
                        for (int j = 0; j < i; j++) {
                            if (part[j] == '+') {
                                part[j] = ' ';
                            }
                        }                    
                        for (int j = 0; j < plen - i; j++) {
                            if (part[i + 1 + j] == '+') {
                                part[i + 1 + j] = ' ';
                            }
                        }                    
                        
                        NSString *key = [[[[NSString alloc] initWithBytes:part
                                                                   length:i
                                                                 encoding:NSUTF8StringEncoding] autorelease] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                        NSString *value = [[[[NSString alloc] initWithBytes:&part[i + 1]
                                                                     length:plen - i - 1
                                                                   encoding:NSUTF8StringEncoding] autorelease] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                        [_postVars setObject:value forKey:key];
                    }
                }
                
            }
        } else if ([contentType hasPrefix:@"multipart/form-data;"]) {
            if (content == nil) {
                content = [[[NSData alloc] initWithBytesNoCopy:buffer
                                                            length:contentLength
                                                      freeWhenDone:NO] autorelease];
            }
            const char *rawContent = [content bytes];
            //strlen("multipart/form-data; boundary=") = 30
            NSData *boundary = [[NSString stringWithFormat:@"%@\r\n", [contentType substringFromIndex:30]] dataUsingEncoding:NSUTF8StringEncoding];
            const char *rawBoundary = [boundary bytes];
            int boundaryLen = [boundary length];
            int start = boundaryLen;
            for (;;) {
                NSRange range = NSMakeRange(start, [content length] - start);
                // xxx if we search the raw bytes, we don't need to use rangeOfData and can do 10.5 but we need memmem
                int searchMax = range.location + range.length;
                NSRange result = NSMakeRange(NSNotFound, 0);
                for (int i = range.location; i < searchMax - boundaryLen + 1; i++) {
                    BOOL boundaryFound = YES;
                    for (int j = 0; j < boundaryLen; j++) {
                        if (i + j > searchMax || rawContent[i + j] != rawBoundary[j]) {
                            boundaryFound = NO;
                            break;
                        }
                    }
                    if (boundaryFound) {
                        result = NSMakeRange(i, boundaryLen);
                        break;
                    }
                }
                //NSRange result = [content rangeOfData:boundary options:0 range:range];
                int end = contentLength - (boundaryLen + 4);
                if (result.location != NSNotFound) {
                    end = result.location;
                }
                char *headerEnd = strnstr(&rawContent[start], "\r\n\r\n", end - start);
                if (headerEnd == NULL) {
                    break;
                }
                headerEnd[0] = 0;
                const char *header = &rawContent[start];
                int headerLen = strlen(header);
                // okay we have the header... now the actual data...
                char *data = &headerEnd[4];
                int dataLen = (end - start) - (headerEnd - &rawContent[start] + 6); // xxx check...
                char *formName = strnstr(header, "name=\"", headerLen);
                if (formName == NULL) {
                    break;
                }
                formName = &formName[6];
                int formNameLen = strchr(formName, '"') - formName;
                char *fileName = strnstr(header, "filename=\"", headerLen);
                if (fileName == NULL) {
                    for (int i = 0; i < dataLen - 2; i++) {
                        if (data[i] == '+') {
                            data[i] = ' ';
                        }
                    }                    
                    for (int i = 0; i < formNameLen - 2; i++) {
                        if (formName[i] == '+') {
                            formName[i] = ' ';
                        }
                    }                    
                    // it's a POST variable -- are these ever encoded?  what if it is not text -- is that possible?
                    [_postVars setObject:[[[[NSString alloc] initWithBytes:data
                                                                    length:dataLen - 2
                                                                  encoding:NSUTF8StringEncoding] autorelease] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                                  forKey:[[[[NSString alloc] initWithBytes:formName
                                                                    length:formNameLen
                                                                  encoding:NSUTF8StringEncoding] autorelease] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
                } else {
                    fileName = &fileName[10];
                    int fileNameLen = strchr(fileName, '"') - fileName;
                    char *fileMimeType = strnstr(header, "Content-Type: ", headerLen);
                    if (fileMimeType == NULL) {
                        break;
                    }
                    fileMimeType = &fileMimeType[14];
                    int fileMimeTypeLen = strlen(fileMimeType); // should be null terminated from headerEnd[0] = 0
                    const char *tempDir = [NSTemporaryDirectory() UTF8String];
                    int tempDirLen = strlen(tempDir);
                    char tempTemplate[tempDirLen + 64];
                    strcpy(tempTemplate, tempDir);
                    tempTemplate[tempDirLen] = 0;
                    int fileno = mkstemp(strcat(tempTemplate, "/bombax-upload.XXXXXXXX"));
                    if (fileno == -1) {
                        // error
                        continue;
                    }
                    write(fileno, data, dataLen);
                    close(fileno);
                    NSString *tempFilePath = [NSString stringWithCString:tempTemplate encoding:NSUTF8StringEncoding];
                    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:tempFilePath];
                    BxFile *bxFile = [[BxFile alloc] initWithFileName:[[[[NSString alloc] initWithBytes:fileName
                                                                                                 length:fileNameLen
                                                                                               encoding:NSUTF8StringEncoding] autorelease] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                                                             formName:[[[[NSString alloc] initWithBytes:formName
                                                                                                 length:formNameLen
                                                                                               encoding:NSUTF8StringEncoding] autorelease] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                                                             mimeType:[[[[NSString alloc] initWithBytes:fileMimeType
                                                                                                 length:fileMimeTypeLen
                                                                                               encoding:NSUTF8StringEncoding] autorelease] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                                                         tempFilePath:tempFilePath
                                                               handle:handle
                                                               length:dataLen];
                    [_uploadedFiles addObject:bxFile];
                }
                start = end + [boundary length];
                if (result.location == NSNotFound) {
                    break;   
                }
            }
        } else {
            _rawPostData = [[NSMutableData alloc] initWithBytes:buffer
                                                         length:contentLength];
            /*
            NSString *contentLengthStr = [_serverVars objectForKey:@"CONTENT_LENGTH"];
            int contentLength;
            char *buffer;
            NSMutableData *content = nil;
            if (contentLengthStr == nil) {
                buffer = malloc(65536);
                int result;
                while ((result = FCGX_GetStr(buffer, 65536, _request->in)) > 0) {
                    if (_rawPostData != nil) {
                        if (result == 65536) {
                            _rawPostData = [NSMutableData dataWithCapacity:262144];
                        } else {
                            _rawPostData = [NSMutableData dataWithCapacity:result];
                        }
                    }
                    [content appendBytes:buffer length:result];
                }
                if (result < 0) {
                    // error
                }
                if (_rawPostData == nil) {
                    _rawPostData = [NSMutableData data];
                }
                free(buffer);
            } else {
                contentLength = [contentLengthStr integerValue];
                buffer = malloc(contentLength);
                FCGX_GetStr(buffer, contentLength, _request->in); // contentLength = 
                _rawPostData = [[NSMutableData alloc] initWithBytes:buffer
                                                      length:contentLength];
                char *bytes = [_rawPostData bytes];
                for (int i = 0; i < contentLength; i+=8) {
                    NSLog(@"%d %d %d %d  %d %d %d %d", bytes[i], bytes[i+1], bytes[i+2], bytes[i+3], bytes[i+4], bytes[i+5], bytes[i+6], bytes[i+7]);
                }
                NSLog(@"%@", _rawPostData);
            }
             */
        }
        free(buffer);
    }
    
    NSString *cookieStr = [_serverVars objectForKey:@"HTTP_COOKIE"];
    if (cookieStr) {
        NSArray *cookieParts = [cookieStr componentsSeparatedByString:@"; "];
        for (NSString *cookiePart in cookieParts) {
            NSRange range = [cookiePart rangeOfString:@"="];
            if (range.location == NSNotFound) {
                continue;
            } else {
                [_cookies setObject:[[cookiePart substringFromIndex:range.location + 1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]
                                 forKey:[cookiePart substringToIndex:range.location]];
            }
        }
    }    
    
    return self;
}

- (id)_setRequestPath:(NSString *)requestPath {
    _requestPath = requestPath;
    return self;
}

- (FCGX_Request *)_rawRequest {
    return _request;
}

- (id)close {
    _isClosed = YES;
    return self;
}

- (id)setCookie:(NSString *)name
          value:(NSString *)value {
    [_outboundCookies addObject:[NSString stringWithFormat:@"%@=%@",
                                      name,
                                      [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
    return self;
}

- (id)setPersistentCookie:(NSString *)name
                    value:(NSString *)value
                   maxAge:(NSTimeInterval)maxAge {
    [_outboundCookies addObject:[NSString stringWithFormat:@"%@=%@; Max-Age=%d",
                                      name,
                                      [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                                      (int) maxAge]];
    return self;
}

- (id)setPersistentCookie:(NSString *)name
                    value:(NSString *)value
                   maxAge:(NSTimeInterval)maxAge
                     path:(NSString *)path
                   domain:(NSString *)domain {
    [_outboundCookies addObject:[NSString stringWithFormat:@"%@=%@; Max-Age=%d; Path=%@; Domain=%@",
                                      name,
                                      [value stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                                      (int) maxAge,
                                      path,
                                      domain]];
    return self;
}

- (id)setHeader:(NSString *)header
          value:(NSString *)value {
    if ([header isEqualToString:@"Set-Cookie"]) {
        [_outboundCookies addObject:value];
    } else {
        [_outboundHeaders setObject:value forKey:header];
    }
    return self;
}

- (id)setHttpStatusCode:(int)status {
    if (! _isClosed) {
        [self setHeader:@"Status"
                  value:[NSString stringWithFormat:@"%d", status]];
        FCGX_SetExitStatus(status, _request->out);
    }
    return self;
}

- (id)_writeHeaders {
    if (_hasWrittenHeaders && ! _isClosed) {
        return self;
    }
    _hasWrittenHeaders = YES;    
    NSMutableString *hstr = [NSMutableString stringWithCapacity:[_outboundHeaders count] * 32];
    
    for (NSString *key in _outboundHeaders) {
        [hstr appendFormat:@"%@: %@\r\n", key, [_outboundHeaders objectForKey:key]];
    }
    for (NSString *value in _outboundCookies) {
        [hstr appendFormat:@"Set-Cookie: %@\r\n", value];
    }
    [hstr appendString:@"\r\n"];
    [self write:hstr];
    return self;
}

- (id)write:(NSString *)string {
    if (string != nil && ! _isClosed) {
        if (! _hasWrittenHeaders) {
            [self _writeHeaders];
        }
        if (! [string isKindOfClass:[NSString class]]) {
            string = [string description];
        }
        // xxx check for errors
        FCGX_PutS([string UTF8String], _request->out);
    }
    return self;
}

- (id)writeData:(NSData *)data {
    if (data != nil && ! _isClosed) {
        if (! _hasWrittenHeaders) {
            [self _writeHeaders];
        }
        // xxx check for errors
        FCGX_PutStr([data bytes], [data length], _request->out);
    }
    return self;
}

- (id)writeFormat:(NSString *)format, ... {
    if (format == nil || _isClosed) {
        return self;
    }
    va_list args;
    va_start(args, format);
    NSString *str = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
    va_end(args);
    if (! _hasWrittenHeaders) {
        [self _writeHeaders];
    }
    // xxx check for errors
    FCGX_PutS([str UTF8String], _request->out);
    return self;
}

- (id)writeError:(NSString *)string {
    if (string != nil && ! _isClosed) {
        // xxx check for errors
        FCGX_PutS([string UTF8String], _request->err);
    }
    return self;
}

- (id)flush {
    if (! _isClosed) {
        FCGX_FFlush(_request->out);
    }
    return self;
}

- (void)dealloc {
    if (_rawPostData) {
        [_rawPostData release];
    }
    [_outboundHeaders release];
    [_uploadedFiles release];
    [_postVars release];
    [_outboundCookies release];
    [_cookies release];
    [_queryVars release];
    [_serverVars release];
    [_state release];
    [super dealloc];
}

@end
