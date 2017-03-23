//
//  Promise.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/14/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public typealias PromiseTask<T> = (_ terminated: Observable<StreamState>, _ completion: @escaping (Result<T>) -> Void) -> Void

/// Internal protocol defines an object that can be canceled and/or pass the cancelation request on to the parent
protocol Cancelable : class {
  weak var cancelParent: Cancelable? { get set }
  func cancelTask()
}

protocol Retriable : class {
  weak var retryParent: Retriable? { get set }
  func retry()
}

/**
 Type erasure base type to allow cast testing when checking down stream processors (see the `shouldPrune` for where this is used).
 */
class PromiseProcessor<T> : StreamProcessor<T> { }

/**
 Custom Processor for Promises. It's primarily used for type casting so a Promise can check the down stream type and prune if none of them are a Promise
 */
class DownstreamPromiseProcessor<T, U> : PromiseProcessor<T> {
  var stream: Stream<U>
  var processor: StreamOp<T, U>
  
  init(stream: Stream<U>, processor: @escaping StreamOp<T, U>) {
    self.stream = stream
    self.processor = processor
    stream.onTerminate = { processor(nil, .terminate(reason: $0), { _ in }) }
  }
  
  override var shouldPrune: Bool { return stream.shouldPrune }
  
  override func process(prior: T?, next: Event<T>, withKey key: String?) {
    stream.process(key: key, prior: prior, next: next, withOp: processor)
  }
  
}

extension Promise : Cancelable { }
extension Promise : Retriable { }

public class Promise<T> : Stream<T> {
  
  /// The current task for the promise.  If there's no task, there should be a parent with a task.
  let task: PromiseTask<T>?
  
  /// The parent to handle cancelations
  weak var cancelParent: Cancelable?
  
  /// Parent, retriable stream.  Note: This creates a retain cycle.  The parent must release the child in order to unravel the cycle.  This is done with the `prune` command when the child is no longer viable.
  var retryParent: Retriable?
  
  /// The promise needed to pass into the promise task.
  lazy private var stateObservable: ObservableInput<StreamState> = ObservableInput(self.state)
  
  /// Override and observe didSet to update the observable
  override public var state: StreamState {
    didSet { stateObservable.set(state) }
  }
  
  /// Once completed, the promise shouldn't accept or process any more f
  private(set) fileprivate var complete: Bool = false
  
  private var isCancelled: Bool {
    guard case .terminated(.cancelled) = state else { return false }
    return true
  }
  
  /// If true, then a retry will be filled with the last completed value from this stream if it's available
  private var fillsRetry: Bool = false
  
  /// We should only prune if the stream is complete (or no longer active), and has no down stream promises.
  override var shouldPrune: Bool {
    guard isActive else { return true }
    guard complete else { return false }
    
    // We need to prune if there are no active down stream _promises_.  Since a promise emits only one value that can be retried, we can't prune until those streams complete.
    let active = downStreams.reduce(0) { (count, processor) -> Int in
      guard !processor.shouldPrune else { return count }
      guard processor is PromiseProcessor<T> else { return count }
      return count + 1
    }
    return active < 1
  }
  
  /// The number of downStreams that are promises. Used to determine if the stream should terminate after a value has been pushed.
  private var downStreamPromises: Int {
    return downStreams.reduce(0) { (count, processor) -> Int in
      guard processor is PromiseProcessor<T> else { return count }
      return count + 1
    }
  }
  
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
    self.task = task
    super.init()
    persist()
    run(task: task)
  }
  
  /// Internal init for creating down stream promises
  override init() {
    task = nil
    super.init()
  }
  
  /// Overriden to update the complete variable
  override func preProcess<U>(event: Event<U>, withKey key: String?) -> (key: String?, event: Event<U>)? {
    guard !complete else { return nil }
    complete = true
    return (key, event)
  }
  
  /// Added logic will terminate the stream if it's not already terminated and we've received a value the stream is complete
  override func postProcess<U>(event: Event<U>, producedEvents events: [Event<T>], withTermination termination: Termination?) {
    guard termination == nil else { return }
    guard self.downStreamPromises == 0 else { return }
    
    switch event {
    case .next where self.shouldPrune:
      terminate(reason: .completed, andPrune: .upStream)
    case .error(let error) where self.shouldPrune:
      terminate(reason: .error(error), andPrune: .upStream)
    case .terminate(let reason):
      terminate(reason: reason, andPrune: .upStream)
    default: break
    }
  }
  
  /// Create a promise down stream processor if the stream is a Promise, so the termination logic works out.
  override func newDownstreamProcessor<U>(forStream stream: Stream<U>, withProcessor processor: @escaping (T?, Event<T>, @escaping ([Event<U>]?) -> Void) -> Void) -> StreamProcessor<T> {
    if let child = stream as? Promise<U> {
      child.cancelParent = self
      child.retryParent = self
      return DownstreamPromiseProcessor(stream: stream, processor: processor)
    } else {
      return super.newDownstreamProcessor(forStream: stream, withProcessor: processor)
    }
  }
  
  /// Used to run the task and process the value the task returns.
  private func run(task: @escaping PromiseTask<T>) {
    dispatch.execute {
      var complete = false
      task(self.stateObservable) { [weak self] completion in
        guard let me = self, !complete, me.isActive else { return }
        complete = true
        completion
          .onFailure{ me.process(event: .error($0)) }
          .onSuccess{ me.process(event: .next($0)) }
      }
    }
  }
  
  /// Cancel the task, if we have one, otherwise, pass the request to the parent.
  func cancelTask() {
    guard isActive else { return }
    guard task == nil else {
      process(event: .terminate(reason: .cancelled))
      return
    }
    cancelParent?.cancelTask()
  }
  
  /// A Retry will propogate up the chain, re-enabling the the parent stream(s), until it find a task to retry, where it will retry that task.
  func retry() {
    // There's two states we can retry on: error and completed.  If the state is active, then the task we want to retry is already pending.  If the state is cancelled then someone cancelled the stream and no retry is possible.
    guard !isCancelled else { return }
    // If complete is false, then a task is in progress and a retry is not necessary
    guard complete else { return }
    self.complete = false
    
    if fillsRetry, let value = self.last {
      self.process(event: .next(value))
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
