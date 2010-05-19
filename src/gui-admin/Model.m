#import "Model.h"
#import "Server.h"

@implementation Model

@synthesize isDebugEnabled = _isDebugEnabled;
@synthesize isRunning = _isRunning;;
@synthesize runningSince = _runningSince;;
@synthesize debugPort = _debugPort;;
@synthesize servers = _servers;
@synthesize cpuUsage = _cpuUsage;
@synthesize ramUsage = _ramUsage;
@synthesize points = _points;

- (id)init {
    _isDebugEnabled = YES;
    _isRunning = NO;
    _runningSince = 0;
    _debugPort = 10228;
    _servers = [[NSMutableArray alloc] initWithCapacity:8];
    _cpuUsage = 0;
    _ramUsage = 0;
    _points = [[NSMutableArray alloc] initWithCapacity:250];
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    Model *copy = [[Model alloc] init];
    copy.isDebugEnabled = _isDebugEnabled;
    copy.isRunning = _isRunning;
    copy.runningSince = _runningSince;
    copy.debugPort = _debugPort;
    copy.cpuUsage = _cpuUsage;
    copy.ramUsage = _ramUsage;
    copy.points = _points;
    for (Server *server in _servers) {
        [copy.servers addObject:[server copyWithZone:zone]];
    }
    return copy;
}

- (void)dealloc {
    [_servers release];
    [_points release];
    [super dealloc];    
}

- (id)loadFromPreferences {
    // tbd
    return self;
}

- (id)saveToPreferences {
    // tbd
    return self;
}

- (id)beginTransaction {
    // tbd
    return self;
}

- (id)commit {
    // tbd
    return self;
}

- (id)rollback {
    // tbd
    return self;
}

- (Model *)createSnapshot {
    // tbd
    return nil;
}

- (id)restoreFromSnapshot:(Model *)snapshot {
    // tbd
    return self;
}

- (void)addPoint:(NSNumber *)point {
    if ([_points count] == 250) {
        [_points removeLastObject];
    }
    [_points insertObject:point atIndex:0];
}

@end
