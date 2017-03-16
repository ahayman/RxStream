//
//  Hot.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/8/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public class Hot<T> : Stream<T> {
  
  fileprivate func push(event: Event<T>) {
    self.process(key: nil, prior: nil, next: event) { (_, event, completion) in
      completion([event])
    }
  }
  
}

public class HotInput<T> : Hot<T> {
  
  public func terminateWith(reason: Termination) {
    self.push(event: .terminate(reason: reason))
  }
  
  public func push(_ value: T) {
    self.push(event: .next(value))
  }
  
}

public typealias HotTask<T> = ((Event<T>) -> Void) -> Void

public class HotProducer<T> : Hot<T> {
  
  private let task: HotTask<T>
  
  public init(task: @escaping HotTask<T>) {
    self.task = task
    super.init()
    self.task { [weak self] event in
      self?.push(event: event)
    }
  }
  
}
