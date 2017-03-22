//
//  Result.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/8/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
 Result is a function construct usefull when retrieving some kind of information that can fail.
 Frequently, it's used in places where using `throw` doesn't make sense, like data that is returned asynchronously.
 */
public enum Result<Value> {
  /// The success case, containing the result value
  case success(Value)
  /// The failure case, containing an error.
  case failure(Error)
  
  /// This allows you to retrieve that value using in using a normal throwing function.
  public func value() throws -> Value {
    switch self {
    case let .success(value): return value
    case let .failure(error): throw error
    }
  }
  
  /// Use this to execute a handler that will only run if the enum is .success.  Returns `self` for chaining.
  @discardableResult public func onSuccess(_ handler: (Value) -> Void) -> Result<Value> {
    switch self {
    case let .success(value): handler(value)
    default: break
    }
    return self
  }
  
  /// Use this to execute a handler that will only run if the enum is .failure.  Returns `self` for chaining.
  @discardableResult public func onFailure(_ handler: (Error) -> Void) -> Result<Value> {
    switch self {
    case let .failure(error): handler(error)
    default: break
    }
    return self
  }
  
}
