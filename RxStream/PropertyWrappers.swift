//
//  PropertyWrappers.swift
//  RxStream
//
//  Created by Aaron Hayman on 5/5/20.
//  Copyright © 2020 Aaron Hayman. All rights reserved.
//

import Foundation

@propertyWrapper public struct HotWrap<T> {
  private let input: HotInput<T>
  
  public var wrappedValue: Hot<T> {
    return input
  }
  
  public init() {
    input = HotInput().persist()
  }
  
  public func push(value: T) {
    input.push(value)
  }
  
  public func push(error: Error) {
    input.push(error)
  }
  
}

@propertyWrapper public struct ObservableWrap<T> {
  private let input: ObservableInput<T>
  
  public var wrappedValue: Observable<T> {
    return input
  }
  
  public init(_ value: T) {
    input = ObservableInput(value).persist()
  }
  
  public func push(value: T) {
    input.set(value)
  }
  
  public func push(error: Error) {
    input.push(error: error)
  }
  
}
