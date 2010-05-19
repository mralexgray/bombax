/**
 \brief Container for mail attachment data
 \class BxMailerAttachment
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 1.0
 
 Instances of this class are passed to \ref BxMailer to include MIME attachments
 with outgoing emails.
 
 Example of creating a BxMailerAttachment from a PNG file:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxMailerAttachment *attachment = [[BxMailerAttachment alloc] initWithName:@"snapshot.png"
                                                                          path:@"/path/to/snapshot.png"];
     BxMailer *mailer = [BxMailer systemMailer];
     [mailer sendMessage:@"Here is the snapshot"
                 subject:@"Snapshot"
                      to:@"jane@example.com"
                    from:@"joe@example.net"
                 headers:nil
             attachments:attachment, nil];
     [attachment release];
     return self;
 }
 \endcode

 \note The attachment MIME type is automatically determined by the recipient's e-mail program
 
 */

#import <Cocoa/Cocoa.h>

@interface BxMailerAttachment : NSObject {
    NSData *_data;
    NSString *_name;
    NSString *_mimeType;
}

/** \anchor initWithName
 \brief Creates a new mail attachment with NSData

 This constructor simply retains the NSData.  Therefore, if NSMutableData
 is passed to it and changes are made to the data, those changes will affect
 the mailed attachment.
 
 Example of creating an attachment from an encoded NSArray:
 \code
 - (BxMailerAttachment *) attachmentFromArray:(NSArray *)array {
     NSData *data = [NSKeyedArchiver archivedDataWithRootObject:array];
     return [[[BxMailerAttachment alloc] initWithName:@"array.bin"
                                                 data:data
                                                 mimeType:@"application/octet-stream"] autorelease];
 }
 \endcode
 
 \param name the name the recipient will see the attachment as having
 \param data the raw data of the attachment
 \param mimeType the MIME type of the attachment
 \return the new BxMailerAttachment instance of \c nil if an error occurred
 \since 2.0
 */
- (id)initWithName:(NSString *)name
              data:(NSData *)data
          mimeType:(NSString *)mimeType;

/** \anchor initWithName2
 \brief Creates a new mail attachment from a file
 
 This constructor loads the data available at \c path.  The MIME type is automatically determined by the extension using BxUtil.
 If the extension does not map to a known MIME type, 'application/octet-stream' is used instead.
 
 Example of creating an attachment from an existing file:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxMailerAttachment *attachment = [[BxMailerAttachment alloc] initWithPath:@"/path/to/info.pdf"];
                                                                          name:@"info.pdf"];
     if (attachment) {
         // ... mail attachment
     }
     return self;
 }
 \endcode
 
 \param name the name the recipient will see the attachment as having
 \param path the path to the file used as the attachment
 \return the new BxMailerAttachment instance of \c nil if an error occurred
 \since 1.0
 */
- (id)initWithName:(NSString *)name
              path:(NSString *)path;

/** \anchor data
 The raw data of the attachment
 
 Example of ensuring the attachment length is reasonable:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSString *choice = [transport.queryVars objectForKey:@"uploadChoice"];
     if (choice) {
         NSString *uploadPath = [[BxStaticFileHandler staticResourcePath] stringByAppendingPathComponent:uploadChoice];
         BxMailerAttachment *attachment = [[BxMailerAttachment alloc] initWithPath:uploadPath
                                                                              name:@"report.zip"];
         if ([attachment.data length] < 1048576) {
             // ... mail attachment
         }
         [attachment release];
     }
     return self;
 }
 \endcode
 
 \since 1.0
 */
@property (readonly, nonatomic) NSData *data;

/** \anchor mimeType
 The MIME type for the attachment
 
 Example of determining the MIME type:
 \code
 - (BOOL)allowAttachment:(BxMailerAttachment *)attachment {
     if ([attachment.mimeType isEqualToString:@"application/java-archive"]) {
         return NO;
     } else {
         return YES;
     }
 }
 \endcode
 
 \since 2.0
 */
@property (readonly, nonatomic) NSString *mimeType;

/** \anchor name
 The file name that will be given to the attachment
 
 Example of checking file name:
 \code
 - (BOOL)allowAttachment:(BxMailerAttachment *)attachment {
     if ([attachment.name hasSuffix:@".vbs"]) {
         return NO;
     } else {
         return YES;
     }
 }
 \endcode
 
 \since 1.0
 */
@property (readonly, nonatomic) NSString *name;

@end
