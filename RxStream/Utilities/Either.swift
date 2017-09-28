//
//  Either.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/9/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
  Either serves as a functional construct to represent a variable that can be _either_ one value or another (Either Left or Right).
  It includes convenience initializer and accessors, along with closures that can be used to execute code
  depending on the value represent by Either.
*/
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
  
  /// Returns the left value, if the Either contains one
  public var left: Left? {
    guard case let .left(value) = self else { return nil }
    return value
  }
  
  /// Returns the right value, if the Either contains one
  public var right: Right? {
    guard case let .right(value) = self else { return nil }
    return value
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


/**
  EitherAnd is a specialized version of Either that can represent either value separately or _both_ values at once.
  EitherAnd can be useful if you need to provide both values but do not know which values are coming in which order.
  It solves the problem inherent in trying to represent two optional values, ( `(Left?, Right?)` ) when you know
  you will have one or another, but never none at all.
*/
public enum EitherAnd<Left, Right> {
  case left(Left)
  case right(Right)
  case both(Left, Right)

  /// Convenient Initializer: Initialize with value and the Enum will choose the appropriate case for it.
  public init(_ value: Left) {
    self = .left(value)
  }

  /// Convenient Initializer: Initialize with value and the Enum will choose the appropriate case for it.
  public init(_ value: Right) {
    self = .right(value)
  }

  public init(_ left: Left, _ right: Right) {
    self = .both(left, right)
  }

  /// Returns the left value, if the Either contains one
  public var left: Left? {
    switch self {
    case let .left(value): return value
    case let .both(value, _): return value
    default: return nil
    }
  }

  /// Returns the right value, if the Either contains one
  public var right: Right? {
    switch self {
    case let .right(value): return value
    case let .both(_, value): return value
    default: return nil
    }
  }

  public var both: (Left, Right)? {
    switch self {
    case let .both(left, right): return (left, right)
    default: return nil
    }
  }

  /// Use this to execute a handler that will only run if the enum is .success.  Returns `self` for chaining.
  @discardableResult public func onLeft(_ handler: (Left) -> Void) -> EitherAnd<Left, Right> {
    switch self {
    case let .left(value): handler(value)
    default: break
    }
    return self
  }

  /// Use this to execute a handler that will only run if the enum is .failure.  Returns `self` for chaining.
  @discardableResult public func onRight(_ handler: (Right) -> Void) -> EitherAnd<Left, Right> {
    switch self {
    case let .right(value): handler(value)
    default: break
    }
    return self
  }

  @discardableResult public func onBoth(_ handler: (Left, Right) -> Void) -> EitherAnd<Left, Right> {
    switch self {
    case let .both(left, right): handler(left, right)
    default: break
    }
    return self
  }

}

