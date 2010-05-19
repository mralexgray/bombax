/**
 \brief Sends e-mail with configurable headers and attachments
 \class BxMailer
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 1.0
 
 BxMailer makes it very easy to send outgoing e-mails with varied headers
 (such as "From:", "CC:", and "Reply-to:") and multimedia attachments.  Because
 BxMailer is not dependent on Apple Mail, etc, you can send e-mails on behalf
 of different addressees and hosts.
 
 \note Mail delivery policies may vary depending on your Postfix configuration.
 For example, you may not be able to send mail with a "From:" hostname that is not
 on a list of allowed hosts.
 
 Example of sending an e-mail with an attachment to one person while carbon copying another:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxMailerAttachment *attachment = [[BxMailerAttachment alloc] initWithName:@"diagram-v1.svg"
                                                                          path:@"/path/to/diagram.svg"];
     BxMailer *mailer = [BxMailer systemMailer];
     [mailer sendMessage:@"This is the diagram we talked about.\nSincerely,\nJohn Doe"
                 subject:@"Interesting diagram..."
                      to:@"joe@example.net"
                    from:@"john@example.com"
                 headers:[NSDictionary dictionaryWithObject:@"jane@example.net"
                                                     forKey:@"CC"]
             attachments:attachment, nil];
     [attachment release];
     return self;
 }
 \endcode
 
 \note E-mails sent through BxMailer are queued up into your sendmail handler (e.g. Postfix).
 Because of this, BxMailer returns from mail methods very quickly but it is not possible to
 test programmatically to see if the e-mail was successfully delivered.
 
 */

#import <Cocoa/Cocoa.h>

@class BxMailerAttachment;

@interface BxMailer : NSObject {
    BOOL _isSMTP;
    BOOL _useSSL;
    int _port;
    NSString *_server;
    NSString *_user;
    NSString *_password;
}

/** \anchor systemMailer
 \brief Returns the sendmail-based BxMailer singleton
 
 This is a BxApp-wide BxMailer instance that uses \c sendmail for its
 outgoing e-mails.
 
 Example of using the system mailer:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxMailer *systemMailer = [BxMailer systemMailer];
     [systemMailer sendMessage:@"Please come to the meeting at 10"
                       subject:@"Meeting schedule"
                            to:@"punctual.penelope@example.com"];
     [systemMailer sendMessage:@"Please come to the meeting at 9:45"
                       subject:@"Meeting schedule"
                            to:@"late.lenny@example.com"];
     return self;
 }
 \endcode
 \return the system mailer singleton
 \since 1.0
 */
+ (BxMailer *)systemMailer;

/*
- (id)initSMTPServer:(NSString *)server
                user:(NSString *)user
            password:(NSString *)password;

- (id)initSMTPServer:(NSString *)server
                user:(NSString *)user
            password:(NSString *)password
                port:(int)port
              useSSL:(BOOL)useSSL;
 */

/** \anchor sendMessage
 \brief Sends an e-mail using the default user and host for the "From:"
 
 This method is often suitable for administrative notifications, but
 it is usually preferrable to specify the "From:" explicitly using the
 other \c sendMessage methods.
 
 Example of sending an administrative message:
 \code
 - (id)emailLog:(NSString *)log {
     BxMailer *systemMailer = [BxMailer systemMailer];
     [systemMailer sendMessage:log
        subject:@"Log File"
             to:@"admin@example.com"];
     return self;
 }
 \endcode
 
 \param message the e-mail's message body
 \param subject the e-mail's subject
 \param to the e-mail recipient
 \return the BxMailer instance
 \since 1.0
 */
- (id)sendMessage:(NSString *)message
          subject:(NSString *)subject
               to:(NSString *)to;

/** \anchor sendMessage2
 \brief Sends an e-mail with extra header information
 
 This is the most typical usage of BxMailer.  The \c headers parameter
 may contain a variety of e-mail headers.
 
 \sa See RFC 822 and other standards for information about specific headers
 
 Example of sending an e-mail:
 \code
 - (id)sendNewsletterToCustomers:(NSArray *)customerEmails {
     NSMutableString *bccString = [NSMutableString stringWithCapacity:[customerEmails count] * 15];
     for (NSString *email in customerEmails) {
         [bccString appendFormat:@"'%@', ", email];
     }
     NSDictionary *headers = [NSDictionary dictionaryWithObject:bccString
                                                         forKey:@"BCC"];
     BxMailer *systemMailer = [BxMailer systemMailer];
     [systemMailer sendMessage:_newsletter
                       subject:@"What's Happening"
                            to:@"newsletter@example.com"
                          from:@"newsletter@example.com"
                       headers:headers];
     return self;
 }
 \endcode
 
 \param message the e-mail's message body
 \param subject the e-mail's subject
 \param to the e-mail recipient
 \param from the e-mail's sender
 \param headers any additional e-mail headers or \c nil if no headers
 \return the BxMailer instance
 \since 1.0
 */
- (id)sendMessage:(NSString *)message
          subject:(NSString *)subject
               to:(NSString *)to
             from:(NSString *)from
          headers:(NSDictionary *)headers;

/** \anchor sendMessage3
 \brief Sends an e-mail with attachments
 
 This method sends one or more attachments along with the e-mail.  These attachments
 are added onto the end of the e-mail in the order provided.
 
 Example of sending an e-mail with an attachment:
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
 
 \param message the e-mail's message body
 \param subject the e-mail's subject
 \param to the e-mail recipient
 \param from the e-mail's sender
 \param headers any additional e-mail headers or \c nil if no headers
 \param attachments a \c nil terminated list of BxMailerAttachment instances
 \return the BxMailer instance
 \since 1.0
 */
- (id)sendMessage:(NSString *)message
          subject:(NSString *)subject
               to:(NSString *)to
             from:(NSString *)from
          headers:(NSDictionary *)headers
      attachments:(BxMailerAttachment *)attachments, ...;

@end
