#import "BxDatabaseConnection.h"
#import <Bombaxtic/BxDatabaseStatement.h>
#import "sqlite3.h"
#import "mysql.h"
#import "libpq-fe.h"
#import "oci.h"

@implementation BxDatabaseConnection

@synthesize connectionType = _connectionType;
@synthesize isLocking = _isLocking;
@synthesize rawConnection = _rawConnection;
@synthesize lastError = _lastError;
@synthesize recursiveLock = _lock;

static BOOL _hasInitializedOracle = NO;
static OCIEnv *_oraEnv = NULL;

- (NSMutableSet *)_statements {
    return _statementsSet;
}

- (OCIError *)_ociError {
    return (OCIError *) _rawError;
}

- (OCIEnv *)_ociEnv {
    return (OCIEnv *) _oraEnv;
}

- (BOOL)beginTransaction {
    if (_isClosed) {
        self.lastError = @"Database closed.";
        return NO;
    }
    if (_isLocking) {
        [_lock lock];
    }
    BOOL result = NO;
    if (_connectionType == BxDatabaseConnectionTypeSQLite) {
        result = [self execute:@"BEGIN"];
    } else if (_connectionType == BxDatabaseConnectionTypePostgreSQL) {
        result = [self execute:@"BEGIN"];
    } else if (_connectionType == BxDatabaseConnectionTypeMySQL) {
        result = [self commitTransaction]; // tbd note this in docs
    } else if (_connectionType == BxDatabaseConnectionTypeOracle) {
        OCIError *oraErr = (OCIError *) _rawError;
        OCISvcCtx *oraSvc = (OCISvcCtx *) _rawConnection;
        text errorBuf[512];
        int rc;
        if (rc = OCITransStart(oraSvc, oraErr, 5, OCI_TRANS_NEW)) {
            OCIErrorGet(oraErr, 1, NULL, &rc, errorBuf, 512, OCI_HTYPE_ERROR);
            self.lastError = [NSString stringWithUTF8String:(char *) errorBuf];
            result = NO;
        }
    }
    if (_isLocking) {
        [_lock unlock];
    }
    return result;
}

- (BOOL)close {
    if (_isClosed) {
        self.lastError = @"Database already closed.";
        return NO;
    }
    if (_isLocking) {
        [_lock lock];
    }
    BOOL result = YES;
    if (_connectionType == BxDatabaseConnectionTypeSQLite) {
        sqlite3 *conn = (sqlite3 *) _rawConnection;
        if (sqlite3_close(conn) != SQLITE_OK) {
            self.lastError = [NSString stringWithUTF8String:sqlite3_errmsg(conn)];
            result = NO;
        } else {
            _isClosed = YES;
        }
    } else if (_connectionType == BxDatabaseConnectionTypePostgreSQL) {
        PGconn *conn = (PGconn *) _rawConnection;
        PQfinish(conn);
        [_statementsSet release];        
    } else if (_connectionType == BxDatabaseConnectionTypeMySQL) {
        MYSQL *conn = (MYSQL *) _rawConnection;
        mysql_close(conn);
    } else if (_connectionType == BxDatabaseConnectionTypeOracle) {
        OCIError *oraErr = (OCIError *) _rawError;
        OCIServer *oraSrv = (OCIServer *) _rawServer;
        OCISvcCtx *oraSvc = (OCISvcCtx *) _rawConnection;
        text errorBuf[512];
        int rc;
        // tbd serverdetach
        if (rc = OCILogoff(oraSvc, oraErr)) {
            OCIErrorGet(oraErr, 1, NULL, &rc, errorBuf, 512, OCI_HTYPE_ERROR);
            self.lastError = [NSString stringWithUTF8String:(char *) errorBuf];
            result = NO;
        } else {
            OCIHandleFree(oraSrv, OCI_HTYPE_SERVER);
            OCIHandleFree(oraErr, OCI_HTYPE_ERROR);
            OCIHandleFree(oraSvc, OCI_HTYPE_SVCCTX);
        }
    }
    if (_isLocking) {
        [_lock unlock];
    }
    return result;
}

- (BOOL)commitTransaction {
    if (_isClosed) {
        self.lastError = @"Database closed.";
        return NO;
    }
    if (_isLocking) {
        [_lock lock];
    }
    BOOL result = YES;
    if (_connectionType == BxDatabaseConnectionTypeSQLite) {
        result = [self execute:@"COMMIT"];
    } else if (_connectionType == BxDatabaseConnectionTypePostgreSQL) {
        result = [self execute:@"COMMIT"];
    } else if (_connectionType == BxDatabaseConnectionTypeMySQL) {
        MYSQL *conn = (MYSQL *) _rawConnection;
        if (mysql_commit(conn) != 0) {
            self.lastError = [NSString stringWithUTF8String:mysql_error(conn)];
            result = NO;
        }
    } else if (_connectionType == BxDatabaseConnectionTypeOracle) {
        OCIError *oraErr = (OCIError *) _rawError;
        OCISvcCtx *oraSvc = (OCISvcCtx *) _rawConnection;
        text errorBuf[512];
        int rc;
        if (rc = OCITransCommit(oraSvc, oraErr, OCI_DEFAULT)) {
            OCIErrorGet(oraErr, 1, NULL, &rc, errorBuf, 512, OCI_HTYPE_ERROR);
            self.lastError = [NSString stringWithUTF8String:(char *) errorBuf];
            result = NO;
        }
    }
    if (_isLocking) {
        [_lock unlock];
    }
    return result;
}

- (BOOL)execute:(NSString *)sql {
    return [self executeWith:sql, nil];
}

- (BOOL)executeWith:(NSString *)sql, ... {
    if (_isClosed) {
        self.lastError = @"Database closed.";
        return NO;
    }
    if (_isLocking) {
        [_lock lock];
    }
    BOOL result;
    BxDatabaseStatement *stmt;
    va_list args;
    va_start(args, sql);
    stmt = [[BxDatabaseStatement alloc] initWithConnection:self
                                                       sql:sql
                                                      args:args];
    va_end(args);
    if (stmt == nil) {
        result = NO;
    } else {
        result = [stmt execute];
        [stmt release];
    }
    if (_isLocking) {
        [_lock unlock];
    }
    return result;
}


- (NSArray *)fetchAll:(NSString *)sql {
    return [self fetchAllWith:sql, nil];
}

- (NSArray *)fetchAllWith:(NSString *)sql, ... {
    if (_isClosed) {
        self.lastError = @"Database closed.";
        return nil;
    }
    if (_isLocking) {
        [_lock lock];
    }
    NSMutableArray *array = nil;
    va_list args;
    va_start(args, sql);
    BxDatabaseStatement *stmt = [[BxDatabaseStatement alloc] initWithConnection:self
                                                                            sql:sql
                                                                           args:args];
    va_end(args);
    if (stmt != nil) {
        if ([stmt execute]) {
            array = [NSMutableArray arrayWithCapacity:128];
            for (NSArray *row in stmt) {
                if (row == nil) {
                    array = nil;
                    break;
                }
                [array addObject:row];
            }
        }
        [stmt release];
    }
    if (_isLocking) {
        [_lock unlock];
    }    
    return array;
}    


- (NSArray *)fetchNamedAll:(NSString *)sql {
    return [self fetchNamedAllWith:sql, nil];
}

- (NSArray *)fetchNamedAllWith:(NSString *)sql, ... {
    if (_isClosed) {
        self.lastError = @"Database closed.";
        return nil;
    }
    if (_isLocking) {
        [_lock lock];
    }
    NSMutableArray *array = nil;
    va_list args;
    va_start(args, sql);
    BxDatabaseStatement *stmt = [[BxDatabaseStatement alloc] initWithConnection:self
                                                                            sql:sql
                                                                           args:args];
    va_end(args);
    if (stmt != nil) {
        if ([stmt execute]) {
            array = [NSMutableArray arrayWithCapacity:128];
            NSDictionary *dict;
            while (stmt.hasMoreRows) {
                dict = [stmt fetchDictionary];
                if (dict == nil) {
                    array = nil;
                    break;
                }
                [array addObject:dict];
            }
        }
        [stmt release];
    }
    if (_isLocking) {
        [_lock unlock];
    }    
    return array;
}    

- (NSDictionary *)fetchNamedRow:(NSString *)sql {
    return [self fetchNamedRowWith:sql, nil];
}

- (NSDictionary *)fetchNamedRowWith:(NSString *)sql, ... {
    if (_isClosed) {
        self.lastError = @"Database closed.";
        return nil;
    }
    if (_isLocking) {
        [_lock lock];
    }
    
    NSDictionary *row = nil;
    va_list args;
    va_start(args, sql);
    BxDatabaseStatement *stmt = [[BxDatabaseStatement alloc] initWithConnection:self
                                                                            sql:sql
                                                                           args:args];
    va_end(args);
    if (stmt != nil) {
        if ([stmt execute]) {
            row = [stmt fetchDictionary];
        }
        [stmt release];
    }
    if (_isLocking) {
        [_lock unlock];
    }    
    return row;    
}

- (NSArray *)fetchRow:(NSString *)sql {
    return [self fetchRowWith:sql, nil];
}

- (NSArray *)fetchRowWith:(NSString *)sql, ... {
    if (_isClosed) {
        self.lastError = @"Database closed.";
        return nil;
    }
    if (_isLocking) {
        [_lock lock];
    }
    
    NSArray *row = nil;
    va_list args;
    va_start(args, sql);
    BxDatabaseStatement *stmt = [[BxDatabaseStatement alloc] initWithConnection:self
                                                                            sql:sql
                                                                           args:args];
    va_end(args);
    if (stmt != nil) {
        if ([stmt execute]) {
            row = [stmt fetchArray];
        }
        [stmt release];
    }
    if (_isLocking) {
        [_lock unlock];
    }    
    return row;    
}

- (id)initWithMySQLServer:(NSString *)server
                 database:(NSString *)database
                     user:(NSString *)user
                 password:(NSString *)password
                  locking:(BOOL)locking
                    error:(NSString **)error {
    return [self initWithMySQLServer:server
                            database:database
                                user:user
                            password:password
                                port:0
                              socket:nil
                             locking:locking
                               error:error];
}
    
- (id)initWithMySQLServer:(NSString *)server
                 database:(NSString *)database
                     user:(NSString *)user
                 password:(NSString *)password
                     port:(int)port
                   socket:(NSString *)socket
                  locking:(BOOL)locking
                    error:(NSString **)error {
    [super init];
    _isLocking = locking;
    _connectionType = BxDatabaseConnectionTypeMySQL;
    self.lastError = nil;
    _isClosed = NO;
    
    MYSQL *conn;
    conn = mysql_init(NULL);
    if (conn == NULL) {
        if (error != nil && error != NULL) {
            *error = @"Could not allocate MySQL connection";
        }
        return nil;
    }
    
    const char *cSocket = socket == nil ? NULL : [socket UTF8String];
    if (! mysql_real_connect(conn,
                             [server UTF8String],
                             [user UTF8String],
                             [password UTF8String],
                             [database UTF8String],
                             port,
                             cSocket,
                             0)) {
        if (error != nil && error != NULL) {
            *error = [NSString stringWithUTF8String:mysql_error(conn)];
        }
        mysql_close(conn);
        return nil;
    }
    _rawConnection = (void *) conn;
    if (_isLocking) {
        _lock = [[NSRecursiveLock alloc] init];
    }
    return self;
}


- (id)initWithOracleInstance:(NSString *)server
                        user:(NSString *)user
                    password:(NSString *)password
                     locking:(BOOL)locking
                       error:(NSString **)error {
    [super init];
    _isLocking = locking;
    _connectionType = BxDatabaseConnectionTypeOracle;
    self.lastError = nil;
    _isClosed = NO;
    if (_hasInitializedOracle == NO) {
        int rc;
        if (rc = OCIEnvCreate(&_oraEnv,
                              OCI_THREADED | OCI_NEW_LENGTH_SEMANTICS,
                              NULL,
                              NULL,
                              NULL,
                              NULL,
                              0,
                              NULL)) {
            NSLog(@"err: %d", rc);
            if (error != nil && error != NULL) {
                *error = @"Could not initialize Oracle environment";
            }
            return nil;
        } else {
            _hasInitializedOracle = YES;
        }
    }
    OCIError *oraErr;
    OCIServer *oraSrv;
    OCISvcCtx *oraSvc;
    OCISession *oraSess;
    text errorBuf[512];
    int rc;
    
    OCIHandleAlloc(_oraEnv, (dvoid **) &oraErr, OCI_HTYPE_ERROR, 0, NULL);
    OCIHandleAlloc(_oraEnv, (dvoid **) &oraSrv, OCI_HTYPE_SERVER, 0, NULL);
    if ((server == nil && (rc = OCIServerAttach(oraSrv,
                                                oraErr,
                                                NULL,
                                                0,
                                                OCI_DEFAULT))) ||
        (server != nil && (rc = OCIServerAttach(oraSrv,
                                                oraErr,
                                                (text *) [server UTF8String],
                                                [server length],
                                                OCI_DEFAULT)))) {
        if (error != nil && error != NULL) {
            OCIErrorGet(oraErr, 1, NULL, &rc, errorBuf, 512, OCI_HTYPE_ERROR);
            *error = [NSString stringWithUTF8String:(char *) errorBuf];
            OCIHandleFree(oraSrv, OCI_HTYPE_SERVER);
            OCIHandleFree(oraErr, OCI_HTYPE_ERROR);
            return nil;
        }
    }
    
   OCIHandleAlloc(_oraEnv, (dvoid **) &oraSvc, OCI_HTYPE_SVCCTX, 0, NULL);
    OCIAttrSet(oraSvc,
               OCI_HTYPE_SVCCTX,
               oraSrv,
               0,
               OCI_ATTR_SERVER,
               oraErr);
    OCIHandleAlloc(_oraEnv, (dvoid **) &oraSess, OCI_HTYPE_SESSION, 0, NULL);
    OCIAttrSet(oraSess, OCI_HTYPE_SESSION, (text *) [user UTF8String], [user length], OCI_ATTR_USERNAME, oraErr);
    OCIAttrSet(oraSess, OCI_HTYPE_SESSION, (text *) [password UTF8String], [password length], OCI_ATTR_PASSWORD, oraErr);
    
    if ((rc = OCISessionBegin(oraSvc, oraErr, oraSess, OCI_CRED_RDBMS, OCI_DEFAULT))) {
        if (error != nil && error != NULL) {
            OCIErrorGet(oraErr, 1, NULL, &rc, errorBuf, 512, OCI_HTYPE_ERROR);
            *error = [NSString stringWithUTF8String:(char *) errorBuf];
            OCIHandleFree(oraSrv, OCI_HTYPE_SERVER);
            OCIHandleFree(oraErr, OCI_HTYPE_ERROR);
            OCIHandleFree(oraSvc, OCI_HTYPE_SVCCTX);
            return nil;
        }
    }        
    
    OCIAttrSet(oraSvc, OCI_HTYPE_SVCCTX, oraSess, 0, OCI_ATTR_SESSION, oraErr);
    
    _rawConnection = (void *) oraSvc;
    _rawServer = (void *) oraSrv;
    _rawError = (void *) oraErr;
    if (_isLocking) {
        _lock = [[NSRecursiveLock alloc] init];
    }
    return self;
}
 
- (id)initWithPostgreSQLServer:(NSString *)server
                      database:(NSString *)database
                          user:(NSString *)user
                      password:(NSString *)password
                          port:(NSString *)port
                       locking:(BOOL)locking
                         error:(NSString **)error {
    [super init];
    _isLocking = locking;
    _connectionType = BxDatabaseConnectionTypePostgreSQL;
    self.lastError = nil;
    _isClosed = NO;
    _statementsSet = [[NSMutableSet alloc] initWithCapacity:16];
    const char *cServer = server == nil ? NULL : [server UTF8String];
    const char *cDatabase = database == nil ? NULL : [database UTF8String];
    const char *cUser = user == nil ? NULL : [user UTF8String];
    const char *cPassword = password == nil ? NULL : [password UTF8String];
    const char *cPort = port == nil ? NULL : [port UTF8String];    
    
    PGconn *conn = PQsetdbLogin(cServer,
                                cPort,
                                NULL,
                                NULL,
                                cDatabase,
                                cUser,
                                cPassword);
    if (PQstatus(conn) != CONNECTION_OK) {
        if (error != nil && error != NULL) {
            *error = [NSString stringWithUTF8String:PQerrorMessage(conn)];
        }
        PQfinish(conn);
        return nil;
    }
    _rawConnection = (void *) conn;
    if (_isLocking) {
        _lock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (id)initWithSQLiteFile:(NSString *)path
                 locking:(BOOL)locking
                   error:(NSString **)error {
    [super init];
    _isLocking = locking;
    _connectionType = BxDatabaseConnectionTypeSQLite;
    self.lastError = nil;
    _isClosed = NO;
    sqlite3 *conn;
    if (sqlite3_open([path UTF8String], &conn) != SQLITE_OK) {
        if (error != nil && error != NULL) {
            *error = [NSString stringWithUTF8String:sqlite3_errmsg(conn)];
        }
        sqlite3_close(conn);
        return nil;
    }
    _rawConnection = (void *) conn;
    if (_isLocking) {
        _lock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (id)initWithSQLiteMemoryWithLocking:(BOOL)locking
                                error:(NSString **)error {
    return [self initWithSQLiteFile:@":memory:"
                            locking:locking
                              error:error];
}    

- (BxDatabaseStatement *)prepare:(NSString *)sql {
    return [self prepareWith:sql, nil];
}

- (BxDatabaseStatement *)prepareWith:(NSString *)sql, ... {
    if (_isClosed) {
        self.lastError = @"Database closed.";
        return nil;
    }
    if (_isLocking) {
        [_lock lock];
    }
    BxDatabaseStatement *stmt = nil;
    va_list args;
    va_start(args, sql);
    stmt = [[[BxDatabaseStatement alloc] initWithConnection:self
                                                        sql:sql
                                                       args:args] autorelease];
    va_end(args);
    if (_isLocking) {
        [_lock unlock];
    }
    return stmt;
}

- (BOOL)rollbackTransaction {
    if (_isClosed) {
        self.lastError = @"Database closed.";
        return NO;
    }
    if (_isLocking) {
        [_lock lock];
    }
    BOOL result = NO;
    if (_connectionType == BxDatabaseConnectionTypeSQLite) {
        result = [self execute:@"ROLLBACK"];
    } else if (_connectionType == BxDatabaseConnectionTypePostgreSQL) {
        result = [self execute:@"ROLLBACK"];
    } else if (_connectionType == BxDatabaseConnectionTypeMySQL) {
        MYSQL *conn = (MYSQL *) _rawConnection;
        if (mysql_rollback(conn) != 0) {
            self.lastError = [NSString stringWithUTF8String:mysql_error(conn)];
            result = NO;
        }
    } else if (_connectionType == BxDatabaseConnectionTypeOracle) {
        OCIError *oraErr = (OCIError *) _rawError;
        OCISvcCtx *oraSvc = (OCISvcCtx *) _rawConnection;
        text errorBuf[512];
        int rc;
        if (rc = OCITransRollback(oraSvc, oraErr, OCI_DEFAULT)) {
            OCIErrorGet(oraErr, 1, NULL, &rc, errorBuf, 512, OCI_HTYPE_ERROR);
            self.lastError = [NSString stringWithUTF8String:(char *) errorBuf];
            result = NO;
        }
    }
    if (_isLocking) {
        [_lock unlock];
    }
    return result;
}

- (void)dealloc {
    if (!_isClosed) {
        [self close];
    }
    if (_isLocking) {
        [_lock release];
    }
    if (_connectionType == BxDatabaseConnectionTypeSQLite) {
        
    } else if (_connectionType == BxDatabaseConnectionTypePostgreSQL) {

    } else if (_connectionType == BxDatabaseConnectionTypeMySQL) {
        
    } else if (_connectionType == BxDatabaseConnectionTypeOracle) {
        
    }
    [super dealloc];    
}

@end
