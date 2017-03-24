//
//  Functional.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/7/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
This is takes a value on the left and transforms it using the function on the right if the left value exists. This allows you to chain conditional transforms together and return it's result in a single line, avoiding excessive nesting or parenthesis.
*/
@discardableResult func >>? <From, To> (from: From?, transform: (From) throws -> To?) rethrows -> To? {
  if let value = from {
    return try transform(value)
  }
  return nil
}
infix operator >>? : LogicalConjunctionPrecedence
