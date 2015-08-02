#import <Foundation/Foundation.h>

void exceptionHandler(NSException *exception) {
  [NSThread exit];
}

void setExceptionHandler() {
  NSSetUncaughtExceptionHandler(&exceptionHandler);
}
