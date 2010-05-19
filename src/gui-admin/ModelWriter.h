#import <Cocoa/Cocoa.h>
#import "Model.h"

@interface ModelWriter : NSObject {

}

+ (NSXMLDocument *)writeModel:(Model *)model;

@end
