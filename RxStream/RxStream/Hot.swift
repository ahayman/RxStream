//
//  Hot.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/8/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
 A Hot stream is a type of stream that will continually push events without regard to who is subscribing.
 */
public class Hot<T> : Stream<T> {
  
  /// Conveniene function for pushing into the stream.
  fileprivate func push(event: Event<T>) {
    self.process(key: nil, prior: nil, next: event) { (_, event, completion) in
      completion([event])
    }
  }
  
}

/**
 A HotInput allows inputs to be pushed into the hot stream.
 */
public class HotInput<T> : Hot<T> {
  
  /// Public initialize to create a new HotInput.
  public override init() {
    super.init()
  }
  
  /// Terminate the Hot Stream with a reason.
  public func terminateWith(reason: Termination) {
    self.push(event: .terminate(reason: reason))
  }
  
  /// Push a new event into the hot stream.
  public func push(_ value: T) {
    self.push(event: .next(value))
  }
  
  /// Push a non-terminating error into the hot stream.
  public func push(_ error: Error) {
    self.push(event: .error(error))
  }
  
}

public typealias HotTask<T> = ((Event<T>) -> Void) -> Void

/**
 A HotProducer takes a task that generates events to push into the hot stream.
 */
public class HotProducer<T> : Hot<T> {
  
  private let task: HotTask<T>
  
  /**
   Initialize a a new HotProducer with a task that generates events.
   
   - parameter task: The task is takes a closure that can be used to generate new events by calling the completion handler.
   
   - returns: A new HotProducer
   */
  public init(task: @escaping HotTask<T>) {
    self.task = task
    super.init()
    self.task { [weak self] event in
      self?.push(event: event)
    }
  }
  
}
