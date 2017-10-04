//
//  Progression.swift
//  RxStream iOS
//
//  Created by Aaron Hayman on 9/25/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
  A ProgressEvent represents the current progress for a task.
*/
public struct ProgressEvent<T> {
  // The title should be a user friendly, short stream describing the task.
  public let title: String
  // The unit name should describe the progress units. Example: 'mb', '%', etc
  public let unitName: String
  // The current progress.
  public var current: T
  // The total expected progress.
  public let total: T
}

/// Use to detect the presence of a Progression stream down stream and pass it a progress event.
protocol ProgressStream {
  func processProgressEvent<Unit>(_ event: ProgressEvent<Unit>)
}
extension Progression: ProgressStream { }

/// Progression streams are cancelable.
extension Progression: Cancelable { }

/**
  A Progression stream is a type of Future that allows the client to observe the progress of the task while waiting for the task to complete.
  The most obvious and common use case for this is to update a Progression Indicator in the UI while waiting for something to complete/download/process/etc.

  At it's core, the Progression stream replaces the standard two handler function signature with a single return value.  For example, this:

      func downloadImage(at url: URL, progressHandler: ((Progression) -> Void)?, completion: (URL) -> Void)

  can be replaced with:

      func downloadImage(at url: URL) -> Progression<Double, URL>

  The client can then choose to observe the progress on their own terms:

      downloadImage(at: someURL)
         .onProgress{ p in self.updateUIWith(progress: p) }
         .on{ url in self.handleDownloadedImage(at: url) }

  Warning: Unless the Stream is cancelled, the task should _always_ return a result.  Otherwise, both the task and the stream will be leaked in memory.
*/
public class Progression<ProgressUnit, T> : Future<T> {

  /**
    When creating a Progression stream, you'll need to pass in the task closure that both updates the progress _and_ submits the final value when completed.
    The closure takes two arguments:

      - parameter cancelled: a reference Boolean value that indicates whether the task has been cancelled.
        If possible, the task should cancel and clean up.  Any further attempts to call the handler will be ignored.
      - parameter resultHandler: This is an embedded closure that takes either a ProgressEvent or a Result.
        If a progress event is passed in, the stream will be updated with the current progress.  If a Result is passed in,
        the stream will complete with the Result and terminate.
  */
  public typealias ProgressTask = (_ cancelled: Box<Bool>, _ result: @escaping (Either<ProgressEvent<ProgressUnit>, Result<T>>) -> Void) -> Void

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
  private var cancelled = Box(false)

  // MARK: Initializers

  /**
  Initialize a Progression with a Task.  The task should be use to:
   - Pass updates regarding the progress of the task.
   - Monitor the cancelled boolean status and clean up if the flag is marked `true`
   - Pass the Result when the task has completed or encountered an error.

  Note: The task will be called immediately on instantiation.

   - parameter task: A ProgressTask used to perform the task, update progress, and return the Result.
   - return: A new Progression Stream
  */
  public init(task: @escaping ProgressTask) {
    super.init(op: "Task")
    var complete = false
    self.task = task
    task(cancelled) { result in
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

  // MARK: Overrides

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
    case .terminate(.cancelled): cancelled.value = true; fallthrough
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

  // MARK: Cancellation

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

  // MARK: Processing

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

  // MARK: Progress Operations

  /**
    ## Branching

    Attache a simple handler to observe when new Progression Events are emitted.

    - parameter handler: The handler takes a ProgressEvent and returns `Void`.  A new event will be emitted whenever the progress is updated from the task.

    - returns: A new Progression Stream of the same type.

    - warning: There is no guarantee the handler will be called on the main thread unless you specify the appropriate dispatch.  This is an important
    consideration if you are attempting to update a UI from the handler.
  */
  @discardableResult public func onProgress(_ handler: @escaping (ProgressEvent<ProgressUnit>) -> Void) -> Progression<ProgressUnit, T> {
    let stream = append(stream: Progression<ProgressUnit, T>(op: "onProgress")) { (event, completion) in completion(event.signal) }
    stream.onHandler = handler
    return stream
  }

  /**
    ## Branching

    This will map the progress events of this stream to a new progress event type.
    It does not map the final emitted value of the stream.

    - parameter mapper: Handler should take a progress event and map it to the new type.

    - returns: a new Progression Stream with the new ProgressEvent type.
  */
  @discardableResult public func mapProgress<U>(_ mapper: @escaping (ProgressEvent<ProgressUnit>) -> ProgressEvent<U>) -> Progression<U, T> {
    let stream = append(stream: Progression<U, T>(op: "onProgress")) { (event: Event<T>, completion: @escaping (OpSignal<T>) -> Void) in completion(event.signal) }
    stream.progressMapper = { event in
      guard let event = event as? ProgressEvent<ProgressUnit> else { return nil }
      return mapper(event)
    }
    return stream
  }


  /**
   ## Branching

   Merge another Progression stream into this one, emitting the completed values from each string as a single tuple.

   Requires that you also map the progress events of each stream into a new progress event.  In most situations,
   the progress emitted from the mapper should be _additive_, that is, taking the current progress and totals
   of each event and adding them together to produce a total of both.  Of course, you are able to do whatever
   is appropriate for the situation.

   - parameter stream: The stream to combine into this one.
   - parameter progressMapper: Maps the progress of one or both streams into a new progress event.

   - returns: A new Progression Stream
   */
  @discardableResult public func combineProgress<U, R, P>(
    stream: Progression<R, U>,
    progressMapper mapper: @escaping (EitherAnd<ProgressEvent<ProgressUnit>, ProgressEvent<R>>)
    -> ProgressEvent<P>) -> Progression<P, (T, U)>
  {
    let combined = appendCombine(stream: stream, intoStream: Progression<P, (T, U)>(op: "combine(stream: \(stream))"), latest: true)
    var left: ProgressEvent<ProgressUnit>? = nil
    var right: ProgressEvent<R>? = nil

    self.onHandler = { left = $0 }
    stream.onHandler = { right = $0 }

    combined.progressMapper = { event in
      switch (event, left, right) {
      case let (left as ProgressEvent<ProgressUnit>, _, .some(right)): return mapper(.both(left, right))
      case let (right as ProgressEvent<R>, .some(left), _): return mapper(.both(left, right))
      case let (left as ProgressEvent<ProgressUnit>, _, .none): return mapper(.left(left))
      case let (right as ProgressEvent<R>, .none, _): return mapper(.right(right))
      default: return nil
      }
    }

    return combined
  }


  // MARK: Operations
  // MARK:

  /**
   ## Branching

   Attach a simple observation handler to the stream to observe new values.

   - parameter handler: The handler used to observe new values.
   - parameter value: The next value in the stream

   - returns: A new Progression stream
   */
  @discardableResult public override func on(_ handler: @escaping (_ value: T) -> Void) -> Progression<ProgressUnit, T> {
    return appendOn(stream: Progression<ProgressUnit, T>(op: "on"), handler: handler)
  }

  /**
   ## Branching

   This will call the handler when the stream receives any error.

   - parameter handler: Handler will be called when an error is received.
   - parameter error: The error thrown by the stream

   - note: The behavior of this operation is slightly different from other streams in that an error is _always_ reported, whether it is terminating or not.  Other streams only report non-terminating errors.

   - returns: a new Progression stream
   */
  @discardableResult public override func onError(_ handler: @escaping (_ error: Error) -> Void) -> Progression<ProgressUnit, T> {
    return append(stream: Progression<ProgressUnit, T>(op: "onError")) { (next, completion) in
      switch next {
      case .error(let error): handler(error)
      case .terminate(.error(let error)): handler(error)
      default: break
      }
      completion(next.signal)
    }
  }

  /**
   ## Branching

   Attach an observation handler to observe termination events for the stream.

   - parameter handler: The handler used to observe the stream's termination.

   - returns: A new Progression Stream
   */
  @discardableResult public override func onTerminate(_ handler: @escaping (Termination) -> Void) -> Progression<ProgressUnit, T> {
    return appendOnTerminate(stream: Progression<ProgressUnit, T>(op: "onTerminate"), handler: handler)
  }

  /**
   ## Branching

   Map values in the current stream to new values returned in a new stream.

   - note: The mapper returns an optional type.  If the mapper returns `nil`, nothing will be passed down the stream, but the stream will continue to remain active.

   - parameter mapper: The handler to map the current type to a new type.
   - parameter value: The current value in the stream

   - returns: A new Progression Stream
   */
  @discardableResult public override func map<U>(_ mapper: @escaping (_ value: T) -> U?) -> Progression<ProgressUnit, U> {
    return appendMap(stream: Progression<ProgressUnit, U>(op: "map<\(String(describing: T.self))>"), withMapper: mapper)
  }

  /**
   ## Branching

   Map values in the current stream to new values returned in a new stream.
   The mapper returns a result type that can return an error or the mapped value.

   - parameter mapper: The handler to map the current value either to a new value or an error.
   - parameter value: The current value in the stream

   - returns: A new Progression Stream
   */
  @discardableResult public override func resultMap<U>(_ mapper: @escaping (_ value: T) -> Result<U>) -> Progression<ProgressUnit, U> {
    return appendMap(stream: Progression<ProgressUnit, U>(op: "resultMap<\(String(describing: T.self))>"), withMapper: mapper)
  }

  /**
   ## Branching

   Map values _asynchronously_ to either a new value, or else an error.
   The handler should take the current value along with a completion handler.
   Once ready, the completion handler should be called with:

    - New Value:  New values will be passed down stream
    - Error: An error will be passed down stream.  If you wish the error to terminate, add `onError` down stream and return a termination for it.
    - `nil`: Passing `nil` into will complete the handler but pass nothing down stream.

   - warning: The completion handler must _always_ be called, even if it's called with `nil`.  Failing to call the completion handler will block the stream, prevent it from being terminated, and will result in memory leakage.

   - parameter mapper: The mapper takes a value and a comletion handler.
   - parameter value: The current value in the stream
   - parameter completion: The completion handler; takes an optional Result type passed in.  _Must always be called only once_.

   - returns: A new Progression Stream
   */
  @discardableResult public override func asyncMap<U>(_ mapper: @escaping (_ value: T, _ completion: @escaping (Result<U>?) -> Void) -> Void) -> Progression<ProgressUnit, U> {
    return appendMap(stream: Progression<ProgressUnit, U>(op: "asyncMap<\(String(describing: T.self))>"), withMapper: mapper)
  }

  /**
   ## Branching

   Map values to an array of values that are emitted sequentially in a new stream.

   - parameter mapper: The mapper should take a value and map it to an array of new values. The array of values will be emitted sequentially in the returned stream.
   - parameter value: The next value in the stream.

   - note: Because a future can only return 1 value, using flatmap will instead return a Hot Stream that emits the mapped values and then terminates.

   - returns: A new Hot Stream
   */
  @discardableResult public override func flatMap<U>(_ mapper: @escaping (_ value: T) -> [U]) -> Hot<U> {
    return appendFlatMap(stream: Hot<U>(op: "flatMap<\(String(describing: T.self))>"), withFlatMapper: mapper)
  }

  /**
   ## Branching

   Filter out values if the handler returns `false`.

   - parameter include: Handler to determine whether the value should filtered out (`false`) or included in the stream (`true`)
   - parameter value: The next value to be emitted by the stream.

   - returns: A new Progression Stream
   */
  @discardableResult public override func filter(include: @escaping (_ value: T) -> Bool) -> Progression<ProgressUnit, T> {
    return appendFilter(stream: Progression<ProgressUnit, T>(op: "filter"), include: include)
  }

  /**
   ## Branching

   Append a stamp to each item emitted from the stream.  The Stamp and the value will be emitted as a tuple.

   - parameter stamper: Takes a value emitted from the stream and returns a stamp for that value.
   - parameter value: The next value for the stream.

   - returns: A new Progression Stream
   */
  @discardableResult public override func stamp<U>(_ stamper: @escaping (_ value: T) -> U) -> Progression<ProgressUnit, (value: T, stamp: U)> {
    return appendStamp(stream: Progression<ProgressUnit, (value: T, stamp: U)>(op: "stamp"), stamper: stamper)
  }

  /**
   ## Branching

   Append a timestamp to each value and return both as a tuple.

   - returns: A new Progression Stream
   */
  @discardableResult public override func timeStamp() -> Progression<ProgressUnit, (value: T, stamp: Date)> {
    return stamp{ _ in return Date() }
  }

  /**
   ## Branching

   This will delay the values emitted from the stream by the time specified.

   - warning: The stream cannot terminate until all events are terminated.

   - parameter delay: The time, in seconds, to delay emitting events from the stream.

   - returns: A new Progression Stream
   */
  @discardableResult public override func delay(_ delay: TimeInterval) -> Progression<ProgressUnit, T> {
    return appendDelay(stream: Progression<ProgressUnit, T>(op: "delay(\(delay))"), delay: delay)
  }

  /**
   ## Branching

   Emit provided values immediately before the first value received by the stream.

   - note: These values are only emitted when the stream receives its first value.  If the stream receives no values, these values won't be emitted.
   - note: Since a Progression can only emit 1 item, flatten will return a hot stream instead, emit the flattened values and then terminate.

   - parameter with: The values to emit before the first value

   - returns: A new Progression Stream
   */
  @discardableResult public override func start(with: [T]) -> Hot<T> {
    return appendStart(stream: Hot<T>(op: "start(with: \(with.count) values)"), startWith: with)
  }

  /**
   ## Branching

   Emit provided values after the last item, right before the stream terminates.
   These values will be the last values emitted by the stream.

   - parameter concat: The values to emit before the stream terminates.

   - note: Since a Progression can only emit 1 item, flatten will return a hot stream instead, emit the flattened values and then terminate.

   - returns: A new Progression Stream
   */
  @discardableResult public override func concat(_ concat: [T]) -> Hot<T> {
    return appendConcat(stream: Hot<T>(op: "concat(\(concat.count) values)"), concat: concat)
  }

  /**
   ## Branching

   Define a default value to emit if the stream terminates without emitting anything.

   - parameter value: The default value to emit.

   - returns: A new Progression Stream
   */
  @discardableResult public override func defaultValue(_ value: T) -> Progression<ProgressUnit, T> {
    return appendDefault(stream: Progression<ProgressUnit, T>(op: "defaultValue(\(value))"), value: value)
  }

  // MARK: Combining operators

  /**
   ## Branching

   Merge a separate stream into this one, returning a new stream that emits values from both streams sequentially as an Either

   - parameter stream: The stream to merge into this one.

   - returns: A new Progression Stream
   */
  @discardableResult public override func merge<U>(_ stream: Stream<U>) -> Progression<ProgressUnit, Either<T, U>> {
    return appendMerge(stream: stream, intoStream: Progression<ProgressUnit, Either<T, U>>(op: "merge(stream:\(stream))"))
  }

  /**
   ## Branching

   Merge into this stream a separate stream with the same type, returning a new stream that emits values from both streams sequentially.

   - parameter stream: The stream to merge into this one.

   - returns: A new Progression Stream
   */
  @discardableResult public override func merge(_ stream: Stream<T>) -> Progression<ProgressUnit, T> {
    return appendMerge(stream: stream, intoStream: Progression<ProgressUnit, T>(op: "merge(stream:\(stream))"))
  }

  /**
   ## Branching

   Merge another stream into this one, _zipping_ the values from each stream into a tuple that's emitted from a new stream.

   - note: Zipping combines a stream of two values by their _index_.
   In order to do this, the new stream keeps a buffer of values emitted by either stream if one stream emits more values than the other.
   In order to prevent unconstrained memory growth, you can specify the maximum size of the buffer.
   If you do not specify a buffer, the buffer will continue to grow if one stream continues to emit values more than another.

   - parameter stream: The stream to zip into this one
   - parameter buffer: _(Optional)_, **Default:** `nil`. The maximum size of the buffer. If `nil`, then no maximum is set (the buffer can grow indefinitely).

   - returns: A new Progression Stream
   */
  @discardableResult public override func zip<U>(_ stream: Stream<U>, buffer: Int? = nil) -> Progression<ProgressUnit, (T, U)> {
    return appendZip(stream: stream, intoStream: Progression<ProgressUnit, (T, U)>(op: "zip(stream: \(stream), buffer: \(buffer ?? -1))"), buffer: buffer)
  }

  /**
   ## Branching

   Merge another stream into this one, emitting the values as a tuple.

   If one stream emits more values than another, the latest value in that other stream will be emitted multiple times, thus enumerating each combination.

   - parameter stream: The stream to combine into this one.

   - returns: A new Progression Stream
   */
  @discardableResult public override func combine<U>(stream: Stream<U>) -> Progression<ProgressUnit, (T, U)> {
    return appendCombine(stream: stream, intoStream: Progression<ProgressUnit, (T, U)>(op: "combine(stream: \(stream))"), latest: true)
  }

  // MARK: Lifetime operators

  /**
   ## Branching

   Emit values from stream until the handler returns `false`, and then terminate the stream with the provided termination.

   - parameter then: **Default:** `.cancelled`. When the handler returns `false`, then terminate the stream with this termination.
   - parameter handler: Takes the next value and returns `false` to terminate the stream or `true` to remain active.
   - parameter value: The current value being passed down the stream.

   - warning: Be aware that terminations propagate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.

   - returns: A new Hot Stream
   */
  @discardableResult public override func doWhile(then: Termination = .cancelled, handler: @escaping (_ value: T) -> Bool) -> Progression<ProgressUnit, T> {
    return appendWhile(stream: Progression<ProgressUnit, T>(op: "doWhile(then: \(then))"), handler: handler, then: then)
  }

  /**
   ## Branching

   Emit values from stream until the handler returns `true`, and then terminate the stream with the provided termination.

   - note: This is the inverse of `doWhile`, in that the stream remains active _until_ it returns `true` whereas `doWhile` remains active until the handler return `false`.

   - parameter then: **Default:** `.cancelled`. When the handler returns `true`, then terminate the stream with this termination.
   - parameter handler: Takes the next value and returns `true` to terminate the stream or `false` to remain active.
   - parameter value: The current value being passed down the stream.

   - warning: Be aware that terminations propagate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.

   - returns: A new Hot Stream
   */
  @discardableResult public override func until(then: Termination = .cancelled, handler: @escaping (T) -> Bool) -> Progression<ProgressUnit, T> {
    return appendUntil(stream: Progression<ProgressUnit, T>(op: "until(then: \(then)"), handler: handler, then: then)
  }

  /**
   ## Branching

   Emit values from stream until the handler returns a `Termination`, at which the point the stream will Terminate.

   - parameter handler: Takes the next value and returns a `Termination` to terminate the stream or `nil` to continue as normal.
   - parameter value: The current value being passed down the stream.

   - warning: Be aware that terminations propagate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.

   - returns: A new Hot Stream
   */
  @discardableResult public override func until(_ handler: @escaping (_ value: T) -> Termination?) -> Progression<ProgressUnit, T> {
    return appendUntil(stream: Progression<ProgressUnit, T>(op: "until"), handler: handler)
  }

  /**
   ## Branching

   Keep a weak reference to an object, emitting both the object and the current value as a tuple.
   Terminate the stream on the next event that finds object `nil`.

   - parameter object: The object to keep a week reference.  The stream will terminate on the next even where the object is `nil`.
   - parameter then: The termination to apply after the reference has been found `nil`.

   - warning: Be aware that terminations propagate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   - warning: This stream will return a stream that _cannot_ be replayed.  This prevents the stream of retaining the object and extending its lifetime.

   - returns: A new Hot Stream
   */
  @discardableResult public override func using<U: AnyObject>(_ object: U, then: Termination = .cancelled) -> Progression<ProgressUnit, (U, T)> {
    return appendUsing(stream: Progression<ProgressUnit, (U, T)>(op: "using(\(object), then: \(then))"), object: object, then: then).canReplay(false)
  }

  /**
   ## Branching

   Tie the lifetime of the stream to that of the object.
   Terminate the stream on the next event that finds object `nil`.

   - parameter object: The object to keep a week reference.  The stream will terminate on the next even where the object is `nil`.
   - parameter then: The termination to apply after the reference has been found `nil`.

   - warning: Be aware that terminations propagate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   - warning: This stream will return a stream that _cannot_ be replayed.  This prevents the stream of retaining the object and extending its lifetime.

   - returns: A new Progression Stream
   */
  @discardableResult public override func lifeOf<U: AnyObject>(_ object: U, then: Termination = .cancelled) -> Progression<ProgressUnit, T> {
    return appendLifeOf(stream: Progression<ProgressUnit, T>(op: "lifeOf(\(object), then: \(then))"), object: object, then: then)
  }


}
