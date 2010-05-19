#import <Cocoa/Cocoa.h>
#import "MainWindow.h"
#import "Model.h"

@class MainWindow;
@class Model;

@interface BxAppTable : NSObject {
    MainWindow *_mainWindow;
    Model *_model;
    NSTableView *_tableView;
    NSMutableArray *_apps;
}

- (id)syncApps;

- (id)initWithMainWindow:(MainWindow *)mainWindow
                   model:(Model *)model
               tableView:(NSTableView *)tableView;

@property (readonly) Model *model;
@property (readonly) NSArray *apps;

@end
