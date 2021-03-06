//
//  Promise.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/14/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public typealias PromiseTask<T> = (_ terminated: Observable<StreamState>, _ completion: @escaping (Result<T>) -> Void) -> Void

extension Promise : Cancelable { }
extension Promise : Retriable { }

public class Promise<T> : Stream<T> {

  override var streamType: StreamType { return .promise }
  
  /// The current task for the promise.  If there's no task, there should be a parent with a task.
  let task: PromiseTask<T>?
  
  /// The parent to handle cancellations
  weak var cancelParent: Cancelable?
  
  /// Parent, retriable stream.  Note: This creates a retain cycle.  The parent must release the child in order to unravel the cycle.  This is done with the `prune` command when the child is no longer viable.
  var retryParent: Retriable?

  /// Marked as false while auto replay is pending to prevent multiple replays
  private var autoReplayable: Bool = true

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
  private var reuse: Bool = false
  
  /// We should only prune if the stream is complete (or no longer active), and has no down stream promises.
  override var shouldPrune: Bool {
    guard isActive else { return true }
    guard complete else { return false }
    
    // We need to prune if there are no active down stream _promises_.  Since a promise emits only one value that can be retried, we can't prune until those streams complete.
    let active = downStreams.reduce(0) { (count, processor) -> Int in
      guard !processor.stream.shouldPrune else { return count }
      guard processor.stream.streamType == .promise else { return count }
      return count + 1
    }
    return active < 1
  }
  
  /// The number of downStreams that are promises. Used to determine if the stream should terminate after a value has been pushed.
  private var downStreamPromises: Int {
    return downStreams.reduce(0) { (count, processor) -> Int in
      guard processor.stream.streamType == .promise else { return count }
      return count + 1
    }
  }
  
  /**
   A Promise is initialized with the task.
   The task should call the completions handler with the result when it's done.
   The task will also be passed an observable that indicates the current stream state.
   If the stream is terminated, the task should cancel whatever it's doing (if possible).
   After a stream has been terminated, calling the completion handler will do nothing.
   
   - parameter task: The task that should complete the Promise
   - parameter dispatch: (Optional) set the dispatch the task is to run on.
   
   - returns: A new Promise
   */
  public init(dispatch: Dispatch? = nil, task: @escaping PromiseTask<T>) {
    self.task = task
    super.init(op: "Task")
    self.dispatch = dispatch
    persist()
    run(task: task)
  }
  
  /// Internal init for creating down stream promises
  override init(op: String) {
    task = nil
    super.init(op: op)
  }

  /// Overridden to auto replay the Promise stream result when a new stream is added
  override func didAttachStream<U>(stream: Stream<U>) {
    if !isActive && autoReplayable {
      autoReplayable = false
      Dispatch.after(delay: 0.01, on: .main).execute {
        self.autoReplayable = true
        self.replay()
      }
    }
  }


  /// Overridden to update the complete variable
  override func preProcess<U>(event: Event<U>) -> Event<U>? {
    guard !complete else { return nil }
    complete = true
    return event
  }
  
  /// Added logic will terminate the stream if it's not already terminated and we've received a value the stream is complete
  override func postProcess<U>(event: Event<U>, producedSignal signal: OpSignal<T>) {
    if case .merging = signal {
      complete = false
    }
    guard self.downStreamPromises == 0 else { return }
    
    switch signal {
    case .push where self.shouldPrune:
      terminate(reason: .completed, andPrune: .upStream, pushDownstreamTo: StreamType.all().removing([.promise, .future]))
    case .error(let error) where self.shouldPrune:
      terminate(reason: .error(error), andPrune: .upStream, pushDownstreamTo: StreamType.all().removing([.promise, .future]))
    case .terminate(_, let reason):
      terminate(reason: reason, andPrune: .upStream, pushDownstreamTo: StreamType.all().removing([.promise, .future]))
    default: break
    }
  }
  
  /// Used to run the task and process the value the task returns.
  private func run(task: @escaping PromiseTask<T>) {
    let work = {
      var complete = false
      task(self.stateObservable) { [weak self] completion in
        guard let me = self, !complete, me.isActive else { return }
        complete = true
        completion
          .onFailure{ me.process(event: .error($0)) }
          .onSuccess{ me.process(event: .next($0)) }
      }
    }

    if let dispatch = self.dispatch {
      dispatch.execute(work)
    } else {
      work()
    }
  }
  
  /// Cancel the task, if we have one, otherwise, pass the request to the parent.
  func cancelTask() {
    guard isActive else { return }
    guard task == nil else { return process(event: .terminate(reason: .cancelled)) }
    guard let parent = cancelParent else { return process(event: .terminate(reason: .cancelled)) }
    parent.cancelTask()
  }
  
  /// A Retry will propagate up the chain, re-enabling the the parent stream(s), until it find a task to retry, where it will retry that task.
  func retry() {
    // There's two states we can retry on: error and completed.  If the state is active, then the task we want to retry is already pending.  If the state is cancelled then someone cancelled the stream and no retry is possible.
    guard !isCancelled else { return }
    // If complete is false, then a task is in progress and a retry is not necessary
    guard complete else { return }
    self.complete = false
    
    if reuse, let values = self.current {
      for value in values {
        self.process(event: .next(value))
      }
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
   This will cause the promise to automatically reuse a valid value when retrying, if any, instead of re-running the task or pushing the retry further up the chain.
   This allows you to prevent a retry from re-running the task for an error that might have been generated down stream.
   
   - note: If there is no completed value, then the Promise's task will be re-run or, if there's no task, the retry pushed up the chain.
   
   - parameter reuse: If `true`, completed values are used to fill a retry request instead of re-running the Promise's task (or it's parent).
   
   - returns: Self, for chaining
   */
  public func reuse(_ reuse: Bool = true) -> Self {
    self.reuse = reuse
    return self
  }

}
