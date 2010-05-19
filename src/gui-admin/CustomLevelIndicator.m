#import "CustomLevelIndicator.h"

@implementation CustomLevelIndicator

- (void)drawWithFrame:(NSRect)cellFrame
               inView:(NSView *)controlView {
    [super drawWithFrame:cellFrame
                  inView:controlView];
    
    NSString *percent = [NSString stringWithFormat:@"%0.1f%%", [self doubleValue]];
    NSMutableDictionary *attrs = [[[self attributedStringValue] attributesAtIndex:0
                                                                  effectiveRange:NULL] mutableCopy];
    [attrs setObject:[NSColor blackColor]
              forKey:@"NSColor"];
    NSRect rect = cellFrame;
    rect.size = [percent sizeWithAttributes:attrs];
    rect.origin.x += (cellFrame.size.width - rect.size.width) / 2;
    rect.origin.y += (cellFrame.size.height - rect.size.height) / 2;
    [percent drawInRect:rect
         withAttributes:attrs];
}

@end
