#import <Cocoa/Cocoa.h>
#import "Model.h"

@interface ModelReader : NSObject {

}

+ (Model *)readModel:(NSXMLDocument *)xmlDoc;

@end
