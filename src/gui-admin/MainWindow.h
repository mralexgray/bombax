#import <Cocoa/Cocoa.h>
#import "Controller.h"
#import "LocationsTable.h"
#import "ServersTable.h"
#import "GraphView.h"
#import "Location.h"
#import "Server.h"
#import "Model.h"
#import "DetailOutlineTable.h"
#import "BxAppTable.h"

@class Controller;
@class LocationsTable;
@class ServersTable;
@class Server;
@class Location;
@class Model;
@class GraphView;
@class DetailOutlineTable;
@class BxAppTable;

@interface MainWindow : NSWindow {
    IBOutlet NSButton *addLocationButton;
    IBOutlet NSButton *addServerButton;
    IBOutlet NSButton *applyButton;
    IBOutlet NSButton *authorUrlBxAppButton;
    IBOutlet NSButton *configBxAppButton;
    IBOutlet NSButton *createBxAppButton;
    IBOutlet NSButton *deleteLocationButton;
    IBOutlet NSButton *deleteServerButton;
    IBOutlet NSButton *revertButton;
    IBOutlet NSButton *startButton;
    IBOutlet NSButton *viewLogsButton;
    
    IBOutlet NSPopUpButton *enableDebugCheckButton;
    IBOutlet NSPopUpButton *useSslCheckButton;
    IBOutlet NSPopUpButton *watchdogCheckButton;

    IBOutlet NSPopUpButton *loadBalancingPopupButton;
    IBOutlet NSPopUpButton *locationTypePopupButton;
    IBOutlet NSPopUpButton *patternStylePopupButton;
    
    IBOutlet NSButton *locationPathButton;
    IBOutlet NSButton *logPathButton;
    IBOutlet NSButton *sslCertPathButton;
    IBOutlet NSButton *sslCertKeyPathButton;
    
    IBOutlet NSTextField *locationPathField;
    IBOutlet NSTextField *logPathField;
    IBOutlet NSTextField *sslCertKeyPathField;
    IBOutlet NSTextField *sslCertPathField;
        
    IBOutlet NSTableView *locationTableView;
    IBOutlet NSTableView *serverTableView;
    
    IBOutlet NSTextField *cpuField;
    IBOutlet NSTextField *ramField;
    IBOutlet NSTextField *uptimeField;    
    IBOutlet NSTextField *versionField;

    IBOutlet NSTextField *debugPortField;
    IBOutlet NSTextField *hostnameField;
    IBOutlet NSTextField *ipAddressField;
    IBOutlet NSTextField *patternField;
    IBOutlet NSTextField *portField;
    IBOutlet NSTextField *processField;    
    IBOutlet NSTextField *threadsField;
    
    IBOutlet Controller *controller;
    
    // ---- new stuff
    
    IBOutlet NSImageView *statusImageView;
    IBOutlet NSImageView *bigIconImageView;
    IBOutlet NSTextField *statusTextField;
    IBOutlet NSSegmentedControl *modeSegmentedControl;
    IBOutlet NSButton *visitDebugButton;
    IBOutlet NSButton *visitServerButton;
    IBOutlet NSButton *visitBxAppButton;
    IBOutlet NSButton *visitBxAppAuthorButton;
    IBOutlet NSButton *visitStaticButton;
    IBOutlet NSButton *visitFastcgiButton;
    IBOutlet NSButton *viewBxAppLogsButton;
    IBOutlet NSButton *viewStaticLogsButton;
    IBOutlet NSButton *viewFastcgiLogsButton;
    IBOutlet NSPathControl *bxAppPathControl;
    IBOutlet NSPathControl *staticPathControl;
    IBOutlet NSPathControl *fastcgiPathControl;
    IBOutlet NSPathControl *logPathControl;
    IBOutlet NSPathControl *certificatePathControl;
    IBOutlet NSPathControl *keyPathControl;
    IBOutlet NSTextField *serverNotesField;
    IBOutlet NSTextField *bxAppNotesField;
    IBOutlet NSTextField *staticNotesField;
    IBOutlet NSTextField *fastcgiNotesField;
    IBOutlet NSTextField *bxAppNameField;
    IBOutlet NSTextField *bxAppVersionField;
    IBOutlet NSTextField *bxAppAuthorField;
    IBOutlet NSTextField *bxAppAuthorURLField;
    IBOutlet NSTextField *bxAppInfoField;
    IBOutlet NSImageView *bxAppIconView;
    IBOutlet NSPopUpButton *bxAppTypeSwitcher;
    IBOutlet NSPopUpButton *staticTypeSwitcher;
    IBOutlet NSPopUpButton *fastcgiTypeSwitcher;
    IBOutlet NSTabView *modeTabView;
    IBOutlet NSTabView *detailTabView;
    IBOutlet NSTextField *noDetailField;
    IBOutlet NSPopUpButton *staticPatternTypeButton;
    IBOutlet NSPopUpButton *fastcgiPatternTypeButton;
    IBOutlet NSTextField *staticPatternField;
    IBOutlet NSTextField *fastcgiPatternField;
    IBOutlet NSOutlineView *detailOutlineView;
    IBOutlet NSTableView *bxAppTableView;
    IBOutlet GraphView *graphView;
    
    IBOutlet NSWindow *logWindow;
    IBOutlet NSWindow *registrationWindow;
    IBOutlet NSMenuItem *registrationItem;    
    IBOutlet NSTextField *registrationField;
    IBOutlet NSTextView *logTextView;
    NSString *_logCommand;
    
    BxAppTable *_bxAppTable;
    DetailOutlineTable *_detailOutlineTable;
    
    LocationsTable *_locationsTable;
    ServersTable *_serversTable;
    Server *_editedServer;
    Location *_editedLocation;
    Model *_originalModel;
    NSTimer *_statsTimer;
    NSString *_registeredTo;
}
- (IBAction)registerPressed:(id)sender;
- (IBAction)buyNowPressed:(id)sender;
- (IBAction)registrationCancelPressed:(id)sender;
- (IBAction)enterRegistration:(id)sender;
- (IBAction)visitPressed:(id)sender;
- (IBAction)viewLogsPressed:(id)sender;
- (IBAction)modeChanged:(id)sender;
- (IBAction)locationTypeChanged:(id)sender;
- (IBAction)loadBalancingChanged:(id)sender;
- (IBAction)patternStyleChanged:(id)sender;
- (IBAction)watchdogCheckChanged:(id)sender;
- (IBAction)authorUrlPressed:(id)sender;
- (IBAction)visitApp:(id)sender;

- (IBAction)addLocationPressed:(id)sender;
- (IBAction)addServerPressed:(id)sender;
- (IBAction)applyPressed:(id)sender;
- (IBAction)configPressed:(id)sender;
- (IBAction)createBxAppPressed:(id)sender;
- (IBAction)deleteLocationPressed:(id)sender;
- (IBAction)deleteServerPressed:(id)sender;
- (IBAction)locationPathPressed:(id)sender;
- (IBAction)logPathPressed:(id)sender;
- (IBAction)revertPressed:(id)sender;
- (IBAction)sslCertKeyPathPressed:(id)sender;
- (IBAction)sslCertPathPressed:(id)sender;
- (IBAction)startPressed:(id)sender;

- (IBAction)enableDebugChanged:(id)sender;
- (IBAction)enableSslChanged:(id)sender;

- (IBAction)closeApp:(id)sender;
- (IBAction)checkForUpdates:(id)sender;
- (IBAction)showBombaxticCom:(id)sender;
- (IBAction)showAboutWindow:(id)sender;

- (IBAction)contactSupport:(id)sender;

- (NSString *)pathForServer:(Server *)server;

- (id)displayServer:(Server *)server;
- (id)displayLocation:(Location *)location;
- (id)clearDisplay;

- (id)markTransaction;
- (id)updateFromModel;
- (id)saveToModel:(BOOL)ignoreError;

- (id)updateStats;
- (id)loadAppInfo;
- (NSString *)showSaveWithPath:(NSString *)startingPath defaultPath:(NSString *)defaultPath;
- (void)statTimerUpdate:(NSTimer *)timer;

- (id)updateLog;

@property (readonly) Server *editedServer;
@property (readonly) Location *editedLocation;
@property (readonly) Controller *controller;

@end
