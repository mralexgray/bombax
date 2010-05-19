#import <Cocoa/Cocoa.h>

typedef enum {
    BX_PROCESS_NGINX,
    BX_PROCESS_BXAPP
} BX_process_type;

@interface ProcessInfo : NSObject {
    int _pid;
    double _cpu;
    double _ram;
    NSTimeInterval _runningSince;
    NSString *_command;
    BX_process_type _type;
}

- (id)initWithPid:(int)pid
              cpu:(double)cpu
              ram:(double)ram
     runningSince:(NSTimeInterval)runningSince
          command:(NSString *)command
             type:(BX_process_type)type;

@property (readonly, nonatomic) int pid;
@property (readonly, nonatomic) double cpu;
@property (readonly, nonatomic) double ram;
@property (readonly, nonatomic) NSTimeInterval runningSince;
@property (readonly, nonatomic) NSString *command; 
@property (readonly, nonatomic) BX_process_type type;

@end
