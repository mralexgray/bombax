#import <Cocoa/Cocoa.h>
#import "MainWindow.h"
#import "Model.h"

@class MainWindow;
@class Model;

@interface LocationsTable : NSObject  {
    MainWindow *_mainWindow;
    Model *_model;
    NSTableView *_tableView;
}

- (id)initWithMainWindow:(MainWindow *)mainWindow
                   model:(Model *)model
               tableView:(NSTableView *)tableView;

@property (readonly) Model *model;

@end
