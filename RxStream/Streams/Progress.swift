//
//  Progress.swift
//  RxStream iOS
//
//  Created by Aaron Hayman on 9/25/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public struct ProgressEvent<T> {
  public let title: String
  public let unitName: String
  public let current: T
  public let total: T
}

/// Use to detect the presence of a Progress stream down stream and pass it a progress event.
protocol ProgressStream {
  func processProgressEvent<Unit>(_ event: ProgressEvent<Unit>)
}

extension Progress : Cancelable { }
extension Progress : ProgressStream { }

/**
  A Progress stream is a type of Future that allows the client to observe the progress of the task while waiting for the task to complete.
  The most obvious and common use case for this is to update a Progress Indicator in the UI while waiting for something to complete/download/process/etc.

  At it's core, the Progress stream replaces the standard two handler function signature with a single return value.  For example, this:

      func downloadImage(at url: URL, progressHandler: ((Progress) -> Void)?, completion: (URL) -> Void)

  can be replaced with:

      func downloadImage(at url: URL) -> Progress<Double, URL>

  The client can then choose to observe the progress on their own terms:

      downloadImage(at: someURL)
         .onProgress{ p in self.updateUIWith(progress: p) }
         .on{ url in self.handleDownloadedImage(at: url) }

  Warning: Unless the Stream is cancelled, the task should _always_ return a result.  Otherwise, both the task and the stream will be leaked in memory.
*/
public class Progress<ProgressUnit, T> : Future<T> {

  /**
    When creating a Progress stream, you'll need to pass in the task closure that both updates the progress _and_ submits the final value when completed.
    The closure takes two arguments:

      - parameter cancelled: a reference Boolean value that indicates whether the task has been cancelled.
        If possible, the task should cancel and clean up.  Any further attempts to call the handler will be ignored.
      - parameter resultHandler: This is an embedded closure that takes either a ProgressEvent or a Result.
        If a progress event is passed in, the stream will be updated with the current progress.  If a Result is passed in,
        the stream will complete with the Result and terminate.
  */
  public typealias ProgressTask = (inout Bool, (Either<ProgressEvent<ProgressUnit>, Result<T>>) -> Void) -> Void

  /**
    The progress mapper should map a progress event to the this streams ProgressUnit type.
    In order to work with Swift's type system, the argument type is `Any` to get around the type system.
    However, since this is only assigned from within this module, it should always be consistent if I've done everything correctly.
  */
  internal var progressMapper: ((Any) -> ProgressEvent<ProgressUnit>?)?

  /// On handler for progress events.  Since we're not using the standard "piping" in the Stream, we've gotta keep an explicit reference.
  internal var onHandler: ((ProgressEvent<ProgressUnit>) -> Void)?

  /// Satisfied the Cancelable protocol to allow a stream to be cancelled.
  weak var cancelParent: Cancelable?

  /**
    The task associated with this stream.
    Note: The task is strongly referenced and within that is a closure that strongly references this class.
    This created a memory lock on the stream so long as the task is active.
  */
  private var task: ProgressTask?

  /// We keep a separate cancelled variable here so we can pass it into the task as an inout reference.
  private var cancelled = false

  /**
  Initialize a Progress with a Task.  The task should be use to:
   - Pass updates regarding the progress of the task.
   - Monitor the cancelled boolean status and clean up if the flag is marked `true`
   - Pass the Result when the task has completed or encountered an error.

  Note: The task will be called immediately on instantiation.

   - parameter task: A ProgressTask used to perform the task, update progress, and return the Result.
   - return: A new Progress Stream
  */
  public init(task: @escaping ProgressTask) {
    super.init(op: "Task")
    var complete = false
    self.task = task
    task(&cancelled) { result in
      guard complete == false && self.isActive else { return }
      switch result {
      case .left(let progress):
        self.processProgressEvent(progress)
      case .right(.success(let data)):
        complete = true
        self.process(event: .next(data))
      case .right(.failure(let error)):
        complete = true
        self.process(event: .terminate(reason: .error(error)))
      }
    }
  }

  /// Internal init for creating down streams for operations
  override init(op: String) {
    task = nil
    super.init(op: op)
  }

  /// If we have a handler or mapper, then those should use the dispatcher and the stream op should only be a passthrough.
  override func shouldDispatch<U>(event: Event<U>) -> Bool {
    return onHandler == nil && progressMapper == nil
  }

  /// If we have a handler or mapper, then those should use the throttle and the stream op should only be a passthrough.
  override func shouldThrottle<U>(event: Event<U>) -> Bool {
    return onHandler == nil && progressMapper == nil
  }

  /// We need to handle cancelled and terminate events properly to ensure we release the lock and mark the stream cancelled for the task.
  override func preProcess<U>(event: Event<U>) -> Event<U>? {
    // Terminations are always processed.
    switch event {
    case .terminate(.cancelled): cancelled = true; fallthrough
    case .terminate, .error: self.task = nil
    default: break
    }
    return super.preProcess(event: event)
  }

  /// Used to detect when we should remove the task to release the memory lock
  override func postProcess<U>(event: Event<U>, producedSignal signal: OpSignal<T>) {
    switch signal {
    case .push, .error, .cancel: self.task = nil
    default: break
    }
    super.postProcess(event: event, producedSignal: signal)
  }

  /// Part of the Cancelable protocol, we either cancel the task or pass the cancellation to the parent.
  func cancelTask() {
    guard isActive else { return }
    guard task == nil else { return process(event: .terminate(reason: .cancelled)) }
    guard let parent = cancelParent else { return process(event: .terminate(reason: .cancelled)) }
    parent.cancelTask()
  }

  /**
  This will cancel the stream.  It will travel up stream until it reaches the task that is performing the operation.
  A flag is passed into that task, indicating that the stream has been cancelled.  While the stream itself is guaranteed
  to be cancelled (an no further events propagated), the task itself may or may not cancel, depending on whether it is watching
  that flag.
  */
  public func cancel() {
    cancelTask()
  }

  /**
    Despite it's length, all of the work is done primarily in the `work` closure, where we map the progress event, call the handler,
    and pass the event downstream. Pretty much everything else iterates the variations needed to use dispatch and throttle.
  */
  func processProgressEvent<Unit>(_ event: ProgressEvent<Unit>) {

    /// Convenience function to map a progress event or return the current event if it's type signature matches this instance.
    func mapProgressEvent<U>(_ event: ProgressEvent<U>) -> ProgressEvent<ProgressUnit>? {
      return progressMapper?(event) ?? event as? ProgressEvent<ProgressUnit>
    }

    let work = {
      guard let pEvent = mapProgressEvent(event) else { return }
      self.onHandler?(pEvent)
      for stream in self.downStreams.oMap({ $0.stream as? ProgressStream }) {
        stream.processProgressEvent(pEvent)
      }
    }

    switch (self.throttle, self.dispatch) {
    case let (.some(throttle), .some(dispatch)):
      throttle.process { signal in
        switch signal {
        case .cancel: return
        case let .perform(completion):
          dispatch.execute {
            work()
            completion()
          }
        }
      }
    case let (.some(throttle), .none):
      throttle.process { signal in
        switch signal {
        case .cancel: return
        case let .perform(completion):
          work()
          completion()
        }
      }
    case let (.none, .some(dispatch)):
      dispatch.execute(work)
    case (.none, .none):
      work()
    }
  }

}
