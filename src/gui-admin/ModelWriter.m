#import "ModelWriter.h"
#import "Server.h"
#import "Location.h"

@implementation ModelWriter

+ (NSXMLDocument *)writeModel:(Model *)model {
    NSXMLElement *root = [NSXMLNode elementWithName:@"bombax"];
    [root addAttribute:[NSXMLNode attributeWithName:@"version"
                                        stringValue:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]];
    NSXMLElement *modelElem = [NSXMLNode elementWithName:@"model"];
    [modelElem addAttribute:[NSXMLNode attributeWithName:@"isDebugEnabled"
                                             stringValue:[NSString stringWithFormat:@"%d", model.isDebugEnabled]]];
    [modelElem addAttribute:[NSXMLNode attributeWithName:@"debugPort"
                                             stringValue:[NSString stringWithFormat:@"%d", model.debugPort]]];
    for (Server *server in model.servers) {
        NSXMLElement *serverElem = [NSXMLNode elementWithName:@"server"];
        [serverElem addAttribute:[NSXMLNode attributeWithName:@"logPath"
                                                  stringValue:server.logPath]];
        [serverElem addAttribute:[NSXMLNode attributeWithName:@"sslEnabled"
                                                  stringValue:[NSString stringWithFormat:@"%d", server.sslEnabled]]];
        [serverElem addAttribute:[NSXMLNode attributeWithName:@"sslCertificatePath"
                                                  stringValue:server.sslCertificatePath]];
        [serverElem addAttribute:[NSXMLNode attributeWithName:@"sslCertificateKeyPath"
                                                  stringValue:server.sslCertificateKeyPath]];
        for (NSString *port in server.ports) {
            [serverElem addChild:[NSXMLNode elementWithName:@"port"
                                                stringValue:port]];
        }
        for (NSString *ipAddress in server.ipAddresses) {
            [serverElem addChild:[NSXMLNode elementWithName:@"ipAddress"
                                                stringValue:ipAddress]];
        }
        for (NSString *hostname in server.hostnames) {
            [serverElem addChild:[NSXMLNode elementWithName:@"hostname"
                                                stringValue:hostname]];
        }
        for (Location *location in server.locations) {
            NSXMLElement *locElem = [NSXMLNode elementWithName:@"location"];
            [locElem addAttribute:[NSXMLNode attributeWithName:@"pattern"
                                                   stringValue:location.pattern]];
            [locElem addAttribute:[NSXMLNode attributeWithName:@"path"
                                                   stringValue:location.path]];
            [locElem addAttribute:[NSXMLNode attributeWithName:@"locationType"
                                                   stringValue:[NSString stringWithFormat:@"%d", location.locationType]]];
            [locElem addAttribute:[NSXMLNode attributeWithName:@"patternStyle"
                                                   stringValue:[NSString stringWithFormat:@"%d", location.patternStyle]]];
            [locElem addAttribute:[NSXMLNode attributeWithName:@"loadBalancing"
                                                   stringValue:[NSString stringWithFormat:@"%d", location.loadBalancing]]];
            [locElem addAttribute:[NSXMLNode attributeWithName:@"processes"
                                                   stringValue:[NSString stringWithFormat:@"%d", location.processes]]];
            [locElem addAttribute:[NSXMLNode attributeWithName:@"threads"
                                                   stringValue:[NSString stringWithFormat:@"%d", location.threads]]];
            [locElem addAttribute:[NSXMLNode attributeWithName:@"watchdogEnabled"
                                                   stringValue:[NSString stringWithFormat:@"%d", location.watchdogEnabled]]];
            [locElem addAttribute:[NSXMLNode attributeWithName:@"notes"
                                                   stringValue:location.notes]];
            for (NSString *command in location.runningCommands) {
                [locElem addChild:[NSXMLNode elementWithName:@"runningCommand"
                                                 stringValue:command]];
            }
            [serverElem addAttribute:[NSXMLNode attributeWithName:@"notes"
                                                      stringValue:server.notes]];
            [serverElem addChild:locElem];
        }
        [modelElem addChild:serverElem];
    }
    [root addChild:modelElem];
    NSXMLDocument *doc = [NSXMLDocument documentWithRootElement:root];
    return doc;
}
     
@end
