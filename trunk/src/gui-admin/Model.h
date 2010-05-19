#import <Cocoa/Cocoa.h>

@interface Model : NSObject <NSCopying> {
    BOOL _isDebugEnabled;
    BOOL _isRunning;
    NSTimeInterval _runningSince;
    int _debugPort;
    NSMutableArray *_servers;
    double _cpuUsage;
    double _ramUsage;
    NSMutableArray *_points;
}

- (id)loadFromPreferences;
- (id)saveToPreferences;

- (id)beginTransaction;
- (id)commit;
- (id)rollback;
- (Model *)createSnapshot;
- (id)restoreFromSnapshot:(Model *)snapshot;
- (void)addPoint:(NSNumber *)point;

@property (nonatomic, assign) BOOL isDebugEnabled;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) NSTimeInterval runningSince;
@property (nonatomic, assign) int debugPort;
@property (readonly) NSMutableArray *servers;
@property (nonatomic, assign) double cpuUsage;
@property (nonatomic, assign) double ramUsage;
@property (copy) NSMutableArray *points;

@end
