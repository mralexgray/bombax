#import <Cocoa/Cocoa.h>
#import "MainWindow.h"
#import "Model.h"

@class MainWindow;
@class Model;

@interface DetailOutlineTable : NSObject {
    MainWindow *_mainWindow;
    Model *_model;
    NSOutlineView *_outlineView;
}

- (id)initWithMainWindow:(MainWindow *)mainWindow
                   model:(Model *)model
             outlineView:(NSOutlineView *)outlineView;

@property (readonly) Model *model;
@end
