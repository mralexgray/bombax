/**
 \brief Contains information about uploaded POST files
 \class BxFile
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 1.0
 
 When a file is uploaded via an HTML form, it is included as a special kind of
 POST variable. BxTransport handles the upload of these files and makes them
 available as an array of BxFile instances through BxTransport's \ref uploadedFiles
 property.
 
 BxFile instances contain a variety of information about the POST file uploaded
 including the MIME type, form variable name, and file name. In addition to this
 information, the BxFile provides direct access to the actual file itself.
 
 \warning The uploaded file is stored in a temporary directory and may not be
 retained between server restarts or even different client connections. For this
 reason, it is highly recommended that if you to persist the file, you move it
 to a more permanent location.
 
 Example of persisting a BxFile's contents:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxFile *file = [transport.uploadedFiles objectAtIndex:0];
     if (file != nil) {
         [file.handle closeFile];
         NSError *error;
         [[NSFileManager defaultManager] moveItemAtPath:file.tempFilePath
                                                 toPath:@"/path/to/uploads"
                                                  error:&error];
         if (error == nil) {
             [transport write:@"Successfully uploaded."];
         }
     }
     return self;
 }
 \endcode

 \sa BxTransport, especially \ref uploadedFiles
 */
 
@interface BxFile : NSObject {
    NSFileHandle *_handle;
    NSString *_formName;
    NSString *_fileName;
    NSString *_tempFilePath;
    NSString *_mimeType;
    NSUInteger _length;
}

- (id)initWithFileName:(NSString *)fileName
              formName:(NSString *)formName
              mimeType:(NSString *)mimeType
          tempFilePath:(NSString *)tempFilePath
                handle:(NSFileHandle *)handle
                length:(NSUInteger)length;

/** \anchor length
 The file length of the uploaded file in bytes
 
 Example of testing length of file:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSFile *file = [transport.uploadedFiles objectAtIndex:0];
     if (file == nil || file.length == 0) {
         [transport write:@"Empty file"];
     }
     return self;
 }
 \endcode
 \since 1.0
 */
@property (readonly, nonatomic) NSUInteger length;

/** \anchor handle
 This is the file handle already opened for reading.
 
 \note The handle is open for read only. To write to the file, close the handle and
 open a new writeable NSFileHandle using tempFilePath.
 
 Example writing the file's data out to the client:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSFile *file = [transport.uploadedFiles objectAtIndex:0];
     if (file != nil) {
         [transport setHeader:@"Content-Type" value:file.mimeType];
         [transport writeData:[file.handle readDataToEndOfFile]];
     }
     return self;
 }
 \endcode
 \since 1.0
 */
@property (readonly) NSFileHandle *handle;

/** \anchor fileName
 This is the name of the file uploaded, as it existed on the client.
 
 Example of ensuring an uploaded PNG file has the .png extension:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSFile *file = [transport.uploadedFiles objectAtIndex:0];
     if (file != nil &&
      [file.mimeType isEqualToString:@"image/png"] &&
      [[file.fileName pathExtension] caseInsensitiveCompare:@"png"] == NSOrderedSame) {
         // ... handle upload
     }
     return self;
 }
 \endcode
 \since 1.0
 */
@property (readonly, nonatomic) NSString *fileName;

/** \anchor formName
 The variable name used for the file in the uploading form.
 
 Example of distinguishing between two files using formName in BXML:
 \code
 <html>
  <body>
   <? 
    if ([_.uploadedFiles count] == 0) {
        for (BxFile *file in _.uploadedFiles) {
            if ([file.formName isEqualToString:@"file1"]) {
                [_ writeFormat:@"File 1 has %d bytes.", file.length];
            } else if ([file.formName isEqualToString:@"file2"]) {
                [_ writeFormat:@"File 2 has %d bytes.", file.length];
            }
        }
    } else { ?>
   <form method="POST">
    <input type="file" name="file1" />
    <input type="file" name="file2" />
    <input type="submit" />
   </form>
   <? } ?>
  </body>
 </html>
 \endcode
 \since 1.0
 */
@property (readonly, nonatomic) NSString *formName;

/** \anchor mimeType
 This is the MIME type as passed according to the client.
 
 \warning Although the MIME type is normally determined automatically by
 the client's browser and file system, it can be faked and should not be
 considered a definite description of the file's contents.
 
 Example determining how to handle a file based on its MIME type:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSFile *file = [transport.uploadedFiles objectAtIndex:0];
     if (file != nil) {
         if ([file.mimeType hasPrefix:@"image"]) {
             // ... handle as image file
         } else if ([file.mimeType hasPrefix:@"video"]) {
             // ... handle as video file
         } else if ([file.mimeType hasPrefix:@"audio"]) {
             // ... handle as audio file
         }
     }
     return self;
 }
 \endcode
 \sa For a list of registered MIME types, see http://www.iana.org/assignments/media-types/
 \since 1.0
 */
@property (readonly, nonatomic) NSString *mimeType;

/** \anchor tempFilePath
 This is absolute path to the file itself.

 \note When the BxFile is created, the file is open via the handle and
 this should be closed prior to deleting or moving the file.
 
 Example of deleting the file:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSFile *file = [transport.uploadedFiles objectAtIndex:0];
     if (file != nil) {
         // ... process file
         [file.handle closeFile];
         NSError *error;
         [[NSFileManager defaultManager] removeItemAtPath:file.tempFilePath error:&error];
         if (error == nil) {
             [transport write:@"File processed and removed."];
         }
     }
     return self;
 }
 \endcode
 \since 1.0
 */
@property (readonly, nonatomic) NSString *tempFilePath;

@end
