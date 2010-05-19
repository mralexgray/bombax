#import "Controller.h"
#import <SecurityFoundation/SFAuthorization.h>


static Controller *_singleton = nil;
static NSString *_defaultLogPath = nil;
static NSCharacterSet *_quoteCharacterSet = nil;

@implementation Controller

@synthesize mainWindow = _mainWindow;
@synthesize model = _model;
@synthesize defaultStaticPath = _defaultStaticPath;
@synthesize defaultCgiPath = _defaultCgiPath;
@synthesize defaultBxAppPath = _defaultBxAppPath;
@synthesize defaultSslPath = _defaultSslPath;
@synthesize nginxBinPath = _nginxBinPath;
@synthesize supportPath = _supportPath;
@synthesize nginxConfPath = _nginxConfPath;
@synthesize bombaxConfPath = _bombaxConfPath;
@synthesize processInfos = _processInfos;

+ (Controller *)singleton {
    if (_singleton == nil) {
        _singleton = [[Controller alloc] init];
    }
    return _singleton;
}

- (id)init {
    [super init];
    
    _authRef = NULL;
    
    if (_quoteCharacterSet == nil) {
        _quoteCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"\"'"] retain];
    }
    
    // tbd set Urls
    _defaultStaticPath = [NSHomeDirectory() retain];
    _defaultCgiPath = [NSHomeDirectory() retain];
    _defaultBxAppPath = [NSHomeDirectory() retain];
    _defaultSslPath = [NSHomeDirectory() retain];

    _nginxBinPath = [[[NSBundle mainBundle] pathForResource:@"bombax-nginx" ofType:nil] retain];
    _supportPath = [[[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Bombax/"] retain];
    _nginxConfPath = [[_supportPath stringByAppendingPathComponent:@"bombax-nginx.conf"] retain];
    _bombaxConfPath = [[_supportPath stringByAppendingPathComponent:@"bombax.conf"] retain];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (! [fileManager fileExistsAtPath:_supportPath]) {
        [fileManager createDirectoryAtPath:_supportPath
                                attributes:nil];
        [fileManager createDirectoryAtPath:[_supportPath stringByAppendingPathComponent:@"logs"]
                                attributes:nil];
        [fileManager createDirectoryAtPath:[_supportPath stringByAppendingPathComponent:@"html"]
                                attributes:nil];
    }
    if ([fileManager fileExistsAtPath:_bombaxConfPath]) {
        NSError *error = nil;
        NSXMLDocument *doc = [[NSXMLDocument alloc] initWithContentsOfURL:[NSURL fileURLWithPath:_bombaxConfPath]
                                                                  options:NSXMLNodeOptionsNone
                                                                    error:&error];
        if (error) {
            NSLog(@"%@", [error localizedDescription]);
            _model = [[Model alloc] init];
            [_model.servers addObject:[[Server alloc] init]];
        } else {
            _model = [ModelReader readModel:doc];
            [doc release];
        }
    } else {
        _model = [[Model alloc] init];
        [_model.servers addObject:[[Server alloc] init]];
    }
    _nginxStderrPath = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"bombax-nginx-stderr.txt"] retain];
    
    [self writeNginxConf:[self createNginxConfString]];
    _processInfos = [[NSMutableArray alloc] initWithCapacity:32];
    [self updateProcessInfos];

    return self;
}

+ (NSString *)defaultLogPath {
    if (_defaultLogPath == nil) {
        _defaultLogPath = [[[[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"Bombax"] stringByAppendingPathComponent:@"logs/global.log"] retain];
    }
    return _defaultLogPath;
}

- (NSTimeInterval)convertEtimeString:(NSString *)str {
    NSTimeInterval delta = 0;
    int len = [str length];
    if (len >= 10) {
        delta += [[str substringToIndex:[str length] - 9] intValue] * 60 * 60 * 24;
    }
    if (len >= 7) {
        delta += [[str substringWithRange:NSMakeRange(len - 8, 2)] integerValue] * 60 * 60;        
    }
    if (len >= 4) {
        delta += [[str substringWithRange:NSMakeRange(len - 5, 2)] integerValue] * 60;
    }
    if (len >= 1) {
        delta += [[str substringFromIndex:len - 2] integerValue];
    }
    return delta;
}

- (id)updateProcessInfos {
    NSTask *psTask = [[NSTask alloc] init];
    [psTask setLaunchPath:@"/bin/ps"];
    [psTask setArguments:[NSArray arrayWithObjects:@"-Ao", @"pid %cpu %mem etime command", nil]];
    NSPipe *pipe = [NSPipe pipe];
    [psTask setStandardOutput:pipe];
    NSFileHandle *psFile = [pipe fileHandleForReading];
    [psTask launch];
    NSString *psStr = [[NSString alloc] initWithData:[psFile readDataToEndOfFile]
                                            encoding:NSUTF8StringEncoding];
    NSArray *lines = [psStr componentsSeparatedByString:@"\n"];
    [_processInfos removeAllObjects];
    double cpu = 0;
    double ram = 0;
    BOOL isRunning = NO;
    NSTimeInterval runningTime = 0;
    NSMutableDictionary *expectedCommands = [NSMutableDictionary dictionaryWithCapacity:8];
    NSMutableDictionary *commandLocations = [NSMutableDictionary dictionaryWithCapacity:8];
    for (Server *server in _model.servers) {
        for (Location *location in server.locations) {
            if (location.locationType == BX_LOCATION_BXAPP) {
                for (NSString *command in location.runningCommands) {
                    NSString *searchCommand = [command stringByReplacingOccurrencesOfString:@"\""
                                                                                 withString:@""];
                    [expectedCommands setObject:command
                                         forKey:searchCommand];
                    location.cpuUsage = 0;
                    location.memoryUsage = 0;
                    [commandLocations setObject:location
                                         forKey:searchCommand];
                }
            }
        }
    }
    
    for (int i = 1; i < [lines count] - 1; i++) {
        NSMutableString *line = [[[lines objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] mutableCopy];
        while ([line replaceOccurrencesOfString:@"  "
                                     withString:@" "
                                        options:0
                                          range:NSMakeRange(0, [line length])] > 0);
        NSArray *parts = [line componentsSeparatedByString:@" "];
        [line release];
        NSString *command = [[parts subarrayWithRange:NSMakeRange(4, [parts count] - 4)] componentsJoinedByString:@" "];
        if (([command rangeOfString:@"bombax-nginx"].location != NSNotFound && ![command hasSuffix:@"(bombax-nginx)"]) || [command hasPrefix:@"nginx: "]) {
            ProcessInfo *info = [[ProcessInfo alloc] initWithPid:[[parts objectAtIndex:0] integerValue]
                                                             cpu:[[parts objectAtIndex:1] doubleValue]
                                                             ram:[[parts objectAtIndex:2] doubleValue]
                                                    runningSince:[self convertEtimeString:[parts objectAtIndex:3]] 
                                                         command:command
                                                            type:BX_PROCESS_NGINX];
            [_processInfos addObject:info];
            //[info release];
            cpu += info.cpu;
            ram += info.ram;
            if (info.runningSince > runningTime) {
                runningTime = info.runningSince;
            }
            isRunning = YES;
        } else if ([command rangeOfString:@"bombax-bxapp"].location != NSNotFound) {
            [expectedCommands removeObjectForKey:command];
            double cpuL = [[parts objectAtIndex:1] doubleValue];
            double memoryL = [[parts objectAtIndex:2] doubleValue];
            
            ProcessInfo *info = [[ProcessInfo alloc] initWithPid:[[parts objectAtIndex:0] integerValue]
                                                             cpu:cpuL
                                                             ram:memoryL
                                                    runningSince:[self convertEtimeString:[parts objectAtIndex:3]] 
                                                         command:command
                                                            type:BX_PROCESS_BXAPP];
            Location *location = [commandLocations objectForKey:command];
            if (location) {
                location.cpuUsage = location.cpuUsage + cpuL;
                location.memoryUsage = location.memoryUsage + memoryL;
            }
            [_processInfos addObject:info];
            //[info release];
            cpu += info.cpu;
            ram += info.ram;
        }
    }
    
    for (NSString *foundCommand in expectedCommands) {     
        Location *location = [commandLocations objectForKey:foundCommand];
        if (location && location.watchdogEnabled) {
            system([[[expectedCommands objectForKey:foundCommand] stringByAppendingString:@" &"] UTF8String]);
        }
    }
    NSUInteger cInt = (NSUInteger) (100 * cpu);
    NSUInteger rInt = (NSUInteger) (100 * ram);
    [_model addPoint:[NSNumber numberWithUnsignedInteger:(cInt << 16) | rInt]];
    _model.cpuUsage = cpu;
    _model.ramUsage = ram;
    _model.isRunning = isRunning;
    _model.runningSince = [NSDate timeIntervalSinceReferenceDate] - runningTime;
    [psStr release];
    [psTask release];
    return self;
}

- (BOOL)initAuth {
    if (_authRef == NULL) {
        OSStatus status = AuthorizationCreate(NULL,
                                              kAuthorizationEmptyEnvironment,
                                              kAuthorizationFlagDefaults,
                                              &_authRef);
        if (status != errAuthorizationSuccess) {
            return NO;
        }
    }
    return YES;
}

- (NSString *)startBombax:(BOOL)affectBxApps {
    [self writeNginxConf:[self createNginxConfString]];
    if (! [self initAuth]) {
        return NSLocalizedString(@"Could not authorize user.", nil);
    } else {
        if (affectBxApps) {
            NSMutableDictionary *sockDict = [NSMutableDictionary dictionaryWithCapacity:8];
            for (Server *server in _model.servers) {
                for (Location *location in server.locations) {
                    if (location.locationType == BX_LOCATION_BXAPP) {
                        [location.runningCommands removeAllObjects];
                        for (int i = 0; i < location.processes; i++) {
                            NSString *hash = [NSString stringWithFormat:@"%@/%d.sock", _supportPath, [location.path hash]];
                            NSNumber *num = [sockDict objectForKey:hash];
                            if (num) {
                                num = [NSNumber numberWithInt:[num integerValue] + 1];
                            } else {
                                num = [NSNumber numberWithInt:0];
                            }
                            [sockDict setObject:num forKey:hash];
                            // tbd do this better...
                            int result;
                            NSString *execPath = location.path;
                            NSString *socket = [hash stringByAppendingFormat:@"-%d", [num integerValue]];
                            if ([location.path hasSuffix:@".app"]) {
                                execPath = [location.path stringByAppendingFormat:@"/Contents/MacOS/%@", [[location.path lastPathComponent] stringByDeletingPathExtension]];
                            }
                            NSString *command;
                            if (location.patternStyle == BX_PATTERN_START && [location.pattern length] > 0) {
                                command = [NSString stringWithFormat:@"\"/%@\" -socket \"%@\" -threads %d -root \"%@\" -bombax-bxapp 1 &",
                                           execPath,
                                           socket,
                                           location.threads,
                                           ([location.pattern hasSuffix:@"/"] ? location.pattern : [@"/" stringByAppendingString:location.pattern])];                                
                            } else {
                                command = [NSString stringWithFormat:@"\"/%@\" -socket \"%@\" -threads %d -bombax-bxapp 1 &",
                                           execPath,
                                           socket,
                                           location.threads];
                            }
                            result = system([command UTF8String]);
                            [location.runningCommands addObject:[command substringToIndex:[command length] - 2]];
                        }
                    }
                }
            }
        }
        
        char *args[3];
        args[0] = "-c";
        args[1] = (char *) [[NSString stringWithFormat:@"\"%@\" -c \"%@\" -p \"%@\" 2> \"%@\"",
                             _nginxBinPath,
                             _nginxConfPath,
                             _supportPath,
                             _nginxStderrPath] UTF8String];
        args[2] = NULL;
        AuthorizationExecuteWithPrivileges(_authRef,
                                           "/bin/sh",
                                           kAuthorizationFlagDefaults,
                                           args,
                                           NULL);
        NSString *error = [NSString stringWithContentsOfFile:_nginxStderrPath
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
        if (error &&
            [error length] > 0 &&
            ! [error hasPrefix:@"[alert]: kill"] &&
            ! [error hasPrefix:@"[error]: open"]) {
            return error;
        }
    }
    [self updateProcessInfos];
    return nil;
}

- (NSString *)reloadBombax:(BOOL)affectBxApps {
    [self writeNginxConf:[self createNginxConfString]];
    if (! [self initAuth]) {
        return NSLocalizedString(@"Could not authorize user.", nil);
    } else {        
        char *args[3];
        args[0] = "-c";
        args[1] = (char *) [[NSString stringWithFormat:@"\"%@\" -c \"%@\" -s reload -p \"%@\" 2> \"%@\"",
                             _nginxBinPath,
                             _nginxConfPath,
                             _supportPath,
                             _nginxStderrPath] UTF8String];
        args[2] = NULL;
        // tbd if status         return NSLocalizedString(@"Could not authorize user.", nil);
        AuthorizationExecuteWithPrivileges(_authRef,
                                           "/bin/sh",
                                           kAuthorizationFlagDefaults,
                                           args,
                                           NULL);
        if (affectBxApps) {
            for (ProcessInfo *info in _processInfos) {
                if (info.type == BX_PROCESS_BXAPP) {
                    system([[NSString stringWithFormat:@"/bin/kill -2 %d", info.pid] UTF8String]);
                }
            }
            // xxx pause??
            NSMutableDictionary *sockDict = [NSMutableDictionary dictionaryWithCapacity:8];
            for (Server *server in _model.servers) {
                for (Location *location in server.locations) {
                    if (location.locationType == BX_LOCATION_BXAPP) {
                        [location.runningCommands removeAllObjects];
                        for (int i = 0; i < location.processes; i++) {
                            NSString *hash = [NSString stringWithFormat:@"%@/%d.sock", _supportPath, [location.path hash]];
                            NSNumber *num = [sockDict objectForKey:hash];
                            if (num) {
                                num = [NSNumber numberWithInt:[num integerValue] + 1];
                            } else {
                                num = [NSNumber numberWithInt:0];
                            }
                            [sockDict setObject:num forKey:hash];
                            // tbd do this better...
                            int result;
                            NSString *execPath = location.path;
                            NSString *socket = [hash stringByAppendingFormat:@"-%d", [num integerValue]];
                            if ([location.path hasSuffix:@".app"]) {
                                execPath = [location.path stringByAppendingFormat:@"/Contents/MacOS/%@", [[location.path lastPathComponent] stringByDeletingPathExtension]];
                            }
                            NSString *command;
                            if (location.patternStyle == BX_PATTERN_START && [location.pattern length] > 0) {
                                command = [NSString stringWithFormat:@"\"/%@\" -socket \"%@\" -threads %d -root \"%@\" -bombax-bxapp 1 &",
                                           execPath,
                                           socket,
                                           location.threads,
                                           ([location.pattern hasSuffix:@"/"] ? location.pattern : [@"/" stringByAppendingString:location.pattern])];                                
                            } else {
                                command = [NSString stringWithFormat:@"\"/%@\" -socket \"%@\" -threads %d -bombax-bxapp 1 &",
                                           execPath,
                                           socket,
                                           location.threads];
                            }
                            result = system([command UTF8String]);
                            [location.runningCommands addObject:[command substringToIndex:[command length] - 2]];
                        }
                    }
                }
            }
        }                
        NSString *error = [NSString stringWithContentsOfFile:_nginxStderrPath
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];
        if (error && [error length] > 0) {
            return error;
        }
    }
    [self updateProcessInfos];
    return nil;
}

- (id)stopBombax:(BOOL)affectBxApps {
    if (! [self initAuth]) {
        return NSLocalizedString(@"Could not authorize user.", nil);
    } else {
        char *args[3];
        args[0] = "-c";
        args[1] = (char *) [[NSString stringWithFormat:@"\"%@\" -c \"%@\" -s stop -p \"%@\" 2> \"%@\"",
                             _nginxBinPath,
                             _nginxConfPath,
                             _supportPath,
                             _nginxStderrPath] UTF8String];
        args[2] = NULL;
        AuthorizationExecuteWithPrivileges(_authRef,
                                           "/bin/sh",
                                           kAuthorizationFlagDefaults,
                                           args,
                                           NULL);
        if (affectBxApps) {
            for (ProcessInfo *info in _processInfos) {
                args[0] = "-9";
                args[1] = (char *) [[NSString stringWithFormat:@"%d", info.pid] UTF8String];
                AuthorizationExecuteWithPrivileges(_authRef,
                                                   "/bin/kill",
                                                   kAuthorizationFlagDefaults,
                                                   args,
                                                   NULL);                    
            }
            for (Server *server in _model.servers) {
                for (Location *location in server.locations) {
                    [location.runningCommands removeAllObjects];
                }
            }
        }
        
        NSString *error = [NSString stringWithContentsOfFile:_nginxStderrPath
                                                    encoding:NSUTF8StringEncoding
                                                       error:nil];        
        if (error && [error length] > 0) {
            //return error;
        }
    }
    [self updateProcessInfos];
    return nil;
}

- (NSString *)createNginxConfString {
    NSMutableString *conf = [NSMutableString stringWithCapacity:2048];
    NSString *runningUser = NSUserName();
    NSString *runningGroup = @"staff";
    int workerProcesses = 4;
    NSString *defaultLog = [_supportPath stringByAppendingPathComponent:@"logs/bombax.log"];
    NSString *pidPath = [_supportPath stringByAppendingPathComponent:@"bombax-nginx.pid"];
    int workerConnections = 1024;
    NSString *mimeInclude = [[NSBundle mainBundle] pathForResource:@"mime.types" ofType:nil];
    NSString *fcgiInclude = [[NSBundle mainBundle] pathForResource:@"fastcgi_params" ofType:nil];
    NSString *defaultType = @"application/octet-stream";
    int keepAliveTimeout = 5;
    NSString *charset = @"utf-8";
    NSString *defaultIndex = @"index.html index.htm";
    NSString *debugSocket = [NSTemporaryDirectory() stringByAppendingPathComponent:@"bombax-debug.sock"];
    
    [conf appendFormat:@"user %@ %@;\n", runningUser, runningGroup];
    [conf appendFormat:@"worker_processes %d;\n", workerProcesses];
    [conf appendFormat:@"error_log \"%@\";\n", defaultLog];
    [conf appendFormat:@"pid \"%@\";\n", pidPath];
    [conf appendFormat:@"events {\n worker_connections %d;\n}\n", workerConnections];
    [conf appendString:@"http {\n"];
    [conf appendFormat:@" include \"%@\";\n", mimeInclude];
    [conf appendFormat:@" default_type %@;\n", defaultType];
    [conf appendFormat:@" access_log \"%@\";\n", defaultLog];
    [conf appendFormat:@" error_log \"%@\";\n", defaultLog];
    [conf appendFormat:@" sendfile on;\n keepalive_timeout %d;\n", keepAliveTimeout];
    NSMutableDictionary *sockDict = [NSMutableDictionary dictionaryWithCapacity:0];
    int sIndex = 0;
    for (Server *server in _model.servers) {
        for (Location *location in server.locations) {
            if (location.locationType == BX_LOCATION_BXAPP) {
                if (location.processes > 1) {
                    [conf appendFormat:@" upstream backend%d {\n", sIndex];
                    NSString *hash = [NSString stringWithFormat:@"%@/%d.sock", _supportPath, [location.path hash]];
                    if (location.loadBalancing == BX_LOAD_HASHIP) {
                        [conf appendString:@"  ip_hash;\n"];
                    }
                    for (int i = 0; i < location.processes; i++) {
                        NSNumber *num = [sockDict objectForKey:hash];
                        if (num) {
                            num = [NSNumber numberWithInt:[num integerValue] + 1];
                        } else {
                            num = [NSNumber numberWithInt:0];
                        }
                        [sockDict setObject:num forKey:hash];
                        [conf appendFormat:@"  server \"unix:%@-%d\";\n", hash, [num integerValue]];
                    }
                    [conf appendString:@" }\n"];
                    sIndex++;
                } else {
                    NSString *hash = [NSString stringWithFormat:@"%@/%d.sock", _supportPath, [location.path hash]];
                    NSNumber *num = [sockDict objectForKey:hash];
                    if (num) {
                        num = [NSNumber numberWithInt:[num integerValue] + 1];
                    } else {
                        num = [NSNumber numberWithInt:0];
                    }
                    [sockDict setObject:num forKey:hash];
                }
            }
        }
    }
    [sockDict removeAllObjects];
    sIndex = 0;
    for (Server *server in _model.servers) {
        [conf appendString:@" server {\n"];
        if (server.sslEnabled) {
            [conf appendString:@"  ssl on;\n"];
            [conf appendFormat:@"  ssl_certificate \"%@\";\n", server.sslCertificatePath];
            [conf appendFormat:@"  ssl_certificate_key \"%@\";\n", server.sslCertificateKeyPath];
        }
        if ([server.ipAddresses count] > 0) {
            for (NSString *ipAddress in server.ipAddresses) {
                if ([server.ports count] > 0) {
                    for (NSString *port in server.ports) {
                        if ([ipAddress rangeOfString:@":"].location != NSNotFound) {
                            [conf appendFormat:@"  listen [%@]:%@;\n", ipAddress, port];
                        } else {
                            [conf appendFormat:@"  listen %@:%@;\n", ipAddress, port];
                        }
                    }
                } else {
                    if ([ipAddress rangeOfString:@":"].location != NSNotFound) {
                        [conf appendFormat:@"  listen [%@];\n", ipAddress];
                    } else {
                        [conf appendFormat:@"  listen %@;\n", ipAddress];
                    }
                }
            }
        } else {
            if ([server.ports count] > 0) {
                for (NSString *port in server.ports) {
                    [conf appendFormat:@"  listen %@;\n", port];
                }
            } else {
                [conf appendString:@"  listen 80;\n"];
            }
        }
        if ([server.hostnames count] > 0) {
            [conf appendString:@"  server_name"];
            BOOL found = NO;
            for (NSString *hostname in server.hostnames) {
                if ([hostname length] > 0) {
                    [conf appendFormat:@" %@", hostname];
                    found = YES;
                }
            }
            if (found == NO) {
                [conf appendString:@" _"];
            }
            [conf appendString:@";\n"];
        } else {
            [conf appendString:@"  server_name _;\n"];
        }
        [conf appendFormat:@"  access_log \"%@\";\n", server.logPath];
        [conf appendFormat:@"  error_log \"%@\";\n", server.logPath];
        [conf appendFormat:@"  charset %@;\n", charset];
        for (Location *location in server.locations) {
            if (location.locationType == BX_LOCATION_BXAPP && location.processes == 0) {
                continue;
            }
            if ([location.path length] == 0) {
                [conf appendString:@"  location / {\n"];
//            } else if (location.patternStyle == BX_PATTERN_EXACT) {
//                [conf appendFormat:@"  location = \"/%@\" {\n", location.pattern];
            } else if (location.patternStyle == BX_PATTERN_END) {
                [conf appendFormat:@"  location \"%@$\" {\n", location.pattern];
            } else {
                [conf appendFormat:@"  location \"/%@\" {\n", location.pattern];
            }
            if (location.locationType == BX_LOCATION_BXAPP) {
                NSString *hash = [NSString stringWithFormat:@"%@/%d.sock", _supportPath, [location.path hash]];
                NSNumber *num = [sockDict objectForKey:hash];
                if (location.processes > 1) {
                    [conf appendFormat:@"   fastcgi_pass backend%@;\n", sIndex];
                    sIndex++;
                    if (num) {
                        num = [NSNumber numberWithInt:[num integerValue] + location.processes];
                    } else {
                        num = [NSNumber numberWithInt:location.processes - 1];
                    }
                } else {
                    [conf appendFormat:@"   fastcgi_pass \"unix:%@-%d\";\n", hash, [num integerValue]];
                    if (num) {
                        num = [NSNumber numberWithInt:[num integerValue] + 1];
                    } else {
                        num = [NSNumber numberWithInt:0];
                    }
                }
                [sockDict setObject:num forKey:hash];
                [conf appendFormat:@"   include \"%@\";\n", fcgiInclude];
                if (num && [num integerValue] == 0) {
                    [sockDict removeObjectForKey:hash];
                } else {
                    num = [NSNumber numberWithInt:[num integerValue] - 1];
                    [sockDict setObject:num forKey:hash];
                }
            } else if (location.locationType == BX_LOCATION_FASTCGI) {
                [conf appendFormat:@"   fastcgi_pass \"%@\";\n", location.path];
                [conf appendFormat:@"   include \"%@\";\n", fcgiInclude];
                [conf appendString:@"   fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;\n"];
            } else {
                [conf appendFormat:@"   alias \"%@\";\n", location.path];
                [conf appendFormat:@"   index %@;\n", defaultIndex];
            }
            [conf appendString:@"  }\n"];
            if (location.locationType == BX_LOCATION_BXAPP &&
                location.patternStyle == BX_PATTERN_START) {
                NSString *infoPath = [location.path stringByAppendingPathComponent:@"Contents/Info.plist"];
                NSDictionary *info;
                if ([[NSFileManager defaultManager] fileExistsAtPath:infoPath] &&
                    (info = [NSDictionary dictionaryWithContentsOfFile:infoPath]) != nil) {
                    NSString *webPath = [info objectForKey:@"BxApp Static Web Path"];
                    if (webPath == nil) {
                        webPath = @"static";
                    }
                    [conf appendFormat:@"  location \"/%@/%@/\" {\n", location.pattern, webPath];
                    NSString *resourcePath = [info objectForKey:@"BxApp Static Resource Path"];
                    if (resourcePath == nil) {
                        resourcePath = @"static";
                    }
                    [conf appendFormat:@"   alias \"%@/Contents/Resources/%@/\";\n", location.path, resourcePath];
                    [conf appendString:@"  }\n"]; // server
                }
            }
        }
        [conf appendString:@" }\n"]; // server
    }
    if (_model.isDebugEnabled) {
        [conf appendString:@" server {\n"];
        [conf appendFormat:@"  listen 127.0.0.1:%d;\n", _model.debugPort];
        [conf appendString:@"  location / {\n"];
        [conf appendFormat:@"   fastcgi_pass \"unix:%@\";\n", debugSocket];
        [conf appendFormat:@"   include \"%@\";\n", fcgiInclude];
        [conf appendString:@"  }\n }\n"];
        
    }
    [conf appendString:@"}\n"]; // http

    return conf;
}

- (id)writeNginxConf:(NSString *)conf {
    [[self createNginxConfString] writeToFile:_nginxConfPath
                                   atomically:YES
                                     encoding:NSUTF8StringEncoding
                                        error:nil];
     return self;
}

- (id)saveConfig {
    return [self saveConfigTo:_bombaxConfPath];
}

- (id)saveConfigTo:(NSString *)path {
    NSXMLDocument *doc = [ModelWriter writeModel:_model];
    if (doc == nil || ![[doc XMLData] writeToFile:path
                                       atomically:YES]) {
        // xxx error
    }
    return self;
}


- (void)awakeFromNib {
    [_mainWindow updateFromModel];
}

@end
