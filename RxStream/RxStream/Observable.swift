//
//  Observable.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/10/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public class Observable<T> : Hot<T> {
  
  private func push(event: Event<T>) {
    self.process(prior: nil, next: event) { (_, event, completion) in
      completion([event])
    }
  }
  
  fileprivate(set) public var value: T {
    didSet { push(event: .next(value)) }
  }
  
  public init(value: T) {
    self.value = value
  }
  
}

public class ObservableInput<T> : Observable<T> {
  
  @discardableResult public func set(_ value: T) -> Self {
    self.value = value
    return self
  }
  
}
