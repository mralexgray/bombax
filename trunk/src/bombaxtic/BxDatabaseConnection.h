/**
 \brief Connects to and communicates with a database
 \class BxDatabaseConnection
 \author Bombaxtic LLC - http://www.bombaxtic.com
 \since 1.0
 
 BxDatabaseConnection opens a connection with a DBMS and provides methods for
 executing SQL queries, creating prepared statements, and controlling transactions.
 BxDatabaseConnection uses BxDatabaseStatement instances for most of its interoperation
 with the DBMS such as executeWith:.  Currently, BxDatabaseConnection supports Oracle, 
 MySQL, PostgreSQL, and SQLite.
 
 BxDatabaseConnection supports thread-safe access if the \c locking parameter is \c YES
 when the database is initialized.  No state is shared between BxDatabaseConnection
 instances and multiple concurrent connections to different databases are possible.
  
 Example of connecting to a MySQL DBMS on localhost and using a prepared statement:
 \code
 @interface MyHandler : BxHandler {
    BxDatabaseConnection *_db;
 }
 @end
 
 @implementation MyHandler
 - (id)setup {
     _db = [[BxDatabaseConnection alloc] initWithMySQLServer:@"localhost"
                                                    database:@"exampledb"
                                                        user:@"jane"
                                                    password:@"secret"
                                                     locking:YES
                                                       error:nil];
     [_db execute:@"CREATE TABLE ipInfo (rowId INT AUTO_INCREMENT, ip VARCHAR(64), key VARCHAR(64), value VARCHAR(128), PRIMARY KEY (rowId))"];
     return self;
 }
 
 - (id)renderWithTransport:(BxTransport *)transport {
     NSString *ipAddress = [transport.serverVars objectForKey:@"REMOTE_ADDR"];
     NSMutableDictionary *results = [_db fetchNamedRowWith:@"SELECT * FROM ipInfo WHERE ip=?", ipAddress, nil];
     if (results != nil) {
         [transport write:@"Old variables:\n"];
         [transport writeFormat:@"%@", results];
     }
     BxDatabaseStatement *stmt = [_db prepare:@"INSERT INTO ipInfo (ip, key, value) VALUES (?, ?, ?)"];
     for (NSString *key in transport.serverVars) {
         [stmt bindWith:ipAddress, key, [transport.serverVars objectForKey:key]];
         [stmt execute];
     }
     results = [_db fetchNamedRowWith:@"SELECT * FROM ipInfo WHERE ip=?", ipAddress, nil];
     if (results != nil) {
        [transport write:@"New variables:\n"];
        [transport writeFormat:@"%@", results];
     }
     return self;
 }
 \endcode
 
 \sa For more information, please see the documentation for the respective DBMS you are using
 
 */

#import <Cocoa/Cocoa.h>

enum BxDatabaseConnectionType_enum {
    BxDatabaseConnectionTypeUnknown,
    BxDatabaseConnectionTypeMySQL,
    BxDatabaseConnectionTypeOracle,
    BxDatabaseConnectionTypePostgreSQL,
    BxDatabaseConnectionTypeSQLite
} typedef BxDatabaseConnectionType;

@class BxDatabaseStatement;

@interface BxDatabaseConnection : NSObject {
    BOOL _isClosed;
    BOOL _isLocking;
    BxDatabaseConnectionType _connectionType;
    NSRecursiveLock *_lock;
    NSString *_lastError;
    void *_rawConnection;
    void *_rawError;
    void *_rawServer;
    NSMutableSet *_statementsSet;
}

/** \anchor beginTransaction
 \brief Begins a database transaction
 
 Begins a new database transaction.  Note that the database and tables must support
 transactions for this command to have any effect (e.g. MySQL MyISAM tables do not
 support transactions while InnoDB tables do).  Currently, named transactions are
 not supported.
 
 \note Because transaction state is shared within a connection, transactions within
 a multithreaded connection may want to manually lock the \c recursiveLock.

 \note When using MySQL, calling \c beginTransaction implicitly calls \c commitTransaction
 
 Example of using a transaction:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [_db beginTransaction];
     NSArray *result = [_db fetchRowWith:@"SELECT balance FROM accounts WHERE accountNumber=?", _accountNumber];
     BOOL cancel = NO;
     if (result != nil) {
         double balance = [[result lastObject] doubleValue];
         balance += 100;
         if (! [_db executeWith:@"UPDATE accounts SET balance=? WHERE accountNumber=?", [NSString stringWithFormat:@"%f", balance], _accountNumber, nil]) {
             cancel = YES;
         }
     } else {
         cancel = YES;
     }
     if (cancel) {
         [_db rollbackTransaction];
         [transport write:@"Transaction cancelled"];
     } else {
         [_db commitTransaction];
         [transport write:@"Transaction succeeded"];
     }
     return self;
 }
 \endcode
 
 \return \c YES if the command succeeded, else \c lastError is set
 \since 1.0
 */
- (BOOL)beginTransaction;

/** \anchor close
 \brief Closes the database connection
 
 This method permanently closes the database connection and frees up associated memory.
 After \c close is called, all other BxDatabaseConnection methods no longer have any
 effect.  As \c close is automatically called when the instance is deallocated, it is
 rarely necessary to call this method explicitly.
 
 Example of explicitly closing a connection in a garbage-collected environment:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     if ([[transport.queryVars objectForKey:@"command"] isEqual:@"close"]) {
         [_db close];
         _db = nil;
     }
     return self;
 }
 \endcode
 
 \return \c NO if any errors were encountered
 
 \since 1.0
 */
- (BOOL)close;

/** \anchor commitTransaction
 \brief Commits an existing database transaction
 
 Note that the database and tables must support transactions for this command to
 have any effect (e.g. MySQL MyISAM tables do not support transactions while InnoDB
 tables do).  Currently, named transactions are not supported.
 
 \note Because transaction state is shared within a connection, transactions within
 a multithreaded connection may want to manually lock the \c recursiveLock.
 
 Example of using a transaction:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [_db beginTransaction];
     NSArray *result = [_db fetchRowWith:@"SELECT balance FROM accounts WHERE accountNumber=?", _accountNumber];
     BOOL cancel = NO;
     if (result != nil) {
         double balance = [[result lastObject] doubleValue];
         balance += 100;
         if (! [_db executeWith:@"UPDATE accounts SET balance=? WHERE accountNumber=?", [NSString stringWithFormat:@"%f", balance], _accountNumber, nil]) {
             cancel = YES;
         }
     } else {
         cancel = YES;
     }
     if (cancel) {
         [_db rollbackTransaction];
         [transport write:@"Transaction cancelled"];
     } else {
         [_db commitTransaction];
         [transport write:@"Transaction succeeded"];
     }
     return self;
 }
 \endcode
 
 \return \c YES if the command succeeded, else \c lastError is set
 \since 1.0
 */
- (BOOL)commitTransaction;

/** \anchor execute
 \brief Executes the provided SQL
 
 This command executes the raw SQL passed as the \c sql parameter.  It is not
 advisable to construct the SQL from user-provided parameters due to the
 danger of SQL injection.  In such cases, use of \c executeWith: is recommended.
 
 Example of creating a database with \c execute:
 \code
 - (id)setup {
     _db = [[BxDatabaseConnection alloc] initWithSqliteMemoryLocking:YES error:nil];
     [_db execute:@"CREATE TABLE cheeses (name TEXT, flavor INT)"];
     return self;
 }
 \endcode
 
 \param sql the raw SQL to execute
 \return \c YES if the command succeeded, else \c lastError is set
 \since 1.0
 */
- (BOOL)execute:(NSString *)sql;

/** \anchor executeWith
 \brief Executes the provided SQL with the provided values
 
 This command executes the raw SQL passed as the \c sql parameter. The \c NSStrings
 following \c sql are bound to the placeholders in the SQL.  The exact format for
 specifying the placeholders varies from database to database (e.g. \c :name for Oracle,
 \c ? for MySQL, etc).
 
 Example of inserting a value using \c excuteWith:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSString *cheese = [transport.queryVars objectForKey:@"cheese"];
     NSString *flavor = [transport.queryVars objectForKey:@"flavor"];
     if (cheese && flavor) {
         [_db executeWith:@"INSERT INTO cheeses (name, flavor) VALUES (:1, :2)", cheese, flavor, nil];
     }
     return self;
 }
 \endcode
 
 \param sql the raw SQL to execute, followed by a \c nil terminated list of values
 \return \c YES if the command succeeded, else \c lastError is set
 \since 1.0
 */
- (BOOL)executeWith:(NSString *)sql, ...;

/** \anchor fetchAll
 \brief Returns an array of row arrays for a SELECT statement
 
 This command executes the raw SQL passed as the \c sql parameter and returns
 the result set as a \c NSArray populated with a \c NSArray rows.  It is not
 advisable to construct the SQL from user-provided parameters due to the
 danger of SQL injection.  In such cases, use of \c fetchAllWith: is recommended.
 
 Note: NULL values are returned as [NSNull null].  All other values are NSStrings.

 Example of returning all the results in a table:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSArray *results = [_db fetchAll:@"SELECT name, flavor IN cheeses"];
     if (results) {
         for (NSArray *result in results) {
             [transport writeFormat:@"Name:%@ Flavor:%@\n", [result objectAtIndex:0], [result objectAtIndex:1]];
         }
     } else {
         [transport writeFormat:@"Error: %@", _db.lastError];
     }
     return self;
 }
 \endcode
 
 \param sql the raw SQL SELECT statement to execute
 \return an populated array of rows or \c nil if an error occurred
 \since 1.0
 */
- (NSArray *)fetchAll:(NSString *)sql;

/** \anchor fetchAllWith
 \brief Returns an array of row arrays for a SELECT statement with the provided values
 
 This command executes the raw SQL passed as the \c sql parameter and returns
 the result set as a \c NSArray populated with a \c NSArray rows. The \c NSStrings
 following \c sql are bound to the placeholders in the SQL.  The exact format for
 specifying the placeholders varies from database to database (e.g. \c :name for Oracle,
 \c ? for MySQL, etc).
 
 Note: NULL values are returned as [NSNull null].  All other values are NSStrings.

 Example of returning all the results in a table:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSArray *results = [_db fetchAllWith:@"SELECT name, flavor IN cheeses WHERE flavor > ?", @"5", nil];
     if (results) {
         for (NSArray *result in results) {
             [transport writeFormat:@"Name:%@ Flavor:%@\n", [result objectAtIndex:0], [result objectAtIndex:1]];
         }
     } else {
         [transport writeFormat:@"Error: %@", _db.lastError];
     }
     return self;
 }
 \endcode
 
 \param sql the raw SQL SELECT statement to execute, followed by a \c nil terminated list of values
 \return an populated array of rows or \c nil if an error occurred
 \since 1.0
 */
- (NSArray *)fetchAllWith:(NSString *)sql, ...;

/** \anchor fetchNamedAll
 \brief Returns an array of row dictionaries for a SELECT statement
 
 This command executes the raw SQL passed as the \c sql parameter and returns
 the result set as a \c NSArray populated with a \c NSDictionary rows.  It is not
 advisable to construct the SQL from user-provided parameters due to the
 danger of SQL injection.  In such cases, use of \c fetchNamedAllWith: is recommended.
 
 Note: NULL values are returned as [NSNull null].  All other values are NSStrings.

 Example of returning all the results in a table:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSArray *results = [_db fetchNamedAll:@"SELECT name, flavor IN cheeses"];
     if (results) {
         for (NSDictionary *result in results) {
             [transport writeFormat:@"Name:%@ Flavor:%@\n",
                                   [result objectForKey:@"name"],
                                   [result objectForKey:@"flavor"]];
         }
     } else {
         [transport writeFormat:@"Error: %@", _db.lastError];
     }
     return self;
 }
 \endcode
 
 \param sql the raw SQL SELECT statement to execute
 \return an populated array of rows or \c nil if an error occurred
 \since 1.0
 */
- (NSArray *)fetchNamedAll:(NSString *)sql;

/** \anchor fetchNamedAllWith
 \brief Returns an array of row dictionaries for a SELECT statement with the provided values
 
 This command executes the raw SQL passed as the \c sql parameter and returns
 the result set as a \c NSArray populated with a \c NSDictionary rows. The \c NSStrings
 following \c sql are bound to the placeholders in the SQL.  The exact format for
 specifying the placeholders varies from database to database (e.g. \c :name for Oracle,
 \c ? for MySQL, etc).

 Note: NULL values are returned as [NSNull null].  All other values are NSStrings.

 Example of returning all the results in a table:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSArray *results = [_db fetchNamedAllWith:@"SELECT name, flavor IN cheeses WHERE flavor > ?", @"5", nil];
     if (results) {
         for (NSDictionary *result in results) {
             [transport writeFormat:@"Name:%@ Flavor:%@\n",
                                    [result objectForKey:@"name"],
                                    [result objectForKey:@"flavor"]];
         }
     } else {
         [transport writeFormat:@"Error: %@", _db.lastError];
     }
     return self;
 }
 \endcode
 
 \param sql the raw SQL SELECT statement to execute, followed by a \c nil terminated list of values
 \return an populated array of rows or \c nil if an error occurred
 \since 1.0
 */
- (NSArray *)fetchNamedAllWith:(NSString *)sql, ...;

/** \anchor fetchNamedRow
 \brief Returns a single of row dictionary for a SELECT statement
 
 This command executes the raw SQL passed as the \c sql parameter and returns
 the result set as a single \c NSDictionary row.  It is not advisable to
 construct the SQL from user-provided parameters due to the danger of SQL injection.
 In such cases, use of \c fetchNamedRowWith: is recommended.
 
 Note: NULL values are returned as [NSNull null].  All other values are NSStrings.

 Example of returning a single results for a table:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSDictionary *result = [_db fetchNamedRow:@"SELECT value, setOn IN settings WHERE name='config_path'"];
     if (result) {
         [transport writeFormat:@"Path:%@  set on:@%",
                                [result objectForKey:@"value"],
                                [result objectForKey:@"setOn"]];
     } else {
         [transport writeFormat:@"Error: %@", _db.lastError];
     }
     return self;
 }
 \endcode
 
 \param sql the raw SQL SELECT statement to execute
 \return a single row dictionary or \c nil if an error occurred
 \since 1.0
 */
- (NSDictionary *)fetchNamedRow:(NSString *)sql;

/** \anchor fetchNamedRowWith
 \brief Returns a single of row dictionary for a SELECT statement with the provided values
 
 This command executes the raw SQL passed as the \c sql parameter and returns
 the result set as a single \c NSDictionary row.   The \c NSStrings
 following \c sql are bound to the placeholders in the SQL.  The exact format for
 specifying the placeholders varies from database to database (e.g. \c :name for Oracle,
 \c ? for MySQL, etc).

 Note: NULL values are returned as [NSNull null].  All other values are NSStrings.
 
 Example of returning a single results for a table:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSDictionary *results = [_db fetchNamedRowWith:@"SELECT value, setOn IN settings WHERE name=?", @"config_path", nil];
     if (result) {
         [transport writeFormat:@"Path:%@  set on:@%",
                                [result objectForKey:@"value"],
                                [result objectForKey:@"setOn"]];
     } else {
         [transport writeFormat:@"Error: %@", _db.lastError];
     }
     return self;
 }
 \endcode
 
 \param sql the raw SQL SELECT statement to execute, followed by a \c nil terminated list of values
 \return a single row dictionary or \c nil if an error occurred
 \since 1.0
 */
- (NSDictionary *)fetchNamedRowWith:(NSString *)sql, ...;

/** \anchor fetchRow
 \brief Returns a single of row array for a SELECT statement
 
 This command executes the raw SQL passed as the \c sql parameter and returns
 the result set as a single \c NSArray row.  It is not advisable to
 construct the SQL from user-provided parameters due to the danger of SQL injection.
 In such cases, use of \c fetchRowWith: is recommended.
 
 Note: NULL values are returned as [NSNull null].  All other values are NSStrings.
 
 Example of returning a single results for a table:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSArray *result = [_db fetchRow:@"SELECT value, setOn IN settings WHERE name='config_path'"];
     if (result) {
         [transport writeFormat:@"Path:%@  set on:@%",
                               [result objectAtIndex:0],
                               [result objectAtIndex:1]];
     } else {
         [transport writeFormat:@"Error: %@", _db.lastError];
     }
     return self;
 }
 \endcode
 
 \param sql the raw SQL SELECT statement to execute
 \return a single row array or \c nil if an error occurred
 \since 1.0
 */
- (NSArray *)fetchRow:(NSString *)sql;

/** \anchor fetchRowWith
 \brief Returns a single of row array for a SELECT statement with the provided values
 
 This command executes the raw SQL passed as the \c sql parameter and returns
 the result set as a single \c NSArray row.   The \c NSStrings following \c sql
 are bound to the placeholders in the SQL.  The exact format for specifying the
 placeholders varies from database to database (e.g. \c :name for Oracle, \c ?
 for MySQL, etc).
 
 Note: NULL values are returned as [NSNull null].  All other values are NSStrings.

 Example of returning a single results for a table:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSArray *result = [_db fetchRowWith:@"SELECT value, setOn IN settings WHERE name=?", @"config_path", nil];
     if (result) {
         [transport writeFormat:@"Path:%@  set on:@%",
                                [result objectAtIndex:0],
                                [result objectAtIndex:1]];
     } else {
         [transport writeFormat:@"Error: %@", _db.lastError];
     }
     return self;
 }
 \endcode
 
 \param sql the raw SQL SELECT statement to execute, followed by a \c nil terminated list of values
 \return a single row array or \c nil if an error occurred
 \since 1.0
 */
- (NSArray *)fetchRowWith:(NSString *)sql, ...;

/** \anchor initWithMySQLServer
 \brief Creates a new BxDatabaseConnection for a MySQL server
 
 This establishes a connection with a MySQL server.  The MySQL server may be
 remote or local.
 
 \note the threadsafe version of the MySQL client library is used
 
 Establishing a connection to a remote MySQL database:
 \code
 - (id)setup {
     NSString *error = nil;
     _db = [[BxDatabaseConnection alloc] initWithMySQLServer:@"10.20.30.69"
                                                    database:@"maindb"
                                                        user:@"jane"
                                                    password:@"secret"
                                                     locking:YES
                                                       error:&error]
     if (error) {
         NSLog(@"%@", error);
     }
     return self;
 }
 \endcode
 
 \note This command is equivalent to calling:
 \code
   [bxDatabaseConnection initWithMySQLServer:server
                                    database:database
                                        user:user
                                    password:password
                                        port:0
                                      socket:nil
                                     locking:locking
                                       error:error];
 \endcode

 \sa See full initWithMySQL method for parameter details
 
 \param server the location of the server such as 'localhost' or '192.168.1.100'
 \param database the name of the database
 \param user the database user to connect as
 \param password the password for the database user
 \param locking if \c YES then all database access will be guarded through the \c recursiveLock
 \param error if not \c nil will be populated with the error message if an error occurs
 
 \return a successfully connection BxDatabaseConnection or \c nil if an error occurred
 \since 1.0
 */
- (id)initWithMySQLServer:(NSString *)server
                 database:(NSString *)database
                     user:(NSString *)user
                 password:(NSString *)password
                  locking:(BOOL)locking
                    error:(NSString **)error;

/** \anchor initWithMySQLServer2
 \brief Creates a new BxDatabaseConnection for a MySQL server

 This establishes a connection with a MySQL server.  The MySQL server may be
 remote or local.
 
 \note the threadsafe version of the MySQL client library is used
 
 Establishing a connection to a local MySQL database:
 \code
 - (id)setup {
     NSString *error = nil;
     _db = [[BxDatabaseConnection alloc] initWithMySQLServer:@"localhost"
                                                    database:@"maindb"
                                                        user:@"joe"
                                                    password:@"secret"
                                                        port:0
                                                      socket:nil
                                                     locking:YES
                                                       error:&error]
     if (error) {
         NSLog(@"%@", error);
     }
     return self;
 }
 \endcode
 
 \param server the location of the server such as 'localhost' or '192.168.1.100'
 \param database the name of the database
 \param user the database user to connect as
 \param password the password for the database user
 \param port the port of the server. 0 will use the default port of 3306
 \param socket the local mysql socket to connect to such as '/tmp/mysql.sock'.  nil uses the default
 \param locking if \c YES then all database access will be guarded through the \c recursiveLock
 \param error if not \c nil will be populated with the error message if an error occurs
 
 \sa See \c mysql_real_connect in the MySQL Reference Manual for more information
 
 \return a successfully connection BxDatabaseConnection or \c nil if an error occurred
 \since 1.0
 */
- (id)initWithMySQLServer:(NSString *)server
                 database:(NSString *)database
                     user:(NSString *)user
                 password:(NSString *)password
                     port:(int)port
                   socket:(NSString *)socket
                  locking:(BOOL)locking
                    error:(NSString **)error;
    
/** \anchor initWithMyOracleInstance
 \brief Creates a new BxDatabaseConnection to an Oracle server
 
 This establishes a connection with database instance on an Oracle server.
 
 Establishing a connection to a remote Oracle database:
 \code
 - (id)setup {
     NSString *error = nil;
     _db = [[BxDatabaseConnection alloc] initWithMyOracleInstance:@"//oradb.intranet:1521/ORCL"
                                                             user:@"scott"
                                                         password:@"tiger"
                                                          locking:YES
                                                            error:&error]
     if (error) {
         NSLog(@"%@", error);
     }
     return self;
 }
 \endcode
 
 \param instance the Oracle connection string as for SQLPLUS or nil for default local connection
 \param user the database user to connect as
 \param password the password for the database user
 \param locking if \c YES then all database access will be guarded through the \c recursiveLock
 \param error if not \c nil will be populated with the error message if an error occurs
 
 \sa See the OCIServerAttach function in the OCI Programmer's Guide for more information on
 valid \c instance values.
 
 \return a successfully connection BxDatabaseConnection or \c nil if an error occurred
 \since 1.0
 */
- (id)initWithOracleInstance:(NSString *)instance
                      user:(NSString *)user
                  password:(NSString *)password
                   locking:(BOOL)locking
                     error:(NSString **)error;


/** \anchor initWithPostgreSQLServer
 \brief Creates a new BxDatabaseConnection for a PostgreSQL server
 
 This establishes a connection with a PostgreSQL server.  The PostgreSQL server
 may be remote or local.
 
 \note The enabling of \c locking is recommended.
 
 Example of connecting to a local PostgreSQL server:
 \code
 - (id)setup {
     NSString *error = nil
     _db = [[BxDatabaseConnection alloc] initWithPostgreSQLServer:@"localhost"
                                                         database:@"maindb"
                                                             user:@"joe"
                                                         password:@"secret"
                                                             port:0
                                                          locking:YES
                                                            error:&error]
     if (error) {
         NSLog(@"%@", error);
     }
     return self;
 }
 \endcode
 
 \param server the location of the server such as 'localhost' or '192.168.1.100'
 \param database the name of the database
 \param user the database user to connect as
 \param password the password for the database user
 \param port the port of the server. 0 will use the default port of 3306
 \param locking if \c YES (recommended) then all database access will be guarded through the \c recursiveLock
 \param error if not \c nil will be populated with the error message if an error occurs
 
 \sa See \c PQsetdbLogin in the PostgreSQL \c libpq documentation for more information
 
 \return a successfully connection BxDatabaseConnection or \c nil if an error occurred
 \since 1.0
 */
- (id)initWithPostgreSQLServer:(NSString *)server
                      database:(NSString *)database
                          user:(NSString *)user
                      password:(NSString *)password
                          port:(NSString *)port
                       locking:(BOOL)locking
                         error:(NSString **)error;

/** \anchor initWithSQLiteFile
 \brief Creates a new BxDatabaseConnection for a SQLite file
 
 This establishes connection for a SQLite file.  The the file does
 not already exist, it will be created.
 
 \note The file format expected is SQLite 3
 
 Example of connecting to a SQLite file located at /path/to/file.sqlite3:
 \code
 - (id)setup {
     NSString *error = nil
     _db = [[BxDatabaseConnection alloc] initWithSQLiteFile:@"/path/to/file.sqlite3"
                                                    locking:NO
                                                      error:&error]
     if (error) {
         NSLog(@"%@", error);
     }
     return self;
 }
 \endcode
 
 \param path the location of the SQLite file to open or create.  Use ':memory:' for an in-memory database
 \param locking if \c YES (recommended) then all database access will be guarded through the \c recursiveLock
 \param error if not \c nil will be populated with the error message if an error occurs
 
 \sa See \c sqlite3_open in the SQLite C Interface documentation for more information
 
 \return a successfully connection BxDatabaseConnection or \c nil if an error occurred
 \since 1.0
 */
- (id)initWithSQLiteFile:(NSString *)path
                 locking:(BOOL)locking
                   error:(NSString **)error;

/** \anchor initWithSQLiteMemoryWithLocking
 \brief Creates a new BxDatabaseConnection for an in-memory SQLite database
 
 This connection creates an in-memory SQLite database that will not be saved when the BxApp closes
 
 Example of connecting to a new in-memory SQLite database:
 \code
 - (id)setup {
     NSString *error = nil
     _db = [[BxDatabaseConnection alloc] initWithSQLiteMemoryWithLocking:NO
                                                                   error:&error]
     if (error) {
         NSLog(@"%@", error);
     }
     return self;
 }
 \endcode
 
 \note This is equivalent to calling:
 \code
  [bxDatabaseConnection initWithSQLiteFile:@":memory:"
                                   locking:locking
                                     error:error];
 \endcode
 
 \param locking if \c YES (recommended) then all database access will be guarded through the \c recursiveLock
 \param error if not \c nil will be populated with the error message if an error occurs
 
 \sa See \c sqlite3_open in the SQLite C Interface documentation for more information
 
 \return a successfully connection BxDatabaseConnection or \c nil if an error occurred
 \since 1.0
 */
- (id)initWithSQLiteMemoryWithLocking:(BOOL)locking
                                error:(NSString **)error;


/** \anchor prepare
 \brief Creates a newly allocated BxDatabaseStatement using the SQL provided
 
 This command executes the raw SQL passed as the \c sql parameter and returns
 a prepared statement that may be executed many times efficiently.
 
 Values may be bound to prepared statements using bind indicators which vary from database
 to database.  For example, MySQL uses '?' in place of the variable, Oracle uses ':name',
 PostgreSQL '$1', and SQLite can use any of the above.  For details, please consult
 your database's documentation on bind values in prepared statements.
  
 Example of preparing and executing a BxDatabaseStatement:
 \code 
 - (id)renderWithTransport:(BxTransport *)transport {
     NSString *count = [transport.queryVars objectForKey:@"count"];
     if (count) {
         BxDatabaseStatement *stmt = [_db prepare:@"INSERT INTO counter (number) VALUES (?)"];
         if (stmt == nil) {
             NSLog(@"%@", _db.lastError);
         } else {
             for (int i = 0; i < [count integerValue]; i++) {
                 [stmt bindValue:[NSString stringWithFormat:@"%d", i]
                       forColumn:i + 1];
                 [stmt execute];
             }
         }
     }
     return self;
 }
 \endcode
 
 \param sql the SQL to be executed when the prepared statement is called
 
 \sa BxDatabaseStatement's \c initWithConnection: method
 
 \return an autoreleased BxDatabaseStatement or \c nil if an error occurred, in which case \c lastError is set
 \since 1.0
 */
- (BxDatabaseStatement *)prepare:(NSString *)sql;

/** \anchor prepareWith
 \brief Creates a newly allocated BxDatabaseStatement using the SQL and bind values provided
 
 This command executes the raw SQL passed as the \c sql parameter and returns
 a prepared statement that may be executed many times efficiently.  Initially the statement
 is bound using the \c nil terminated arguments passed after \c sql.
 
 Values may be bound to prepared statements using bind indicators which vary from database
 to database.  For example, MySQL uses '?' in place of the variable, Oracle uses ':name',
 PostgreSQL '$1', and SQLite can use any of the above.  For details, please consult
 your database's documentation on bind values in prepared statements.
 
 Example of preparing and executing a BxDatabaseStatement:
 \code 
 - (id)renderWithTransport:(BxTransport *)transport {
     NSString *count = [transport.queryVars objectForKey:@"count"];
     if (count) {
         BxDatabaseStatement *stmt = [_db prepareWith:@"INSERT INTO counter (number) VALUES (?)", @"0", nil];
         if (stmt == nil) {
             NSLog(@"%@", _db.lastError);
         } else {
             [stmt execute];
             for (int i = 1; i < [count integerValue]; i++) {
                 [stmt bindValue:[NSString stringWithFormat:@"%d", i]
                                                  forColumn:i + 1];
                 [stmt execute];
             }
         }
     }
     return self;
 }
 \endcode
 
 \param sql the SQL to be executed when the prepared statement is called followed by all bind variables and \c nil
 
 \sa BxDatabaseStatement's \c initWithConnection: method
 
 \return an autoreleased BxDatabaseStatement or \c nil if an error occurred, in which case \c lastError is set
 \since 1.0
 */
- (BxDatabaseStatement *)prepareWith:(NSString *)sql, ...;

/** \anchor rollbackTransaction
 \brief Cancels an existing database transaction
 
 Note that the database and tables must support transactions for this command to
 have any effect (e.g. MySQL MyISAM tables do not support transactions while InnoDB
 tables do).  Currently, named transactions are not supported.

 \note Because transaction state is shared within a connection, transactions within
 a multithreaded connection may want to manually lock the \c recursiveLock.

 Example of using a transaction:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     [_db beginTransaction];
     NSArray *result = [_db fetchRowWith:@"SELECT balance FROM accounts WHERE accountNumber=?", _accountNumber];
     BOOL cancel = NO;
     if (result != nil) {
         double balance = [[result lastObject] doubleValue];
         balance += 100;
         if (! [_db executeWith:@"UPDATE accounts SET balance=? WHERE accountNumber=?", [NSString stringWithFormat:@"%f", balance], _accountNumber, nil]) {
             cancel = YES;
         }
     } else {
         cancel = YES;
     }
     if (cancel) {
         [_db rollbackTransaction];
         [transport write:@"Transaction cancelled"];
     } else {
         [_db commitTransaction];
         [transport write:@"Transaction succeeded"];
     }
     return self;
 }
 \endcode
 
 \return \c YES if the command succeeded, else \c lastError is set
 \since 1.0
 */
- (BOOL)rollbackTransaction;

/** \anchor isLocking
 Is set to \c YES if the connection was established with locking enabled
 
 Example of checking if locking is enabled for improved transactions:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     if (_db.isLocking) {
         [_db.recursiveLock lock];
         [_db beginTransaction];
     }
     // ...
     if (_db.isLocking) {
         [_db commitTransaction];
         [_db.recursiveLock unlock];
     }
     return self;
 }
 \endcode
 \since 1.0
 */
@property (nonatomic, readonly) BOOL isLocking;

/** \anchor connectionType
 The type of database this BxDatabaseConnection is connected to.
 
 \note The result may be:
 \code
    BxDatabaseConnectionTypeUnknown -> Undefined
    BxDatabaseConnectionTypeMySQL -> MySQL
    BxDatabaseConnectionTypeOracle -> Oracle
    BxDatabaseConnectionTypePostgreSQL -> PostgreSQL
    BxDatabaseConnectionTypeSQLite -> SQLite (in memory or file based)
 \endcode
 
 Example of checking the type of database:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     NSArray *result;
     if (_db.connectionType == BxDatabaseConnectionTypeMySQL) {
         result = [_db fetchRowWith:@"SELECT * FROM cheese WHERE name=?", @"cheddar", nil];
     } else if (_db.connectionType == BxDatabaseConnectionTypePostgreSQL) {
         result = [_db fetchRowWith:@"SELECT * FROM cheese WHERE name=$1", @"cheddar", nil];
     }
     // ...
     return self
 }
 \endcode

 \since 1.0
 */
@property (nonatomic, readonly) BxDatabaseConnectionType connectionType;

/** \anchor lastError
 If an error has occurred in a BxPreparedStatement or BxDatabaseConnection, the
 text of the error will be available in /c lastError.
 
 \note In a multithreaded BxApp it is possible for an additional error
 to occur between the time the first error occurs and \c lastError is checked.  If this
 rare case is a concern, you may manually lock \c recursiveLock to prevent it.
 
 Example of checking the error:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
    if (! [_db.execute:@"SELECT * FROM invalidTable"]) {
        [transport write:db.lastError];
    }
    return self;
 }
 \endcode
 
 \since 1.0
 */
@property (nonatomic, copy) NSString *lastError;


/** \anchor recursiveLock
 The raw \c NSRecursiveLock if locking enabled.  Normally there is no need to access this directly,
 but occasionally, such as with transactions, it may be useful.
 
 Example of checking if locking is enabled for improved transactions:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     if (_db.isLocking) {
         [_db.recursiveLock lock];
         [_db beginTransaction];
     }
     // ...
     if (_db.isLocking) {
         [_db commitTransaction];
         [_db.recursiveLock unlock];
     }
     return self;
 }
 \endcode
 \since 1.0
 */
@property (nonatomic, readonly) NSRecursiveLock *recursiveLock;

/** \anchor rawConnection
 This is the raw database connection object backing the connection.  Use of this 
 object is not recommended and is not protected by the \c recursiveLock.
 
 \note The type of object returned varies as follows:
 \code
     MySQL -> MYSQL *
     Oracle -> OCISvcCtx *
     PostgreSQL -> PGconn *
     SQLite -> sqlite3 *
 \endcode

 Example of accessing the raw connection of a SQLite database:
 \code
 - (id)renderWithTransport:(BxTransport *)transport {
     sqlite3 *rawDb = (sqlite3 *) _db.rawConnection;
     BOOL isAutocommitMode = sqlite3_get_autocommit(rawDb) != 0;
     // ...
     return self;
 }
 \endcode
 
 \since 1.0
 */
@property (nonatomic, readonly) void *rawConnection;

@end
