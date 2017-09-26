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

extension Progress : Cancelable { }
public class Progress<ProgressUnit, T> : Stream<Either<ProgressEvent<ProgressUnit>, T>> {

  public typealias Task = (inout Bool, (Either<ProgressEvent<ProgressUnit>, Result<T>>) -> Void) -> Void

  weak var cancelParent: Cancelable?
  override var streamType: StreamType { return .progress }
  private var complete = false
  /// Marked as false while auto replay is pending to prevent multiple replays
  private var autoReplayable: Bool = true
  private var task: Task?
  private var cancelled = false

  public init(task: @escaping Task) {
    super.init(op: "Task")
    var complete = false
    self.task = task
    task(&cancelled) { result in
      guard complete == false else { return }
      switch result {
      case .left(let progress):
        self.process(event: .next(.left(progress)))
      case .right(.success(let data)):
        complete = true
        self.process(event: .next(.right(data)))
      case .right(.failure(let error)):
        self.process(event: .terminate(reason: .error(error)))
      }
    }
  }

  /// Internal init for creating down streams for operations
  override init(op: String) {
    task = nil
    super.init(op: op)
  }

  /// Overridden to auto replay the progress stream result when a new stream is added
  override func didAttachStream<U>(stream: Stream<U>) {
    if !isActive && autoReplayable {
      autoReplayable = false
      Dispatch.after(delay: 0.01, on: .main).execute {
        self.autoReplayable = true
        self.replay()
      }
    }
  }

  override func preProcess<U>(event: Event<U>) -> Event<U>? {
    // Terminations are always processed.
    if case .terminate(reason: .cancelled) = event { cancelled = true }
    if case .terminate = event {
      self.task = nil
      return event
    }
    guard !complete else { return nil }
    if case .error(let error) = event {
      // All errors terminate in a progress
      self.task = nil
      return .terminate(reason: .error(error))
    }
    return event
  }

  override func postProcess<U>(event: Event<U>, producedSignal signal: OpSignal<Either<ProgressEvent<ProgressUnit>, T>>) {
    switch signal {
    case .push(let value):
      // Note: A Progress should never receive a "flatten".  All operations that use "flatten" convert into a different stream type.
      // For this reason, we only check "value" type for a data return to terminate.
      if case .value(.right) = value, self.isActive && pendingTermination == nil {
        complete = true
        terminate(reason: .completed, andPrune: .none, pushDownstreamTo: StreamType.all().removing([.promise, .future, .progress]))
        self.task = nil
      }
    case .error:
      if self.isActive && pendingTermination == nil {
        terminate(reason: .completed, andPrune: .none, pushDownstreamTo: StreamType.all().removing([.promise, .future, .progress]))
        self.task = nil
      }
    case .cancel:
      if self.isActive && pendingTermination == nil {
        terminate(reason: .completed, andPrune: .none, pushDownstreamTo: StreamType.all())
        self.task = nil
      }
    case .merging:
      complete = false
    default: break
    }
  }

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

}
