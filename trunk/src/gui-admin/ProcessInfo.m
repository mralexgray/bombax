#import "ProcessInfo.h"

@implementation ProcessInfo

@synthesize pid = _pid;
@synthesize cpu = _cpu;
@synthesize ram = _ram;
@synthesize runningSince = _runningSince;
@synthesize command = _command;
@synthesize type = _type;

- (id)initWithPid:(int)pid
              cpu:(double)cpu
              ram:(double)ram
     runningSince:(NSTimeInterval)runningSince
          command:(NSString *)command
             type:(BX_process_type)type {
    [super init];
    _pid = pid;
    _cpu = cpu;
    _ram = ram;
    _runningSince = runningSince;
    _command = [command retain];
    _type = type;
    return self;
}

- (void)dealloc {
    [_command release];
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"PID:%d CPU:%0.1f RAM:%0.1f Time:%0.1fs Type:%@ Command:'%@'", _pid, _cpu, _ram, _runningSince, (_type == BX_PROCESS_BXAPP ? @"BxApp" : @"Nginx"), _command];
}

@end
