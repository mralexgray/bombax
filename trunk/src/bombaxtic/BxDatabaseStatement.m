#import "BxDatabaseStatement.h"
#import <Bombaxtic/BxDatabaseConnection.h>
#import "sqlite3.h"
#import "mysql.h"
#import "libpq-fe.h"
#import "oci.h"
#import <time.h>

@implementation BxDatabaseStatement

@synthesize connection = _connection;
@synthesize hasMoreRows = _hasMoreRows;
@synthesize rawStatement = _rawStatement;


enum BxDatabaseStatementFetchType_enum {
    BxDatabaseStatementFetchTypeArray,
    BxDatabaseStatementFetchTypeDictionary,
    BxDatabaseStatementFetchTypeValue
} typedef BxDatabaseStatementFetchType;


- (BOOL)_prelockedBindValue:(NSString *)value
               forColumn:(int)column {
    if (_hasClosed) {
        return NO;
    }
    if (value != nil) {
        if (! [value isKindOfClass:[NSString class]]) {
            if (value == [NSNull null]) {
                value = nil;
            } else {
                value = [value description];
            }
        }
    }
    // note: column starts at 1
    if (_connection.connectionType == BxDatabaseConnectionTypeSQLite) {
        sqlite3 *conn = (sqlite3 *) _connection.rawConnection;
        sqlite3_stmt *stmt = (sqlite3_stmt *) _rawStatement;
        if (! _hasResetted) {
            if (sqlite3_reset(stmt) != SQLITE_OK) {
                _connection.lastError = [NSString stringWithUTF8String:sqlite3_errmsg(conn)];
                return NO;
            }
            _hasResetted = YES;
        }            
        if (value == nil || value == NULL) {
            if (sqlite3_bind_null(stmt, column) != SQLITE_OK) {
                _connection.lastError = [NSString stringWithUTF8String:sqlite3_errmsg(conn)];
                return NO;
            } else {
                return YES;
            }
        } else {
            if (sqlite3_bind_text(stmt,
                                  column,
                                  [value UTF8String],
                                  [value length],
                                  SQLITE_TRANSIENT) != SQLITE_OK) {
                _connection.lastError = [NSString stringWithUTF8String:sqlite3_errmsg(conn)];
                return NO;
            } else {
                return YES;
            }
        }
    } else if (_connection.connectionType == BxDatabaseConnectionTypePostgreSQL) {
        column--;
        if (value == nil) {
            [_bindValues replaceObjectAtIndex:column
                                   withObject:[NSNull null]];
        } else {
            [_bindValues replaceObjectAtIndex:column
                                   withObject:value];
        }
    } else if (_connection.connectionType == BxDatabaseConnectionTypeMySQL) {
        column--;
        MYSQL_BIND *binds = (MYSQL_BIND *) _rawBinds;
        if (value == nil) {
            binds[column].buffer_type = MYSQL_TYPE_NULL;
        } else {
            binds[column].buffer_type = MYSQL_TYPE_STRING;
            int len = [value length];
            if (len > 65525) {
                len = 65525;
            }
            strncpy(&(_rawBindsBuffer[65536 * column]), [value UTF8String], len);
            binds[column].buffer = &(_rawBindsBuffer[65536 * column]);
            binds[column].buffer_length = len;
            _rawBindsBuffer[65536 * column + 65526] = 0;
            binds[column].is_null = &(_rawBindsBuffer[65536 * column + 65526]);
            *((unsigned long *) &(_rawBindsBuffer[65536 * column + 65528])) = len;
            binds[column].length = (unsigned long *) &(_rawBindsBuffer[65536 * column + 65528]);
        }
    } else if (_connection.connectionType == BxDatabaseConnectionTypeOracle) {
        OCIStmt *stmt = (OCIStmt *) _rawStatement;
        OCIError *oraErr = (OCIError *) [_connection _ociError];
        text errorBuf[512];
        int rc;
        int len;
        if (value == nil) {
            len = 0;
        } else {
            len = [value length];
            if (len > 65518) {
                len = 65518;
            }
        }
        column--;
        // 0-65529 char* buffer, 65530-65531 indicator, 65532-65533 len, 65534-65535 res
        if (value != nil) {
            strncpy(&(_rawBindsBuffer[65536 * column]), [value UTF8String], len);
            _rawBindsBuffer[65536 * column + len] = 0;
        }
        *((sb2 *) &(_rawBindsBuffer[65536 * column + 65530])) = (sb2) (value == nil ? -1 : 0);        
        *((ub2 *) &(_rawBindsBuffer[65536 * column + 65532])) = (ub2) 0;
        *((ub2 *) &(_rawBindsBuffer[65536 * column + 65534])) = (ub2) 0;
        OCIBind **binds = (OCIBind **) _rawBinds;
        if (rc = OCIBindByPos(stmt,
                              &(binds[column]),
                              oraErr,
                              column + 1,
                              &(_rawBindsBuffer[65536 * column]),
                              value == nil ? 0 : [value length] + 1,
                              SQLT_STR,
                              (sb2 *) &(_rawBindsBuffer[65536 * column + 65530]),
                              0,
                              0,
                              0,
                              NULL,
                              OCI_DEFAULT)) {
            OCIErrorGet(oraErr, (ub4) 1, NULL, &rc, errorBuf, 512, OCI_HTYPE_ERROR);
            _connection.lastError = [NSString stringWithUTF8String:(char *) errorBuf];
            return NO;
        }
    }
    return YES;
}

- (BOOL)_prelockedBindValue:(NSString *)value
                     forKey:(NSString *)key {
    NSUInteger column = [_bindNames indexOfObject:key];
    if (column == NSNotFound) {
        return NO;
    } else {
        return [self _prelockedBindValue:value
                               forColumn:column + 1];
    }
}

- (NSString *)_convertToStringColumn:(int)column
                                name:(NSString **)name {
    column--;
    ub2 dType = *((ub2 *) &(_rawResultsBuffer[column * 65536]));
    if (name != nil) {
        *name = [NSString stringWithUTF8String:(char *) &_rawResultsBuffer[column * 65536 + 2]];
    }
    sb2 nullIndicator = *((sb2 *) &(_rawResultsBuffer[column * 65536 + 128]));
    void *data = &_rawResultsBuffer[column * 65536 + 130];
    if (nullIndicator == -1) {
        return nil;
    }
    ub2 len = *((ub2 *) &(_rawResultsBuffer[column * 65536 + 126]));
    struct tm tyme;    
    switch (dType) {
		case SQLT_UIN:
            return [NSString stringWithFormat:@"0x%X", *((int *) data)];
			break;
            
		case SQLT_VNU:
		case SQLT_NUM:
		case SQLT_INT:
            // ahhh...
            return [NSString stringWithFormat:@"%i", *((int *) data)];
			break;

		case SQLT_FLT:
		case SQLT_BFLOAT:
		case SQLT_BDOUBLE:
		case SQLT_IBFLOAT:
		case SQLT_IBDOUBLE:
		case SQLT_PDN:
            return [NSString stringWithFormat:@"%g", *((double *) data)];
			break;
            
		case SQLT_DATE:
		case SQLT_DAT:
		case SQLT_ODT:
		case SQLT_TIMESTAMP:
		case SQLT_TIMESTAMP_TZ:
		case SQLT_TIMESTAMP_LTZ:
            memset(&tyme, 0, sizeof(struct tm));
            OCIDate *ociDate = (OCIDate *) data;
            OCIDateGetTime(ociDate, &tyme.tm_hour, &tyme.tm_min, &tyme.tm_sec);
            OCIDateGetDate(ociDate, &tyme.tm_year, &tyme.tm_mon, &tyme.tm_mday);
            if (tyme.tm_mon) {
                tyme.tm_mon--;
            }
            if (tyme.tm_year >= 1900) {
                tyme.tm_year -= 1900;
            }
            char tymeStr[256];
            strftime(tymeStr, sizeof(256), "%d-%b-%Y %T", &tyme);
            return [NSString stringWithUTF8String:tymeStr];
			break;
            
		case SQLT_CLOB:
		case SQLT_BLOB:
		case SQLT_CHR:
		case SQLT_STR:
		case SQLT_VST:
		case SQLT_VCS:
		case SQLT_AFC:
		case SQLT_AVC:
            return [[NSString alloc] initWithCString:data
                                              length:len];
			break;
            
		default:
			return nil;
    }            
}

- (id)_fetchRow:(BxDatabaseStatementFetchType)fetchType {
    if (! _hasMoreRows) {
        return nil;
    }
    if (_connection.isLocking) {
        [_connection.recursiveLock lock];
    }
    id result = nil;
    if (_connection.connectionType == BxDatabaseConnectionTypeSQLite) {
        sqlite3_stmt *stmt = (sqlite3_stmt *) _rawStatement;
        char *cStr;
        if (fetchType == BxDatabaseStatementFetchTypeValue) {
            cStr = (char *) sqlite3_column_text(stmt, 0);
            if (cStr == NULL) {
                result = [NSNull null];
            } else {
                result = [NSString stringWithUTF8String:cStr];
            }
        } else if (fetchType == BxDatabaseStatementFetchTypeDictionary) {
            int count = sqlite3_column_count(stmt);
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:count];
            for (int i = 0; i < count; i++) {
                cStr = (char *) sqlite3_column_name(stmt, i);
                if (cStr == NULL) {
                    break;
                }   
                NSString *key = [NSString stringWithUTF8String:cStr];
                cStr = (char *) sqlite3_column_text(stmt, i);
                if (cStr == NULL) {
                    [dict setObject:[NSNull null]
                             forKey:key];
                } else {
                    [dict setObject:[NSString stringWithUTF8String:cStr]
                             forKey:key];
                }
            }
            result = dict;
        } else { // BxDatabaseStatementFetchTypeArray
            int count = sqlite3_column_count(stmt);
            NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
            for (int i = 0; i < count; i++) {
                cStr = (char *) sqlite3_column_text(stmt, i);
                if (cStr == NULL) {
                    [array addObject:[NSNull null]];
                } else {
                    [array addObject:[NSString stringWithUTF8String:cStr]];
                }   
            }
            result = array;
        }
        
        int code = sqlite3_step(stmt);
        if (code == SQLITE_DONE || code == SQLITE_ROW) {
            _hasMoreRows = code == SQLITE_ROW;
        } else {
            _connection.lastError = [NSString stringWithUTF8String:sqlite3_errmsg((sqlite3 *) _connection.rawConnection)];
        }
    } else if (_connection.connectionType == BxDatabaseConnectionTypePostgreSQL) {
        PGresult *res = (PGresult *) _rawResults;
        if (res == NULL || _rowsLeft < 1) {
            result = nil;
        } else {
            _rowsLeft--;
            int columns = PQnfields(res);
            if (columns < 0) {
                result = nil;
            } else if (fetchType == BxDatabaseStatementFetchTypeValue) {
                if (PQgetisnull(res, _rowsLeft, 0)) {
                    result = [NSNull null];
                } else {
                    result = [NSString stringWithUTF8String:PQgetvalue(res, _rowsLeft, 0)];
                }
            } else if (fetchType == BxDatabaseStatementFetchTypeDictionary) {
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:columns];
                for (int i = 0; i < columns; i++) {
                    NSString *key = [NSString stringWithUTF8String:PQfname(res, i)];
                    if (PQgetisnull(res, _rowsLeft, i)) {
                        [dict setObject:[NSNull null]
                                 forKey:key];
                    } else {
                        [dict setObject:[NSString stringWithUTF8String:PQgetvalue(res, _rowsLeft, i)]
                                 forKey:key];
                    }
                }
                result = dict;
            } else { // BxDatabaseStatementFetchTypeArray
                NSMutableArray *array = [NSMutableArray arrayWithCapacity:columns];
                for (int i = 0; i < columns; i++) {
                    if (PQgetisnull(res, _rowsLeft, i)) {
                        [array addObject:[NSNull null]];
                    } else {
                        [array addObject:[NSString stringWithUTF8String:PQgetvalue(res, _rowsLeft, i)]];
                    }
                }
                result = array;
            }
        }            
        _hasMoreRows = _rowsLeft > 0;
    } else if (_connection.connectionType == BxDatabaseConnectionTypeMySQL) {
        MYSQL_STMT *stmt = (MYSQL_STMT *) _rawStatement;
        MYSQL_BIND *results = (MYSQL_BIND *) _rawResults;
        int count = mysql_stmt_field_count(stmt);        
        if (fetchType == BxDatabaseStatementFetchTypeValue) {
            if (count > 0) {
                if (*(results[0].is_null)) {
                    result = [NSNull null];
                } else {
                    result = [[[NSString alloc] initWithBytes:results[0].buffer
                                                       length:*(results[0].length)
                                                     encoding:NSUTF8StringEncoding] autorelease];
                }
            }
        } else if (fetchType == BxDatabaseStatementFetchTypeDictionary) {
            MYSQL_RES *info;
            if (_rawResultsInfo == NULL) {
                info = mysql_stmt_result_metadata(stmt);
                _rawResultsInfo = info;
            } else {
                info = (MYSQL_RES *) _rawResultsInfo;
            }
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:count];
            for (int i = 0; i < count; i++) {
                MYSQL_FIELD *field = mysql_fetch_field_direct(info, i);
                NSString *key = [NSString stringWithUTF8String:field->name];
                if (*(results[i].is_null)) {
                    [dict setObject:[NSNull null]
                             forKey:key];
                } else {
                    NSString *str = [[[NSString alloc] initWithBytes:results[i].buffer
                                                              length:*(results[i].length)
                                                            encoding:NSUTF8StringEncoding] autorelease];
                    if (str == nil) {
                        dict = nil;
                        break;
                    } else {                        
                        [dict setObject:str
                                 forKey:key];
                    }
                }
            }
            result = dict;
        } else { // BxDatabaseStatementFetchTypeArray
            NSMutableArray *array = [NSMutableArray arrayWithCapacity:count];
            for (int i = 0; i < count; i++) {
                if (*(results[i].is_null)) {
                    [array addObject:[NSNull null]];
                } else {
                    NSString *str = [[[NSString alloc] initWithBytes:results[i].buffer
                                                              length:*(results[i].length)
                                                            encoding:NSUTF8StringEncoding] autorelease];
                    //NSLog(@"str:%@", str);
                    if (str == nil) {
                        array = nil;
                        break;
                    } else {                        
                        [array addObject:str];
                    }
                }
            }
            result = array;
        }
        
        int code = mysql_stmt_fetch(stmt);
        if (code == 0) {
            _hasMoreRows = YES;
        } else if (code == MYSQL_NO_DATA) {
            _hasMoreRows = NO;
        } else {
            _hasMoreRows = NO;
            _connection.lastError = [NSString stringWithUTF8String:mysql_stmt_error(stmt)];
        }
    } else if (_connection.connectionType == BxDatabaseConnectionTypeOracle) {
        OCIStmt *stmt = (OCIStmt *) _rawStatement;
        OCIError *oraErr = (OCIError *) [_connection _ociError];
        
        NSString *strResult;
        if (fetchType == BxDatabaseStatementFetchTypeValue) {
            NSString *name = nil;
            strResult = [self _convertToStringColumn:1
                                                name:&name];
            if (strResult == nil) {
                if (name == nil) {
                    _connection.lastError = @"Error fetching results";
                    result = nil;
                } else {
                    result = [NSNull null];
                }
            } else {
                result = strResult;
            }
        } else if (fetchType == BxDatabaseStatementFetchTypeDictionary) {
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:_columnCount];
            for (int i = 0; i < _columnCount; i++) {
                NSString *key = nil;
                strResult = [self _convertToStringColumn:i + 1
                                                    name:&key];
                if (strResult == nil) {
                    if (key == nil) {
                        _connection.lastError = @"Error fetching results";
                        dict = nil;
                        break;
                    } else {
                        [dict setObject:[NSNull null]
                                 forKey:key];
                    }
                } else {
                    [dict setObject:strResult
                             forKey:key];
                }
            }
            result = dict;
        } else { // BxDatabaseStatementFetchTypeArray
            NSMutableArray *array = [NSMutableArray arrayWithCapacity:_columnCount];
            for (int i = 0; i < _columnCount; i++) {
                NSString *name = nil;
                strResult = [self _convertToStringColumn:i + 1
                                                    name:&name];
                if (strResult == nil) {
                    if (name == nil) {
                        _connection.lastError = @"Error fetching results";
                        array = nil;
                        break;
                    } else {
                        [array addObject:[NSNull null]];
                    }
                } else {
                    [array addObject:strResult];
                }
            }
            result = array;
        }
        
        for (int i = 0; i < _columnCount; i++) {
            memset(&_rawResultsBuffer[i * 65536 + 130], 0, 256);
        }
        int rc = OCIStmtFetch2(stmt,
                               oraErr,
                               1,
                               OCI_DEFAULT,
                               0,
                               OCI_DEFAULT);            
        if (rc == OCI_SUCCESS || rc == OCI_SUCCESS_WITH_INFO) {
            _hasMoreRows = YES;
        } else {
            _hasMoreRows = NO;
        }
    }
    if (_connection.isLocking) {
        [_connection.recursiveLock unlock];
    }
    return result;
}

- (BOOL)_bind:(id)binds
         args:(va_list)args {
    BOOL result = YES;
    for (int i = 1; i <= [_bindNames count]; i++) {
        if (i == 1) {
            if (! [self _prelockedBindValue:binds
                                  forColumn:i]) {
                result = NO;
            }
        } else {
            NSString *str = va_arg(args, NSString *);
            if (str == nil || str == NULL) {
                break;
            }
            if (! [self _prelockedBindValue:str
                                  forColumn:i]) {
                result = NO;
            }
        }
    }
    return result;
}

- (BOOL)bindArray:(NSArray *)binds {
    if (_hasClosed) {
        return NO;
    }
    if (_connection.isLocking) {
        [_connection.recursiveLock lock];
    }
    BOOL result = YES;
    for (int i = 0; i < [binds count]; i++) {
        id obj = [binds objectAtIndex:i];
        if (obj == [NSNull null]) {
            obj = nil;
        } else if (obj != nil && ![obj isKindOfClass:[NSString class]]) {
            obj = [obj description];
        }
        if (! [self _prelockedBindValue:obj
                              forColumn:i + 1]) {
            result = NO;
        }
    }
    if (_connection.isLocking) {
        [_connection.recursiveLock unlock];
    }
    return result;
}

- (BOOL)bindDictionary:(NSDictionary *)binds {
    if (_hasClosed) {
        return NO;
    }
    if (_connection.isLocking) {
        [_connection.recursiveLock lock];
    }
    BOOL result = YES;
    for (NSString *key in binds) {
        id obj = [binds objectForKey:key];
        if (obj == [NSNull null]) {
            obj = nil;
        } else if (obj != nil && ![obj isKindOfClass:[NSString class]]) {
            obj = [obj description];
        }
        if (! [self _prelockedBindValue:obj
                                 forKey:key]) {
            result = NO;
        }
    }
    if (_connection.isLocking) {
        [_connection.recursiveLock unlock];
    }
    return result;
}

- (BOOL)bindWith:(id)binds, ... {
    if (_hasClosed) {
        return NO;
    }
    if (_connection.isLocking) {
        [_connection.recursiveLock lock];
    }
    va_list args;
    va_start(args, binds);
    BOOL result = [self _bind:binds args:args];
    va_end(args);    
    if (_connection.isLocking) {
        [_connection.recursiveLock unlock];
    }    
    return result;
}

- (BOOL)bindValue:(id)value
        forColumn:(int)column {
    if (_hasClosed) {
        return NO;
    }
    if (_connection.isLocking) {
        [_connection.recursiveLock lock];
    }
    BOOL result = [self _prelockedBindValue:value
                                  forColumn:column];
    if (_connection.isLocking) {
        [_connection.recursiveLock unlock];
    }
    return result;
}

- (BOOL)bindValue:(id)value
           forKey:(NSString *)key {
    if (_hasClosed) {
        return NO;
    }
    if (_connection.isLocking) {
        [_connection.recursiveLock lock];
    }
    BOOL result = [self _prelockedBindValue:value
                                     forKey:key];
    if (_connection.isLocking) {
        [_connection.recursiveLock unlock];
    }
    return result;
}

- (BOOL)close {
    if (! _hasClosed) {
        if (_connection.isLocking) {
            [_connection.recursiveLock lock];
        }
        if (_connection.connectionType == BxDatabaseConnectionTypeSQLite) {
            sqlite3 *conn = (sqlite3 *) _connection.rawConnection;
            sqlite3_stmt *stmt = (sqlite3_stmt *) _rawStatement; 
            if (sqlite3_finalize(stmt) != SQLITE_OK) {
                _connection.lastError = [NSString stringWithUTF8String:sqlite3_errmsg(conn)];
            }
        } else if (_connection.connectionType == BxDatabaseConnectionTypePostgreSQL) {
            if (_rawResults) {
                PQclear(_rawResults);
            }
            [_statementName release];
        } else if (_connection.connectionType == BxDatabaseConnectionTypeMySQL) {
            MYSQL_STMT *stmt = (MYSQL_STMT *) _rawStatement;
            mysql_stmt_close(stmt);
            if (_rawBinds) {
                free(_rawBinds);
            }
            if (_rawResults) {
                free(_rawResults);
            }
            if (_rawResultsBuffer) {
                free(_rawResultsBuffer);
            }
            if (_rawBindsBuffer) {
                free(_rawBindsBuffer);
            }
            if (_rawResultsInfo) {
                mysql_free_result((MYSQL_RES *) _rawResultsInfo);
            }
        } else if (_connection.connectionType == BxDatabaseConnectionTypeOracle) {
            OCIStmt *stmt = (OCIStmt *) _rawStatement;
            OCIError *oraErr = (OCIError *) [_connection _ociError];
            if (_rawBinds) {
                OCIBind **binds = (OCIBind **) _rawBinds;
                for (int i = 0; i < [_bindValues count]; i++) {
                    if (binds[i] != NULL) {
                        OCIHandleFree(binds[i], OCI_HTYPE_BIND);
                    }
                }
                free(_rawBinds);
            }
            if (_rawResults) {
                OCIDefine **defines = (OCIDefine **) _rawResults;
                OCIDefine *define = defines[0];
                for (int i = 0; define != NULL; i++) {
                    OCIHandleFree(define, OCI_HTYPE_DEFINE);
                    define = defines[i];
                }
                free(_rawResults);
            }
            if (_rawResultsBuffer) {
                free(_rawResultsBuffer);
            }
            if (_rawBindsBuffer) {
                free(_rawBindsBuffer);
            }
            OCIStmtRelease(stmt, oraErr, NULL, 0, OCI_DEFAULT);
            OCIHandleFree(stmt, OCI_HTYPE_STMT);
        }
        [_connection release];
        [_bindNames release];
        [_bindValues release];
        _hasClosed = YES;
        if (_connection.isLocking) {
            [_connection.recursiveLock unlock];
        }
    }
    return YES;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state
                                  objects:(id *)stackbuf
                                    count:(NSUInteger)len {
    int count = 0;
    NSArray *row = nil;
    for (count = 0; count < len && (row = [self fetchArray]) != nil; count++) {
        stackbuf[count] = row;
    }
    state->state = (unsigned long) row;
    state->itemsPtr = stackbuf;
    state->mutationsPtr = (unsigned long *) self;
    
    return count;
}

- (BOOL)execute {
    if (_hasClosed) {
        return NO;
    }
    if (_connection.isLocking) {
        [_connection.recursiveLock lock];
    }
    _hasMoreRows = NO;
    BOOL result = YES;
    if (_connection.connectionType == BxDatabaseConnectionTypeSQLite) {
        sqlite3_stmt *stmt = (sqlite3_stmt *) _rawStatement;
        int code = sqlite3_step(stmt);
        if (code == SQLITE_DONE || code == SQLITE_ROW) {                
            _hasResetted = NO;
            _hasMoreRows = code == SQLITE_ROW;
        } else {
            _connection.lastError = [NSString stringWithUTF8String:sqlite3_errmsg((sqlite3 *) _connection.rawConnection)];
            result = NO;
        }
    } else if (_connection.connectionType == BxDatabaseConnectionTypePostgreSQL) {
        PGconn *conn = (PGconn *) _connection.rawConnection;
        int count = [_bindValues count];
        char **values = malloc(sizeof(char *) * count);
        int *formats = malloc(sizeof(int) * count);
        int *lengths = malloc(sizeof(int) * count);
        for (int i = 0; i < [_bindValues count]; i++) {
            id value = [_bindValues objectAtIndex:i];
            if (value == [NSNull null]) {
                values[i] = NULL;
                lengths[i] = 0;
                formats[i] = 0;
            } else {
                NSString *strVal = value;
                values[i] = (char *) [strVal UTF8String];
                lengths[i] = [strVal length]; 
                formats[i] = 0;
            }
        }
        PGresult *res;
        if (_rawResults != NULL) {
            res = (PGresult *) _rawResults;
            PQclear(res);
            res = NULL;
        }
        res = PQexecPrepared(conn,
                             (char *) [_statementName UTF8String],
                             [_bindValues count],
                             (const char **) values,
                             lengths,
                             formats,
                             0);
        free(values);
        free(formats);
        free(lengths);
        ExecStatusType status = PQresultStatus(res);
        if (status == PGRES_TUPLES_OK || status == PGRES_COMMAND_OK) {
            _rowsLeft = PQntuples(res);
            _rawResults = (void *) res;
            _hasMoreRows = _rowsLeft > 0;
        } else {
            PQclear(res);
            _connection.lastError = [NSString stringWithUTF8String:PQerrorMessage(conn)];
            _hasMoreRows = NO;
            result = NO;
        }
    } else if (_connection.connectionType == BxDatabaseConnectionTypeMySQL) {
        MYSQL_STMT *stmt = (MYSQL_STMT *) _rawStatement;
        if ([_bindNames count] > 0) {
            MYSQL_BIND *binds = (MYSQL_BIND *) _rawBinds;
            if (mysql_stmt_bind_param(stmt, binds) != 0) {
                _connection.lastError = [NSString stringWithUTF8String:mysql_stmt_error(stmt)];
                result = NO;
            }
        }
        if (result == YES && mysql_stmt_execute(stmt) != 0) {
            _connection.lastError = [NSString stringWithUTF8String:mysql_stmt_error(stmt)];
            result = NO;
        } else {            
            int count = mysql_stmt_field_count(stmt);
            if (count > 0) {
                if (_rawResults == NULL) {
                    MYSQL_BIND *results = calloc(count, sizeof(MYSQL_BIND));
                    _rawResults = results;
                    _rawResultsBuffer = calloc(count, 65536);
                    for (int i = 0; i < count; i++) {
                        results[i].buffer_type = MYSQL_TYPE_STRING;
                        results[i].buffer = &(_rawResultsBuffer[i * 65536]);
                        results[i].buffer_length = 65525;
                        _rawResultsBuffer[65536 * i + 65526] = 0;
                        results[i].is_null = &(_rawResultsBuffer[65536 * i + 65526]);
                        *((unsigned long *) &(_rawResultsBuffer[65536 * i + 65528])) = 0;
                        results[i].length = (unsigned long *) &(_rawResultsBuffer[65536 * i + 65528]);
                    }
                    if (mysql_stmt_bind_result(stmt, results) != 0) {
                        _connection.lastError = [NSString stringWithUTF8String:mysql_stmt_error(stmt)];
                        result = NO;
                        free(results);
                        _rawResults = NULL;
                    }
                }
                int code = mysql_stmt_fetch(stmt);
                if (code == 0) {
                    _hasMoreRows = YES;
                } else if (code == MYSQL_NO_DATA) {
                    _hasMoreRows = NO;
                } else {
                    _connection.lastError = [NSString stringWithUTF8String:mysql_stmt_error(stmt)];
                    result = NO;
                }
            } else {
                _hasMoreRows = NO;
            }
            _columnCount = count;
        }
    } else if (_connection.connectionType == BxDatabaseConnectionTypeOracle) {
        OCIStmt *stmt = (OCIStmt *) _rawStatement;
        OCIError *oraErr = (OCIError *) [_connection _ociError];
        OCISvcCtx *oraSvc = (OCISvcCtx *) _connection.rawConnection;
        
        text errorBuf[512];
        int rc;
        if (rc = OCIStmtExecute(oraSvc,
                                stmt,
                                oraErr,
                                _isSelect ? 0 : 1,
                                0,
                                NULL,
                                NULL,
                                OCI_DEFAULT)) {
            OCIErrorGet(oraErr, 1, NULL, &rc, errorBuf, 512, OCI_HTYPE_ERROR);
            _connection.lastError = [NSString stringWithUTF8String:(char *) errorBuf];
            result = NO;
        } else {
            int count;
            OCIAttrGet(stmt, OCI_HTYPE_STMT, &count, 0, OCI_ATTR_PARAM_COUNT, oraErr);
            _columnCount = count;
            if (count > 0) {
                if (_rawResultsBuffer == NULL) {

                    _rawResultsBuffer = calloc(count, 65536); // 0 - 1 type, 2 - 127 name, 128 - 129 ind, 130 - 65535 data
                    OCIParam *param;
                    _rawResults = calloc(count + 1, sizeof(OCIDefine *));
                    OCIDefine **defines = (OCIDefine **) _rawResults;
                    
                    for (int i = 1; i <= count; i++) {
                        OCIParamGet(stmt, OCI_HTYPE_STMT, oraErr, (void **) &param, i);
                        ub2 dType;
                        int index = i - 1;
//                        OCIAttrGet(param,
//                                   OCI_DTYPE_PARAM,
//                                   &dType,
//                                   NULL,
//                                   OCI_ATTR_DATA_TYPE,
//                                   oraErr);
                        dType = SQLT_CHR;
                        *((ub2 *) &(_rawResultsBuffer[index * 65536])) = dType;
                        text *name;
                        ub4 len;
                        OCIAttrGet(param,
                                   OCI_DTYPE_PARAM,
                                   &name,
                                   &len,
                                   OCI_ATTR_NAME, //OCI_ATTR_NAME,
                                   oraErr);
                        // tbd free name?
                        strncpy(&(_rawResultsBuffer[65536 * index + 2]), name, len);
                        
                        _rawResultsBuffer[index * 65536 + 2 + len] = 0;
                        _rawResultsBuffer[index * 65536 + 125] = 0;
                        text errorBuf[512];
                        
                        if (OCIDefineByPos(stmt,
                                           &(defines[index]),
                                           oraErr,
                                           i,
                                           &_rawResultsBuffer[index * 65536 + 130],
                                           65405,
                                           dType,
                                           &_rawResultsBuffer[index * 65536 + 128],
                                           (ub2 *) &_rawResultsBuffer[index * 65536 + 126],
                                           NULL,
                                           OCI_DEFAULT)) {
                            OCIErrorGet(oraErr, (ub4) 1, NULL, &rc, errorBuf, 512, OCI_HTYPE_ERROR);
                            _connection.lastError = [NSString stringWithUTF8String:(char *) errorBuf];
                        }
                        OCIDescriptorFree(param, OCI_DTYPE_PARAM);
                    }
                }
                rc = OCIStmtFetch2(stmt,
                                   oraErr,
                                   1,
                                   OCI_DEFAULT,
                                   0,
                                   OCI_DEFAULT);
                if (rc == OCI_SUCCESS || rc == OCI_SUCCESS_WITH_INFO) {
                    _hasMoreRows = YES;
                } else {
                    _hasMoreRows = NO;
                }
            } else {
                _hasMoreRows = NO;
            }
        }
    }
    if (_connection.isLocking) {
        [_connection.recursiveLock unlock];
    }
    return result;
}

- (BOOL)executeWith:(id)binds, ... {
    if (_hasClosed) {
        return NO;
    }
    if (_connection.isLocking) {
        [_connection.recursiveLock lock];
    }
    va_list args;
    va_start(args, binds);
    BOOL result = [self _bind:binds args:args];
    if (result) {
        result = [self execute];
    }
    va_end(args);    
    if (_connection.isLocking) {
        [_connection.recursiveLock unlock];
    }    
    return result;
}

- (NSArray *)fetchArray {
    if (_hasClosed) {
        return nil;
    }
    return [self _fetchRow:BxDatabaseStatementFetchTypeArray];
}

- (NSDictionary *)fetchDictionary {
    if (_hasClosed) {
        return nil;
    }
    return [self _fetchRow:BxDatabaseStatementFetchTypeDictionary];
}

- (id)fetchValue {
    if (_hasClosed) {
        return nil;
    }
    return [self _fetchRow:BxDatabaseStatementFetchTypeValue];
}

- (id)initWithConnection:(BxDatabaseConnection *)connection
                     sql:(NSString *)sql, ... {
    if (connection.isLocking) {
        [connection.recursiveLock lock];
    }
    va_list args;
    va_start(args, sql);
    id result =  [self initWithConnection:connection
                                      sql:sql
                                     args:args];
    va_end(args);
    if (connection.isLocking) {
        [connection.recursiveLock unlock];
    }
    return result;
}


- (id)initWithConnection:(BxDatabaseConnection *)connection
                     sql:(NSString *)sql
                    args:(va_list)args {
    if (connection == nil) {
        return nil;
    } else if (sql == nil || [sql length] == 0) {
        connection.lastError = @"Empty SQL";
        return nil;
    }
    _hasClosed = NO;
    _hasMoreRows = NO;
    _hasResetted = YES;    
    _connection = [connection retain];
    _bindNames = [[NSMutableArray alloc] initWithCapacity:8];
    _rawBinds = NULL;
    _rawBindsBuffer = NULL;
    _rawResults = NULL;
    _rawResultsBuffer = NULL;
    _rawResultsInfo = NULL;
    BOOL isSingleQuoting = NO;
    BOOL isValue = NO;
    int valStart = 0;
    int length = [sql length];
    for (int i = 0; i < length; i++) {
        unichar c = [sql characterAtIndex:i];
        if (isSingleQuoting) {
            if (c == '\'') {
                isSingleQuoting = NO;
            }
        } else if (isValue) {
            if (!(isalnum(c) || c == '_')) {
                [_bindNames addObject:[sql substringWithRange:NSMakeRange(valStart, i - valStart)]];
                isValue = NO;
                if (c == '\'') {
                    isSingleQuoting = YES;
                }
            }
        } else if (c == ':' || c == '?' || c == '$') {
            valStart = i + 1;
            isValue = YES;
        } else if (c == '\'') {
            isSingleQuoting = YES;
        }
    }
    if (isValue) {
        [_bindNames addObject:[sql substringWithRange:NSMakeRange(valStart, length - valStart)]];        
    }
    _bindValues = [[NSMutableArray alloc] initWithCapacity:[_bindNames count]];
    for (int i = 0; i < [_bindNames count]; i++) {
        [_bindValues addObject:[NSNull null]];
    }
    
    if (_connection.connectionType == BxDatabaseConnectionTypeSQLite) {
        sqlite3 *conn = (sqlite3 *) _connection.rawConnection;
        sqlite3_stmt *stmt;
        if (sqlite3_prepare_v2(conn,
                               [sql UTF8String],
                               [sql length] + 1,
                               &stmt,
                               NULL) != SQLITE_OK) {
            _connection.lastError = [NSString stringWithUTF8String:sqlite3_errmsg(conn)];
            [_bindNames release];
            [_bindValues release];
            [_connection release];
            return nil;
        }
        _rawStatement = (void *) stmt;
    } else if (_connection.connectionType == BxDatabaseConnectionTypePostgreSQL) {
        _statementName = [[NSString alloc] initWithFormat:@"BX%uBX", [sql hash]];
        NSMutableSet *statements = [_connection _statements];
        if (! [statements member:_statementName]) {
            PGconn *conn = (PGconn *) _connection.rawConnection;
            PGresult *res = PQprepare(conn,
                                      [_statementName UTF8String],
                                      [sql UTF8String],
                                      [_bindValues count],
                                      NULL);
            if (PQresultStatus(res) == PGRES_COMMAND_OK) {
                [statements addObject:_statementName];
                PQclear(res);
            } else {
                [_bindNames release];
                [_bindValues release];
                [_connection release];
                [_statementName release];
                PQclear(res);
                return nil;
            }
        }
    } else if (_connection.connectionType == BxDatabaseConnectionTypeMySQL) {
        MYSQL *conn = (MYSQL *) _connection.rawConnection;
        MYSQL_STMT *stmt = mysql_stmt_init(conn);
        if (! stmt) {
            _connection.lastError = @"Could not allocate MySQL statement";
            [_bindNames release];
            [_bindValues release];
            [_connection release];
            return nil;
        }
        if (mysql_stmt_prepare(stmt,
                               [sql UTF8String],
                               [sql length]) != 0) {
            _connection.lastError = [NSString stringWithUTF8String:mysql_error(conn)];
            [_bindNames release];
            [_bindValues release];
            [_connection release];
            return nil;
        }
        int count = mysql_stmt_param_count(stmt);
        if (count > 0) {
            _rawBinds = calloc(count, sizeof(MYSQL_BIND));
            MYSQL_BIND *binds = (MYSQL_BIND *) _rawBinds;
            for (int i = 0; i < count; i++) {
                binds[i].buffer_type = MYSQL_TYPE_NULL;
            }
            _rawBindsBuffer = calloc(count, 65536); // 0-65525 char* buffer, 65526 = bool, 65528-65535 = long
        }
        _rawStatement = (void *) stmt;
    } else if (_connection.connectionType == BxDatabaseConnectionTypeOracle) {
        OCIStmt *stmt;
        OCIEnv *oraEnv = (OCIEnv *) [_connection _ociEnv];
        OCIError *oraErr = (OCIError *) [_connection _ociError];
        OCIHandleAlloc(oraEnv, (dvoid **) &stmt, OCI_HTYPE_STMT, 0, NULL);
        text errorBuf[512];
        int rc;
        OCISvcCtx *oraSvc = (OCISvcCtx *) [_connection rawConnection];
//        if (rc = OCIStmtPrepare(stmt,
//                                oraErr,
//                                (text *) [sql UTF8String],
//                                (ub4) [sql length],
//                                OCI_NTV_SYNTAX,
//                                OCI_DEFAULT)) {
        if (rc = OCIStmtPrepare2(oraSvc,
                                 &stmt,
                                 oraErr,
                                (text *) [sql UTF8String],
                                (ub4) [sql length],
                                 NULL,
                                 0,
                                OCI_NTV_SYNTAX,
                                OCI_DEFAULT)) {
            OCIErrorGet(oraErr, 1, NULL, &rc, errorBuf, 512, OCI_HTYPE_ERROR);
            _connection.lastError = [NSString stringWithUTF8String:(char *) errorBuf];
            [_bindNames release];
            [_bindValues release];
            [_connection release];
            return nil;
        }
        _rawBindsBuffer = calloc([_bindValues count], 65535); // 0-65529 char* buffer, 65530-65531 indicator, 65532-65533 len, 65534-65535 res
        _rawBinds = calloc([_bindValues count], sizeof(OCIBind *));
        _isSelect = [sql rangeOfString:@"SELECT"
                               options:NSCaseInsensitiveSearch].location != NSNotFound;
        _rawStatement = (void *) stmt;
    }
        
    for (int i = 0; i < [_bindValues count]; i++) {
        NSString *obj = va_arg(args, NSString *);
        if (obj == nil || obj == NULL) {
            break;
        } else if ([obj isKindOfClass:[NSString class]]) {
            [self _prelockedBindValue:obj
                         forColumn:i + 1];
        } else {
            [self _prelockedBindValue:[obj description]
                         forColumn:i + 1];
        }
    }
    return self;
}

- (void)dealloc {
    [self close];
    [super dealloc];
}

@end
