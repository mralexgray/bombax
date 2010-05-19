#import "LocationsTable.h"
#import "Server.h"
#import "Location.h"
#import "ProcessInfo.h"

@implementation LocationsTable

@synthesize model = _model;

- (id)initWithMainWindow:(MainWindow *)mainWindow
                   model:(Model *)model
               tableView:(NSTableView *)tableView {
    [super init];
    _mainWindow = mainWindow;
    _model = model;
    _tableView = tableView;
    return self;
}

#pragma mark data source

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    Server *server = _mainWindow.editedServer;
    if (server != nil) {
        return [server.locations count];
    } else {
        return 0;
    }
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex {
    Server *server = _mainWindow.editedServer;
    if (server != nil) {
        Location *location = [server.locations objectAtIndex:rowIndex];
        if (location == nil) {
            return nil;
        }
        NSString *identifier = [aTableColumn identifier];
        if ([identifier isEqualToString:@"pattern"]) {
            if ([location.pattern length] == 0) {
                return @"*";
            } else if (location.patternStyle == BX_PATTERN_END) {
                return [@"*" stringByAppendingString:location.pattern];
            } else {
                return location.pattern;
            }
        } else if ([identifier isEqualToString:@"type"]) {
            return [Location locationTypeString:location.locationType];
        } else if ([identifier isEqualToString:@"extra"]) {
            if (location.locationType == BX_LOCATION_BXAPP) {
                return [NSString stringWithFormat:NSLocalizedString(@"%@, %@", nil), location.appName, location.appVersion];
            } else {
                return location.path;
            }
        } else if ([identifier isEqualToString:@"on"]) {
            if (location.locationType == BX_LOCATION_BXAPP) {
                NSRange range = [location.path rangeOfString:@".app"];
                NSString *path = range.location == NSNotFound ? location.path : [location.path substringToIndex:range.location + 4];
                for (ProcessInfo *info in _mainWindow.controller.processInfos) {
                    if ([info.command rangeOfString:path].location != NSNotFound) {
                        return [NSNumber numberWithBool:YES];
                        break;
                    }
                }
            }
            return [NSNumber numberWithBool:NO];
        } else {
            return nil;
        }
    } else {
        return nil;
    }    
}

 
- (BOOL)tableView:(NSTableView *)aTableView
       acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)operation {
    if (_mainWindow.editedServer != nil && operation == NSTableViewDropAbove) {
        NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
        if ([files count] > 0) {
            NSString *file = [files objectAtIndex:0];
            NSString *ext = [file pathExtension];
            NSRange range;
            if ([ext isEqualToString:@"app"]) {
                // pass
            } else if ([ext length] == 0 && (range = [file rangeOfString:@".app/"]).location != NSNotFound) {
                file = [file substringToIndex:range.location + 4];
            } else {
                return NO;
            }
            [_mainWindow markTransaction];
            Location *location = [[Location alloc] init];
            location.path = file;
            location.locationType = BX_LOCATION_BXAPP;
            [location updateAppInfo];
            if ([location.appName length] > 0) {
                location.pattern = location.appName;
            } else {
                location.pattern = [[file lastPathComponent] stringByDeletingPathExtension];
            }
            location.pattern = [location.pattern stringByReplacingOccurrencesOfString:@" " withString:@""]; // _ -?
            [_mainWindow.editedServer.locations addObject:location];
            [_tableView reloadData];
            [_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[_mainWindow.editedServer.locations count] - 1]
                    byExtendingSelection:NO];
            [_mainWindow displayLocation:location];
            return YES;
        }
    }    
    return NO;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)operation {
    if (_mainWindow.editedServer != nil && operation == NSTableViewDropAbove) {
        NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
        if ([files count] > 0) {
            NSString *file = [files objectAtIndex:0];
            NSString *ext = [file pathExtension];
            if ([ext isEqualToString:@"app"]) {
                return NSDragOperationCopy;
            } else if ([ext length] == 0 && [file rangeOfString:@".app/"].location != NSNotFound) {
                return NSDragOperationCopy;
            }
        }
    }
    return NSDragOperationNone;
}

/*


- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn
              row:(NSInteger)rowIndex {
    
}

- (void)tableView:(NSTableView *)aTableView
sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    
}

 - (NSArray *)tableView:(NSTableView *)aTableView
 namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
 forDraggedRowsWithIndexes:(NSIndexSet *)indexSet {
 
 }

 - (BOOL)tableView:(NSTableView *)aTableView
 writeRowsWithIndexes:(NSIndexSet *)rowIndexes
 toPasteboard:(NSPasteboard *)pboard {
 
 }
 
 */
 
#pragma mark delegate

- (void)tableViewSelectionIsChanging:(NSNotification *)aNotification {
    int row = [_tableView selectedRow];
    Location *location;
    if (row < 0) {
        location = nil;
    }  else {
        location = [_mainWindow.editedServer.locations objectAtIndex:row];
    }
    if (location != _mainWindow.editedLocation) {
        [_mainWindow displayLocation:location];
    }
}

- (BOOL)tableView:(NSTableView *)aTableView
shouldSelectTableColumn:(NSTableColumn *)aTableColumn {
    return NO;
}


/*
 
- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView {
    
}

- (NSCell *)tableView:(NSTableView *)tableView
dataCellForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row {
    
}

- (void)tableView:(NSTableView *)tableView
didClickTableColumn:(NSTableColumn *)tableColumn {
    
}

- (void)tableView:(NSTableView *)tableView
didDragTableColumn:(NSTableColumn *)tableColumn {
    
}

- (CGFloat)tableView:(NSTableView *)tableView
         heightOfRow:(NSInteger)row {
    
}

- (BOOL)tableView:(NSTableView *)tableView
       isGroupRow:(NSInteger)row {
    
}

- (void)tableView:(NSTableView *)tableView
mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn {
    
}

- (NSInteger)tableView:(NSTableView *)tableView
nextTypeSelectMatchFromRow:(NSInteger)startRow
                 toRow:(NSInteger)endRow
             forString:(NSString *)searchString {
    
}

- (NSIndexSet *)tableView:(NSTableView *)tableView
selectionIndexesForProposedSelection:(NSIndexSet *)proposedSelectionIndexes {
    
}

- (BOOL)tableView:(NSTableView *)aTableView
shouldEditTableColumn:(NSTableColumn *)aTableColumn
              row:(NSInteger)rowIndex {
    
}

- (BOOL)tableView:(NSTableView *)tableView
shouldReorderColumn:(NSInteger)columnIndex
         toColumn:(NSInteger)newColumnIndex {
    
}

- (BOOL)tableView:(NSTableView *)aTableView
  shouldSelectRow:(NSInteger)rowIndex {
    
}

- (BOOL)tableView:(NSTableView *)tableView
shouldShowCellExpansionForTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)row {
    
}

- (BOOL)tableView:(NSTableView *)tableView
  shouldTrackCell:(NSCell *)cell
   forTableColumn:(NSTableColumn *)tableColumn
              row:(NSInteger)row {
    
}

- (BOOL)tableView:(NSTableView *)tableView
shouldTypeSelectForEvent:(NSEvent *)event
withCurrentSearchString:(NSString *)searchString {
    
}

- (CGFloat)tableView:(NSTableView *)tableView
sizeToFitWidthOfColumn:(NSInteger)column {
    
}

- (NSString *)tableView:(NSTableView *)aTableView
         toolTipForCell:(NSCell *)aCell
                   rect:(NSRectPointer)rect
            tableColumn:(NSTableColumn *)aTableColumn
                    row:(NSInteger)row
          mouseLocation:(NSPoint)mouseLocation {
    
}

- (NSString *)tableView:(NSTableView *)tableView
typeSelectStringForTableColumn:(NSTableColumn *)tableColumn
                    row:(NSInteger)row {
    
}

- (void)tableView:(NSTableView *)aTableView
  willDisplayCell:(id)aCell
   forTableColumn:(NSTableColumn *)aTableColumn
              row:(NSInteger)rowIndex {
    
}

- (void)tableViewColumnDidMove:(NSNotification *)aNotification {
    
}

- (void)tableViewColumnDidResize:(NSNotification *)aNotification {
    
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    
}
*/

@end
