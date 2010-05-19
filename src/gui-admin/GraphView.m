#import "GraphView.h"


@implementation GraphView

@synthesize model = _model;

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _graphBezier = [[NSBezierPath alloc] init];
        [_graphBezier setLineWidth:0.5];
        for (int x = 0; x <= 50; x++) {
            if (x % 5 == 0) {
                [_graphBezier moveToPoint:NSMakePoint(x * 10, 13)];
            } else {
                [_graphBezier moveToPoint:NSMakePoint(x * 10, 15)];
            }
            [_graphBezier lineToPoint:NSMakePoint(x * 10, 145)];
        }
        for (int y = 0; y <= 10; y++) {
            [_graphBezier moveToPoint:NSMakePoint(0, y * 13 + 15)];
            [_graphBezier lineToPoint:NSMakePoint(500, y * 13 + 15)];
            [_graphBezier moveToPoint:NSMakePoint(505, y * 13 + 15)];
            [_graphBezier lineToPoint:NSMakePoint(530, y * 13 + 15)];            
            [_graphBezier moveToPoint:NSMakePoint(535, y * 13 + 15)];
            [_graphBezier lineToPoint:NSMakePoint(560, y * 13 + 15)];            
        }
        [_graphBezier appendBezierPathWithRect:NSMakeRect(505, 15, 25, 130)];
        [_graphBezier appendBezierPathWithRect:NSMakeRect(535, 15, 25, 130)];
        
        
        _backColor = [[NSColor colorWithDeviceRed:0
                                            green:0
                                             blue:0
                                            alpha:1] retain];
        _gridColor = [[NSColor colorWithDeviceRed:.2
                                            green:.2
                                             blue:.2
                                            alpha:1] retain];
        _cpuColor = [[NSColor colorWithDeviceRed:.2
                                           green:.2
                                            blue:1
                                           alpha:1] retain];
        _memoryColor = [[NSColor colorWithDeviceRed:1
                                              green:.2
                                               blue:.2
                                              alpha:1] retain];
        _labelAttrs = [[NSMutableDictionary alloc] initWithCapacity:4];
        NSFont *font = [NSFont labelFontOfSize:9];
        [_labelAttrs setObject:font
                        forKey:NSFontAttributeName];
        NSMutableParagraphStyle *paraStyle = [[NSMutableParagraphStyle alloc] init];
        [paraStyle setAlignment:NSCenterTextAlignment];
        [_labelAttrs setObject:paraStyle
                        forKey:NSParagraphStyleAttributeName];
    }
    return self;
}

static double _scaleValue(double x) {
    return 130 * (x / 100);
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    [_graphBezier setLineWidth:0];
    [_backColor set];
    NSBezierPath *path = [NSBezierPath bezierPathWithRect:NSMakeRect(0, 15, 500, 130)];
    [path fill];
    [path removeAllPoints];
    [path appendBezierPathWithRect:NSMakeRect(505, 15, 25, 130)];
    [path fill];
    [path removeAllPoints];
    [path appendBezierPathWithRect:NSMakeRect(535, 15, 25, 130)];
    [path fill];
    [_gridColor set];
    [_graphBezier stroke];

    double cpuPoints[250];
    double ramPoints[250];
    int len = [_model.points count];
    for (int i = 0; i < len; i++) {
        NSNumber *num = [_model.points objectAtIndex:i];
        NSUInteger val = [num unsignedIntegerValue];
        cpuPoints[i] = (val >> 16) / 100.0;
        ramPoints[i] = (val & 0xFFFF) / 100.0;
    }
        
    double ram = _model.isRunning ? _scaleValue(_model.ramUsage) : 0;

    [path removeAllPoints];
    [_memoryColor set];
    [path appendBezierPathWithRect:NSMakeRect(535, 15, 25, ram)];
    [path fill];
    [path removeAllPoints];
    [path moveToPoint:NSMakePoint(535, ram + 15)];
    [path lineToPoint:NSMakePoint(500, ram + 15)];
    for (int i = 0; i < len; i++) {
        [path lineToPoint:NSMakePoint(500 - i * 2, _scaleValue(ramPoints[i]) + 15)];
    }
    [path stroke];
    
    [path removeAllPoints];
    double cpu = _model.isRunning ? _scaleValue(_model.cpuUsage) : 0;
    [_cpuColor set];
    [path appendBezierPathWithRect:NSMakeRect(505, 15, 25, cpu)];
    [path fill];
    [path removeAllPoints];
    [path moveToPoint:NSMakePoint(505, cpu + 15)];
    [path lineToPoint:NSMakePoint(500, cpu + 15)];
    for (int i = 0; i < len; i++) {
        [path lineToPoint:NSMakePoint(500 - i * 2, _scaleValue(cpuPoints[i]) + 15)];
    }
    [path stroke];
    
    [_labelAttrs setObject:[NSColor blackColor]
                    forKey:NSForegroundColorAttributeName];
    [@"CPU" drawInRect:NSMakeRect(505, 0, 25, 15)
        withAttributes:_labelAttrs];
    [@"RAM" drawInRect:NSMakeRect(535, 0, 25, 15)
        withAttributes:_labelAttrs];
    NSString *label;
    for (int i = 0; i <= 10; i++) {
        int t = 30 - (i * 3);
        label = [NSString stringWithFormat:@"%dm", t];
        int offset = i * 50 - 10;
        if (i == 0) {
            offset += 10;
        } else if (i == 10) {
            offset -= 5;
        }
        [label drawInRect:NSMakeRect(offset, 0, 20, 15)
           withAttributes:_labelAttrs];
    }
    [_labelAttrs setObject:[NSColor whiteColor]
                    forKey:NSForegroundColorAttributeName];
    label = [NSString stringWithFormat:@"%0.1f\n%%", _model.cpuUsage];
    [label drawInRect:NSMakeRect(505, 52, 25, 30)
       withAttributes:_labelAttrs];
    label = [NSString stringWithFormat:@"%0.1f\n%%", _model.ramUsage];
    [label drawInRect:NSMakeRect(535, 52, 25, 30)
       withAttributes:_labelAttrs];
}


@end
