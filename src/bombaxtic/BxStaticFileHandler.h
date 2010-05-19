/**
 \brief Convenience handler for serving static files
 \class BxStaticFileHandler
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 1.0
 
 Although it is much more efficient to use static folders configured
 in the Bombax server, this handler returns static files to the client
 with support for a large variety of MIME types and automatic removal
 of location prefixes.  By default BxStaticFileHandler is mapped to the
 special \c static resource folder as described in BxApp's \ref staticWebPath
 documentation.
 
 \note The most common use of BxStaticFileHandler is to transparently
 support accessing the \c static resources folder during debugging.
 
 Example of enabling the BxStaticFileHandler in a BxApp:
 \code
 - (id)setup {
     [BxStaticFileHandler setStaticResourcePath:@"/path/to/uploads"];
     [self setHandler:@"BxStaticFileHandler" forPrefix:@"uploads"];
     return self;
 }
 \endcode
 
 */

#import <Cocoa/Cocoa.h>

@class BxHandler;

@interface BxStaticFileHandler : BxHandler {
}

/** \anchor setStaticResourcePath
 \brief sets the root path for BxStaticFileHandler requests
 
 By default the your BxApp's \c static resource folder is used.
 
 \warning Because the handler is instantiated and used based
 on its class name, it is not normally possible to have multiple
 BxStaticFileHandler roots.
 
 Example of changing the static resource path:
 \code
 - (id)setup {
     [BxStaticFileHandler setStaticResourcePath:@"/path/to/uploads"];
     [self setHandler:@"BxStaticFileHandler" forPrefix:@"uploads"];
     return self;
 }
 \endcode
 
 \param path the new static resource root
 \since 1.0
 */
+ (void)setStaticResourcePath:(NSString *)path;

/** \anchor staticResourcePath
 \brief returns the current root path for BxStaticFileHandler requests
 
 By default the your BxApp's \c static resource folder is used.
 
 Example of checking the static resource path:
 \code
 - (id)setup {
     if ([[BxStaticFileHandler staticResourcePath] hasSuffix:@"/testdata"] {
         // ...
     }
     return self;
 }
 \endcode
 
 \return the current static resource root
 \since 1.0
 */
+ (NSString *)staticResourcePath;

@end
