#import <Bombaxtic/BxApp.h>
#import <Bombaxtic/BxClientLibAuthenticator.h>
#import <Bombaxtic/BxClientLibAuthorizer.h>
#import <Bombaxtic/BxClientLibHandler.h>
#import <Bombaxtic/BxDatabaseConnection.h>
#import <Bombaxtic/BxDatabaseStatement.h>
#import <Bombaxtic/BxFile.h>
#import <Bombaxtic/BxHandler.h>
#import <Bombaxtic/BxMailer.h>
#import <Bombaxtic/BxMailerAttachment.h>
#import <Bombaxtic/BxMessage.h>
#import <Bombaxtic/BxSession.h>
#import <Bombaxtic/BxStaticFileHandler.h>
#import <Bombaxtic/BxTransport.h>
#import <Bombaxtic/BxUtil.h>

/*
 Your BxApp must call BxMain in the main() entry point function, passing to it
 the name of your BxApp subclass. This is done instead of the usual call to
 NSApplicationMain. If a problem occurs during initialization, a non-zero value
 is returned.
 
 Example main.m file:
 
 #import <Cocoa/Cocoa.h>
 #import <Bombaxtic/Bombaxtic.h>
 #import "handler_list.h"
 
 int main(int argc, char *argv[])
 {
     return BxMain("MyApp");
 }
 
 */
int BxMain(char *bxAppClassName);
