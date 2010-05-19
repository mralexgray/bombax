#import "BxMailer.h"
#import <Bombaxtic/BxMailerAttachment.h>
#import <Bombaxtic/BxUtil.h>

static BxMailer *_systemMailer = nil;

@implementation BxMailer

- (NSString *)_randomTempPath {
    return [NSString stringWithFormat:@"%@/%f%ld",
            NSTemporaryDirectory(),
            [NSDate timeIntervalSinceReferenceDate],
            random()];
}

- (id)init {
    [super init];
    _isSMTP = NO;
    _useSSL = NO;
    _port = 25;
    _server = nil;
    _user = nil;
    _password = nil;
    return self;
}

- (id)initSystemMailer {
    [self init];
    _isSMTP = NO;
    return self;
}

- (id)initSMTPServer:(NSString *)server
                user:(NSString *)user
            password:(NSString *)password {
    [self init];
    _isSMTP = YES;
    _server = [server copy];
    _user = [user copy];
    _password = [password copy];
    return self;    
}

- (id)initSMTPServer:(NSString *)server
                user:(NSString *)user
            password:(NSString *)password
                port:(int)port
              useSSL:(BOOL)useSSL {
    [self init];
    _isSMTP = YES;
    _server = [server copy];
    _user = [user copy];
    _password = [password copy];
    _port = port;
    _useSSL = useSSL;
    return self;
}

+ (BxMailer *)systemMailer {
    if (_systemMailer == nil) {
        _systemMailer = [[BxMailer alloc] initSystemMailer];
    }
    return _systemMailer;
}


- (id)sendMessage:(NSString *)message
          subject:(NSString *)subject
               to:(NSString *)to {
    if (_isSMTP) {
        
    } else {
        NSString *path = [self _randomTempPath];
        message = [NSString stringWithFormat:@"To: %@\nSubject: %@\n\n%@\n.\n",
                   to,
                   subject,
                   message];
        [message writeToFile:path
                  atomically:NO
                    encoding:NSUTF8StringEncoding
                       error:nil];
        NSString *command = [NSString stringWithFormat:@"cat %@ | sendmail -t", path];
        system([command UTF8String]);
        [[NSFileManager defaultManager] removeItemAtPath:path
                                                   error:nil];
    }
    return self;
}

- (id)sendMessage:(NSString *)message
          subject:(NSString *)subject
               to:(NSString *)to
             from:(NSString *)from
          headers:(NSDictionary *)headers {
    if (_isSMTP) {
        
    } else {
        NSString *path = [self _randomTempPath];
        NSMutableString *headerBuffer;
        if (headers == nil) {
            headerBuffer = [NSMutableString stringWithCapacity:0];
        } else {
            headerBuffer = [NSMutableString stringWithCapacity:[headers count] * 10];            
            for (NSString *key in headers) {
                [headerBuffer appendFormat:@"%@: %@\n", key, [headers objectForKey:key]];
            }
        }
        message = [NSString stringWithFormat:@"To: %@\nFrom: %@\nSubject: %@\n%@\n%@\n.\n",
                   to,
                   from,
                   subject,
                   headerBuffer,
                   message];
        [message writeToFile:path
                  atomically:NO
                    encoding:NSUTF8StringEncoding
                       error:nil];
        NSString *command = [NSString stringWithFormat:@"cat %@ | sendmail -t", path];
        system([command UTF8String]);
        [[NSFileManager defaultManager] removeItemAtPath:path
                                                   error:nil];
    }
    return self;
}

- (id)sendMessage:(NSString *)message
          subject:(NSString *)subject
               to:(NSString *)to
             from:(NSString *)from
          headers:(NSDictionary *)headers
      attachments:(BxMailerAttachment *)attachments, ... {
    if (_isSMTP) {
        
    } else {
        NSMutableString *headerBuffer;
        if (headers == nil) {
            headerBuffer = [NSMutableString stringWithCapacity:0];
        } else {
            headerBuffer = [NSMutableString stringWithCapacity:[headers count] * 10];            
            for (NSString *key in headers) {
                [headerBuffer appendFormat:@"%@: %@\r\n", key, [headers objectForKey:key]];
            }
        }
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSMutableArray *uuPaths = [NSMutableArray arrayWithCapacity:8];
        
        NSMutableString *messageBuffer = [NSMutableString stringWithCapacity:1024];
        NSString *boundary = [BxUtil randomAlphaNumericString:24];
        char *cMsg = [message UTF8String];
        int openAngles = 0;
        int closeAngles = 0;
        int cMsgLen = strlen(cMsg);
        for (int i = 0; i < cMsgLen; i++) {
            if (cMsg[i] == '<') {
                openAngles++;
            } else if (cMsg[i] == '>') {
                closeAngles++;
            }
        }
        NSString *messageMime;
        if (openAngles > 0 && closeAngles >= openAngles) {
            messageMime = @"Content-Type: text/html\r\nContent-Transfer-Encoding: 7bit";
        } else {
            messageMime = @"Content-Type: text/plain\r\nContent-Transfer-Encoding: 7bit";            
        }
        [messageBuffer appendFormat:@"To: %@\r\nFrom: %@\r\nContent-Type: multipart/mixed; boundary=\"%@\"\r\nSubject: %@\r\n%@\r\n\r\n--%@\n%@\n\n%@\n",
         to,
         from,
         boundary,
         subject,
         headerBuffer,
         boundary,
         messageMime,
         message];

        va_list args;
        va_start(args, attachments);
        BxMailerAttachment *attachment = attachments;
        while (attachment != nil &&
               attachment != NULL &&
               [attachment isKindOfClass:[BxMailerAttachment class]]) {
            [messageBuffer appendFormat:@"--%@\r\nContent-Type: %@; name=\"%@\"\r\nContent-Transfer-Encoding: base64\r\nContent-Disposition: attachment\r\n\r\n%@\n",
                boundary,
                attachment.mimeType,
                attachment.name,
                [[[NSString alloc] initWithData:[BxUtil base64EncodeData:attachment.data]
                                       encoding:NSUTF8StringEncoding] autorelease]];
            attachment = va_arg(args, BxMailerAttachment *);
        }
        va_end(args);
        
        [messageBuffer appendFormat:@"--%@\r\n\r\n", boundary];
        
        NSString *path = [self _randomTempPath];
        [messageBuffer writeToFile:path
                        atomically:NO
                          encoding:NSUTF8StringEncoding
                             error:nil];         
        NSString *command = [NSString stringWithFormat:@"cat %@ | sendmail -t", path];
        system([command UTF8String]);
        [fileManager removeItemAtPath:path
                                error:nil];        
        for (NSString *uuPath in uuPaths) {
            [fileManager removeItemAtPath:uuPath
                                    error:nil];        
        }
    }
    return self;
}

- (void)dealloc {
    if (_server != nil) {
        [_server release];
    }
    if (_user != nil) {
        [_user release];
    }
    if (_password != nil) {
        [_password release];
    }
    [super dealloc];
}

@end
