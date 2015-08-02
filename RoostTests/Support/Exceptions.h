#import <Foundation/Foundation.h>

// Global uncaught exception handling

typedef void (^RCustomExceptionHandlerType)(NSException*);

extern RCustomExceptionHandlerType RUncaughtExceptionHandler;

void RSetupExceptionHandler();


// Try-catch utility function

typedef void (^RTryBlock)(void);
typedef void (^RCatchBlock)(NSException*);

BOOL RTryCatch(RTryBlock, RCatchBlock);


// Silent assertion handler

@interface RSilentAssertionHandler : NSAssertionHandler

+ (void)setup;

@end
