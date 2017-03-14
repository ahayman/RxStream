//
//  Future.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/14/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public typealias FutureTask<T> = (_ completion: @escaping (Result<T>) -> Void) -> Void

public class Future<T> : Stream<T> {
  
  private var lock: Future<T>?
  private var complete: Bool = false
  
  /// Override the process function to ensure it can only be alled once
  override func process<U>(prior: U?, next: Event<U>, withOp op: @escaping (U?, Event<U>, @escaping ([Event<T>]?) -> Void) -> Void) -> Bool {
    guard !complete else { return false }
    complete = true
    super.process(prior: prior, next: next, withOp: op)
    if case .next(let value) = next {
      super.process(prior: value, next: .terminate(reason: .completed), withOp: op)
    }
    
    return false
  }
  
  /// Privately used to push new events down stream
  private func push(value: Event<T>) {
    _ = self.process(prior: nil, next: value) { (_, _, _) in }
  }
  
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
        .onFailure{ me.push(value: .terminate(reason: .error($0))) }
        .onSuccess{ me.push(value: .next($0)) }
      me.lock = nil
    }
  }
  
  override init() { }
  
}
