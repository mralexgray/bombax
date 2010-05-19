#import "MainWindow.h"

@implementation MainWindow

@synthesize editedLocation = _editedLocation;
@synthesize editedServer = _editedServer;
@synthesize controller;

static NSCharacterSet *dividerCharacterSet;
static BOOL _wasRunning = NO;


- (void)handleBxAppTableDoubleClick:(id)sender {
    int row = [bxAppTableView selectedRow];
    if (row >= 0 && row < [_bxAppTable.apps count]) {
        Location *location = [_bxAppTable.apps objectAtIndex:row];
        row = [detailOutlineView rowForItem:location];
        if (row < 0) {
            return;
        }
        [modeSegmentedControl setSelectedSegment:1];
        [detailOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                       byExtendingSelection:NO];        
        [modeTabView selectTabViewItemAtIndex:1];        
        [self displayLocation:location];
    }
}

- (IBAction)enterRegistration:(id)sender {
    if (_registeredTo) {
        NSRunAlertPanel(NSLocalizedString(@"Registration Information", nil),
                        [NSString stringWithFormat:NSLocalizedString(@"This copy of Bombax is registered to '%@'. Thank you for purchasing Bombax!", nil), _registeredTo],
                        NSLocalizedString(@"OK", nil), nil, nil);
    } else {
        [registrationWindow makeKeyAndOrderFront:sender];
    }
}

- (IBAction)registerPressed:(id)sender {
    NSString *regCode = [self _registrationDecode:[registrationField stringValue]];
    if (regCode) {
        if (NSRunAlertPanel(NSLocalizedString(@"Please Confirm Registration", nil),
                            [NSString stringWithFormat:@"This registration code is for '%@'. Is this correct?", NSLocalizedString(regCode, nil)],
                            NSLocalizedString(@"Register", nil),
                            NSLocalizedString(@"Cancel", nil),
                            nil) == NSAlertAlternateReturn) {
            return;
        }
        NSRunAlertPanel(NSLocalizedString(@"Registration Successful", nil),
                        NSLocalizedString(@"Thank you for purchasing Bombax! All limitations have been removed. Thank you!", nil),
                        NSLocalizedString(@"OK", nil), nil, nil);
        [[NSUserDefaults standardUserDefaults] setObject:[registrationField stringValue]
                                                  forKey:@"registration"];
        _registeredTo = [regCode retain];
        [registrationWindow orderOut:self];
    } else {
        NSRunAlertPanel(NSLocalizedString(@"Invalid Registration", nil),
                        NSLocalizedString(@"We're sorry, but that code is not valid. Please check the code and try again or contact support@bombaxtic.com.", nil),
                        NSLocalizedString(@"OK", nil), nil, nil);
    }    
}

- (IBAction)buyNowPressed:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.bombaxtic.com/"]];
}

- (IBAction)registrationCancelPressed:(id)sender {
    [registrationWindow orderOut:self];
}

static char *_registrationChars = "0123456789ABCDEF";

//- (NSString *)encodeRegistration:(NSString *)text {
//    NSMutableString *code = [NSMutableString stringWithCapacity:[text length] * 2 + 4];
//    srandom(time(NULL));
//    int key = random() % 256;
//    [code appendString:[NSString stringWithFormat:@"%c", _registrationChars[key >> 4]]];
//    [code appendString:[NSString stringWithFormat:@"%c", _registrationChars[key & 0xF]]];
//    char *textChars = (char *) [text UTF8String];
//    int len = strlen(textChars);
//    for (int i = 0; i < len; i++) {        
//        int c = ((int) textChars[i]) ^ key;
//        key = c;
//        [code appendString:[NSString stringWithFormat:@"%c", _registrationChars[c >> 4]]];
//        [code appendString:[NSString stringWithFormat:@"%c", _registrationChars[c & 0xF]]];
//    }
//    key = key ^ 69;
//    [code appendString:[NSString stringWithFormat:@"%c", _registrationChars[key >> 4]]];
//    [code appendString:[NSString stringWithFormat:@"%c", _registrationChars[key & 0xF]]];
//    return [[code copy] autorelease];
//}

- (int)_regIntForChar:(unichar)c {
    for (int i = 0; i < 16; i++) {
        if (_registrationChars[i] == c) {
            return i;
        }
    }
    return -1000;
}

- (NSString *)_registrationDecode:(NSString *)code {
    code = [code stringByReplacingOccurrencesOfString:@"-" withString:@""];
    if (code == nil || [code length] < 4) {
        return nil;
    }
    NSMutableString *text = [NSMutableString stringWithCapacity:[code length] / 2];
    int key = ([self _regIntForChar:[code characterAtIndex:0]] << 4) | 
        ([self _regIntForChar:[code characterAtIndex:1]] & 0xF);
    if (key < 0) {
        return nil;
    }
    for (int i = 2; i < [code length] - 2; i += 2) {
        int c = (([self _regIntForChar:[code characterAtIndex:i]] << 4) |
                 ([self _regIntForChar:[code characterAtIndex:i + 1]] & 0xF));
        if (c < 0) {
            return nil;
        }
        int oc = c;
        c = c ^ key;
        key = oc;
        [text appendString:[NSString stringWithFormat:@"%c", c]];
    }
    int last = ([self _regIntForChar:[code characterAtIndex:[code length] - 2]] << 4) | 
        ([self _regIntForChar:[code characterAtIndex:[code length] - 1]] & 0xF);
    last = last ^ key;
    if (last != 69) {
        return nil;
    } else {
        return [[text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] retain];
    }
}


- (void)awakeFromNib {
    _logCommand = nil;
    [self center];
    _registeredTo = @"Community"; // xxx [self _registrationDecode:[[NSUserDefaults standardUserDefaults] stringForKey:@"registration"]];
    if (! _registeredTo) {
        NSUInteger result = NSRunAlertPanel(NSLocalizedString(@"Bombax Developer Edition", nil),
                                            NSLocalizedString(@"Thank you for using the Developer Edition of Bombax. Please note that the developer license only permits use of this software for testing and development. To purchase a license for deployment, please visit http://www.bombaxtic.com", nil),
                                            NSLocalizedString(@"Continue", nil),
                                            NSLocalizedString(@"Visit Bombaxtic.com", nil),
                                            NSLocalizedString(@"Enter Registration Code", nil));
        if (result == NSAlertAlternateReturn) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.bombaxtic.com/"]];
        } else if (result == NSAlertOtherReturn) {
            [registrationWindow makeKeyAndOrderFront:self];
        }
    }
    
    [logTextView setFont:[NSFont fontWithName:@"Andale Mono"
                                         size:9]];
    [logTextView setTextColor:[NSColor whiteColor]];
    [[logTextView textContainer] setWidthTracksTextView:NO];
    [[logTextView textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
//    [self setBackgroundColor:[NSColor colorWithDeviceRed:.21
//                                                   green:.21
//                                                    blue:.21
//                                                   alpha:1]];
    graphView.model = controller.model;
    dividerCharacterSet = [[NSCharacterSet characterSetWithCharactersInString:@"\n\t ,;"] retain];
    _locationsTable = [[LocationsTable alloc] initWithMainWindow:self
                                                           model:controller.model
                                                       tableView:locationTableView];
    _serversTable = [[ServersTable alloc] initWithMainWindow:self
                                                       model:controller.model
                                                   tableView:serverTableView];
    _bxAppTable = [[BxAppTable alloc] initWithMainWindow:self
                                                   model:controller.model
                                               tableView:bxAppTableView];
    _detailOutlineTable = [[DetailOutlineTable alloc] initWithMainWindow:self
                                                                   model:controller.model
                                                             outlineView:detailOutlineView];
    
    [locationTableView setDataSource:_locationsTable];
    [locationTableView setDelegate:_locationsTable];
    [serverTableView setDataSource:_serversTable];
    [serverTableView setDelegate:_serversTable];
    [bxAppTableView setDataSource:_bxAppTable];
    [bxAppTableView setDelegate:_bxAppTable];
    [detailOutlineView setDataSource:_detailOutlineTable];
    [detailOutlineView setDelegate:_detailOutlineTable];
    _editedServer = nil;
    _editedLocation = nil;
    _originalModel = nil;
    _statsTimer = nil;
    [self setTitle:[NSString localizedStringWithFormat:@"Bombax %@", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]];
    [self setDelegate:self];
    [detailOutlineView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
    [modeTabView selectTabViewItemAtIndex:0];
    [detailTabView setHidden:YES];
    [noDetailField setHidden:NO];
    [detailOutlineView expandItem:nil
                   expandChildren:YES];
    [bxAppTableView setDoubleAction:@selector(handleBxAppTableDoubleClick:)];
    [self checkForUpdates:nil];
    [_bxAppTable syncApps];
    [bxAppTableView reloadData];    
}

- (id)updateLog {
    if (_logCommand != nil && [logWindow isVisible]) {
        NSTask *task = [[NSTask alloc] init];
        NSPipe *pipe = [[NSPipe alloc] init];
        [task setStandardOutput:pipe];
        [task setLaunchPath:@"/bin/sh"];
        NSArray *args = [NSArray arrayWithObjects:@"-c",
                         _logCommand, nil];
        [task setArguments:args];
        [task launch];
        NSFileHandle *handle = [pipe fileHandleForReading];
        NSString *log = [[[NSString alloc] initWithData:[handle readDataToEndOfFile]
                                               encoding:NSUTF8StringEncoding] autorelease];\
        [logTextView setString:log];
        [pipe release];
        [task terminate];
        [task release];
        
    }
    return self;
}

- (IBAction)modeChanged:(id)sender {
    if ([modeSegmentedControl selectedSegment] == 0) {
        [modeTabView selectTabViewItemAtIndex:0];
        [_bxAppTable syncApps];
        [bxAppTableView reloadData];
    } else if ([modeSegmentedControl selectedSegment] == 1) {
        [modeTabView selectTabViewItemAtIndex:1];        
    }
}

- (IBAction)visitApp:(id)sender {
    int row = [bxAppTableView selectedRow];
    if (row >= 0 && row < [_bxAppTable.apps count]) {
        Location *location = [_bxAppTable.apps objectAtIndex:row];
        if (location.patternStyle == BX_PATTERN_END) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[self pathForServer:location.server]]];
        } else {
            NSString *path = [NSString stringWithFormat:@"%@/%@",
                              [self pathForServer:location.server],
                              location.pattern];
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:path]];                
        }
    }
}
    
- (NSString *)pathForServer:(Server *)server {
    NSMutableString *result = [NSMutableString stringWithCapacity:32];
    if (server.sslEnabled) {
        [result appendString:@"https://"];
    } else {
        [result appendString:@"http://"];
    }
    if ([server.hostnames count] == 0 ||
        ([server.hostnames count] == 1 &&
         [[server.hostnames objectAtIndex:0] length] < 2)) {
            if ([server.ipAddresses count] == 0 ||
                [[server.ipAddresses objectAtIndex:0] length] < 2) {
                [result appendString:@"127.0.0.1"];
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
    return result;
}

- (IBAction)visitPressed:(id)sender {
    if (sender == visitDebugButton) {
        NSString *path = [NSString stringWithFormat:@"http://127.0.0.1:%d", controller.model.debugPort];
        if ([[self currentEvent] modifierFlags] & NSCommandKeyMask) {            
            if (_logCommand != nil) {
                [_logCommand release];
            }
            NSString *defaultLog = [controller.supportPath stringByAppendingPathComponent:@"logs/bombax.log"];
            _logCommand = [[NSString stringWithFormat:@"tail -n 10000 -r '%@' | grep '%@' | head -n 1000", defaultLog, path] retain]; 
            [logWindow makeKeyAndOrderFront:sender];
            [self updateLog];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:path]];
        }
    } else {
        int panelIndex = [detailTabView indexOfTabViewItem:[detailTabView selectedTabViewItem]];
        if (panelIndex == 0) { // server
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[self pathForServer:_editedServer]]];    
        } else if (_editedLocation != nil) {
            NSString *path;
            if (_editedLocation.locationType == BX_LOCATION_STATIC) {
                path = [NSString stringWithFormat:@"%@/%@/",
                                  [self pathForServer:_editedLocation.server],
                                  _editedLocation.pattern];                
            } else {
                path = [NSString stringWithFormat:@"%@/%@",
                                  [self pathForServer:_editedLocation.server],
                                  _editedLocation.pattern];
            }
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:path]];    
        }
    }
}

- (id)markTransaction {
    if (_originalModel == nil) {
        _originalModel = [[controller.model copy] retain];
        [applyButton setEnabled:YES];
        [revertButton setEnabled:YES];
    }
    return self;
}

- (id)updateFromModel {
    Model *model = controller.model;
    if (_originalModel != nil) {
        model.debugPort = _originalModel.debugPort;
        model.isDebugEnabled = _originalModel.isDebugEnabled;
        model.isRunning = _originalModel.isRunning;
        model.runningSince = _originalModel.runningSince;
        [model.servers removeAllObjects];
        for (Server *server in _originalModel.servers) {
            [model.servers addObject:server];
        }
        [_originalModel release];
        _originalModel = nil;
    }
    [enableDebugCheckButton setState:(model.isDebugEnabled ? NSOnState : NSOffState)];
    [debugPortField setIntegerValue:model.debugPort];
    if (model.isRunning) {
        [startButton setTitle:NSLocalizedString(@"Stop Bombax", nil)];
    } else {
        [startButton setTitle:NSLocalizedString(@"Start Bombax", nil)];
    }
    
    [self updateStats];
    
    [detailOutlineView reloadData];
    if ([controller.model.servers count] == 0) {
        [self displayServer:nil];
        [detailOutlineView deselectAll:self];
    } else {
        [self displayServer:[controller.model.servers objectAtIndex:0]];
        [detailOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
                       byExtendingSelection:NO];
    }
    [detailOutlineView expandItem:nil
                   expandChildren:YES];
    
    [applyButton setEnabled:NO];
    [revertButton setEnabled:NO];
    
    [_bxAppTable syncApps];
    [bxAppTableView reloadData];
    
    if (_statsTimer == nil) {
        _statsTimer = [NSTimer scheduledTimerWithTimeInterval:7.2
                                                       target:self
                                                     selector:@selector(statTimerUpdate:)
                                                     userInfo:nil
                                                      repeats:YES];
    }
    
    return self;
}

- (id)saveToModel:(BOOL)ignoreError {
    NSString *error = [controller reloadBombax:YES];
    if (error && !ignoreError) {
        NSRunAlertPanel(NSLocalizedString(@"Configuration Error", nil), error, NSLocalizedString(@"OK", nil), nil, nil);
    } else {
        if (_originalModel != nil) {
            [_originalModel release];
            _originalModel = nil;
        }
        [controller saveConfig];

        [applyButton setEnabled:NO];
        [revertButton setEnabled:NO];
    }        
    return self;
}

- (id)clearDisplay {
    _editedLocation = nil;
    _editedServer = nil;    
    [noDetailField setHidden:NO];
    [detailTabView setHidden:YES];
    [deleteLocationButton setEnabled:NO];
    [deleteServerButton setEnabled:NO];
    return self;
}

- (id)displayServer:(Server *)server {
    _editedServer = server;
    if (server == nil) {
        return [self clearDisplay];
    }
    _editedLocation = nil;
    [noDetailField setHidden:YES];
    [detailTabView selectTabViewItemAtIndex:0];
    [detailTabView setHidden:NO];
    
    [hostnameField setStringValue:[server.hostnames componentsJoinedByString:@"\n"]];
    [portField setStringValue:[server.ports componentsJoinedByString:@" "]];
    [ipAddressField setStringValue:[server.ipAddresses componentsJoinedByString:@"\n"]];
    [serverNotesField setStringValue:server.notes];
    if (server.sslEnabled) {
        [useSslCheckButton selectItemWithTitle:NSLocalizedString(@"Enabled", nil)];
    } else {
        [useSslCheckButton selectItemWithTitle:NSLocalizedString(@"Disabled", nil)];
    }
    if ([server.logPath isEqualToString:@""]) {
        [logPathControl setURL:[NSURL fileURLWithPath:[Controller defaultLogPath]]];
    } else {
        [logPathControl setURL:[NSURL fileURLWithPath:server.logPath]];
    }
    if ([server.sslCertificatePath isEqualToString:@""]) {
        [certificatePathControl setURL:[NSURL fileURLWithPath:controller.defaultSslPath]];
    } else {
        [certificatePathControl setURL:[NSURL fileURLWithPath:server.sslCertificatePath]];
    }
    if ([server.sslCertificateKeyPath isEqualToString:@""]) {
        [keyPathControl setURL:[NSURL fileURLWithPath:controller.defaultSslPath]];
    } else {
        [keyPathControl setURL:[NSURL fileURLWithPath:server.sslCertificateKeyPath]];
    }    
    [deleteLocationButton setEnabled:NO];
    [deleteServerButton setEnabled:YES];    
    return self;
}

- (id)displayLocation:(Location *)location {
    _editedLocation = location;
    if (location == nil) {
        return [self clearDisplay];
    }
    _editedServer = nil;
    [noDetailField setHidden:YES];
    [detailTabView setHidden:NO];
    
    if (location.locationType == BX_LOCATION_BXAPP) {
        [detailTabView selectTabViewItemAtIndex:1];
        [bxAppPathControl setURL:[NSURL fileURLWithPath:location.path]];
        [patternStylePopupButton selectItemWithTitle:[Location patternStyleString:location.patternStyle]];
        [patternField setStringValue:location.pattern];
        if (location.watchdogEnabled) {
            [watchdogCheckButton selectItemAtIndex:0];
        } else {
            [watchdogCheckButton selectItemAtIndex:1];
        }
        [processField setIntegerValue:location.processes];
        [threadsField setIntegerValue:location.threads];
        [loadBalancingPopupButton selectItemWithTitle:[Location loadBalancingString:location.loadBalancing]];
        [bxAppNotesField setStringValue:location.notes];
        [self loadAppInfo];
    } else if (location.locationType == BX_LOCATION_STATIC) {
        [detailTabView selectTabViewItemAtIndex:2];
        [staticPathControl setURL:[NSURL fileURLWithPath:location.path]];
        [staticPatternTypeButton selectItemWithTitle:[Location patternStyleString:location.patternStyle]];
        [staticPatternField setStringValue:location.pattern];
        [staticNotesField setStringValue:location.notes];
    } else {
        [detailTabView selectTabViewItemAtIndex:3];
        [fastcgiPathControl setURL:[NSURL fileURLWithPath:location.path]];
        [fastcgiPatternTypeButton selectItemWithTitle:[Location patternStyleString:location.patternStyle]];
        [fastcgiPatternField setStringValue:location.pattern];
        [fastcgiNotesField setStringValue:location.notes];
    }
    [deleteLocationButton setEnabled:YES];
    [deleteServerButton setEnabled:NO];

    
     
    return self;
    
    if (location == nil) {
        [patternStylePopupButton setTitle:[Location patternStyleString:BX_PATTERN_START]];
        [patternField setStringValue:@""];
        [locationTypePopupButton setTitle:[Location locationTypeString:BX_LOCATION_STATIC]];
        [locationPathField setStringValue:controller.defaultStaticPath];
        [loadBalancingPopupButton setTitle:[Location loadBalancingString:BX_LOAD_ROUNDROBIN]];
        [processField setIntValue:1];
        [threadsField setIntValue:4];
        [patternStylePopupButton setEnabled:NO];
        [patternField setEnabled:NO];
        [locationTypePopupButton setEnabled:NO];
        [locationPathField setEnabled:NO];
        [loadBalancingPopupButton setEnabled:NO];
        [processField setEnabled:NO];
        [threadsField setEnabled:NO];
        [configBxAppButton setEnabled:NO];
        [authorUrlBxAppButton setEnabled:NO];
        [locationTableView deselectAll:self];
        [deleteLocationButton setEnabled:NO];
        [watchdogCheckButton setHidden:YES];
    } else {
        [patternStylePopupButton setTitle:[Location patternStyleString:location.patternStyle]];
        [patternField setStringValue:location.pattern];
        [locationTypePopupButton setTitle:[Location locationTypeString:location.locationType]];
        if ([location.path isEqualToString:@""]) {
            if (location.locationType == BX_LOCATION_BXAPP) {
                [locationPathField setStringValue:controller.defaultBxAppPath];
            } else if (location.locationType == BX_LOCATION_FASTCGI) {
                [locationPathField setStringValue:controller.defaultCgiPath];
            } else {
                [locationPathField setStringValue:controller.defaultStaticPath];
            }
        } else {
            [locationPathField setStringValue:location.path];
        }
        if (location.locationType == BX_LOCATION_BXAPP) {
            [loadBalancingPopupButton setEnabled:YES];
            [processField setEnabled:YES];
            [threadsField setEnabled:YES];
            [configBxAppButton setEnabled:YES];
            [authorUrlBxAppButton setEnabled:YES];
            [watchdogCheckButton setHidden:NO];
            [watchdogCheckButton setState:location.watchdogEnabled ? NSOnState : NSOffState];
        } else {
            [watchdogCheckButton setHidden:YES];
            [loadBalancingPopupButton setEnabled:NO];
            [processField setEnabled:NO];
            [threadsField setEnabled:NO];
            [configBxAppButton setEnabled:NO];
            [authorUrlBxAppButton setEnabled:NO];                
        }
        [loadBalancingPopupButton setTitle:[Location loadBalancingString:location.loadBalancing]];
        [processField setIntegerValue:location.processes];
        [threadsField setIntegerValue:location.threads];
        [patternStylePopupButton setEnabled:YES];
        [patternField setEnabled:YES];
        [locationTypePopupButton setEnabled:YES];
        [locationPathField setEnabled:YES];
        [deleteLocationButton setEnabled:YES];
    }
    [self loadAppInfo];
    return self;
}



- (NSString *)showSaveWithPath:(NSString *)startingPath
                   defaultPath:(NSString *)defaultPath {
    BOOL isDir = NO;
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setAllowsOtherFileTypes:YES];
    [savePanel setCanCreateDirectories:YES];
    if ([[NSFileManager defaultManager] fileExistsAtPath:startingPath isDirectory:&isDir]) {
        if (isDir) {
            if ([savePanel runModalForDirectory:startingPath file:nil] == NSFileHandlingPanelOKButton) {
                return [[savePanel URL] path];
            } else {
                return startingPath;
            }
        } else {
            if ([savePanel runModalForDirectory:[startingPath stringByDeletingLastPathComponent]
                                           file:[startingPath lastPathComponent]] == NSFileHandlingPanelOKButton) {
                return [[savePanel URL] path];
            } else {
                return startingPath;
            }
        }
    } else if (defaultPath != nil) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:defaultPath isDirectory:&isDir]) {
            if (isDir) {
                if ([savePanel runModalForDirectory:defaultPath file:nil] == NSFileHandlingPanelOKButton) {
                    return [[savePanel URL] path];
                } else {
                    return startingPath;
                }
            } else {
                if ([savePanel runModalForDirectory:[defaultPath stringByDeletingLastPathComponent]
                                               file:[defaultPath lastPathComponent]] == NSFileHandlingPanelOKButton) {
                    return [[savePanel URL] path];
                } else {
                    return startingPath;
                }
            }
        } else {
            NSLog(@"Invalid default path: %@", defaultPath);
            return startingPath;
        }
    } else {
        return startingPath;
    }    
}

- (IBAction)addLocationPressed:(id)sender {
    Server *server = nil;
    if (_editedLocation == nil) {
        server = _editedServer;
    } else {
        server = _editedLocation.server;
    }
    if (server == nil) {
        if ([controller.model.servers count] == 0) {
            return;
        } else {
            server = [controller.model.servers objectAtIndex:0];
        }
    }
    [self markTransaction];
    Location *location = [[Location alloc] init];
    location.server = server;
    location.path = [controller defaultStaticPath];
    [server.locations addObject:location];
    [detailOutlineView reloadData];
    [detailOutlineView expandItem:server];
    int row = [detailOutlineView rowForItem:location];
    [detailOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                   byExtendingSelection:NO];
    [self displayLocation:location];
}

- (IBAction)addServerPressed:(id)sender {
    [self markTransaction];
    Server *server = [[Server alloc] init];
    [controller.model.servers addObject:server];
    [detailOutlineView reloadData];
    int row = [detailOutlineView rowForItem:server];
    [detailOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                   byExtendingSelection:NO];
    [self displayServer:server];
}

- (IBAction)applyPressed:(id)sender {
    [self saveToModel:NO];
}

- (IBAction)authorUrlPressed:(id)sender {
    if (_editedLocation != nil &&
        [_editedLocation.appAuthorUrl length] > 0 &&
        ! [_editedLocation.appAuthorUrl isEqualToString:@"n/a"]) {
        if ([_editedLocation.appAuthorUrl rangeOfString:@":"].location == NSNotFound) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[@"http://" stringByAppendingString:_editedLocation.appAuthorUrl]]];
        } else {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:_editedLocation.appAuthorUrl]];
        }
    }
}

- (IBAction)configPressed:(id)sender {
    if (_editedLocation == nil || _editedLocation.locationType != BX_LOCATION_BXAPP) {
        return;
    }
    NSString *appPath = nil;
    NSRange range = [_editedLocation.path rangeOfString:@".app"];
    if (range.location == NSNotFound) {
        return;
    } else if ([_editedLocation.path length] == range.location - 4) {
        appPath = _editedLocation.path;
    } else {
        appPath = [_editedLocation.path substringToIndex:range.location + 4];
    }
    system([[NSString stringWithFormat:@"/usr/bin/open \"/%@\" --args -config 1 &", appPath] UTF8String]);
}

- (IBAction)createBxAppPressed:(id)sender {
    // tbd
}

- (IBAction)deleteLocationPressed:(id)sender {
    if (_editedLocation == nil) {
        return;
    }
    [self markTransaction];
    if (NSRunAlertPanel(NSLocalizedString(@"Please Confirm", nil), NSLocalizedString(@"Are you sure you want to delete this location?", nil), NSLocalizedString(@"Cancel", nil), NSLocalizedString(@"Delete", nil), nil) == NSAlertAlternateReturn) {
        [_editedLocation.server.locations removeObject:_editedLocation];
        [detailOutlineView reloadData];
        [detailOutlineView deselectAll:self];
        [self clearDisplay];
    }
}

- (IBAction)deleteServerPressed:(id)sender {
    if (_editedServer == nil) {
        return;
    }
    [self markTransaction];
    if (NSRunAlertPanel(NSLocalizedString(@"Please Confirm", nil), NSLocalizedString(@"Are you sure you want to delete this server?", nil), NSLocalizedString(@"Cancel", nil), NSLocalizedString(@"Delete", nil), nil) == NSAlertAlternateReturn) {
        [controller.model.servers removeObject:_editedServer];
        [detailOutlineView reloadData];
        [detailOutlineView deselectAll:self];
        [self clearDisplay];
    }
}

- (IBAction)locationPathPressed:(id)sender {
    if (_editedLocation == nil) {
        return;
    }
    [self markTransaction];
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:NO];
    if (_editedLocation.locationType == BX_LOCATION_BXAPP) {
        [openPanel setCanCreateDirectories:YES];
        [openPanel setCanChooseDirectories:NO];
        [openPanel setCanChooseFiles:YES];
        if ([openPanel runModalForDirectory:[_editedLocation.path stringByDeletingLastPathComponent]
                                       file:[_editedLocation.path lastPathComponent]
                                      types:nil] == NSCancelButton) {
            return;
        }
    } else if (_editedLocation.locationType == BX_LOCATION_FASTCGI) {
        [openPanel setCanCreateDirectories:YES];
        [openPanel setCanChooseDirectories:NO];
        [openPanel setCanChooseFiles:YES];
        if ([openPanel runModalForDirectory:[_editedLocation.path stringByDeletingLastPathComponent]
                                       file:[_editedLocation.path lastPathComponent]
                                      types:nil] == NSCancelButton) {
            return;
        }
    } else {
        [openPanel setCanCreateDirectories:YES];
        [openPanel setCanChooseDirectories:YES];
        [openPanel setCanChooseFiles:NO];
        if ([openPanel runModalForDirectory:_editedLocation.path
                                       file:nil
                                      types:nil] == NSCancelButton) {
            return;
        }
    }
    NSURL *url = [[openPanel URLs] objectAtIndex:0];
    if (url) {
        _editedLocation.path = [url path];
        [sender setURL:url];
        if (_editedLocation.locationType == BX_LOCATION_BXAPP) {
            [self loadAppInfo];
        }
    }
    [detailOutlineView reloadData];
}

- (IBAction)logPathPressed:(id)sender {
    if (_editedServer == nil) {
        return;
    }
    [self markTransaction];
    _editedServer.logPath = [self showSaveWithPath:_editedServer.logPath
               defaultPath:[Controller defaultLogPath]];
    [logPathControl setURL:[NSURL fileURLWithPath:_editedServer.logPath]];
}

- (IBAction)revertPressed:(id)sender {
    [self updateFromModel];
}

- (IBAction)sslCertKeyPathPressed:(id)sender {
    if (_editedServer == nil) {
        return;
    }
    [self markTransaction];
    _editedServer.sslCertificateKeyPath = [self showSaveWithPath:_editedServer.sslCertificateKeyPath
                                                     defaultPath:controller.defaultSslPath];
    [keyPathControl setURL:[NSURL fileURLWithPath:_editedServer.sslCertificateKeyPath]];
}

- (IBAction)sslCertPathPressed:(id)sender {
    if (_editedServer == nil) {
        return;
    }
    [self markTransaction];
    _editedServer.sslCertificatePath = [self showSaveWithPath:_editedServer.sslCertificatePath
                                                  defaultPath:controller.defaultSslPath];
    [certificatePathControl setURL:[NSURL fileURLWithPath:_editedServer.sslCertificatePath]];
}

- (IBAction)startPressed:(id)sender {
    if (_originalModel != nil) {
        if (NSRunAlertPanel(NSLocalizedString(@"Apply Changes?", nil), NSLocalizedString(@"Would you like to apply these changes before proceeding?", nil), NSLocalizedString(@"Apply", nil), NSLocalizedString(@"Cancel", nil), nil) == NSAlertAlternateReturn) {
            return;
        }
    }
    [self saveToModel:YES];
    if (controller.model.isRunning) {
        [controller stopBombax:YES];
    } else {
        NSString *error = [controller startBombax:YES];
        if (error != nil) {
            NSRunAlertPanel(@"Error Starting Server", error, NSLocalizedString(@"OK", nil), nil, nil);
        }
    }
    [controller updateProcessInfos];
    [self updateStats];
}

- (IBAction)viewLogsPressed:(id)sender {
    if ([detailTabView isHidden]) {
        return;
    }
    if (_logCommand != nil) {
        [_logCommand release];
    }
    int index = [detailTabView indexOfTabViewItem:[detailTabView selectedTabViewItem]];
    if (index == 0 && _editedServer != nil) {
        _logCommand = [[NSString stringWithFormat:@"tail -n 10000 -r '%@' | head -n 1000", _editedServer.logPath] retain]; 
    } else if (_editedLocation != nil) {
        if (_editedLocation.patternStyle == BX_PATTERN_END) {
            _logCommand = [[NSString stringWithFormat:@"tail -n 10000 -r '%@' | grep '%@' | head -n 1000", _editedLocation.server.logPath, _editedLocation.pattern] retain]; 
        } else {
            NSString *pattern = [_editedLocation.pattern hasPrefix:@"/"] ? _editedLocation.pattern : [NSString stringWithFormat:@"/%@", _editedLocation.pattern];
            _logCommand = [[NSString stringWithFormat:@"tail -n 10000 -r '%@' | grep ' %@' | head -n 1000", _editedLocation.server.logPath, pattern] retain]; 
        }
    }
    [logWindow makeKeyAndOrderFront:sender];
    [self updateLog];
}

- (IBAction)enableDebugChanged:(id)sender {
    [self markTransaction];
    controller.model.isDebugEnabled = !controller.model.isDebugEnabled;
}

- (IBAction)enableSslChanged:(id)sender {
    if (_editedServer == nil) {
        return;
    }
    [self markTransaction];
    _editedServer.sslEnabled = !_editedServer.sslEnabled;
    [detailOutlineView reloadData];
}

- (IBAction)loadBalancingChanged:(id)sender {
    if (_editedLocation == nil) {
        return;
    }
    [self markTransaction];
    NSString *loadBalancing = [[loadBalancingPopupButton selectedItem] title];
    if ([loadBalancing isEqualToString:[Location loadBalancingString:BX_LOAD_ROUNDROBIN]]) {
        _editedLocation.loadBalancing = BX_LOAD_ROUNDROBIN;
    } else {
        _editedLocation.loadBalancing = BX_LOAD_HASHIP;
    }
}

- (IBAction)locationTypeChanged:(id)sender {
    static BOOL isChanging = NO;
    if (isChanging) {
        return;
    } else {
        isChanging = YES;
    }
    if (_editedLocation == nil) {
        return;
    }
    [self markTransaction];
    NSPopUpButton *popup = (NSPopUpButton *) sender;
    NSString *locationType = [[popup selectedItem] title];
    if ([locationType isEqualToString:[Location locationTypeString:BX_LOCATION_BXAPP]]) {
        _editedLocation.locationType = BX_LOCATION_BXAPP;
    } else if ([locationType isEqualToString:[Location locationTypeString:BX_LOCATION_FASTCGI]]) {
        _editedLocation.locationType = BX_LOCATION_FASTCGI;
    } else {
        _editedLocation.locationType = BX_LOCATION_STATIC;
    }
    [bxAppTypeSwitcher selectItemAtIndex:0];
    [staticTypeSwitcher selectItemAtIndex:1];
    [fastcgiTypeSwitcher selectItemAtIndex:2];
    [detailOutlineView reloadData];
    [self displayLocation:_editedLocation];
    isChanging = NO;
}

- (IBAction)closeApp:(id)sender {
    if (_originalModel != nil) {
        if (NSRunAlertPanel(NSLocalizedString(@"Please Confirm", nil),
                            NSLocalizedString(@"You have changes that haven't been applied. Are you sure you want to exit without applying these changes?", nil),
                            @"Cancel",
                            @"Exit Anyways",
                            nil) == NSAlertDefaultReturn) {
            return;
        }
    }
    [[NSApplication sharedApplication] terminate:self];
}

- (IBAction)checkForUpdates:(id)sender {
    NSError *error = nil;
    NSString *updateResult;
    if (_registeredTo) {
        updateResult = [NSString stringWithContentsOfURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.bombaxtic.com/bombax/latest-version/?id=%@", [[NSUserDefaults standardUserDefaults] stringForKey:@"registration"]]]
                                                      encoding:NSUTF8StringEncoding
                                                         error:&error];
    } else {
        updateResult = [NSString stringWithContentsOfURL:[NSURL URLWithString:@"http://www.bombaxtic.com/bombax/latest-version"]
                                                      encoding:NSUTF8StringEncoding
                                                         error:&error];
    }
    if (error) {
//        NSRunAlertPanel(NSLocalizedString(@"Error Checking Update", nil),
//                        [NSString stringWithFormat:NSLocalizedString(@"Unable to check version. Error: '%@'", nil), [error localizedDescription]],
//                        NSLocalizedString(@"OK", nil),
//                        nil,
//                        nil);
        return;
    }
    updateResult = [updateResult stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (! [updateResult isEqualToString:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]] && [updateResult length] < 16) {
        if (NSRunAlertPanel(NSLocalizedString(@"New Version Available", nil),
                            [NSString stringWithFormat:NSLocalizedString(@"Version %@ of Bombax is available. Would you like to update now?", nil), updateResult],
                            NSLocalizedString(@"Download Update", nil),
                            NSLocalizedString(@"Not Yet", nil),
                            nil) == NSAlertDefaultReturn) {
            [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.bombaxtic.com/bombax/download"]];
        }
    } else if (sender != nil) {
        NSRunAlertPanel(NSLocalizedString(@"No Updates Available", nil),
                        NSLocalizedString(@"You are using the latest version of Bombax.", nil),
                        NSLocalizedString(@"OK", nil),
                        nil,
                        nil);
    }
}

- (IBAction)contactSupport:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.bombaxtic.com/support"]];
}

- (IBAction)showAboutWindow:(id)sender {
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel:sender];
}

- (IBAction)showBombaxticCom:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.bombaxtic.com"]];
}


- (IBAction)patternStyleChanged:(id)sender {
    if (_editedLocation == nil) {
        return;
    }
    [self markTransaction];
    NSPopUpButton *popup = (NSPopUpButton *) sender;
    NSString *patternStyle = [[popup selectedItem] title];
    if ([patternStyle isEqualToString:[Location patternStyleString:BX_PATTERN_END]]) {
        _editedLocation.patternStyle = BX_PATTERN_END;
    } else {
        _editedLocation.patternStyle = BX_PATTERN_START;
    }
    [detailOutlineView reloadData];
}

- (IBAction)watchdogCheckChanged:(id)sender {
    if (_editedLocation == nil) {
        return;
    }
    [self markTransaction];
    _editedLocation.watchdogEnabled = !_editedLocation.watchdogEnabled;
}

- (BOOL)control:(NSControl *)control
textShouldEndEditing:(NSText *)fieldEditor {
    [self markTransaction];
    if (control == debugPortField) {
        int debugPort = [debugPortField intValue];
        if (debugPort <= 0 || debugPort > 65535) {
            NSRunAlertPanel(NSLocalizedString(@"Invalid Port", nil), NSLocalizedString(@"Port numbers must be between 1 and 65535", nil), NSLocalizedString(@"OK", nil), nil, nil);
            return NO;
        }
        controller.model.debugPort = debugPort;
    } else if (control == hostnameField) {
        if (_editedServer == nil) {
            return NO;
        }
        NSArray *hostnames = [[hostnameField stringValue] componentsSeparatedByCharactersInSet:dividerCharacterSet];
        [_editedServer.hostnames removeAllObjects];
        [_editedServer.hostnames addObjectsFromArray:hostnames];
        [detailOutlineView reloadData];
    } else if (control == ipAddressField) {
        if (_editedServer == nil) {
            return NO;
        }
        NSArray *ipAddresses = [[ipAddressField stringValue] componentsSeparatedByCharactersInSet:dividerCharacterSet];
        [_editedServer.ipAddresses removeAllObjects];
        [_editedServer.ipAddresses addObjectsFromArray:ipAddresses];
        [detailOutlineView reloadData];
    } else if (control == serverNotesField) {
        if (_editedServer == nil) {
            return NO;
        }
        _editedServer.notes = [serverNotesField stringValue];
        [detailOutlineView reloadData];
    } else if (control == portField) {
        if (_editedServer == nil) {
            return NO;
        }
        NSArray *ports = [[portField stringValue] componentsSeparatedByCharactersInSet:dividerCharacterSet];
        [_editedServer.ports removeAllObjects];
        for (NSString *port in ports) {
            int portVal = [port intValue];
            if (portVal > 0 && portVal < 65536) {
                [_editedServer.ports addObject:port];
            }
        }
        [detailOutlineView reloadData];
    } else if (control == patternField ||
               control == staticPatternField ||
               control == fastcgiPatternField) {
        if (_editedLocation == nil) {
            return NO;
        }
        
        _editedLocation.pattern = [[control stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [detailOutlineView reloadData];
    } else if (control == bxAppNotesField ||
               control == staticNotesField ||
               control == fastcgiNotesField) {
        if (_editedLocation == nil) {
            return NO;
        }
        _editedLocation.notes = [control stringValue];
        [detailOutlineView reloadData];
    } else if (control == processField) {
        if (_editedLocation == nil) {
            return NO;
        }
        int processes = [processField integerValue];
        if (processes >= 0) {
            _editedLocation.processes = processes;
        } else {
            NSRunAlertPanel(NSLocalizedString(@"Invalid Value", nil), NSLocalizedString(@"The number or processes must be 0 (to disable) or positive", nil), NSLocalizedString(@"OK", nil), nil, nil);            
        }
    } else if (control == threadsField) {
        if (_editedLocation == nil) {
            return NO;
        }
        int threads = [threadsField integerValue];
        if (threads > 0) {
            _editedLocation.threads = threads;
        } else {
            NSRunAlertPanel(NSLocalizedString(@"Invalid Value", nil), NSLocalizedString(@"The number or threads per process must be at least 1", nil), NSLocalizedString(@"OK", nil), nil, nil);                        
        }
    } else if (control == logPathField) {
        if (_editedServer == nil) {
            return NO;
        }
        _editedServer.logPath = [logPathField stringValue];
    } else if (control == sslCertPathField) {
        if (_editedServer == nil) {
            return NO;
        }
        _editedServer.sslCertificatePath = [sslCertPathField stringValue];
    } else if (control == sslCertKeyPathField) {
        if (_editedServer == nil) {
            return NO;
        }
        _editedServer.sslCertificateKeyPath = [sslCertKeyPathField stringValue];
    } else if (control == locationPathField) {
        if (_editedLocation == nil) {
            return NO;
        }
        _editedLocation.path = [locationPathField stringValue];
        [detailOutlineView reloadData];
    }
    return YES;
}

- (id)updateStats {
    [cpuField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%0.1f%%", nil), controller.model.cpuUsage]];
    [ramField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%0.1f%%", nil), controller.model.ramUsage]];
    if (controller.model.isRunning) {
        int since = (int) ([NSDate timeIntervalSinceReferenceDate] - controller.model.runningSince);
        int seconds = since % 60;
        int minutes = since / 60 % 60;
        int hours = since / 3600 % 24;
        int days = since / 86400;
        [uptimeField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"%dd %02d:%02d:%02d", nil), days, hours, minutes, seconds]];
        if (! _wasRunning) {
            [bigIconImageView setAlphaValue:1];
            [startButton setTitle:NSLocalizedString(@"Stop Server", nil)];
            [statusTextField setStringValue:NSLocalizedString(@"Running", nil)];
            [statusImageView setImage:[NSImage imageNamed:@"yellow"]];
            _wasRunning = YES;
        }
    } else {
        [uptimeField setStringValue:NSLocalizedString(@"n/a", nil)];
        if (_wasRunning) {
            [bigIconImageView setAlphaValue:0.4];
            [statusImageView setImage:[NSImage imageNamed:@"red"]];
            [statusTextField setStringValue:NSLocalizedString(@"Stopped", nil)];
            [startButton setTitle:NSLocalizedString(@"Start Server", nil)];
            _wasRunning = NO;
        }
    }
    return self;
}

- (id)loadAppInfo {
    if (_editedLocation != nil && _editedLocation.locationType == BX_LOCATION_BXAPP) {
        [_editedLocation updateAppInfo];
        [bxAppNameField setStringValue:_editedLocation.appName];
        [bxAppInfoField setStringValue:_editedLocation.appDescription];
        [bxAppVersionField setStringValue:_editedLocation.appVersion];
        [bxAppAuthorField setStringValue:_editedLocation.appAuthor];
        [bxAppAuthorURLField setStringValue:_editedLocation.appAuthorUrl];
        [bxAppIconView setImage:_editedLocation.appIcon];
    }
    return self;
}

- (void)statTimerUpdate:(NSTimer *)timer {
    [controller updateProcessInfos];
    [self updateStats];
    [bxAppTableView reloadData];
    [graphView setNeedsDisplay:YES];
    [self updateLog];
}

- (BOOL)windowShouldClose:(id)sender {
    [self closeApp:self];
    return NO;
}

@end
