/**
 \brief Routes client requests to BxHandler instances
 \class BxApp
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 1.0
 
 There is one BxApp instance for each 'BxApp' Bombaxtic application. 
 The BxApp is primarily responsible for setting up the routing paths
 to match incoming requests with BxHandler instances.
 
 Typically, a BxApp examines whether an incoming request's path meets
 different matching criteria such as possessing a certain prefix or suffix
 in order to determine which BxHandler class is responsible for handling
 that request. Once the BxHandler has been determined, the class is
 instantiated and setup is called if it has not been already, and
 the BxTransport for the request is passed to the BxHandler instance.
 If a BxHandler cannot be found to match the request, the default
 handler (set with setDefaultHandler) is used.
 
 Because Objective-C BxHandler classes are not created from BXML until
 after your BxApp subclass header is processed, it is not normally possible
 to import the BXML header. However, you can use the BXML file name (without
 the .bxml extension) in setting a handler. For example a BXML file called
 MyBxmlHandler.bxml could be set as a handler through,
 \code
 - (id)setup {
     [self setHandler:@"MyBxmlHandler" forMatch:@"example"];
     return self;
 }
 \endcode
 \note The BXML file name may be modified by using using '<?name ?>' tag.
 For example, the following should be accessed as 'MyRenamedHandler' regardless
 of the name of the file:
 \code
 <?name MyRenamedHandler ?>
 <html>
  <body>Example</body>
 </html>
 \endcode

 In addition to routing and setting up handler paths, BxApp also provides
 a global state property and a special, override-able launchConfigurator
 method that allows your application to have a custom configuration
 operation when it is configured from the Bombax server.
 
 An example of setting several elsewhere defined BxHandler classes in a BxApp suclass:
 \code
 - (id)setup {
     [self setHandler:@"BxmlRouterHandler" forSuffix:@".bxml"];
     [self setHandler:@"SearchHandler" forPrefix:@"/search"];
     [self setHandler:@"IndexHandler" forMatch:@"/"];
     [self setDefaultHandler:@"404Handler"];
     return self;
 }
 \endcode

 \note The first correct handler is the one returned. If there e.g. multiple
 matching handlers for a suffix, the first suffix according to \c compare:
 will be used. The sequence of path examinations is as follows:
 -# The first exactly match per \ref setHandler2 "setHandler:forMatch:"
 -# The first matching suffix per \ref setHandler4 "setHandler:forSuffix:"
 -# The first matching prefix per \ref setHandler3 "setHandler:forPrefix:"
 -# The first contained keyword per \ref setHandler4 "setHandler:forKeyword:"
 -# The default handler, if set
   
 \warning The \c main entry point function of your application should call
 \c BxMain instead of the usual \c NSApplicationMain. This avoids the creation
 of a desktop application and sets up your BxApp properly. It is very important
 that the name passed to BxMain matches your BxApp subclass. If you change the
 name of your BxApp, you \b must change the name passed to BxMain (e.g. in \c init.m)
 as well. For example, if your BxApp subclass is ExampleApp, your \c init.m should
 look like the following (the \c handler_list.h is necessary to include all generated
 BXML files):
 \code
 #import <Cocoa/Cocoa.h>
 #import <Bombaxtic/Bombaxtic.h>
 #import "handler_list.h"
 
 int main(int argc, char *argv[])
 {
     return BxMain("ExampleApp");
 }
 \endcode
 
 \sa For more information about using BxApp and the Bombaxtic request lifecycle,
 please see the "Bombax Developer's Guide"
 */

@class BxHandler;

@interface BxApp : NSObject {
    NSMutableDictionary *_state;
    BOOL _matchClassName;
}

/** \anchor exit
 \brief invoked as the BxApp is exiting
 
 When exit: returns, the BxApp will terminate.  By default exit: does nothing but may
 be overridden for important pre-exit functions such as closing database connections.
 exit: may be called as either the result of an uncaught exception, a low level error,
 or a request to terminate from the Bombax server.  exit: should be treated as having
 the same restrictions in operation as a \c signal handler, essential that no re-entrant
 functions are called.
 
 Example that closes an Oracle connection on exit:
 \code
 #import <oci.h>
 
 static OCISvcCtx *oraServiceContext;
 static OCIError *oraError;
 
 - (id)setup {
     // ... (OCIInitialize, allocate Oracle handles, and log on)
 }
 
 - (id)exit {
     OCILogoff(oraServiceContext, oraError);
     return self;
 }
 \endcode
 
 \param isError if true, exiting due to error or exception
 \return the BxApp instance
 \since 1.0
 */
- (id)exit:(BOOL)isError;

/** \anchor handlerForPath
 \brief Returns the classname of the handler for a given path
 
 This is automatically called when an incoming request is recieved in order
 to determine which handler is to be used.
 \warning This method may be overridden if you want to perform advanced customization
 of the path routing. \b However, it is not recommended that you override this method
 as doing so will cause your app to ignore all setHandler methods.
 
 Example that converts all incoming paths to lowercase before handing to the BxApp's
 default handlerForPath:
 \code
 - (NSString *)handlerForPath:(NSString *)path {
     return [super handlerForPath:[path lowercaseString]];
 }
 \endcode
 
 \param path the path the client is requesting with leading '/'
 \return the classname of the handler or nil if no handler was found
 \since 1.0
 */
- (NSString *)handlerForPath:(NSString *)path;

/** \anchor handlerInstanceForClassName
 \brief TBD
 
 TBD
 
 \param handlerName the handler class name to match
 \return the BxHandler instance or nil if no match was found
 \since 2.0
 */
- (BxHandler *)handlerInstanceForClassName:(NSString *)handlerName;

/** \anchor launchConfigurator
 \brief Overridden to provide a configuration user interface
 
 Normally your application does not operate as a typical desktop application
 with a UI window and menu bar. This considerably reduces the resources required
 and allows multiple simultaneous processes. However, when the application is
 configured through the Bombax server, the application calls launchConfigurator
 and then exits.
 
 By default, this simply shows an information panel and then exits. However, it can
 be overridden to be extensively customized especially to load and show a Nib file.
 
 \note If you override this method, you are responsible for initializing the UI
 application environment as shown below.

 Example of loading a Nib file :
 \code
 - (id)launchConfigurator {
     NSApplication *app = [NSApplication sharedApplication];
     [NSBundle loadNibNamed:@"MainWindow" owner:app];
     [app run]; // starts run loop; will not return until program is exited
     return self;
 }
 \endcode
 
 \return the BxApp instance
 \since 1.0
 */
- (id)launchConfigurator;

/** \anchor setDefaultHandler
 \brief Sets the default handler 
 
 This is the handler that will be used if no specific match is found.
 \note It is a good practice to set a default handler, especially to
 handle misspelled and missing paths.
 
 Example of setting a 404 handler:
 \code
 - (id)setup {
     [self setDefaultHandler:@"404Handler"];
     return self;
 }
 \endcode

 \param handlerName the classname or BXML filename of the handler
 \return the BxApp instance
 \since 1.0
 */
- (id)setDefaultHandler:(NSString *)handlerName;

/** \anchor setHandler
 \brief Sets the handler for paths that contain the keyword
 
 The provided handler will be used if the path contains the given keyword.
 
 Example that will match '/info', '/info/topic', and '/topic/info':
 \code
 - (id)setup {
     [self setHandler:@"InfoHandler" forKeyword:@"info"];
     return self;
 }
 \endcode
 
 \param handlerName the classname or BXML filename of the handler
 \param keyword the keyword to match (case sensitive)
 \return the BxApp instance
 \since 1.0
 */
- (id)setHandler:(NSString *)handlerName forKeyword:(NSString *)keyword;

/** \anchor setHandler2
 \brief Sets the handler for exactly matching paths
 
 The provided handler will be used if the path exactly matches \c match.
 Note that a '/' is automatically appended to \c match if one does not already
 exist as all incoming paths contain the leading slash.
 
 Example that will match only '/About':
 \code
 - (id)setup {
     [self setHandler:@"AboutHandler" forMatch:@"/About"];
     return self;
 }
 \endcode
 
 \param handlerName the classname or BXML filename of the handler
 \param match the path to exactly match (case sensitive)
 \return the BxApp instance
 \since 1.0
 */
- (id)setHandler:(NSString *)handlerName forMatch:(NSString *)match;

/** \anchor setHandler3
 \brief Sets the handler for paths that have the prefix
 
 The provided handler will be used if the path has the provided prefix.
 
 Example that will match files with a '.report' ending:
 \code
 - (id)setup {
     [self setHandler:@"ReportHandler" forPrefix:@".prefix"];
     return self;
 }
 \endcode
 
 \param handlerName the classname or BXML filename of the handler
 \param prefix the prefix to match (case sensitive)
 \return the BxApp instance
 \since 1.0
 */
- (id)setHandler:(NSString *)handlerName forPrefix:(NSString *)prefix;

/** \anchor setHandler4
 \brief Sets the handler for paths that have the suffix
 
 The provided handler will be used if the path starts with \c suffix.
 Note that a '/' is automatically appended to \c suffix if one does not already
 exist as all incoming paths contain the leading slash.
 
 Example that will match '/users' and '/users/jane':
 \code
 - (id)setup {
     [self setHandler:@"UserHandler" forSuffix:@"/users"];
     return self;
 }
 \endcode
 
 \param handlerName the classname or BXML filename of the handler
 \param suffix the suffix to match (case sensitive)
 \return the BxApp instance
 \since 1.0
 */
- (id)setHandler:(NSString *)handlerName forSuffix:(NSString *)suffix;

/** \anchor setMatchClassNameHandling
 \brief TBD
 
 TBD
  
 \param matchClassName YES to enable class name matching, NO to disable
 \return the BxApp instance
 \since 2.0
 */
- (id)setMatchClassNameHandling:(BOOL)matchClassName;

/** \anchor setup
 \brief overridden to configure the routing and initial state of the BxApp
 
 \c setup is called when your application is first started and should be overridden
 to customize its operation. Normally, whenever you create a BxHandler, you will
 add a corresponding line to setup to map a path to your new handler.
 If you want to persist an object across multiple handlers, such as a database connection,
 setup is the preferred location to do so (BxHandler instances can access your
 BxApp through their \ref app property).
 
 Example that sets up a default handler and a configuration variable:
 \code
 - (id)setup {
     [self setDefaultHandler:@"MyHandler"];
     [self.state setObject:[[NSUserDefaults standardUserDefaults] stringForKey:@"preferredLanguage"]
                    forKey:@"preferredLanguage"];
     return self;
 }
 \endcode 
 \return the BxApp instance
 \since 1.0
 */
- (id)setup;

/** \anchor staticWebPath
 \brief Returns the web path for a given static resource
 
 This method returns an internet-ready path to a static resource such as an image or CSS file.
 In order to determine the web path, \c staticWebPath first adds the root of the BxApp location
 in the Bombax server (for example, if your BxApp is available at "/example" then "/example"
 is prefixed to the web path).  Secondly, the \c "BxApp Static Web Path" variable in your BxApp's
 information property list (Info.plist) is added if present.  If \c "BxApp Static Web Path" is
 not present, "static" is substituted.  Finally the \c resource itself is added. For example,
 if a BxApp had the location "/example" and the \c "BxApp Static Web Path" of "static", if
 \c staticWebPath was called with "logo.png" it would return "/example/static/logo.png".
 
 \note \c resource should exist within the BxApp's physical folder specified in
 \c "BxApp Static Resource Path".  By default this folder is named "static".
  
 \note In debugging mode \ref BxStaticFileHandler is implicitly used to handle request coming
 into the \c "BxApp Static Web Path".
 
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [transport writeFormat:@"<html><head><link rel="stylesheet" type="text/css" href="%@"" /></head><body>",
                            [self.app staticWebPath:@"main.css"]];
     // ...
     [transport write:@"</body></html>"];
     return self;
 }
 \endcode
 
 \param resource the name of the 
 \return the web path such as \c /static/image.jpg
 */
- (NSString *)staticWebPath:(NSString *)resource;

/** \anchor state
 Application-wide state that can be accessed by each BxHandler (through their \ref app
 property).
 \warning Because multiple threads could access state at the same time, you may need to
 ensure that any transactional behavior is threadsafe. For example, you may want to wrap
 access of the state through wrapper methods such as:
 \code
 static NSRecursiveLock *_stateLock = nil;
 
 - (NSMutableDictionary *)lockState {
     if (_stateLock == nil) {
         _stateLock = [[NSRecursiveLock alloc] init];
     }
     [_stateLock lock];
     return self.state;
 }
 
 - (id)unlockState {
     [_stateLock unlock];
     return self;
 }
 \endcode
 This could then be used safely within a handler like this:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [self.app lockState];
     // ... do something with self.app.state
     [self.app unlockState];
     return self;
 }
 \endcode
 
 \sa Apple's Thread Programming Guide
 \since 1.0
 */
@property (readonly) NSMutableDictionary *state;

// xxx enable, disable sessions... the session list is kept in the app...
// 

@end
