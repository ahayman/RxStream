//
//  Either.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/9/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public enum Either<Left, Right> {
  case left(Left)
  case right(Right)
  
  /// Convenient Initializer: Initialize with value and the Enum will choose the appropriate case for it.
  public init(_ value: Left) {
    self = .left(value)
  }
  
  /// Convenient Initializer: Initialize with value and the Enum will choose the appropriate case for it.
  public init(_ value: Right) {
    self = .right(value)
  }
  
  /// Use this to execute a handler that will only run if the enum is .success.  Returns `self` for chaining.
  @discardableResult public func onLeft(_ handler: (Left) -> Void) -> Either<Left, Right> {
    switch self {
    case let .left(value): handler(value)
    default: break
    }
    return self
  }
  
  /// Use this to execute a handler that will only run if the enum is .failure.  Returns `self` for chaining.
  @discardableResult public func onRight(_ handler: (Right) -> Void) -> Either<Left, Right> {
    switch self {
    case let .right(value): handler(value)
    default: break
    }
    return self
  }
  
}
