#import <Cocoa/Cocoa.h>

@interface Server : NSObject <NSCopying> {
    BOOL _sslEnabled;
    NSMutableArray *_ipAddresses;
    NSMutableArray *_hostnames;
    NSMutableArray *_ports;
    NSString *_logPath;
    NSString *_sslCertificatePath;
    NSString *_sslCertificateKeyPath;
    NSMutableArray *_locations;
    NSString *_notes;
}

@property (nonatomic, assign) BOOL sslEnabled;
@property (readonly) NSMutableArray *ipAddresses;
@property (readonly) NSMutableArray *hostnames;
@property (readonly) NSMutableArray *ports;
@property (nonatomic, copy) NSString *logPath;
@property (nonatomic, copy) NSString *sslCertificatePath;
@property (nonatomic, copy) NSString *sslCertificateKeyPath;
@property (nonatomic, copy) NSString *notes;
@property (readonly) NSMutableArray *locations;

@end
