#import "BxAppTable.h"
#import "Server.h"
#import "Location.h"
#import "CustomLevelIndicator.h"

@implementation BxAppTable

@synthesize model = _model;
@synthesize apps = _apps;

- (id)initWithMainWindow:(MainWindow *)mainWindow
                   model:(Model *)model
               tableView:(NSTableView *)tableView {
    [super init];
    _mainWindow = mainWindow;
    _model = model;
    _tableView = tableView;
    _apps = [[NSMutableArray arrayWithCapacity:16] retain];
    return self;
}

- (id)syncApps {
    [_apps removeAllObjects];
    for (Server *server in _model.servers) {
        for (Location *location in server.locations) {
            if (location.locationType == BX_LOCATION_BXAPP) {
                [_apps addObject:location];
            }
        }
    }
    return self;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [_apps count];
}

- (NSCell *)tableView:(NSTableView *)tableView
dataCellForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    if (row < 0 || row > [_apps count] - 1) {
        return [tableColumn dataCell];
    }
    Location *location = [_apps objectAtIndex:row];
    id cell = [tableColumn dataCell];
    NSString *identifier = [tableColumn identifier];
    if ([identifier isEqualToString:@"bxapp"]) {
        NSButtonCell *buttonCell = cell;
        [buttonCell setImage:location.appIcon];
        [buttonCell setTitle:location.appName];
        return buttonCell;
    } else if ([identifier isEqualToString:@"location"]) {
        NSButtonCell *buttonCell = cell;
        if (location.patternStyle == BX_PATTERN_START) {
            if ([location.pattern hasPrefix:@"/"]) {
                [buttonCell setTitle:location.pattern];
            } else {
                [buttonCell setTitle:[NSString stringWithFormat:@"/%@", location.pattern]];
            }
        } else {
            [buttonCell setTitle:[NSString stringWithFormat:@"*%@", location.pattern]];
        }
        return buttonCell;
    } else if ([identifier isEqualToString:@"server"]) {
        NSButtonCell *buttonCell = cell;
        [buttonCell setTitle:[_mainWindow pathForServer:location.server]];
        return buttonCell;
    } else if ([identifier isEqualToString:@"cpu"]) {
        CustomLevelIndicator *levelCell = cell;
        if (_model.isRunning) {
            [levelCell setDoubleValue:location.cpuUsage];
        } else {
            [levelCell setDoubleValue:0];
        }
        return levelCell;
    } else if ([identifier isEqualToString:@"memory"]) {
        CustomLevelIndicator *levelCell = cell;
        if (_model.isRunning) {
            [levelCell setDoubleValue:location.memoryUsage];
        } else {
            [levelCell setDoubleValue:0];
        }
        return levelCell;        
    } else if ([identifier isEqualToString:@"action"]) {
        NSButtonCell *buttonCell = cell;
        [buttonCell setEnabled:_model.isRunning];
        return buttonCell;
    } else {
        return cell;
    }
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)tableColumn
            row:(NSInteger)row {
    NSString *identifier = [tableColumn identifier];
    Location *location = [_apps objectAtIndex:row];
    if ([identifier isEqualToString:@"cpu"]) {
        return [NSNumber numberWithDouble:location.cpuUsage];
    } else if ([identifier isEqualToString:@"memory"]) {
        return [NSNumber numberWithDouble:location.memoryUsage];
    } else {
        return @"";
    }
}

@end
