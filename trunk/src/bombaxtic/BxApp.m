#import "BxApp.h"
#import <Bombaxtic/BxHandler.h>

@implementation BxApp

static NSMutableDictionary *_BX_handlerMap;
static NSMutableDictionary *_BX_suffixMap;
static NSMutableDictionary *_BX_prefixMap;
static NSMutableDictionary *_BX_keywordMap;
static NSMutableDictionary *_BX_urlMap;
static NSMutableArray *_BX_suffixKeyArray;
static NSMutableArray *_BX_prefixKeyArray;
static NSMutableArray *_BX_keywordKeyArray;
static NSString *_BX_defaultHandler;
static NSString *_BX_staticWebPath = nil;

@synthesize state = _state;

extern BOOL _BX_isDebugging;

- (id)init {
    _state = [[NSMutableDictionary alloc] initWithCapacity:32];
    _BX_handlerMap = [[NSMutableDictionary alloc] initWithCapacity:8];
    _matchClassName = NO;
    _BX_suffixMap = nil;
    _BX_prefixMap = nil;
    _BX_keywordMap = nil;
    _BX_urlMap = nil;
    _BX_suffixKeyArray = nil;
    _BX_prefixKeyArray = nil;
    _BX_keywordKeyArray = nil;
    _BX_defaultHandler = nil;
    if (_BX_isDebugging) {
        [self staticWebPath:@""]; // initialize _BX_staticWebPath
        [self setHandler:@"BxStaticFileHandler"
               forPrefix:_BX_staticWebPath];
    }
    return self;
}

- (id)setup {
    return self;
}

- (id)exit:(BOOL)isError {
    return self;
}

- (id)launchConfigurator {
    [NSApplication sharedApplication];
    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    NSString *name = [infoDict objectForKey:@"BxApp Name"];
    if (name == nil) {
        name = @"BxApp";
    }
    NSString *author = [infoDict objectForKey:@"BxApp Author"];
    if (author == nil) {
        author = @"";
    }
    NSString *authorUrl = [infoDict objectForKey:@"BxApp Author URL"];
    if (authorUrl == nil) {
        authorUrl = @"http://www.bombaxtic.com/";
    }
    NSString *bombaxticVersion = [infoDict objectForKey:@"BxApp Bombaxtic Version"];
    if (bombaxticVersion == nil) {
        bombaxticVersion = @"";
    }
    NSString *description = [infoDict objectForKey:@"BxApp Description"];
    if (description == nil) {
        description = @"";
    }
    NSString *version = [infoDict objectForKey:@"CFBundleVersion"];

    NSString *message = [NSString localizedStringWithFormat:@"Version:%@  Bombaxtic Version:%@\nAuthor:%@ %@\n%@",
                         version, bombaxticVersion, author, authorUrl, description];
    if (NSRunAlertPanel(name,
                        message,
                        NSLocalizedString(@"Close", nil),
                        NSLocalizedString(@"Visit Author", nil),
                        nil) == NSAlertAlternateReturn) {
        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:authorUrl]];
    }
    [[NSApplication sharedApplication] terminate:self];
    return self;
}


- (id)setHandler:(NSString *)handlerName forMatch:(NSString *)match {
    if (match == nil) {
        return self;
    } else if (! [match hasPrefix:@"/"]) {
        match = [@"/" stringByAppendingString:match];
    }
    if (_BX_urlMap == nil) {
        _BX_urlMap = [[NSMutableDictionary alloc] initWithCapacity:16];
    }
    if (handlerName == nil) {
        [_BX_urlMap removeObjectForKey:match];
    } else {
        [_BX_urlMap setObject:handlerName forKey:match];
    }
    return self;
}

- (id)setHandler:(NSString *)handlerName forPrefix:(NSString *)prefix {
    if (prefix == nil) {
        return self;
    } else if (! [prefix hasPrefix:@"/"]) {
        prefix = [@"/" stringByAppendingString:prefix];
    }
    if (_BX_prefixMap == nil) {
        _BX_prefixMap = [[NSMutableDictionary alloc] initWithCapacity:16];
        _BX_prefixKeyArray = [[NSMutableArray alloc] initWithCapacity:16];
    }
    if (handlerName == nil) {
        [_BX_prefixMap removeObjectForKey:prefix];
        [_BX_prefixKeyArray removeObject:@"prefix"];
        [_BX_prefixKeyArray sortUsingSelector:@selector(compare:)];     
    } else {
        [_BX_prefixMap setObject:handlerName forKey:prefix];
        [_BX_prefixKeyArray addObject:prefix];
        [_BX_prefixKeyArray sortUsingSelector:@selector(compare:)];
    }
    return self;
}

- (id)setHandler:(NSString *)handlerName forSuffix:(NSString *)suffix {
    if (suffix == nil) {
        return self;
    }
    if (_BX_suffixMap == nil) {
        _BX_suffixMap = [[NSMutableDictionary alloc] initWithCapacity:16];
        _BX_suffixKeyArray = [[NSMutableArray alloc] initWithCapacity:16];
    }
    if (handlerName == nil) {
        [_BX_suffixMap removeObjectForKey:suffix];
        [_BX_suffixKeyArray removeObject:suffix];
        [_BX_suffixKeyArray sortUsingSelector:@selector(compare:)];
    } else {
        [_BX_suffixMap setObject:handlerName forKey:suffix];
        [_BX_suffixKeyArray addObject:suffix];
        [_BX_suffixKeyArray sortUsingSelector:@selector(compare:)];
    }
    return self;
}

- (id)setMatchClassNameHandling:(BOOL)matchClassName {
    _matchClassName = matchClassName;
    return self;
}


- (id)setHandler:(NSString *)handlerName forKeyword:(NSString *)keyword {
    if (keyword == nil) {
        return self;
    }
    if (_BX_keywordMap == nil) {
        _BX_keywordMap = [[NSMutableDictionary alloc] initWithCapacity:16];
        _BX_keywordKeyArray = [[NSMutableArray alloc] initWithCapacity:16];
    }
    if (handlerName == nil) {
        [_BX_keywordMap removeObjectForKey:keyword];
        [_BX_keywordKeyArray removeObject:keyword];
        [_BX_keywordKeyArray sortUsingSelector:@selector(compare:)];
    } else {
        [_BX_keywordMap setObject:handlerName forKey:keyword];
        [_BX_keywordKeyArray addObject:keyword];
        [_BX_keywordKeyArray sortUsingSelector:@selector(compare:)];
    }
    return self;
}

- (id)setDefaultHandler:(NSString *)handlerName {
    if (_BX_defaultHandler != nil) {
        [_BX_defaultHandler release];
    }
    if (handlerName != nil) {
        _BX_defaultHandler = [handlerName retain];
    } else {
        _BX_defaultHandler = nil;
    }
    return self;
}

- (NSString *)_staticPrefix {
    if (_BX_staticWebPath == nil) {
        return [self staticWebPath:nil];
    } else {
        return _BX_staticWebPath;
    }
}

- (NSString *)staticWebPath:(NSString *)resource {
    if (_BX_staticWebPath == nil) {   
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        _BX_staticWebPath  = [info objectForKey:@"BxApp Static Web Path"];
        if (_BX_staticWebPath == nil) {
            _BX_staticWebPath = @"";
        }
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *urlRoot = [defaults stringForKey:@"root"];
        if (urlRoot == nil) {
            urlRoot = @"";
        }
        _BX_staticWebPath = [[NSString stringWithFormat:@"%@/%@/", urlRoot, _BX_staticWebPath] copy];
    }
    if (resource == nil) {
        return _BX_staticWebPath;
    } else {
        return [NSString stringWithFormat:@"%@%@", _BX_staticWebPath, resource];
    }
}

- (NSString *)handlerForPath:(NSString *)path {
    if (path == nil) {
        return nil;
    }
    NSString *handler = nil;
    if (_matchClassName) {
        if ([path hasPrefix:@"/"]) {
            path = [path substringFromIndex:1];
        
        }
        path = [path stringByReplacingOccurrencesOfString:@"/"
                                               withString:@"_"];
        if ([self handlerInstanceForClassName:path]) {
            handler = path;
        }
    } else {
        if (_BX_urlMap != nil) {        
            handler = [_BX_urlMap objectForKey:path];
        }
        if (handler == nil && _BX_prefixMap != nil) {
            for (NSString *key in _BX_prefixKeyArray) {
                if ([path hasPrefix:key]) {
                    handler = [_BX_prefixMap objectForKey:key];
                    break;
                }
            }
        }
        if (handler == nil && _BX_suffixMap != nil) {
            for (NSString *key in _BX_suffixKeyArray) {
                if ([path hasSuffix:key]) {
                    handler = [_BX_suffixMap objectForKey:key];
                    break;
                }
            }
        }
        if (handler == nil && _BX_keywordMap != nil) {
            for (NSString *key in _BX_keywordKeyArray) {
                if ([path rangeOfString:key].location != NSNotFound) {
                    handler = [_BX_keywordMap objectForKey:key];
                    break;
                }
            }
        }
    }
    if (handler == nil) {
        handler = _BX_defaultHandler;
    }
    return handler;
}

- (BxHandler *)handlerInstanceForClassName:(NSString *)handlerName {
    if (handlerName == nil) {
        return nil;
    }
    BxHandler *handler = [_BX_handlerMap objectForKey:handlerName];
    if (handler == nil) {
        Class handlerClass = NSClassFromString(handlerName);
        if (handlerClass == nil ||
            [handlerClass isKindOfClass:[BxHandler class]]) {
            return nil;
        }
        handler = [[handlerClass alloc] initWithApp:(BxApp *)self];
        [handler setup];
        [_BX_handlerMap setObject:handler forKey:handlerName];
    }
    return handler;
}

@end
