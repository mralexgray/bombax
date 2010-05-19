#import "ModelReader.h"
#import "Server.h"
#import "Location.h"

@implementation ModelReader

+ (Model *)readModel:(NSXMLDocument *)xmlDoc { // tbd error
    Model *model = [[Model alloc] init];
    @try {
        NSXMLElement *root = [xmlDoc rootElement];
        //NSString *version = [[root attributeForName:@"version"] stringValue];
        // tbd check version...
        NSXMLElement *modelElem = (NSXMLElement *) [root nextNode];
        model.isDebugEnabled = [[[modelElem attributeForName:@"isDebugEnabled"] stringValue] boolValue];
        model.debugPort = [[[modelElem attributeForName:@"debugPort"] stringValue] integerValue];
        [[model servers] removeAllObjects];
        for (NSXMLElement *serverElem in [modelElem elementsForName:@"server"]) {
            NSXMLNode *node;
            Server *server = [[Server alloc] init];
            server.logPath = [[serverElem attributeForName:@"logPath"] stringValue];
            server.sslEnabled = [[[serverElem attributeForName:@"sslEnabled"] stringValue] boolValue];
            server.sslCertificatePath = [[serverElem attributeForName:@"sslCertificatePath"] stringValue];
            server.sslCertificateKeyPath = [[serverElem attributeForName:@"sslCertificateKeyPath"] stringValue];
            for (NSXMLElement *portElem in [serverElem elementsForName:@"port"]) {
                [server.ports addObject:[portElem stringValue]];
            }
            for (NSXMLElement *hostnameElem in [serverElem elementsForName:@"hostname"]) {
                [server.hostnames addObject:[hostnameElem stringValue]];
            }
            for (NSXMLElement *ipElem in [serverElem elementsForName:@"ipAddress"]) {
                [server.hostnames addObject:[ipElem stringValue]];
            }
            for (NSXMLElement *locElem in [serverElem elementsForName:@"location"]) {
                Location *location = [[Location alloc] init];
                location.server = server;
                location.pattern = [[locElem attributeForName:@"pattern"] stringValue];
                location.path = [[locElem attributeForName:@"path"] stringValue];
                location.locationType = [[[locElem attributeForName:@"locationType"] stringValue] integerValue];
                location.patternStyle = [[[locElem attributeForName:@"patternStyle"] stringValue] integerValue];
                location.loadBalancing = [[[locElem attributeForName:@"loadBalancing"] stringValue] integerValue];
                location.processes = [[[locElem attributeForName:@"processes"] stringValue] integerValue];
                location.threads = [[[locElem attributeForName:@"threads"] stringValue] integerValue];
                node = [locElem attributeForName:@"watchdogEnabled"];
                if (node != nil) {
                    location.watchdogEnabled = [[node stringValue] boolValue];
                    NSArray *cmdElems = [locElem elementsForName:@"runningCommand"];
                    if (cmdElems != nil) {
                        for (NSXMLElement *cmdElem in cmdElems) {
                            [location.runningCommands addObject:[cmdElem stringValue] ];
                        }
                    }
                } else {
                    location.watchdogEnabled = YES;
                }
                node = [locElem attributeForName:@"notes"];
                if (node != nil) {
                    location.notes = [node stringValue];
                } else {
                    location.notes = @"";
                }
                [location updateAppInfo];
                [server.locations addObject:location];
            }
            node = [serverElem attributeForName:@"notes"];
            if (node != nil) {
                server.notes = [node stringValue];
            } else {
                server.notes = @"";
            }
            [model.servers addObject:server];
        }
    } @catch (id ex) {
        NSLog(@"%@", ex);
    }
    return model;
}

@end
