//
//  Future.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/14/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
 A Future Task is a closure that takes a completion handler.
 The closure is called to begin the task and the completion handler should be called with the result when the task has completed.
 */
public class Future<T> : Stream<T> {
  public typealias Task<T> = (_ completion: @escaping (Result<T>) -> Void) -> Void

  override var streamType: StreamType { return .future }

  private var lock: Future<T>?
  private var complete: Bool = false

  // A Future will always replay it's value into new streams because there is ever only 1 value.
  override var replay: Bool {
    get { return true }
    set { }
  }

  /// Allows for the creation of a `Future` that already has a value filled.
  public class func completed(_ value: T) -> Future<T> {
    let future = Future<T>(op: "CompletedValue")
    future.process(event: .next(value))
    return future
  }
  
  /// Allows for the creation of a `Future` that already has an error filled.
  public class func completed(_ error: Error) -> Future<T> {
    let future = Future<T>(op: "CompletedError")
    future.process(event: .error(error))
    return future
  }
  
  /**
   A Future is initialized with the task.  The task should call the completions handler with the result when it's done.
   
   - parameter task: The task that should complete the future
   
   - returns: A new Future
   */
  public init(task: @escaping Task<T>) {
    super.init(op: "Task")
    persist()
    self.lock = self
    var complete = false
    task { [weak self] completion in
      guard let me = self, !complete else { return }
      complete = true
      completion
        .onFailure{ me.process(event: .error($0)) }
        .onSuccess{ me.process(event: .next($0)) }
      me.lock = nil
    }
  }
  
  override init(op: String) {
    super.init(op: op)
  }

  override func preProcess<U>(event: Event<U>, withKey key: EventKey) -> (key: EventKey, event: Event<U>)? {
    // Terminations are always processed.
    if case .terminate = event {
      return (key: key, event: event)
    }
    guard !complete else { return nil }
    complete = true
    if case .error(let error) = event {
      // All errors terminate in a future
      return (key, .terminate(reason: .error(error)))
    }
    return (key, event)
  }
  
  override func postProcess<U>(event: Event<U>, withKey: EventKey, producedSignal signal: OpSignal<T>) {
    switch signal {
    case .push, .error:
      if self.isActive && pendingTermination == nil {
        self.terminate(reason: .completed, andPrune: .none, pushDownstreamTo: StreamType.all().removing([.promise, .future]))
      }
    case .cancel:
      if self.isActive && pendingTermination == nil {
        self.terminate(reason: .completed, andPrune: .none, pushDownstreamTo: StreamType.all())
      }
    case .merging:
      complete = false
    default: break
    }
  }
  
}

/**
 A Future Input is a type of future where the Future can be filled externally instead of inside an attached Task.
 Mostly, this is useful for semantics, where the task in question doesn't easily fit inside a closure.
 Because the Future isn't tied to a task, it's possible for it to deinit before being filled.  
 In that case, the Future will emit a `.cancelled` termination event.
 */
public class FutureInput<T> : Future<T> {
  
  /**
   Initialization of a Future Input requires no parameters, but may require type information.
   After initializing, the Future should be completed by calling  the `complete` func with a value or an error.
   */
  public init() {
    super.init(op: "Input")
  }
  
  /**
   This will complete the future with the provided value.
   After passing this value, no other values or errors can be passed in.
   
   - parameter value: The value to complete the future with.
   */
  public func complete(_ value: T) {
    self.process(event: .next(value))
  }
  
  /**
   This will complete the future with the provided error.
   After passing this error, no other values or errors can be passed in.
   
   - parameter error: The error to complete the future with.
   */
  public func complete(_ error: Error) {
    self.process(event: .terminate(reason: .error(error)))
  }
  
  deinit {
    self.process(event: .terminate(reason: .cancelled))
  }
  
}
