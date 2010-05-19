#import <Cocoa/Cocoa.h>
#import "Server.h"

typedef enum {
    BX_LOCATION_STATIC,
    BX_LOCATION_BXAPP,
    BX_LOCATION_FASTCGI
} BX_location_type;

typedef enum {
    BX_PATTERN_START,
//    BX_PATTERN_EXACT,
    BX_PATTERN_END,
} BX_pattern_type;

typedef enum {
    BX_LOAD_ROUNDROBIN,
    BX_LOAD_HASHIP
} BX_load_type;

@class Server;

@interface Location : NSObject <NSCopying> {
    NSString *_pattern;
    BX_location_type _locationType;
    BX_pattern_type _patternStyle;
    NSString *_path;
    NSString *_information;
    BX_load_type _loadBalacing;
    NSString *_appName;
    NSString *_appVersion;
    NSString *_appAuthor;
    NSString *_appAuthorUrl;
    NSString *_appDescription;
    NSString *_appBombaxticVersion;
    NSImage *_appIcon;
    NSMutableArray *_runningCommands;
    BOOL _watchdogEnabled;
    int _processes;
    int _threads;
    NSString *_notes;
    Server *_server;
    double _cpuUsage;
    double _memoryUsage;
}

+ (NSString *)patternStyleString:(BX_pattern_type)patternStyle;
+ (NSString *)locationTypeString:(BX_location_type)locationType;
+ (NSString *)loadBalancingString:(BX_load_type)loadBalancing;
- (id)updateAppInfo;
    
@property (nonatomic, assign) int processes;
@property (nonatomic, assign) int threads;
@property (nonatomic, copy) NSString *pattern;
@property (nonatomic, assign) BX_location_type locationType;
@property (nonatomic, assign) BX_pattern_type patternStyle;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *information;
@property (nonatomic, assign) BX_load_type loadBalancing;
@property (nonatomic, copy) NSString *notes;
@property (nonatomic, copy) NSString *appName;
@property (nonatomic, copy) NSString *appVersion;
@property (nonatomic, copy) NSString *appAuthor;
@property (nonatomic, copy) NSString *appAuthorUrl;
@property (nonatomic, copy) NSString *appDescription;
@property (nonatomic, copy) NSString *appBombaxticVersion;
@property (readonly) NSMutableArray *runningCommands;
@property (nonatomic, assign) BOOL watchdogEnabled;
@property (retain) NSImage *appIcon;
@property (retain) Server *server;
@property (nonatomic) double cpuUsage;
@property (nonatomic) double memoryUsage;

@end
