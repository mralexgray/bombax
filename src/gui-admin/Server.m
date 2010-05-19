#import "Server.h"
#import "Location.h"
#import "Controller.h"

@implementation Server

@synthesize sslEnabled = _sslEnabled;
@synthesize ipAddresses = _ipAddresses;
@synthesize hostnames = _hostnames;
@synthesize ports = _ports;
@synthesize logPath = _logPath;
@synthesize sslCertificatePath = _sslCertificatePath;
@synthesize sslCertificateKeyPath = _sslCertificateKeyPath;
@synthesize locations = _locations;
@synthesize notes = _notes;

- (id)init {
    _sslEnabled = NO;
    self.notes = @"";
    _ipAddresses = [[NSMutableArray alloc] initWithCapacity:4];
    _hostnames = [[NSMutableArray alloc] initWithCapacity:4];
    _ports = [[NSMutableArray alloc] initWithCapacity:4];
    _logPath = [[Controller defaultLogPath] retain];
    _sslCertificatePath = [NSHomeDirectory() retain];
    _sslCertificateKeyPath = [NSHomeDirectory() retain];
    _locations = [[NSMutableArray alloc] initWithCapacity:4];
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    Server *copy = [[Server alloc] init];
    copy.sslEnabled = _sslEnabled;
    copy.logPath = _logPath;
    copy.sslCertificatePath = _sslCertificatePath;
    copy.sslCertificateKeyPath = _sslCertificateKeyPath;
    copy.notes = _notes;
    for (NSString *ipAddress in _ipAddresses) {
        [copy.ipAddresses addObject:ipAddress];
    }
    for (NSString *hostname in _hostnames) {
        [copy.hostnames addObject:hostname];
    }
    for (NSString *port in _ports) {
        [copy.ports addObject:port];
    }
    for (Location *location in _locations) {
        [copy.locations addObject:[location copyWithZone:zone]];
    }
    return copy;
}

- (void)dealloc {
    [_ipAddresses release];
    [_hostnames release];
    [_ports release];
    [_locations release];
    [_logPath release];
    [_notes release];
    [_sslCertificatePath release];
    [_sslCertificateKeyPath release];
    [super dealloc];    
}

@end
