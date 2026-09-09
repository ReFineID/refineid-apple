// Copyright 2026 Petri Koistinen. Licensed under the Apache License, Version 2.0.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs `block`, catching the Objective-C exception it may raise.
///
/// Swift cannot catch these: a raise inside Swift code terminates the
/// process. System interfaces that can raise are called through this,
/// and the raise becomes a value the caller can look at.
///
/// Returns the exception raised, or nil when the block finished.
NSException *_Nullable CardCoreCatchException(void (NS_NOESCAPE ^block)(void));

NS_ASSUME_NONNULL_END
