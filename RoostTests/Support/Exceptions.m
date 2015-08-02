#import <objc/runtime.h>

#import "Exceptions.h"

RCustomExceptionHandlerType RUncaughtExceptionHandler = nil;

void exceptionHandler(NSException *exception) {
  if (RUncaughtExceptionHandler != nil) {
    RUncaughtExceptionHandler(exception);
  } else {
    [NSThread exit];
  }
}

void RSetupExceptionHandler() {
  NSSetUncaughtExceptionHandler(&exceptionHandler);
}


BOOL RTryCatch(RTryBlock try, RCatchBlock catch) {
  @try {
    try();
    return YES;
  }
  @catch (NSException *exception) {
    catch(exception);
    return NO;
  }
}


@implementation RSilentAssertionHandler

+ (void)setup
{
  NSAssertionHandler *assertionHandler = [RSilentAssertionHandler new];

  [[NSThread currentThread].threadDictionary setValue:assertionHandler
                                               forKey:NSAssertionHandlerKey];
}

- (void)handleFailureInMethod:(SEL)selector
                       object:(id)object
                         file:(NSString *)fileName
                   lineNumber:(NSInteger)line
                  description:(NSString *)format, ...
{
  // NSLog(@"NSAssert Failure: Method %@ for object %@ in %@#%i", NSStringFromSelector(selector), object, fileName, line);
  // message = [NSString stringWithFormat: @"%@:%ld Assertion failed in %@(%@), method %@. %@",
  //   fileName, line, NSStringFromClass([object class]),
  //   class_isMetaClass([object class]) ? @"class" : @"instance",
  //   NSStringFromSelector(selector), format];

  NSString *message;
  va_list ap;

  va_start(ap, format);

  [NSException raise:NSInternalInconsistencyException
              format:format
           arguments:ap];

  va_end(ap);
}

- (void)handleFailureInFunction:(NSString *)functionName
                           file:(NSString *)fileName
                     lineNumber:(NSInteger)line
                    description:(NSString *)format, ...
{
  // NSLog(@"NSCAssert Failure: Function (%@) in %@#%i", functionName, fileName, line);
  // message = [NSString stringWithFormat: @"%@:%ld Assertion failed in %@. %@", fileName, line, functionName, format];

  NSString *message;
  va_list ap;

  va_start(ap, format);

  [NSException raise:NSInternalInconsistencyException
              format:format
           arguments:ap];

  va_end(ap);
}

@end
