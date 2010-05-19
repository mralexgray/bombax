#import "DetailOutlineTable.h"
#import "Server.h"
#import "Location.h"

@implementation DetailOutlineTable

@synthesize model = _model;

- (void)outlineViewSelectionIsChanging:(NSNotification *)notification {
    int row = [_outlineView selectedRow];
    if (row >= 0) {
        id item = [_outlineView itemAtRow:row];
        if ([item isKindOfClass:[Server class]]) {
            [_mainWindow displayServer:item];
        } else if ([item isKindOfClass:[Location class]]) {
            [_mainWindow displayLocation:item];
        } else {
            [_mainWindow clearDisplay];
        }
    } else {
        [_mainWindow clearDisplay];
    }
}

- (id)initWithMainWindow:(MainWindow *)mainWindow
                   model:(Model *)model
             outlineView:(NSOutlineView *)outlineView {
    [super init];
    _mainWindow = mainWindow;
    _model = model;
    _outlineView = outlineView;
    return self;
}


- (id)outlineView:(NSOutlineView *)outlineView
            child:(NSInteger)index
           ofItem:(id)item {
    if (item == nil) {
        return [_model.servers objectAtIndex:index];
    } else if ([item isKindOfClass:[Server class]]) {
        Server *server = (Server *) item;
        return [server.locations objectAtIndex:index];
    } else {
        return nil;
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
   isItemExpandable:(id)item {
    if (item == nil) {
        return [_model.servers count] > 1;
    } else if ([item isKindOfClass:[Server class]]) {
        Server *server = (Server *) item;
        return [server.locations count] > 0;
    } else {
        return NO;
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView
  numberOfChildrenOfItem:(id)item {
    if (item == nil) {
        return [_model.servers count];
    } else if ([item isKindOfClass:[Server class]]) {
            Server *server = (Server *) item;
            return [server.locations count];
    } else {
        return 0;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView
objectValueForTableColumn:(NSTableColumn *)tableColumn
           byItem:(id)item {
    return @"";
}

- (NSCell *)outlineView:(NSOutlineView *)outlineView
 dataCellForTableColumn:(NSTableColumn *)tableColumn
                   item:(id)item {
    NSButtonCell *cell = [tableColumn dataCell];
    static NSImage *instanceImage = nil;
    static NSImage *staticImage = nil;
    static NSImage *fastcgiImage = nil;
    static NSImage *defaultBxAppImage = nil;
    if (instanceImage == nil) {
        instanceImage = [NSImage imageNamed:@"internet-web-browser"];
        staticImage = [NSImage imageNamed:@"folder-remote"];
        fastcgiImage = [NSImage imageNamed:@"application-x-executable"];
        defaultBxAppImage = [NSImage imageNamed:@"bwlogo-128"];
    }    
    if ([item isKindOfClass:[Server class]]) {
        Server *server = (Server *) item;
        NSMutableString *result = [NSMutableString stringWithCapacity:32];
        if (server.sslEnabled) {
            [result appendString:@"https://"];
        } else {
            [result appendString:@"http://"];
        }
        if ([server.hostnames count] == 0 ||
            ([server.hostnames count] == 1 && [[server.hostnames objectAtIndex:0] length] == 0)) {
            if ([server.ipAddresses count] == 0) {
                [result appendString:@"*"];
            } else {            
                [result appendString:[server.ipAddresses objectAtIndex:0]];
            }
        } else {
            [result appendString:[server.hostnames objectAtIndex:0]];
        }
        if ([server.ports count] == 0) {
            [result appendString:@":80"];
        } else {
            [result appendFormat:@":%@", [server.ports objectAtIndex:0]];
        }
        [cell setTitle:result];
        [cell setImage:instanceImage];
    } else if ([item isKindOfClass:[Location class]]) {
        Location *location = (Location *) item;
        NSMutableString *result = [NSMutableString stringWithCapacity:32];
        if (location.patternStyle == BX_PATTERN_START) {
            if ([location.pattern hasPrefix:@"/"]) {
                [result appendFormat:@"%@  ", location.pattern];
            } else {
                [result appendFormat:@"/%@  ", location.pattern];
            }
        } else {
            [result appendFormat:@"*%@  ", location.pattern];
        }
        if (location.locationType == BX_LOCATION_BXAPP) {
            if ([location.appName length] > 0) {
                [result appendString:location.appName];
            } else {
                [result appendString:@"BxApp"];
            }
            
            NSRange range = [location.path rangeOfString:@".app"];
            NSString *path = range.location == NSNotFound ? location.path : [location.path substringToIndex:range.location + 4];
            BOOL isRunning = NO;
            for (ProcessInfo *info in _mainWindow.controller.processInfos) {
                if ([info.command rangeOfString:path].location != NSNotFound) {
                    isRunning = YES;
                    break;
                }
            }
            if (isRunning) {
                [result appendString:@" (On)"];
            } else {
                [result appendString:@" (Off)"];
            }
            if (location.appIcon == nil) {
                [cell setImage:defaultBxAppImage];
            } else {
                [cell setImage:location.appIcon];
            }
        } else if (location.locationType == BX_LOCATION_FASTCGI) {
            if ([location.path length] > 26) {
                [result appendFormat:@"...%@", [location.path substringFromIndex:[location.path length] - 26]];
            } else {
                [result appendString:location.path];                
            }                
            [cell setImage:fastcgiImage];
        } else {
            if ([location.path length] > 26) {
                [result appendFormat:@"...%@", [location.path substringFromIndex:[location.path length] - 26]];
            } else {
                [result appendString:location.path];                
            }                
            [cell setImage:staticImage];
        }
        [cell setTitle:result];        
    } else {
        [cell setTitle:@""];
        [cell setImage:nil];
    }
    return cell;
}


- (NSDragOperation)outlineView:(NSOutlineView *)outlineView
                  validateDrop:(id <NSDraggingInfo>)info
                  proposedItem:(id)item
            proposedChildIndex:(NSInteger)index {
    NSArray *files = [[info draggingPasteboard] propertyListForType:NSFilenamesPboardType];
    if ([files count] > 0) {
        NSString *file = [files objectAtIndex:0];
        NSString *ext = [file pathExtension];
        if ([ext isEqualToString:@"app"]) {
            return NSDragOperationCopy;
        } else if ([ext length] == 0 && [file rangeOfString:@".app/"].location != NSNotFound) {
            return NSDragOperationCopy;
        } else {
            return NSDragOperationNone;
        }
    } else {
        return NSDragOperationNone;
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
         acceptDrop:(id <NSDraggingInfo>)info
               item:(id)item
         childIndex:(NSInteger)index {
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
        Server *server;
        if (item != nil && [item isKindOfClass:[Server class]]) {
            server = (Server *) item;
        } else if (item != nil && [item isKindOfClass:[Location class]]) {
            server = ((Location *) item).server;
        } else {
            if ([_model.servers count] == 0) {
                server = [[Server alloc] init];
                [_model.servers addObject:server];
            } else {
                server = [_model.servers lastObject];
            }
        }
        [server.locations addObject:location];
        [outlineView reloadData];
        [outlineView expandItem:server];
        int row = [outlineView rowForItem:location];
        [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                       byExtendingSelection:NO];
        [_mainWindow displayLocation:location];
        return YES;
    }
    return NO;
}


@end
