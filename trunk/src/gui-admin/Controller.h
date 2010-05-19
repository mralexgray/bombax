#import <Cocoa/Cocoa.h>
#import "ModelReader.h"
#import "ModelWriter.h"
#import "MainWindow.h"
#import "Model.h"
#import "ProcessInfo.h"

@class MainWindow;
@class Model;

@interface Controller : NSObject {
    IBOutlet MainWindow *_mainWindow;
    Model *_model;
    NSString *_defaultStaticPath;
    NSString *_defaultCgiPath;
    NSString *_defaultBxAppPath;
    NSString *_defaultSslPath;
    NSString *_nginxBinPath;
    NSString *_nginxConfPath;
    NSString *_supportPath;
    NSString *_bombaxConfPath;
    NSString *_nginxStderrPath;
    NSMutableArray *_processInfos;
    AuthorizationRef _authRef;
}

+ (Controller *)singleton;

- (NSTimeInterval)convertEtimeString:(NSString *)str;
- (id)updateProcessInfos;
- (NSString *)reloadBombax:(BOOL)affectBxApps;
- (NSString *)startBombax:(BOOL)affectBxApps;
- (NSString *)stopBombax:(BOOL)affectBxApps;
- (NSString *)createNginxConfString;
- (id)writeNginxConf:(NSString *)conf;
- (id)saveConfig;
- (id)saveConfigTo:(NSString *)path;

+ (NSString *)defaultLogPath;

@property (readonly) MainWindow *mainWindow;
@property (readonly) Model *model;
@property (readonly) NSString *defaultStaticPath;
@property (readonly) NSString *defaultCgiPath;
@property (readonly) NSString *defaultBxAppPath;
@property (readonly) NSString *defaultSslPath;
@property (readonly) NSString *nginxConfPath;
@property (readonly) NSString *nginxBinPath;
@property (readonly) NSString *supportPath;
@property (readonly) NSString *bombaxConfPath;
@property (readonly) NSMutableArray *processInfos;

@end
