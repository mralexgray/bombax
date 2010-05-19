/**
 \brief Handles communication with HTTP client
 \class BxTransport
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 1.0
 
 BxTransport is the core class for communicating with the HTTP client.  It provides
 information about the client's request, basic server variables, cookie management,
 header management, and output functions to write the response.  A unique BxTransport
 instance is passed to the BxHandler using the renderWithTransport method
 once in the lifecycle of the request.

 Subclasses of BxHandler override renderWithTransport and use the BxTransport
 instance for all output. In the case of a BXML file, the BxTransport instance is available
 through the variable named '_', e.g. [_ write:@"hello"]
 
 Example of using BxTransport in a BxHandler subclass:
 \code
 @interface MyHandler : BxHandler { }
 @end
 
 @implementation MyHandler
 - (id)renderWithTransport:(BxTransport *)transport {
     [transport setHeader:@"Content-Type" value:@"text/plain"];
     [transport write:@"Hello World!"];
     return self;
 }
 @end
 \endcode
 
 Example of using the \c _ BxTransport variable in a BXML handler:
 \code
 <html>
  <body>
   <?
    [_ setCookie:@"visited" value:@"yes"];
    [_ write:@"Hello World!"];
   ?>
  </body>
 </html>
 \endcode
 
 \sa For more information about using BxTransport please see the Bombax Developer's Guide.

 */

#import <Cocoa/Cocoa.h>
#import "fcgiapp.h"

@interface BxTransport : NSObject {
    BOOL _isClosed;
    NSMutableArray *_uploadedFiles;
    NSMutableData *_rawPostData;
    NSMutableDictionary *_postVars;
    NSMutableDictionary *_queryVars;
    NSMutableDictionary *_serverVars;
    NSMutableDictionary *_cookies;
    NSMutableDictionary *_state;
    NSString *_requestPath;
    
    /*-------------------------------------------------------------------*
     *  The following are non-strictly private variables and should not  *
     *  be accessed by subclasses without considerable care.             *
     *-------------------------------------------------------------------*/

    /* Internally tracks whether the outbound headers have been written which
     takes place once the first call to writeXXX has been made. Once this takes
     place, this variable is set and no new headers will be written. */
    BOOL _hasWrittenHeaders;
    
    /* The raw FastCGI request. It is unlikely that you will need to use this
     directly unless interfacing with existing FastCGI code. For more info
     about FastCGI please see http://www.fastcgi.com */
    FCGX_Request *_request;
     
    /* This is the raw array of outbound cookies as 'NAME=VALUE, OPTIONS' strings.
     Instead of modifying this array, use the setCookie and setPersistentCookie
     methods. See RFC 2109 or 2965 for more info about cookies. */
    NSMutableArray *_outboundCookies;

    /* The raw dictionary of HTTP headers to send in the response. Instead of
     modifying this dictionary, use the setHeader method. */
    NSMutableDictionary *_outboundHeaders;
    
}

/** \anchor close
 \brief Closes the response stream
 
 This closes the response stream and will not allow any more data to be sent to the
 client, including headers and cookies that are queued.  This can be useful to handle
 error cases, especially when a subclass will otherwise send information to the client.
 If you wish to send the headers, be sure to call \ref flush before calling \ref close.
 
 Example closing a connection:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     if ([[transport.queryVars objectForKey:@"user"] isEqualToString:@"admin"]) {
         [transport close];
     } else {
         // ...
     }
     return self;
 }
 \endcode
 \return the BxTransport instance
 \since 2.0
 */
- (id)close;


/** \anchor flush
 \brief Flushes the response stream
 
 This is called automatically when the connection is closing but may be
 called earlier in order to manually control output buffering e.g. when
 sending a large response.
 
 Example writing the contents of an array of strings, flushing every 1000th string:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     for (int i = 0; i < [_myArray count]; i++) {
         [transport write:[_myArray objectAtindex:i]];
         if (i % 1000 == 999) {
             [transport flush];
         }
     }
     return self;
 }
 \endcode
 \return the BxTransport instance
 \since 1.0
 */
- (id)flush;

/** \anchor setCookie
 \brief Adds a session cookie to send to the client
 
 This sends a cookie to the client that will only be retained
 for the browser session. Use the \ref setPersistentCookie for cookies
 that you want to keep longer or for additional options.
 
 Cookies are sent as part of the HTTP response headers.  As a result,
 all cookies need to be set before any write methods are called or
 they will not have an effect.
 
 Example that sets a session cookie if it hasn't been set already and writes it:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSString *sessionId = [transport.cookies objectForKey:@"sessionid"];
     if (sessionId == nil) {
          sessionId = [NSString stringWithFormat:@"%f.%d", [NSDate timeIntervalSinceReferenceDate], random()];
         [transport setCookie:@"sessionid" value:sessionId];
     }
     [transport write:sessionId];
     return self;
 }
 \endcode
 
 \sa See RFCs 2109 and 2965 for more information about cookies.
 
 \param name the name of the cookie
 \param value the value of the cookie. This is automatically URL encoded
 \return the BxTransport instance
 \since 1.0
 */
- (id)setCookie:(NSString *)name
          value:(NSString *)value;

/** \anchor setHeader
 \brief Sets an HTTP header to be sent back to the client
 
 This sets an HTTP header variable that is sent back in the response.
 Initially, the only HTTP header set is 'Content-type'->'text/html'.
 Because this method replaces values if the header already exists, by
 setting the 'Content-type' header, this can be overridden. To set cookies,
 instead of directly setting the header, use the \ref setCookie and
 \ref setPersistentCookie methods to ensure that multiple cookies can be used.
 
 The first time \ref write, \ref writeData, or \ref writeFormat is called, all of
 the headers are written out. Any further calls to \ref setHeader will be
 ignored. Because of this, it is important to remember to write headers
 before output begins, especially with BXML (in which case it should
 precede any other text).

 Example of disabling caching using setHeader in BXML:
 \code
 <? [_ setHeader:@"Cache-Control" value:@"no-cache"] ?>
 <html>
  <body>
   The current time and date is <? [_ write:[[NSDate date] description]] ?>
  </body>
 </html>
 \endcode
 
 \sa For more information about HTTP headers, please see section 14 of RFC 2616. 
 
 \param header the name of the HTTP header
 \param value the value to be set for the header. This will be automatically URL encoded
 \return the BxTransport instance
 \since 1.0
 */
- (id)setHeader:(NSString *)header
          value:(NSString *)value;

/** \anchor setPersistentCookie
 \brief Adds a persistent cookie to send to the client
 
 This sends a cookie to the client that will be retained for \c maxAge
 seconds. Use the \ref setCookie for cookies that you only want the client
 to keep during the browser session.
 
 Cookies are sent as part of the HTTP response headers.  As a result,
 all cookies need to be set before any write methods are called or
 they will not have an effect.
 
 Example that sets a persistent cookie for one week if it hasn't been set already:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSString *theme = [transport.cookies objectForKey:@"theme"];
     if (theme == nil) {
         theme = @"default";
         [transport setPersistentCookie:@"theme" value:theme maxAge:(60 * 60 * 24 * 7)];
     }
     // ... use theme to render page
     [transport self];
 }
 \endcode
 
 \sa See RFCs 2109 and 2965 for more information about cookies.
 
 \param name the name of the cookie
 \param value the value of the cookie. This is automatically URL encoded
 \param maxAge how long in seconds you would like the client to retain the cookie
 \return the BxTransport instance
 \since 1.0
 */
- (id)setPersistentCookie:(NSString *)name
                    value:(NSString *)value
                   maxAge:(NSTimeInterval)maxAge;

/** \anchor setPersistentCookie2
 \brief Adds a persistent cookie to send to the client
 
 This sends a cookie to the client that will be retained for \c maxAge
 seconds. If you'd like the client to only keep the cookie during the
 browser session, use the \ref setCookie instead.
 
 This method allows you to set the \c path and \c domain you would
 like to use.  If you set the domain, the client will only send
 the cookie if the domain it is visiting matches. For example, a
 domain of '.example.com' will be sent when visiting http://example.com
 and http://www.example.com but not http://example.net
 
 Similarly, setting the path to anything other than '/' will mean that
 the client will only send the cookie if the leading part of the
 URL path matches.  For example, setting the path to '/joe-user' will
 cause the cookie to be sent if http://example.com/joe-user/ or
 http://example.com/joe-user/something is requested, but not if
 http://example.com/jane-user is the requested URL.
 
 Cookies are sent as part of the HTTP response headers.  As a result,
 all cookies need to be set before any write methods are called or
 they will not have an effect.
 
 Example that sets a persistent cookie for one week for any requests
 that start with http://users.example.com/jane-user :
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSString *theme = [transport.cookies objectForKey:@"theme"];
     if (theme == nil) {
         theme = @"default";
         [transport setPersistentCookie:@"theme"
                                  value:theme
                                 maxAge:(60 * 60 * 24 * 7)
                                   path:@"/jane-user"
                                 domain:@"users.example.com"];
     }
     // ... use theme to render page
     [transport self];
 }
 \endcode
 
 \sa See RFCs 2109 and 2965 for more information about cookies.
 
 \param name the name of the cookie
 \param value the value of the cookie. This is automatically URL encoded
 \param maxAge how long in seconds you would like the client to retain the cookie
 \param path the URL path this cookie is retained for
 \param domain the internet domain this cookie is retained for
 \return the BxTransport instance
 \since 1.0
 */
- (id)setPersistentCookie:(NSString *)name
                    value:(NSString *)value
                   maxAge:(NSTimeInterval)maxAge
                     path:(NSString *)path
                   domain:(NSString *)domain;

/** \anchor setHttpStatusCode
 \brief Sets the HTTP status code returned to the client
 
 By default, a status code of 200 (OK) indicating success is returned.
 You can use \ref setHttpStatusCode to return a different status code such
 as 301 (Moved Permanently) or 403 (Forbidden).
 
 Example 1, 301 redirection:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [transport setHttpStatusCode:301];
     [transport setHeader:@"Location" value:@"http://www.example.com/newlocation"];
     return self;
 }
 \endcode
 
 Example 2, 404 not found page as BXML:
 \code
 <?
  [_ setHttpStatusCode:404];
 ?>
 <html>
  <body>
   Sorry, but page <? [_ write:[_.serverVars objectForKey:@"REQUEST_URI"]]; ?> could not be found.
  </body>
 </html>
 \endcode
 
 \sa For more information about HTTP status codes, please see section 10 of RFC 2616.
 
 \param status the HTTP status code for the response
 \return the BxTransport instance
 \since 1.0
 */
- (id)setHttpStatusCode:(int)status;

/** \anchor write
 \brief Writes the given NSString to the response stream
 
 \c string is written to the response stream. If any headers or cookies are
 waiting to be written they will be written the first time a write method is called.
 \ref write may be called multiple times during the BxTransport's lifetime and
 each \c string will be passed to the request stream in the order they were called.
 \c string should be UTF-8 encoded.
 
 Example producing 'First.Second.Third.':
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [transport write:@"First."];
     [transport write:@"Second."];
     [transport write:@"Third."];
     return self;
 }
 \endcode
 
 \param string the text to output to the stream. Expected to be UTF-8 encoded
 \return the BxTransport instance
 \since 1.0
 */
- (id)write:(NSString *)string;

/** \anchor writeData
 \brief Writes the given NSData to the response stream
 
 The raw bytes of \c data are written to the response stream without any encoding or
 transformation. If any headers or cookies are waiting to be written they
 will be written the first time a write method is called. \ref writeData may be
 called multiple times during the BxTransport's lifetime and the \c data
 will be passed to the request stream in the order they were called.
 
 Example writing a JPEG file:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSData *jpegData = [NSData dataWithContentsOfFile:@"path/to/file.jpg"];
     [transport setHeader:@"Content-type" value:@"image/jpeg"];
     [transport writeData:jpegData];
     return self;
 }
 \endcode
 
 \param data the data to output to the stream
 \return the BxTransport instance
 \since 1.0
 */
- (id)writeData:(NSData *)data;

/** \anchor writeFormat
 \brief Writes the given format string to the response stream
 
 This provides templated string formatting that works identically to NSString's
 stringWithFormat method.  As a result, the %@ format specifier works correctly.
 The resulting string is written to the response stream. If any headers or cookies are
 waiting to be written they will be written the first time a write method is called.
 \ref writeFormat may be called multiple times during the BxTransport's lifetime and
 each resulting string will be passed to the request stream in the order they were called.
 
 Example producing 'Hello World v1.0':
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [transport writeFormat:@"Hello %@ v%.1f", @"World", 1.0];
     return self;
 }
 \endcode
 
 \param format a UTF-8 encoded format string which may contain formatting specifiers
 \param ... a comma-separated list of arguments to substitute into format
 \return the BxTransport instance
 \since 1.0
 */
- (id)writeFormat:(NSString *)format, ...;

/** \anchor isClosed
 This variable indicates whether the response stream has been closed. Once the response
 stream is closed, no more writes will occur including outputting headers.
 
 Example of checking for a closed connection:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     // superclass may have closed the connection
     if (! [transport isClosed]) {
         [transport write:"Additional information"];
     }
     return self;
 }
 \endcode
 \since 2.0
 */
@property (nonatomic, readonly) BOOL isClosed;

/** \anchor uploadedFiles
 If any files were uploaded in POST variables, they are included here as BxFile instances.
 Example as BXML that allows uploading a file and then showing information about it:
 \code
 <html>
  <body>
   <? 
    if ([_.uploadedFiles count] > 0) {
        BxFile *file = [uploadedFiles objectAtIndex:0];
        [_ writeFormat:@"filename:%@ length:%d mimetype:%@", file.fileName, file.length, file.mimeType];
    } else {
   ?>
    <form method="POST">
     <input type="file" name="thefile" />
     <input type="submit" />
    </form>
   <?
    }
   ?>
  </body>
 </html>
 \endcode
 \since 1.0
*/
@property (nonatomic, readonly) NSArray *uploadedFiles;

/** \anchor rawPostData
 If there is raw data sent to the server via a POST request and the
 Content Type is not application/x-www-form-urlencoded or multipart/form-data it
 is included here. For example, a custom client might send a raw binary or XML document.
 If raw data was not sent, \ref rawPostData will be nil.
 
 Example of handling XML POST:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     if ([[transport.serverVars objectForKey:@"CONTENT_TYPE"] isEqualToString:@"text/xml"] &&
       transport.rawPostData != nil) {
         NSError *error;
         NSXMLDocument *doc = [[NSXMLDocument alloc] initWithData:transport.rawPostData
                                                             mask:0
                                                            error:&error];
         if (error == nil) {
             // ... do something with doc
         }
     }
     return self;
 }
 \endcode
 \since 1.0
 */
@property (nonatomic, readonly) NSData *rawPostData;

/** \anchor cookies
 This dictionary contains all cookies sent by the client as part of its request.
 
 Example outputting all cookies sent to the client:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [transport write:[transport.cookies description]];
     return self;
 }
 \endcode
 \since 1.0
 */
@property (nonatomic, readonly) NSDictionary *cookies;

/** \anchor postVars
 This dictionary contains all POST form variables included in the request.
 
 Example outputting all POST variables sent to the client:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [transport write:[transport.postVars description]];
     return self;
 }
 \endcode
 \since 1.0
 */
@property (nonatomic, readonly) NSDictionary *postVars;

/** \anchor queryVars
 This dictionary contains all query variables set either through a GET method
 form or as part of the URL. For example, http://www.example.com/?name=joe
 will include a \ref queryVars key 'name' containing 'joe' included \ref queryVars
 
 Example outputting all query variables sent to the client:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [transport write:[transport.queryVars description]];
     return self;
 }
 \endcode
 \since 1.0
 */
@property (nonatomic, readonly) NSDictionary *queryVars;

/** \anchor serverVars
 This dictionary contains useful variables provided by the server. Frequently useful
 keys include: REMOTE_ADDR, REQUEST_URI, HTTP_USER_AGENT, and SERVER_PORT
 
 Example outputting all available server variables:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [transport write:[transport.serverVars description]];
     return self;
 }
 \endcode
 \since 1.0
 */
@property (nonatomic, readonly) NSDictionary *serverVars;

/** \anchor state
 This dictionary is intended for containing state during the usage of the
 BxTransport instance. Because the BxTransport is created and released for
 an individual client connection, the main use of this property is for convenience
 in packaging additional BxTransport variables without having to subclass
 BxTransport, which is not advised.
 
 Example of using state to relay information to another method:
 \code
 @implementation MyController
 + (id)logExtraInfo:(BxTransport *)transport {
     MyInfo *extraInfo = [transport.state objectForKey:@"extraInfo"];
     // ... perform global logging using extraInfo
 }
 @end
 
 @implementation MyHandler
 - (id)renderWithTransport:(BxTransport *)transport {
     MyInfo *extraInfo;
     // ... complex process sets extraInfo from transport data
     [MyController logExtraInfo:extraInfo];
     return self;
 }
 @end 
 \endcode
 \since 1.0
 */
@property (readonly) NSMutableDictionary *state;

/** \anchor requestPath
 A convenience variable containing the document URI without your BxApp's leading
 location.  For example, if your BxApp is located at "/example" so that all requests
 that start with http://example.com/example/ are routed to your BxApp, if
 http://www.example.com/example/app/save?x=1 is accessed, \c requestPath will be
 "/app/save"
 
 \note When debugging requestPath does not remove the prefix as Xcode launches the BxApp
 rather than Bombax.app and it is during launch that the prefix is passed.
 
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     if ([transport.requestPath isEqualToString:@"app/save"]) {
         return [_saveHandler renderWithTransport:transport];
     } else if ([transport.requestPath isEqualToString:@"app/load"]) {
         return [_loadHandler renderWithTransport:transport];
     } else {
         // ... handle default
         return self;
     }
 }
 \endcode
 \since 1.0
 */
@property (readonly) NSString *requestPath;

@end
