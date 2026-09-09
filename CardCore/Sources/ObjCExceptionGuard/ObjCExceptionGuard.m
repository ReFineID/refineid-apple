// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#import "ObjCExceptionGuard.h"

NSException *_Nullable CardCoreCatchException(void (NS_NOESCAPE ^block)(void)) {
  @try {
    block();
  } @catch (NSException *exception) {
    return exception;
  }
  return nil;
}
