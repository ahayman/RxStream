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
public typealias FutureTask<T> = (_ completion: @escaping (Result<T>) -> Void) -> Void

public class Future<T> : Stream<T> {
  
  private var lock: Future<T>?
  private var complete: Bool = false
  
  /**
   A Future is initialized with the task.  The task should call the completions handler with the result when it's done.
   
   - parameter task: The task that should complete the future
   
   - returns: A new Future
   */
  public init(task: @escaping FutureTask<T>) {
    super.init()
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
  
  override init() { }
  
  override func preProcess<U>(event: Event<U>, withKey key: EventKey) -> (key: EventKey, event: Event<U>)? {
    guard !complete else { return nil }
    complete = true
    if case .error(let error) = event {
      // All errors terminate in a future
      return (key, .terminate(reason: .error(error)))
    }
    return (key, event)
  }
  
  override func postProcess<U>(event: Event<U>, producedEvents events: [Event<T>], withTermination termination: Termination?) {
    guard termination == nil else { return }
    self.terminate(reason: .completed, andPrune: .none)
  }
  
}
