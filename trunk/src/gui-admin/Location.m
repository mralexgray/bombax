#import "Location.h"

@implementation Location

@synthesize pattern = _pattern;
@synthesize locationType = _locationType;
@synthesize patternStyle = _patternStyle;
@synthesize path = _path;
@synthesize information = _information;
@synthesize loadBalancing = _loadBalacing;
@synthesize appName = _appName;
@synthesize appVersion = _appVersion;
@synthesize appAuthor = _appAuthor;
@synthesize appAuthorUrl = _appAuthorUrl;
@synthesize appDescription = _appDescription;
@synthesize appBombaxticVersion = _appBombaxticVersion;
@synthesize processes = _processes;
@synthesize threads = _threads;
@synthesize runningCommands = _runningCommands;
@synthesize watchdogEnabled = _watchdogEnabled;
@synthesize appIcon = _appIcon;
@synthesize notes = _notes;
@synthesize server = _server;
@synthesize cpuUsage = _cpuUsage;
@synthesize memoryUsage = _memoryUsage;

static NSImage *_bxAppImage = nil;


- (id)init {
    if (_bxAppImage == nil) {
        _bxAppImage = [[NSImage imageNamed:@"bwlogo-128"] retain];
    }
    self.notes = @"";
    self.pattern = @"";
    _locationType = BX_LOCATION_STATIC;
    _patternStyle = BX_PATTERN_START;
    self.path = @"";
    self.information = @"";
    _loadBalacing = BX_LOAD_ROUNDROBIN;
    self.appName = @"";
    self.appVersion = @"";
    self.appBombaxticVersion = @"";
    self.appAuthor = @"";
    self.appAuthorUrl = @"";
    self.appDescription = @"";
    _appIcon = [_bxAppImage retain];
    _processes = 1;
    _threads = 4;
    _cpuUsage = 0;
    _memoryUsage = 0;
    _runningCommands = [[NSMutableArray alloc] initWithCapacity:1];
    _watchdogEnabled = YES;
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    Location *copy = [[Location alloc] init];
    copy.pattern = _pattern;
    copy.locationType = _locationType;
    copy.patternStyle = _patternStyle;
    copy.path = _path;
    copy.information = _information;
    copy.loadBalancing = _loadBalacing;
    copy.appName = _appName;
    copy.appVersion = _appVersion;
    copy.appBombaxticVersion = _appBombaxticVersion;
    copy.appAuthor = _appAuthor;
    copy.appAuthorUrl = _appAuthorUrl;
    copy.appDescription = _appDescription;
    copy.processes = _processes;
    copy.threads = _threads;
    copy.appIcon = _appIcon;
    copy.notes = _notes;
    copy.watchdogEnabled = _watchdogEnabled;
    copy.server = _server;
    copy.cpuUsage = _cpuUsage;
    copy.memoryUsage = _memoryUsage;
    for (NSString *command in _runningCommands) {
        [copy.runningCommands addObject:command];
    }
    return copy;
}

- (id)updateAppInfo {
    if (_locationType == BX_LOCATION_BXAPP) {
        NSString *infoPath = [_path stringByAppendingPathComponent:@"Contents/Info.plist"];
        NSDictionary *infoDict;
        if ([[NSFileManager defaultManager] fileExistsAtPath:infoPath] &&
            (infoDict = [NSDictionary dictionaryWithContentsOfFile:infoPath]) != nil) {
            self.appName = [infoDict objectForKey:@"BxApp Name"];
            self.appVersion = [infoDict objectForKey:@"CFBundleVersion"];
            self.appAuthor = [infoDict objectForKey:@"BxApp Author"];
            self.appAuthorUrl = [infoDict objectForKey:@"BxApp Author URL"];
            self.appDescription = [infoDict objectForKey:@"BxApp Description"];
            self.appBombaxticVersion = [infoDict objectForKey:@"BxApp Bombaxtic Version"];
            if (self.appName == nil) {
                self.appName = @"n/a";
            }
            if (self.appVersion == nil) {
                self.appVersion = @"n/a";
            }
            if (self.appAuthor == nil) {
                self.appAuthor = @"n/a";
            }
            if (self.appAuthorUrl == nil) {
                self.appAuthorUrl = @"n/a";
            }
            if (self.appDescription == nil) {
                self.appDescription = @"n/a";
            }
            if (self.appBombaxticVersion == nil) {
                self.appBombaxticVersion = @"n/a";
            }
            NSString *iconFile = [infoDict objectForKey:@"CFBundleIconFile"];
            if (iconFile != nil) {
                self.appIcon = [[[NSImage alloc] initWithContentsOfFile:[_path stringByAppendingFormat:@"/Contents/Resources/%@.icns", iconFile]] autorelease];
                if (self.appIcon == nil) {
                    self.appIcon = _bxAppImage;
                }
            } else {
                self.appIcon = _bxAppImage;
            }
        } else {
            self.appName = @"n/a";
            self.appVersion = @"n/a";
            self.appAuthor = @"n/a";
            self.appAuthorUrl = @"n/a";
            self.appDescription = @"n/a";
            self.appBombaxticVersion = @"n/a";
            self.appIcon = _bxAppImage;
        }
    }
    return self;
}

+ (NSString *)patternStyleString:(BX_pattern_type)patternStyle {
    if (patternStyle == BX_PATTERN_END) {
        return NSLocalizedString(@"ends with", nil);
    } else {
        return NSLocalizedString(@"starts with", nil);
    }
}

+ (NSString *)locationTypeString:(BX_location_type)locationType {
    if (locationType == BX_LOCATION_BXAPP) {
        return NSLocalizedString(@"BxApp", nil);
    } else if (locationType == BX_LOCATION_FASTCGI) {
        return NSLocalizedString(@"FastCGI Script", nil);
    } else {
        return NSLocalizedString(@"Static Content", nil);
    }
}

+ (NSString *)loadBalancingString:(BX_load_type)loadBalancing {
    if (loadBalancing == BX_LOAD_HASHIP) {
        return NSLocalizedString(@"Hash IP", nil);
    } else {
        return NSLocalizedString(@"Round Robin", nil);
    }
}

- (void)dealloc {
    [_pattern release];
    [_path release];
    [_information release];
    [_appName release];
    [_appVersion release];
    [_appAuthor release];
    [_appDescription release];
    [_appBombaxticVersion release];
    [_appIcon release];
    [_runningCommands release];
    [_notes release];
    [_server release];
    [super dealloc];    
}

@end
