#import "ExceptionHandling/ExceptionHandling.h"
#import <pthread.h>
#import <signal.h>
#import "fcgiapp.h"
#import <Bombaxtic/Bombaxtic.h>

NSString *BX_ERROR_DOMAIN_STRING;


__attribute__((constructor))
static void BombaxticInitializer()
{
    static int initialized = 0;
    if (!initialized)
    {
        initialized = 1;
    }
}

__attribute__((destructor))
static void finalizer()
{
}

/* This is set to YES if the debug socket is being used by this BxApp */
BOOL _BX_isDebugging = NO;

/* This is the location of the BxApp through Bombax, if any. */
NSString *_BX_urlRoot = nil;

BxApp *_BX_bxApp = NULL;

NSString *_BX_version = @"1.1.0";

NSUInteger _BX_version_major = 1;
NSUInteger _BX_version_minor = 1;
NSUInteger _BX_version_release = 0;

static int fcgiSock = -1;

static BOOL isTerminating = NO;


void * BxMain_requestLoop(void *p)
{    
    BOOL continueRunning = YES;
    FCGX_Request request;
    if (FCGX_InitRequest(&request, fcgiSock, 0)) {
        printf("Could not initialize FastCGI request in thread %ld.\n", (long) p);
        return NULL;
    }
    
    while (continueRunning) {
        int rc = FCGX_Accept_r(&request);
        if (rc < 0) {
            printf("Error accepting FastCGI connection in thread %ld.\n", (long) p);
            return NULL;
        }
        NSAutoreleasePool *transportPool = [[NSAutoreleasePool alloc] init];
        BxTransport *transport;
        
        @try {
            transport = [[BxTransport alloc] initWithRequest:&request];
            
            NSString *requestPath = [transport.serverVars objectForKey:@"DOCUMENT_URI"]; // xxx - the starting location, this way it is relocatable
            if (_BX_urlRoot != nil) {
                if ([requestPath hasPrefix:_BX_urlRoot]) {
                    requestPath = [requestPath substringFromIndex:[_BX_urlRoot length]];
                    if ([requestPath length] == 0) {
                        requestPath = @"/";
                    } else if ([requestPath characterAtIndex:0] != '/') {
                        requestPath = [@"/" stringByAppendingString:requestPath];
                    }
                }
            }
            [transport _setRequestPath:requestPath];
            BxHandler *handler = [_BX_bxApp handlerInstanceForClassName:[_BX_bxApp handlerForPath:requestPath]];
            
            if (handler == nil) {
                [transport setHttpStatusCode:404];                
                [transport _writeHeaders];
            } else {
                [handler renderWithTransport:transport];            
                [transport _writeHeaders];
            }
            
            [transport release];        
        } @catch (id exc) {
            if (transport != nil) {
                [transport setHttpStatusCode:500];
                [transport write:@"500 Internal Server Error"];
                [transport _writeHeaders];
                [transport release];
            }
            FCGX_Finish_r(&request);
            NSLog(@"%@", exc);
            if (! isTerminating) {
                isTerminating = YES;
                [_BX_bxApp exit:YES];
                exit(1);
            }
        }
        [transportPool drain];
        FCGX_Finish_r(&request);
    }
    return NULL;
}

void sigint_handler(int signal) {
    if (isTerminating) {
        exit(0);
    } else {
        isTerminating = YES;
    }
    if (_BX_bxApp != NULL) {
        [_BX_bxApp exit:NO];
    }
    exit(0);
}

int BxMain(char *bxAppClassName) {
    if (bxAppClassName == NULL) {
        puts("NULL bxAppClassName");
        return 1;
    }
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    Class bxAppClass = NSClassFromString([NSString stringWithCString:bxAppClassName encoding:NSUTF8StringEncoding]);
    if (bxAppClass == nil) {
        printf("bxAppClassName '%s' could not be located.\n", bxAppClassName);
        return 2;
    }
    if (! [bxAppClass isSubclassOfClass:[BxApp class]]) {
        printf("'%s' is not a subclass of BxApp.\n", bxAppClassName);
        return 3;
    }
    [[NSExceptionHandler defaultExceptionHandler] setExceptionHangingMask:0];
    [[NSExceptionHandler defaultExceptionHandler] setExceptionHandlingMask:NSHandleUncaughtExceptionMask |
     NSHandleUncaughtSystemExceptionMask |
     NSHandleUncaughtRuntimeErrorMask |
     NSLogUncaughtExceptionMask |
     NSLogUncaughtSystemExceptionMask |
     NSLogUncaughtRuntimeErrorMask];
    signal(SIGINT, sigint_handler);
    
    NSUserDefaults *args = [NSUserDefaults standardUserDefaults];
    NSString *socketName = [args stringForKey:@"socket"];
    NSString *defaultDebugSocket = [NSTemporaryDirectory() stringByAppendingPathComponent:@"bombax-debug.sock"];
    if (socketName == nil) {
        puts([[NSString stringWithFormat:@"No socket was specified. Using default debug socket '%@'", defaultDebugSocket] UTF8String]);
        socketName = defaultDebugSocket;
        _BX_isDebugging = YES;
    } else if ([socketName isEqualToString:defaultDebugSocket]) {
        _BX_isDebugging = YES;
    }
    
    _BX_urlRoot = [args stringForKey:@"root"];
    
    _BX_bxApp = (BxApp *) [[bxAppClass alloc] init];
    [_BX_bxApp setup];
    BX_ERROR_DOMAIN_STRING = [@"Bombax" retain];
    
    BOOL isConfig = [args boolForKey:@"config"];
    if (isConfig) {
        [_BX_bxApp launchConfigurator];
        return 0;
    }
    int threadCount = [args integerForKey:@"threads"];
    if (threadCount == 0) {
        threadCount = 4;
    }
    
    if (FCGX_Init()) {
        puts("Could not initialize FastCGI.");
        return 5;
    }
    
    fcgiSock = FCGX_OpenSocket([socketName UTF8String], MIN(threadCount * 2, 32));
    if (fcgiSock == -1) {
        printf("Could not open socket '%s'.\n", [socketName UTF8String]);
        return 6;
    }
    
    pthread_t *threads = malloc(sizeof(pthread_t) * (threadCount - 1));
    for (long i = 1; i < threadCount; i++) {
        pthread_create(&threads[i - 1], NULL, BxMain_requestLoop, (void *) i);
    }
    BxMain_requestLoop(0);    
    
    [pool drain];
    return 0;
}


