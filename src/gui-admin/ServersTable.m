#import "ServersTable.h"
#import "Server.h"

@implementation ServersTable

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
    return [_model.servers count];
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
            row:(NSInteger)rowIndex {
    Server *server = [_model.servers objectAtIndex:rowIndex];
    if (server == nil) {
        return nil;
    }
    NSString *identifier = [aTableColumn identifier];
    if ([identifier isEqualToString:@"hostname"]) {
        if ([server.hostnames count] == 0 || ([server.hostnames count] == 1 && [[server.hostnames objectAtIndex:0] length] == 0)) {
            return @"*";
        } else {
            return [server.hostnames componentsJoinedByString:@", "];
        }
    } else if ([identifier isEqualToString:@"port"]) {
        if ([server.ports count] == 0) {
            return @"80";
        } else {
            return [server.ports componentsJoinedByString:@", "];
        }
    } else if ([identifier isEqualToString:@"ipaddress"]) {
        if ([server.ipAddresses count] == 0) {
            return @"*";
        } else {            
            return [server.ipAddresses componentsJoinedByString:@", "];
        }
    } else if ([identifier isEqualToString:@"ssl"]) {
        return [NSNumber numberWithBool:server.sslEnabled];
    } else {
        return nil;
    }        
}

/*

- (BOOL)tableView:(NSTableView *)aTableView
       acceptDrop:(id <NSDraggingInfo>)info
              row:(NSInteger)row
    dropOperation:(NSTableViewDropOperation)operation {
    
}

- (NSArray *)tableView:(NSTableView *)aTableView
namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
forDraggedRowsWithIndexes:(NSIndexSet *)indexSet {
    
}

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:(id)anObject
   forTableColumn:(NSTableColumn *)aTableColumn
              row:(NSInteger)rowIndex {
    
}

- (void)tableView:(NSTableView *)aTableView
sortDescriptorsDidChange:(NSArray *)oldDescriptors {
    
}

- (NSDragOperation)tableView:(NSTableView *)aTableView
                validateDrop:(id <NSDraggingInfo>)info
                 proposedRow:(NSInteger)row
       proposedDropOperation:(NSTableViewDropOperation)operation {
    
}

- (BOOL)tableView:(NSTableView *)aTableView
writeRowsWithIndexes:(NSIndexSet *)rowIndexes
     toPasteboard:(NSPasteboard *)pboard {
    
}

 */
 
#pragma mark delegate

- (void)tableViewSelectionIsChanging:(NSNotification *)aNotification {
    int row = [_tableView selectedRow];
    Server *server;
    if (row < 0) {
        server = nil;
    }  else {
        server = [_model.servers objectAtIndex:row];
    }
    if (server != _mainWindow.editedServer) {
        [_mainWindow displayServer:server];
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
