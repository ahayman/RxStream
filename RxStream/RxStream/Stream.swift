//
//  Stream.swift
//  RxStream
//
//  Created by Aaron Hayman on 2/23/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

///Termination reason: Defines the reasons a stream can terminate
public enum Termination {
  /// The stream has completed without any problems.
  case completed
  
  /// The stream has been explicitly cancelled.
  case cancelled
  
  /// An error has occurred and the stream is no longer viable.
  case error(Error)
}

/// Defines the current state of the stream, which can be active (the stream is emitting data) or terminated with a reason.
public enum StreamState : Equatable {
  /// The stream is currently active can can emit data
  case active
  
  /// The stream has been terminated with the provided reason.
  case terminated(reason: Termination)
}

public func ==(lhs: StreamState, rhs: StreamState) -> Bool {
  switch (lhs, rhs) {
  case (.active, .active):
    return true
  case let (.terminated(lReason), .terminated(rReason)):
    switch (lReason, rReason){
    case (.completed, .completed),
         (.cancelled, .cancelled),
         (.error, .error): return true
    default: return false
    }
  default:
    return false
  }
}

/// Events are passed down streams for processing
enum Event<T> {
  /// Next data to be passed down the streams
  case next(T)
  /// Stream terminate signal
  case terminate(reason: Termination)
  
  @discardableResult func onValue(_ handler: (T) -> Void) -> Event<T> {
    if case let .next(value) = self { handler(value) }
    return self
  }
  
  @discardableResult func onTerminate(_ handler: (Termination) -> Void) -> Event<T> {
    if case let .terminate(reason) = self { handler(reason) }
    return self
  }
}

/** 
 An event processor takes an event (along with an optional prior), processes it, and passes it into the down stream.
 It should return a `Bool` value to indicate whether the down stream is still active.  It not active, the processor will be removed.
 */
private typealias EventProcessor<T> = (_ prior: T?, _ next: Event<T>) -> Bool

/// Defines work that should be done for an event.  The event is passed in, and the completion handler is called when the work has completed.
typealias StreamWork<U, T> = (_ prior: U?, _ next: Event<U>, _ complete: @escaping ([Event<T>]?) -> Void) -> Void

internal protocol BaseStream : class {
  associatedtype Data
  func process<U>(prior: U?, next: Event<U>, withWork work: @escaping StreamWork<U, Data>) -> Bool
}
extension Stream : BaseStream { }

/// Base class for Streams.  It cannot be instantiated directly and should not generally be used as a type directly.
public class Stream<T> {
  typealias Data = T
  
  /// Storage of all down streams.
  private var downStreams = [EventProcessor<T>]()
  
  /// The amount of work currently in progress.  Mostly, it's used to keep track of running work so that termination events are only processed after
  private var currentWork: UInt = 0
  
  /// The queue contains the prior value, if any, and the current value.  The queue will be `nil` when the stream is first created.
  private var queue: (prior: T?, current: T)?
  
  /// If this is set `true`, the next stream attached will have the current values replayed into it, if any.
  fileprivate var replay: Bool = false
  
  /// When the stream is terminated, this will contain the Terminate reason.  It's primarily used to replay terminate events downstream when a stream is attached.
  private var termination: Termination? {
    guard case let .terminated(terminate) = state else { return nil }
    return terminate
  }
  
  /**
   Represents the current state of the stream.
   If active, new events can be passed into the stream. Otherwise, the stream will reject all attempts to use it.
   Once a stream is terminated, it cannot be made active again.
   */
  private(set) public var state = StreamState.active
  
  /**
   All processing and stream operations will occur on this dispatch.  By default, processing is performed inline, but this can be changed.
   You should be aware of _how_ changing a dispatch queue can affect the order of operations. 
   While all chained operations are guaranteed to be processed serially, changing the dispatch can affect how multiple chains are processed.
   However, since each processor can optionally choose to exhibit asychronous behavior, the below discussion only applies for chains that are serial in nature.
   
   - Using an asynchronous, serial, private queue for performing operations will cause all local processors to process serially, with any downstream processors dispatched back into the queue. This may mean that each "level" of processor may be processed in parallel.
   - Changing this to a synchronous, serial queue will have different behavior:  Each _chain_ will be processed serially.  This means an entire chain will process before the next chain is processed.
   - Changing this to a concurrent queue: Each _chain_ will still be processed serially within itself, but multiple chains will be processed concurrently.  Only use this if you don't care in what order the chains are processed.
   
   - note: This discussion really only applies when you care how multiple chains are processed.  99% of the time you don't need to worry abou it since an individual chain will always process in order and that covers the majority use cases.
   - warning: A dispatch will not forcefully propogate downstream, but it will propogate into newly attached streams. So any existing downsteams won't be affected by changing the dispatch, but any streams attached to this stream after the dispatch is set will.
   */
  fileprivate(set) public var dispatch = Dispatch.inline
  
  /// Convience variable returning whether the stream is currently active
  public var isActive: Bool { return state == .active }
  
  /// A Throttle is used to restrict the flow of information that moves through the stream.
  internal(set) public var throttle: Throttle?
  
  /**
   Used internally by concrete subclasses to append downstream processors.
   A processor will normally be a closure that captures the subclassed `Stream`, processes the data (possibly transforms it), and passes it on to the down stream.
   Using a closure will erase/hide the subclass type in the closure, which is the easiest way to store it.
   
   - parameter replay: Defines whether items in the current queue should be replayed into the processor.
   - parameter processor: The processor should take an event, process it and pass it into a capture downstream
   - note: Termination will always replay. We don't want an active downstream that's attached to an inactive one.
   */
  fileprivate func appendDownStream(processor: @escaping EventProcessor<T>) {
    dispatch.execute {
      let replay = self.replay
      self.replay = false
      
      // If replay is specified, and there are items in the queue, pass those into the processor
      if
        replay,
        let queue = self.queue,
        !processor(queue.prior, .next(queue.current))
      {
        // The processor returned false, meaning the downstream is inactive and nothing else need be done
        return
      }
      
      // If this stream is terminated, pass that into the processor, else append the processor
      if let termination = self.termination {
        _ = processor(self.queue?.current, .terminate(reason: termination))
      } else {
        self.downStreams.append(processor)
      }
    }
  }
  
  /**
   Used internally to push events into the stream. This will update the stream's state and push the event further down stream.
   - warning: if the stream is not active, the event will be ignored.
  */
  private func push(event: Event<T>) {
    dispatch.execute {
      
      // Push the event down stream
      self.downStreams = self.downStreams.filter{ return $0(self.queue?.current, event) }
      
      // update internal state
      switch event {
      case let .next(value):
        self.queue = (self.queue?.current, value)
      case let .terminate(reason):
        self.state = .terminated(reason: reason)
        self.downStreams = []
      }
    }
  }
  
  func terminate(reason: Termination) {
    dispatch.execute {
      guard self.isActive else { return }
      self.state = .terminated(reason: reason)
      if self.currentWork > 0 {
        self.push(event: .terminate(reason: reason))
      }
    }
  }
  
  /**
   This is an internal function used to process event work.  It's important that all processing work done for a stream use this function.
   The main point of this is to ensure that work is correctly dispatched and throttled.
   It also holds back any termination events until prior work has been completed, preventing a termination event from being processed before a data event is finished.
   
   - parameter event: The event that should be processed
   - parameter work: The work processor that should process the event.
   
   - warning: All work for a stream should use this function to process events.
   */
  func process<U>(prior: U?, next: Event<U>, withWork work: @escaping StreamWork<U, T>) -> Bool {
    guard isActive else { return false }
    dispatch.execute {
      // Make sure we're receiving data, otherwise it's a termination event and we should set the terminateWork
      if case let .terminate(reason) = next {
        self.terminate(reason: reason)
      }
      
      self.currentWork += 1
      
      // Abstract out the process work so it can be done inline or applied to a throttle
      let workProcessor: ThrottledWork = { completion in
        work(prior, next) { result in
          result >>? { $0.forEach{ self.push(event: $0) } }
          self.dispatch.execute {
            self.currentWork -= 1
            
            // If all current work is done and the stream is terminated, we need to push that termination downstream
            if self.currentWork == 0, let reason = self.termination {
              self.push(event: .terminate(reason: reason))
            }
            completion()
          }
        }
      }
      
      if let throttle = self.throttle {
        throttle.process(work: workProcessor)
      } else {
        workProcessor { }
      }
    }
    return true
  }
  
}

// MARK: Mutating Functions
extension Stream {
  
  /** 
   Allows you to set the dispatch as part of a chain operation. Returns `self` to continue the chain.
   Dispatches are propogated down _new_ streams, but any existing stream won't be affected by the dispatch.
   */
  @discardableResult public func dispatchOn(_ dispatch: Dispatch) -> Self {
    self.dispatch = dispatch
    return self
  }
  
  /**
   This will cause the last value pushed into the next stream attached to this one.
   - note: The replay will chain, so that the attached stream will also replay it's value into the next stream attached to it.  This causes the replay to propogate down the chain.
  */
  public func replayNext(_ replay: Bool = true) -> Self {
    self.replay = true
    return self
  }
  
}

// MARK: Observation functions
extension Stream {
  
  /**
   ## Non-branching
   While this function returns self for easy chaining, it does _not_ return a new stream.
   Attach a handler to this function that will be called when the stream is terminated.
   
   - parameter callback: The callback handler to be called when the stream is terminated
   
   - returns: Self
  */
  public func onTerminate(_ callback: @escaping (Termination) -> Void) -> Self {
    appendDownStream { (_, event) -> Bool in
      guard case let .terminate(reason) = event else { return true }
      callback(reason)
      return false
    }
    return self
  }
  
}

// Mark: Work Generation
extension Stream {
  
  fileprivate func appendStream<U: BaseStream>(_ stream: U, withWork work: @escaping StreamWork<T,U.Data>) -> U {
    if let stream = stream as? Stream<U.Data> {
      stream.dispatch = dispatch
      stream.replay = replay
    }
    self.appendDownStream { (prior, next) -> Bool in
      stream.process(prior: prior, next: next, withWork: work)
    }
    return stream
  }
  
  func append<U: BaseStream>(stream: U, handler: @escaping (U.Data) -> Bool) -> U where U.Data == T {
    return appendStream(stream) { (_, next, completion) in
      var events = [next]
      next.onValue { value in
        if !handler(value) {
          events.append(.terminate(reason: .completed))
        }
      }
      completion(events)
    }
  }
  
  func append<U: BaseStream>(stream: U, handler: @escaping (U.Data?, U.Data) -> Bool) -> U where U.Data == T {
    return appendStream(stream) { (prior, next, completion) in
      var events = [next]
      next.onValue { value in
        if !handler(prior, value) {
          events.append(.terminate(reason: .completed))
        }
      }
      completion(events)
    }
  }
  
  func append<U: BaseStream>(stream: U, withMapper mapper: @escaping (T) -> U.Data?) -> U {
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{ mapper($0) >>? { completion([.next($0)]) } }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func append<U: BaseStream>(stream: U, withMapper mapper: @escaping (T) -> Result<U.Data>) -> U {
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue {
          mapper($0)
            .onSuccess{ completion([.next($0)]) }
            .onFailure{ completion([.terminate(reason: .error($0))]) }
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func append<U: BaseStream>(stream: U, withMapper mapper: @escaping (T, (Result<U.Data>) -> Void) -> Void) -> U {
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue {
          mapper($0) { $0
            .onSuccess{ completion([.next($0)]) }
            .onFailure{ completion([.terminate(reason: .error($0))]) }
          }
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func append<U: BaseStream>(stream: U, withFlatMapper mapper: @escaping (T) -> [U.Data]) -> U {
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{ completion(mapper($0).map{ .next($0) }) }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func append<U: BaseStream>(stream: U, initial: U.Data, withScanner scanner: @escaping (U.Data, T) -> U.Data) -> U {
    var reduction: U.Data = initial
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{
          reduction = scanner(reduction, $0)
          completion([.next(reduction)])
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendFirst<U: BaseStream>(stream: U) -> U where U.Data == T {
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{ completion([.next($0), .terminate(reason: .completed)]) }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendFirst<U: BaseStream>(stream: U, count: Int, partial: Bool) -> U where U.Data == [T] {
    let first = max(1, count)
    var buffer = [T]()
    buffer.reserveCapacity(first)
    return appendStream(stream) { (_, next, completion) in
      var events: [Event<[T]>] = []
      next
        .onValue{
          buffer.append($0)
          if buffer.count >= count {
            events.append(.next(buffer))
            events.append(.terminate(reason: .completed))
          }
        }
        .onTerminate { _ in
          guard partial else { return }
          events.append(.next(buffer))
      }
      completion(events)
    }
  }
  
  func appendLast<U: BaseStream>(stream: U) -> U where U.Data == T {
    var last: Event<U.Data>? = nil
    return appendStream(stream) { (_, next, completion) in
      switch next {
      case .next:
        last = next
        completion(nil)
      case .terminate:
        completion(last >>? { [$0] })
      }
    }
  }
  
  func appendLast<U: BaseStream>(stream: U, count: Int, partial: Bool) -> U where U.Data == [T] {
    var buffer = CircularBuffer<T>(size: max(1, count))
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{
          buffer.append($0)
          completion(nil)
        }
        .onTerminate{ _ in
          guard buffer.count == count || partial else { return completion(nil) }
          completion([.next(buffer.map{ $0 })])
      }
    }
  }
  
  func appendBuffer<U: BaseStream>(stream: U, bufferSize: Int, partial: Bool) -> U where U.Data == [T] {
    let size = Int(max(1, bufferSize)) - 1
    var buffer: U.Data = []
    buffer.reserveCapacity(size)
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue {
          if buffer.count < size {
            buffer.append($0)
            completion(nil)
          } else {
            let filledBuffer = buffer + [$0]
            buffer.removeAll(keepingCapacity: true)
            completion([.next(filledBuffer)])
          }
        }
        .onTerminate{ _ in
          guard partial else { return completion(nil) }
          completion([.next(buffer)])
      }
    }
  }
  
  func appendWindow<U: BaseStream>(stream: U, windowSize: Int, partial: Bool) -> U where U.Data == [T] {
    var buffer = CircularBuffer<T>(size: windowSize)
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{
          buffer.append($0)
          if !partial && buffer.count < windowSize {
            completion(nil)
          } else {
            let window = buffer.map{ $0 } as U.Data
            completion([.next(window)])
          }
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendWindow<U: BaseStream>(stream: U, windowSize: TimeInterval, limit: Int?) -> U where U.Data == [T] {
    var buffer = [(TimeInterval, T)]()
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{
          let now = Date.timeIntervalSinceReferenceDate
          buffer.append((now, $0))
          var window = buffer
            .filter{ now - $0.0 < windowSize }
            .map{ $0.1 }
          if let limit = limit, window.count > limit {
            window = ((window.count - limit)..<window.count).map{ window[$0] }
          }
          completion([.next(window as U.Data)])
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendFilter<U: BaseStream>(stream: U, include: @escaping (T) -> Bool) -> U where U.Data == T {
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{ completion(include($0) ? [next] : nil) }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendStride<U: BaseStream>(stream: U, stride: Int) -> U where U.Data == T {
    let stride = max(1, stride)
    var current = 0
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{ _ in
          current += 1
          if stride == current {
            current = 0
            completion([next])
          } else {
            completion(nil)
          }
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendTimeStamp<U: BaseStream>(stream: U) -> U where U.Data == (Date, T) {
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{ completion([.next(Date(), $0)]) }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendDistinct<U: BaseStream>(stream: U, isDistinct: @escaping (T, T) -> Bool) -> U where U.Data == T {
    return appendStream(stream) { (prior, next, completion) in
      next
        .onValue{
          guard let prior = prior else { return completion([next]) }
          completion(isDistinct(prior, $0) ? [next] : nil)
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendMin<U: BaseStream>(stream: U, lessThan: @escaping (T, T) -> Bool) -> U where U.Data == T {
    var min: T? = nil
    return appendStream(stream) { (prior, next, completion) in
      next
        .onValue{
          guard let prior = min ?? prior, !lessThan($0, prior) else {
            min = $0
            return (completion([next]))
          }
          completion(nil)
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendMax<U: BaseStream>(stream: U, greaterThan: @escaping (T, T) -> Bool) -> U where U.Data == T {
    var max: T? = nil
    return appendStream(stream) { (prior, next, completion) in
      next
        .onValue{
          guard let prior = max ?? prior, !greaterThan($0, prior) else {
            max = $0
            return (completion([next]))
          }
          completion(nil)
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendCount<U: BaseStream>(stream: U) -> U where U.Data == UInt {
    var count: UInt = 0
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{ _ in
          count += 1
          completion([.next(count)])
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendDelay<U: BaseStream>(stream: U, delay: TimeInterval) -> U where U.Data == T {
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{ _ in
          Dispatch.after(delay: delay, on: .main).execute{ completion([next]) }
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendUsing<U: BaseStream, V: AnyObject>(stream: U, object: V) -> U where U.Data == (V, T) {
    let box = WeakBox(object)
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{ value in
          if let object = box.object {
            completion([.next(object, value)])
          } else {
            completion([.terminate(reason: .completed)])
          }
          
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendMerge<U: BaseStream, V>(stream: Stream<V>, intoStream: U) -> U where U.Data == Either<V, T> {
    _ = stream.appendStream(intoStream) { (_, next, completion) in
      next
        .onValue{ completion([.next(.left($0))]) }
        .onTerminate{ _ in completion(nil) }
    }
    return appendStream(intoStream) { (_, next, completion) in
      next
        .onValue{ completion([.next(.right($0))]) }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendMerge<U: BaseStream>(stream: Stream<T>, intoStream: U) -> U where U.Data == T {
    _ = stream.appendStream(intoStream) { (_, next, completion) in
      next
        .onValue{ completion([.next($0)]) }
        .onTerminate{ _ in completion(nil) }
    }
    return appendStream(intoStream) { (_, next, completion) in
      next
        .onValue{ completion([.next($0)]) }
        .onTerminate{ _ in completion(nil) }
    }
  }
}

extension Stream where T: Arithmetic {
  
  func appendAverage<U: BaseStream>(stream: U) -> U where U.Data == Data {
    var total = T(0)
    var count = T(0)
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{ value in
          count = count + T(1)
          total = total + value
          completion([.next(total / count)])
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendSum<U: BaseStream>(stream: U) -> U where U.Data == Data {
    var current = T(0)
    return appendStream(stream) { (_, next, completion) in
      next
        .onValue{ value in
          current = value + current
          completion([.next(current)])
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
}
