#import <Cocoa/Cocoa.h>
#import "Model.h"

@class Model;

@interface GraphView : NSView {
    NSBezierPath *_graphBezier;
    Model *_model;
    NSColor *_backColor;
    NSColor *_gridColor;
    NSColor *_cpuColor;
    NSColor *_memoryColor;
    NSMutableDictionary *_labelAttrs;
}

@property (assign) Model *model;

@end
