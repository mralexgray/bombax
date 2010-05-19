/** \mainpage
 \image html logo-256.png "Bombax: Web Development, Mac Style"
 
 Welcome to the reference documentation for the Bombaxtic framework. The
 Bombaxtic framework is part of the Bombax web development platform from
 Bombaxtic LLC ( http://www.bombaxtic.com ), which allows you to use
 Objective-C and Cocoa to create highly advanced server-side web
 applications.
 
 When an incoming request is recieved from a client, the Bombax server
 communicates with a special kind of Cocoa Application called a 'BxApp'.
 All BxApps use the Bombaxtic framework in order to communicate and
 integrate with the Bombax server. In turn, the Bombaxtic framework provides
 core classes which are designed to be subclassed or used in order to
 construct web applications. These classes are:
 
 BxApp: Routes client requests to BxHandler instances

 BxHandler: Persistent handler for client requests
 
 BxTransport: Handles communication with HTTP client

 BxFile: Contains information about uploaded POST files
 
 BxDatabaseConnection: Connects to and communicates with a database
 
 BxDatabaseStatement: Database prepared statement that may be executed multiple times
 
 BxMailer: Sends e-mail with configurable headers and attachments
 
 BxMailerAttachment: Container for mail attachment data
 
 BxStaticFileHandler: Convenience handler for serving static files
  
 \sa For more information on how to use the Bombaxtic framework and the Bombax platform,
 please see the Bombax Developer's Guide.
 
 \section history Release History
 
 \subsection release1_0_0 1.0.0 - 2010/01/27
 \subsection release1beta3 1.beta.3 - 2010/01/23 
 \subsection release1beta2 1.beta.2 - 2010/01/18
 \subsection release1beta1 1.beta.1 - 2010/01/13
 \subsection release1beta0 1.beta.0 - 2010/01/10
 
 \image html logo-title.png 
 
 
 */
