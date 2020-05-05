//
//  Operators.swift
//  RxStream iOS
//
//  Created by Aaron Hayman on 5/5/20.
//  Copyright © 2020 Aaron Hayman. All rights reserved.
//

import Foundation

import Foundation

/**
 Convenience operators for Rx
 */

infix operator <- : AssignmentPrecedence

@discardableResult public func <- <T>(left: ObservableInput<T>, right: T) -> T {
  left.set(right)
  return right
}

@discardableResult public func <- <T>(left: HotInput<T>, right: T) -> T {
  left.push(right)
  return right
}

public func == <T: Equatable>(left: Observable<T>, right: T) -> Bool {
  return left.value == right
}

public func == <T: Equatable>(left: T, right: Observable<T>) -> Bool {
  return left == right.value
}

public func != <T: Equatable>(left: Observable<T>, right: T) -> Bool {
  return left.value != right
}

public func != <T: Equatable>(left: T, right: Observable<T>) -> Bool {
  return left != right.value
}

@discardableResult public func <- <T>(left: HotWrap<T>, right: T) -> T {
  left.push(value: right)
  return right
}

@discardableResult public func <- <T>(left: ObservableWrap<T>, right: T) -> T {
  left.push(value: right)
  return right
}
