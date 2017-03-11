//
//  Hot.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/8/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public class Hot<T> : Stream<T> { }

class HotInput<T> : Hot<T> {
  
  private func push(event: Event<T>) {
    self.process(prior: nil, next: event) { (_, event, completion) in
      completion([event])
    }
  }
  
  public func push(_ value: T) {
    self.push(event: .next(value))
  }
  
  public func terminateWith(reason: Termination) {
    self.push(event: .terminate(reason: reason))
  }
  
}
