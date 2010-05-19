/**
 \brief Persistent handler for client requests
 \class BxHandler
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 1.0
 
 The central functionality of every Bombax web application is provided by
 customized BxHandler subclasses. BxHandler is either subclassed explicitly
 as an Objective-C or implicitly as a BXML file to handle incoming client
 requests.
 
 Unlike the BxTransport instance, a BxHandler is normally retained for as long
 as the application is run. However, note that the BxHandler is not created
 until a client requests it (see BxApp for more information). Only one BxHandler
 instance is used for the BxApp, even if it is used for multiple paths (e.g.
 as the default handler and for a particular prefix).

 BxHandler has only two basic methods for overriding, setup and renderWithTransport.
 renderWithTransport is the most important of these two as it is called with each
 client request in order to create the output and often is the only method
 that needs to be overridden.
  
 Basic example of overriding a BxHandler to create a custom request handler:
 \code
 @interface MyHandler : BxHandler {
     int _counter;
 }
 - (id)renderHeader:(BxTransport *)transport;
 - (id)renderFooter:(BxTransport *)transport;
 @end
 
 @implementation MyHandler
 - (id)setup {
     _counter = 0;
 }
 
 - (id)renderWithTransport:(BxTransport *)transport {
     _counter += 1;
     [self renderHeader:transport];
     [transport writeFormat:@"There have been %d visits.", _counter];
     [self renderFooter:transport];
 }
 
 - (id)renderHeader:(BxTransport *)transport {
     [transport write:@"<html><body>"];
 }

 - (id)renderFooter:(BxTransport *)transport {
     [transport write:@"</body></html>"];
 }
 @end
 \endcode
 
 Similar example using a BXML and the \ref state property:
 \code
 <?setup
  [self.state setObject:[NSNumber numberWithInteger:0] forKey:@"counter"];
 ?>
 <html>
  <body>
   <?
   int counter = [[self.state objectForKey:@"counter"] integerValue] + 1;
   [_ writeFormat:@"There have been %d visits.", counter];
   [self.state setObject:[NSNumber numberWithInteger:counter] forKey:@"counter"];
   ?>
  </body>
 </html>
 \endcode
 
 An example which uses a backing class with BXML:
 \code
 @interface BackingHandler : BxHandler {
     int _counter;
 }
 @property (nonatomic, assign) int counter;
 @end
 
 @implementation BackingHandler
 @synthesize counter = _counter;
 - (id)setup {
     _counter = 0;
 }
 @end
 \endcode
 \code
 <?base BackingHandler ?>
 <html>
  <body>
   There have been <? self.counter++; [_ writeFormat:@"%d", self.counter] ?> visits.
  </body>
 </html>
 \endcode
 
 \warning The previous examples non-atomically alter the handler state. Because state is shared
 between renderWithTransport calls, if your BxApp is running as a multithreaded application
 (which is the default) this could allow for a counter increment to be clobbered. One strategy
 for addressing this is to use a NSLock (see Apple's Thread Programming Guide for more
 information):
 \code
 static NSLock *_myLock;
 - (id)setup {
     _myLock = [[NSLock init] alloc];
     return self;
 }
 - (id)renderWithTransport:(BxTransport *)transport {
     @try {
         [_myLock lock];
         // ... perform synchronized operation
     } @finally {
         [_myLock unlock];
     }
     return self;
 }
 \endcode
 
 \sa For more information about using BxHandler and the Bombaxtic request lifecycle,
 please see the "Bombax Developer's Guide"
 */

#import <Cocoa/Cocoa.h>

@class BxApp;
@class BxTransport;

@interface BxHandler : NSObject {
    BxApp *_app;
    NSMutableDictionary *_state;
}

- (id)initWithApp:(BxApp *)app;

/** \anchor renderWithTransport
 \brief Processes the request and sends the output via \c transport
 
 This is the method responsible for handling an individual client request.
 Using the BxTransport instance, the output stream (via the writeXXX
 methods) and a variety of parameters are accessible. renderWithTransport
 is only called once for each client request.
 
 The basic mechanism of handling a request is by subclassing BxHandler
 and overriding the renderWithTransport method. By default, renderWithTransport
 is empty.
 
 BXML '<? ?>' sections are automatically inserted into a generated
 renderWithTransport method in the order provided, connected by the
 non-code sections. For example,
 \code
 <p>This <? [_ write:@"is"] ?> a <? [_ write:@"BxApp"] ?>.</p>
 \endcode
 will output '&lt;p>This is a BxApp.&lt;/p>'.
 
 \warning The \c transport parameter is created and released for a single
 client request and is not intended to be retained.
 
 Example of basic output using renderWithTransport:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [transport setHeader:@"Content-Type" value:@"text/plain"];
     [transport writeFormat:@"The current time is %@.", [NSDate date]];
     return self;
 }
 \endcode
 
 Similar example using BXML:
 \code
 <? [_ setHeader:@"Content-Type" value:@"text/plain"] ?>
 The current time is <? [_ write:[[NSDate date] description]] ?>.
 \endcode
 
 \param transport a newly created BxTransport instance connected to the client
 \return the BxHandler instance
 \since 1.0
 */
- (id)renderWithTransport:(BxTransport *)transport;

/** \anchor setup
 \brief Prepares the BxHandler prior to renderWithTransport calls
 
 This method is called \b once in the lifetime of the BxHandler, directly
 after initialization by BxApp. setup is usually used to create any state
 needed over the successive renderWithTransport calls, including opening
 database or file connections.
 
 To add setup code to BXML, use the special '<?setup ?>' section.
 This may be repeated if necessary and does not strictly need to be at
 the beginning of the file, though this is recommended.
 
 Example of setting up state through setup:
 \code
 - (id)setup {
     NSMutableDictionary *lastVisits = [NSMutableDictionary dictionaryWithCapacity:8];
     [self.state setObject:lastVisits forKey:@"lastVisits"];
     return self;
 }
 
 - (id)renderWithTransport:(BxTransport *)transport {
     NSMutableDictionary *lastVisits = [self.state objectForKey:@"lastVisits"];
     NSString *ipAddress = [self.serverVars objectForKey:@"REMOTE_ADDR"];
     NSDate *date = [lastVisits objectForKey:ipAddress];
     if (date == nil) {
         [transport write:@"This is your first visit."];    
     } else {
         [transport writeFormat:@"Your last visit was on %@.", date];
     }
     [lastVisits setObject:[NSDate date] forKey:ipAddress];
     return self;
 }
 \endcode
 
 Example of creating state in BXML:
 \code
 <?setup
  [self.state setObject:[NSDate date] forKey:@"initDate"];
 ?>
 <html>
  <body>
   This handler was initialized on <? [transport write:[[self.state objectForKey:@"initDate"] description]] ?>.
  </body>
 </html>
 \endcode
 
 \return the BxHandler instance
 \since 1.0
 */
- (id)setup;

/** \anchor app
 This is a reference to the global BxApp. The two main uses of this property are
 to access the global (i.e. pan-Bxhandler) state and to dynamically rewrite path
 handling.
 
 Example of accessing the BxApp state:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     int visits = [[self.app.state objectForKey:@"visits"] integerValue];
     visits++;
     [transport writeFormat:@"You are visitor %d.", visits];
     [self.app.state setObject:[NSNumber numberWithInteger:visits] forKey:@"visits"];
     return self;
 }
 \endcode
 \warning Because the BxApp is shared between handlers, thread-safe programming techniques
 such as using NSLock may be necessary in your application.
 \since 1.0
 */
@property (readonly) BxApp *app;

/** \anchor state
 This is main container of state for the BxHandler between client connections.
 It may be used in place of or in addition to subclass instance variables.
 For BXML handlers that are not based on a BxHandler subclass, it is the
 main way to keep persistent state.
 
 Example of using state to enable or disable a handler by looking for
 'disable' or 'enable' as a query variable:
 \code
 <?setup [self.state setObject:[NSNumber numberWithBool:YES] forKey:@"isEnabled"]; ?>
 <html>
  <body>
   <?
    if ([_.queryVars objectForKey:@"disable"] != nil) {
        [self.state setObject:[NSNumber numberWithBool:NO] forKey:@"isEnabled"];
    } else if ([_.queryVars objectForKey:@"enable"] != nil) {
        [self.state setObject:[NSNumber numberWithBool:YES] forKey:@"isEnabled"];
    }
   ?>
   ...
   <? if ([[self.state objectForKey:@"isEnabled"] boolValue] == YES) { ?>
    This handler is enabled.
   <? } else { ?>
    This handler is disabled.
   <? } ?>
  </body>
 </html>
 \endcode
 \warning See discussion of using NSLock above for information using state in a 
 thread-safe way.
 \since 1.0
 */
@property (readonly) NSMutableDictionary *state;

@end
