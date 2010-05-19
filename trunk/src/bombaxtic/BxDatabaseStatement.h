/**
 \brief Database prepared statement that may be executed multiple times
 \class BxDatabaseStatement
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 1.0
 
 BxDatabaseStatement contains a single prepared statement for a BxDatabaseConnection
 that allows binding with different variables, execution one or more times, and the
 fetching of result sets.  BxDatabaseStatements are created through BxDatabaseConnection's
 prepare: and prepareWith: methods or by directly invoking initWithConnection:.
 
 Values may be bound to prepared statements using bind indicators which vary from database
 to database.  For example, MySQL uses '?' in place of the variable, Oracle uses ':name',
 PostgreSQL '$1', and SQLite can use any of the above.  For details, please consult
 your database's documentation on bind values in prepared statements.
 
 BxDatabaseStatement supports the \c NSFastEnumeration protocol allows it to return
 a series of \c NSArray rows after execution.
 
 Example of using a BxDatabaseStatement with a SQlite database:
 \code
 - (id)setup {
     _db = [[BxDatabaseConnection alloc] initWithSQLiteFile:@"/path/to/file.sqlite3"
                                                    locking:YES];
     _selectStmt = [[BxDatabaseStatement initWithConnection:_db
                                                        sql:@"SELECT * FROM cheeses WITH name=:name",
                                                            nil];
 }
 
 - (id)renderWithTransport:(BxTransport *)transport {
     [_selectStmt bindValue:@"cheddar"
                     forKey:@"name"];
     if ([_selectStmt:execute] && _selectStmt.hasMoreRows) {
         NSDictionary *cheese = [_selectStmt fetchDictionary];
         BxDatabaseStatement *personStmt = [_db prepareWith:@"SELECT name, id FROM persons WITH favoriteCheeseId=:1",
                                                            [cheese objectForKey:@"id"],
                                                            nil];
         if ([personStmt execute]) {
         for (NSArray *person in personStmt) {
             [transport writeFormat:@"%@ with id %@ likes cheddar cheese (id %@)."
                                    [person objectWithIndex:0],
                                    [person objectWithIndex:1],
                                    [cheese objectForKey:@"id"]];
         }
     }
     return self;
 }
 \endcode
 
 \note Parameters that are not explicitly bound are automatically bound as NULLs.
 
 \sa For more information, please see the documentation for the respective DBMS you are using
 
 */

#import <Cocoa/Cocoa.h>

@class BxDatabaseConnection;

@interface BxDatabaseStatement : NSObject <NSFastEnumeration> {
    BOOL _hasClosed;
    BOOL _hasResetted;
    BOOL _hasMoreRows;
    BOOL _isSelect;
    BxDatabaseConnection *_connection;
    char *_rawBindsBuffer;
    char *_rawResultsBuffer;
    int _rowsLeft;
    int _columnCount;
    NSMutableArray *_bindNames;
    NSMutableArray *_bindValues;
    NSString *_statementName;
    void *_rawBinds;
    void *_rawResults;
    void *_rawResultsInfo;
    void *_rawStatement;
}

/** \anchor bindArray
 \brief Binds the array to the prepared statement's parameters
 
 The array binds are bound in the same column order as the parameters.  To bind a value to
 NULL, set it to [NSNull null].  All other values are converted to NSString through the
 \c description: method if they are not strings already.
 
 Example of using \c bindArray:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxDatabaseStatement *stmt = [_db prepare:@"SELECT * FROM persons WHERE city=? AND country=?"];
     NSMutableArray *binds = [NSMutableArray arrayWithCapacity:2];
     [binds addObject:@"Tokyo"]; // column 1
     [binds addObject:@"Japan"]; // column 2
     [stmt bindArray:binds];
     [stmt execute];
     // ...
     return self;
 }
 \endcode
 
 \param binds an array of parameters in the same order as given in the prepared statement
 
 \return \c YES if the bind took place without error
 \since 1.0
 */
- (BOOL)bindArray:(NSArray *)binds;

/** \anchor bindDictionary
 \brief Binds the dictionary to the prepared statement's parameters
 
 The dictionary is bound using the same parameter names as given in the prepared statement.
 To bind a value to NULL, set it to [NSNull null].  All other values are converted to NSString
 through the \c description: method if they are not strings already.
 
 \note Not all databases support named statement parameters (e.g. they are not supported in MySQL).
 
 Example of using \c bindDictionary:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxDatabaseStatement *stmt = [_db prepare:@"SELECT * FROM persons WHERE city=:city AND country=:country"];
     NSMutableDictionary *binds = [NSMutableDictionary dictionaryWithCapacity:2];
     [binds setObject:@"Tokyo"
               forKey:@"city"];
     [binds setObject:@"Japan"
               forKey:@"country"];
     [stmt bindDictionary:binds];
     [stmt execute];
     // ...
     return self;
 }
 \endcode
 
 \param binds a dictionary of parameters using the same names as given in the prepared statement
 
 \return \c YES if the bind took place without error
 \since 1.0
 */
- (BOOL)bindDictionary:(NSDictionary *)binds;

/** \anchor bindWith
 \brief Binds the nil-terminated list of values to the prepared statement's parameters
 
 The list's binds are bound in the same column order as the parameters.  To bind a value to
 NULL, set it to [NSNull null].  All other values are converted to NSString through the
 \c description: method if they are not strings already.
 
 Example of using \c bindWith:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxDatabaseStatement *stmt = [_db prepare:@"SELECT * FROM persons WHERE city=:city AND country=:country"];
     [stmt bindwith:@"Tokyo", @"Japan", nil];
     [stmt execute];
     // ...
     return self;
 }
 \endcode
 
 \param binds a \c nil terminated list of bind values
 
 \return \c YES if the bind took place without error
 \since 1.0
 */
- (BOOL)bindWith:(id)binds, ...;

/** \anchor bindValue
 \brief Binds a value to a 1-indexed column in the prepared statement's parameters
 
 To bind a value to NULL, set it to [NSNull null].  All other values are converted
 to NSString through the \c description: method if they are not strings already.
 It is important to remember that the column is 1-indexed, unlike most C/ObjC objects.
 
 Example of binding a numerically-indexed column:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxDatabaseStatement *stmt = [_db prepare:@"SELECT * FROM persons WHERE city=:city AND country=:country"];
     [stmt bindValue:@"Tokyo"
           forColumn:1];
     [stmt bindValue:@"Japan"
           forColumn:2];
     [stmt execute];
     // ...
     return self;
 }
 \endcode
 
 \param value a NSString, NSNull, or other object to be converted to NSString
 \param column the 1-indexed column to set the parameter for
 
 \return \c YES if the bind took place without error
 \since 1.0
 */
- (BOOL)bindValue:(id)value
        forColumn:(int)column;

/** \anchor bindValue2
 \brief Binds a value to the given named parameter in the prepared statement's parameters
 
 To bind a value to NULL, set it to [NSNull null].  All other values are converted
 to NSString through the \c description: method if they are not strings already.
 It is important to remember that the column is 1-indexed, unlike most C/ObjC objects.
 
 \note Not all databases support named statement parameters (e.g. they are not supported in MySQL).
  
 Example of binding a named parameter:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxDatabaseStatement *stmt = [_db prepare:@"SELECT * FROM persons WHERE city=:city AND country=:country"];
     [stmt bindValue:@"Tokyo"
              forKey:@"city"];
     [stmt bindValue:@"Japan"
              forKey:@"country"];
     [stmt execute];
     // ...
     return self;
 }
 \endcode
 
 \param value a NSString, NSNull, or other object to be converted to NSString
 \param key the name of the parameter to bind to
 
 \return \c YES if the bind took place without error
 \since 1.0
 */
- (BOOL)bindValue:(id)value
           forKey:(NSString *)key;

/** \anchor close
 \brief Closes the statement and frees the given resources
 
 This method permanently closes the statement and frees up associated memory.
 After \c close is called, all other BxDatabaseStatement methods no longer have any
 effect.  As \c close is automatically called when the instance is deallocated, it is
 rarely necessary to call this method explicitly.
 
 Example of explicitly closing a statement in a garbage-collected environment:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     if ([[transport.queryVars objectForKey:@"command"] isEqual:@"close"]) {
         [_stmt close];
         _stmt = nil;
     }
     return self;
 }
 \endcode
 
 \return \c NO if any errors were encountered

 \since 1.0
 */
- (BOOL)close;

/** \anchor execute
 \brief Executes the prepared statement with whatever binds are in place
 
 Until this method is called, the prepared statement has not changed the
 data in the database.  \c execute may be invoked repeatedly with varying
 parameter bindings.
 
 Example of executing a BxDatabaseStatement:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxDatabaseStatement *stmt = [_db prepareWith:@"SELECT * FROM cheeses WHERE name=?", @"swiss", nil];
     [stmt execute];
     // ...
     [stmt bindWith:@"gouda", nil"];
     [stmt execute];
     // ...
     return self;
 }
 \endcode
 
 \return \c NO if any errors were encountered
 
 \since 1.0
 */
- (BOOL)execute;

/** \anchor executeWith
 \brief Executes the prepared statement with the given nil-terminated list of binds
 
 Until this method is called, the prepared statement has not changed the
 data in the database.  \c execute may be invoked repeatedly with varying
 parameter bindings.
 
 The list's binds are bound in the same column order as the parameters.  To bind a value to
 NULL, set it to [NSNull null].  All other values are converted to NSString through the
 \c description: method if they are not strings already.
 
 
 Example of executing a BxDatabaseStatement:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxDatabaseStatement *stmt = [_db prepareWith:@"SELECT * FROM cheeses WHERE name=?"];
     [stmt executeWith:@"swiss", nil];
     // ...
     [stmt executeWith:@"gouda", nil"];
     // ...
     return self;
 }
 \endcode

 \param binds a \c nil terminated list of bind values

 \return \c NO if any errors were encountered
 
 \since 1.0
 */
- (BOOL)executeWith:(id)binds, ...;

/** \anchor fetchArray
 \brief Returns the next row array for a SELECT statement

 Each column in the row is included in the same order as it is specified in
 the SELECT or through the natural order of the database in the case of '*'.
 
 Note: NULL values are returned as [NSNull null].  All other values are NSStrings.

 Example of returning array rows:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxDatabaseStatement *stmt = [_db prepare:@"SELECT name, flavor FROM cheeses"];
     [stmt execute];
     while (stmt.hasMoreRows) {
         NSArray *result = [stmt fetchRow];
        [transport writeFormat:@"%@ has flavor %@",
                               [result objectAtIndex:0],
                               [result objectAtIndex:1]];
     }
     return self;
 }
 \endcode
 
 \return a row array, or \c nil if there are no more rows or an error occurred
 \since 1.0
 */
- (NSArray *)fetchArray;

/** \anchor fetchDictionary
 \brief Returns the next row dictionary for a SELECT statement
 
 Each column is returned using the result set column name.
 
 Note: NULL values are returned as [NSNull null].  All other values are NSStrings.
 
 Example of returning array rows:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxDatabaseStatement *stmt = [_db prepare:@"SELECT name, flavor FROM cheeses"];
     [stmt execute];
     while (stmt.hasMoreRows) {
     NSDictionary *result = [stmt fetchDictionary];
     [transport writeFormat:@"%@ has flavor %@",
                            [result objectForKey:@"name"],
                            [result objectForKey:@"flavor"]];
     }
     return self;
 }
 \endcode
 
 \return a row dictionary, or \c nil if there are no more rows or an error occurred
 \since 1.0
 */
- (NSDictionary *)fetchDictionary;

/** \anchor fetchValue
 \brief Returns the the first column value in the next row for a SELECT statement
 
 Note: NULL values are returned as [NSNull null].  All other values are NSStrings.
 
 Example of returning a single value:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxDatabaseStatement *stmt = [_db prepare:@"SELECT name FROM cheeses"];
     [stmt execute];
     while (stmt.hasMoreRows) {
         [transport writeFormat:@"Cheese: %@", [stmt fetchValue]]; has flavor %@",
     }
     return self;
 }
 \endcode
 
 \return a single value, or \c nil if there are no more rows or an error occurred
 \since 1.0
 */
- (id)fetchValue;

/** \anchor initWithConnection
 \brief Creates a new BxDatabaseStatement for the given SQL
 
 The prepared statement is automatically bound to the \c connection.  A \c nil
 terminated list of parameter values may be added after \c sql.   To bind a value
 to NULL, set it to [NSNull null].  All other values are converted to NSString
 through the \c description: method if they are not strings already.
 
 \note BxDatabaseConnection's \c prepare and \c prepareWith are often more convenient
 to use than \c initWithConnection:.
 
 \note  Values may be bound to prepared statements using bind indicators which vary
 from database to database.  For example, MySQL uses '?' in place of the variable,
 Oracle uses ':name', PostgreSQL '$1', and SQLite can use any of the above.  For
 details, please consult your database's documentation on bind values in prepared
 statements.
 
 Example of creating a prepared statement:
 \code
 - (id)setup {
     _db = [[BxDatabaseConnection alloc] initWithSQLiteFile:@"/path/to/file.sqlite3"
                                                    locking:YES];
     _stmt = [[BxDatabaseStatement alloc] initWithConnection:_db
                                                         sql:@"SELECT * FROM cheeses",
                                                             nil];
     return self;
 }
 \endcode
 
 \param connection an existing, open BxDatabaseConnection
 \param sql the SQL that forms the prepared statement, followed by a \c nil terminated list of initial values
 \return the new BxDatabaseStatement or \c nil if an error occurred (in which case, connection.lastError is set)
 \since 1.0
 */
- (id)initWithConnection:(BxDatabaseConnection *)connection
                     sql:(NSString *)sql, ...;

- (id)initWithConnection:(BxDatabaseConnection *)connection
                     sql:(NSString *)sql
                    args:(va_list)args;


/** \anchor hasMoreRows
 If \c YES there are additional rows available for \c fetchArray, \c fetchDictionary, and
 \c fetchValue.  Each fetch increments the row cursor and will change the value of \c hasMoreRows
 to \c NO if there are no more rows to fetch.
 
 Example of using hasMoreRows:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxDatabaseStatement *stmt = [_db prepare:@"SELECT * FROM cheeses"];
     [stmt execute];
     while (stmt.hasMoreRows) {
         [transport write:[[stmt fetchDictionary] description]];
     }
     return self;
 }
 \endcode
 
 \since 1.0
 */
@property (nonatomic, readonly) BOOL hasMoreRows;

/** \anchor connection
 The BxDatabaseConnection that this statement is attached to.
 
 Example of refering to the connection:
 \code
 - (id)helperFunction:(BxDatabaseStatement *)stmt {
     if ([stmt execute] == NO) {
         BxDatabaseConnection *conn = stmt.connection;
         NSLog(@"%@", conn.lastError);
     } else {
         // ...
     }
     return self;
 }
 \endcode
 
 \since 1.0
 */
@property (nonatomic, readonly) BxDatabaseConnection *connection;

/** \anchor rawStatement
 This is the raw prepared statement object backing the instance.  Use of this 
 object is not recommended.
 
 \note The type of object returned varies as follows:
 \code
     MySQL -> MYSQL_STMT *
     Oracle -> OCIStmt *
     PostgreSQL -> (not set -- prepared statements are stored in a connection-based dictionary)
     SQLite -> sqlite3_stmt *
 \endcode
 
 Example of accessing the raw statement of a SQLite database:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     BxFile *file = [transport.uploadedFiles objectAtIndex:0];
     BxDatabaseStatement *stmt = [_db prepare:@"INSERT INTO uploads (name, data)  VALUES (?, ?)"];
     [stmt bindValue:file.fileName
           forColumn:1];
     NSData *data = [file.handle readDataToEndOfFile];
     sqlite3_stmt *rawStmt = (sqlite3_stmt *) stmt.rawStatement;
     sqlite3_bind_blob(rawStmt, 2, [data bytes], [data length], SQLITE_TRANSIENT);
     [stmt execute];
     return self;
 }
 \endcode
 
 \since 1.0
 */
@property (nonatomic, readonly) void *rawStatement;

@end
