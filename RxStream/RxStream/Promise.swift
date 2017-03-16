//
//  Promise.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/14/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public typealias PromiseTask<T> = (_ terminated: Observable<StreamState>, _ completion: (Result<T>) -> Void) -> Void

/// Internal protocol defines an object that can be canceled and/or pass the cancelation request on to the parent
protocol Cancelable : class {
  weak var cancelParent: Cancelable? { get set }
  func cancelTask()
}

protocol Retriable : class {
  weak var retryParent: Retriable? { get set }
  func retry()
}

extension Promise : Cancelable { }

public class Promise<T> : Stream<T> {
  
  /// The current task for the promise.  If there's no task, there should be a parent with a task.
  var task: PromiseTask<T>?
  
  /// The parent to handle cancelations
  weak var cancelParent: Cancelable?
  
  /// Parent, retriable stream.  Note: This creates a retain cycle.  The parent must release the child in order to unravel the cycle.  This is done with the `prune` command when the child is no longer viable.
  var retryParent: Retriable?
  
  /// Once completed, the promise shouldn't accept or process any more f
  private var complete: Bool = false
  
  private var isCancelled: Bool {
    guard case .terminated(.cancelled) = state.value else { return false }
    return true
  }
  
  /// If true, then a retry will be filled with the last completed value from this stream if it's available
  private var fillsRetry: Bool = false
  
  /**
   A Promise is initialized with the task.
   The task should call the completions handler with the result when it's done.
   The task will also be passed an observable that indicates the current stream state.  
   If the stream is terminated, the task should cancel whatever it's doing (if possible).  
   After a stream has been terminated, calling the completion handler will do nothing.
   
   - parameter task: The task that should complete the future
   
   - returns: A new Future
   */
  public init(task: @escaping PromiseTask<T>) {
    super.init()
    persist()
    self.reusable = true
    run(task: task)
  }
  
  /// Internal init for creating down stream promises
  override init() {
    super.init()
    self.reusable = true
  }
  
  /// Override the process function to ensure it can only be alled once
  override func process<U>(key: String?, prior: U?, next: Event<U>, withOp op: @escaping (U?, Event<U>, @escaping ([Event<T>]?) -> Void) -> Void) -> Bool {
    guard !complete else { return false }
    complete = true
    super.process(key: key, prior: prior, next: next, withOp: op)
    if case .next(let value) = next {
      super.process(key: key, prior: value, next: .terminate(reason: .completed), withOp: op)
    }
    
    return false
  }
  
  /// Privately used to push new events down stream
  private func push(value: Event<T>) {
    _ = self.process(key: nil, prior: nil, next: value) { (_, _, _) in }
  }
  
  /// Used to run the task
  private func run(task: @escaping PromiseTask<T>) {
    dispatch.execute {
      var complete = false
      task(self.state) { [weak self] completion in
        guard let me = self, !complete, me.isActive else { return }
        complete = true
        completion
          .onFailure{ me.push(value: .terminate(reason: .error($0))) }
          .onSuccess{ me.push(value: .next($0)) }
      }
    }
  }
  
  /// Cancel the task, if we have one, otherwise, pass the request to the parent.
  func cancelTask() {
    guard isActive else { return }
    guard task == nil else {
      push(value: .terminate(reason: .cancelled))
      return
    }
    cancelParent?.cancelTask()
  }
  
  /// A Retry will propogate up the chain, re-enabling the the parent stream(s), until it find a task to retry, where it will retry that task.
  func retry() {
    // There's two states we can retry on: error and completed.  If the state is active, then the task we want to retry is already pending.  If the state is cancelled then someone cancelled the stream and no retry is possible.
    guard !isActive && !isCancelled else { return }
    self.reactivate()
    // If complete is false, then a task is in progress and a retry is not necessary
    guard complete else { return }
    self.complete = false
    
    if fillsRetry, let value = self.last {
      self.push(value: .next(value))
    } else if let task = self.task {
      self.run(task: task)
    } else {
      self.retryParent?.retry()
    }
  }
  
  /// This will cancel the promise, including any task associated with it.  If the stream is not active, this does nothing.
  public func cancel() {
    self.cancelTask()
  }
  
  /**
   This will cause the promise to automatically fill a retry with a completed value, if any, instead of re-running the task or pushing the retry further up the chain.
   This allows you to prevent a retry from re-running the task for an error that might have been generated down stream.
   
   - note: If there is no completed value, then the Promise's task will be re-run or, if there's no task, the retry pushed up the chain.
   
   - parameter fillRetry: If `true`, completed values are used to fill a retry request instead of re-running the Promise's task (or it's parent).
   
   - returns: Self, for chaining
   */
  public func fillsRetry(_ fillsRetry: Bool = true) -> Self {
    self.fillsRetry = fillsRetry
    return self
  }
  
}
