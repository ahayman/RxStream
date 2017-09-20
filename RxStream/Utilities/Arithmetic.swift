//
//  Arithmetic.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/9/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public protocol Arithmetic {
  static func +(lhs: Self, rhs: Self) -> Self
  static func -(lhs: Self, rhs: Self) -> Self
  static func *(lhs: Self, rhs: Self) -> Self
  static func /(lhs: Self, rhs: Self) -> Self
  static func %(lhs: Self, rhs: Self) -> Self
  init(_ double: Double)
  init(_ int: Int)
  init(_ uint: UInt)
  init(_ float: Float)
}

extension Int : Arithmetic { }
extension Int8 : Arithmetic { }
extension Int16 : Arithmetic { }
extension Int32 : Arithmetic { }
extension Int64 : Arithmetic { }

extension UInt : Arithmetic { }
extension UInt8 : Arithmetic { }
extension UInt16 : Arithmetic { }
extension UInt32 : Arithmetic { }
extension UInt64 : Arithmetic { }

public func %(lhs: Float, rhs: Float) -> Float {
  return lhs.truncatingRemainder(dividingBy: rhs)
}
extension Float : Arithmetic { }

public func %(lhs: Double, rhs: Double) -> Double {
  return lhs.truncatingRemainder(dividingBy: rhs)
}
extension Double : Arithmetic { }
