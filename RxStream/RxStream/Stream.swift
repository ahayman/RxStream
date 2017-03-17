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
public enum Event<T> {
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
 - note: the next parameter is optional.  If it's not includes, nothing will be processed, but the processor should still return whether the stream is active or not.  The parent can use this to prune inactive streams.
 */
class Processor<T> {
  var shouldPrune: Bool { return true }
  
  func process(prior: T?, next: Event<T>, withKey key: String?) { }
}

class DownstreamProcessor<T, U> : Processor<T> {
  var stream: Stream<U>
  var processor: StreamOp<T, U>
  
  override var shouldPrune: Bool { return !stream.isActive }
  
  override func process(prior: T?, next: Event<T>, withKey key: String?) {
    stream.process(key: key, prior: prior, next: next, withOp: processor)
  }
  
  init(stream: Stream<U>, processor: @escaping StreamOp<T, U>) {
    self.stream = stream
    self.processor = processor
  }
  
}

/// Defines work that should be done for an event.  The event is passed in, and the completion handler is called when the work has completed.
typealias StreamOp<U, T> = (_ prior: U?, _ next: Event<U>, _ complete: @escaping ([Event<T>]?) -> Void) -> Void

internal protocol BaseStream : class {
  associatedtype Data
}
extension Stream : BaseStream { }

protocol ParentStream : class {
  func prune(withReason reason: Termination)
}
extension Stream : ParentStream { }

/// Base class for Streams.  It cannot be instantiated directly and should not generally be used as a type directly.
public class Stream<T> {
  typealias Data = T
  
  /// Storage of all down streams.
  private var downStreams = [Processor<T>]()
  
  /// The amount of work currently in progress.  Mostly, it's used to keep track of running work so that termination events are only processed after
  private var currentWork: UInt = 0
  
  /// The queue contains the prior value, if any, and the current value.  The queue will be `nil` when the stream is first created.
  private var queue: (prior: T?, current: T)?
  
  /// If this is set `true`, the next stream attached will have the current values replayed into it, if any.
  var replay: Bool = false
  
  /// Defines the parent stream to which this stream is attached.  Currently used for pruning when a child is terminated.
  weak var parent: ParentStream? = nil
  
  /// Determines whether the stream will persist even after all down streams have terminated.
  fileprivate var persist: Bool = false
  
  /// When the stream is terminated, this will contain the Terminate reason.  It's primarily used to replay terminate events downstream when a stream is attached.
  private var termination: Termination? {
    guard case let .terminated(terminate) = _state.value else { return nil }
    return terminate
  }
  
  /// Defines the termination work associated with the stream during pruning.  This should only be called when pruning.
  var terminationWork: ((Termination) -> Void)? = nil
  
  /**
   Represents the current state of the stream.
   If active, new events can be passed into the stream. Otherwise, the stream will reject all attempts to use it.
   Once a stream is terminated, it cannot be made active again.
   */
  public var state: Observable<StreamState> { return _state.observable() }
  private var _state = ObservableInput(StreamState.active)
  
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
  internal(set) public var dispatch = Dispatch.inline
  
  /// Convience variable returning whether the stream is currently active
  public var isActive: Bool { return _state.value == .active }
  
  /// A Throttle is used to restrict the flow of information that moves through the stream.
  internal(set) public var throttle: Throttle?
  
  /// Returns the last value to be emitted from the stream
  var last: T? {
    return queue?.current
  }
  
  /** 
   Keys are stored until a appropriate event is received with the provided key, at which point it's removed.
   If a key is passed down with an event, that key must be present here in order to process.  Otherwise, the event should be ignored.
  */
  var keys = Set<String>()
  
  /**
   Used internally by concrete subclasses to append downstream processors.
   A processor will normally be a closure that captures the subclassed `Stream`, processes the data (possibly transforms it), and passes it on to the down stream.
   Using a closure will erase/hide the subclass type in the closure, which is the easiest way to store it.
   
   - parameter replay: Defines whether items in the current queue should be replayed into the processor.
   - parameter processor: The processor should take an event, process it and pass it into a capture downstream
   - note: Termination will always replay. We don't want an active downstream that's attached to an inactive one.
   */
  func appendDownStream(processor: Processor<T>) {
    dispatch.execute {
      let replay = self.replay
      self.replay = false
      
      // If replay is specified, and there are items in the queue, pass those into the processor
      if
        replay,
        let queue = self.queue
      {
        processor.process(prior: queue.prior, next: .next(queue.current), withKey: nil)
      }
      
      // If this stream is terminated, pass that into the processor, else append the processor
      if let termination = self.termination {
        processor.process(prior: self.queue?.current, next: .terminate(reason: termination), withKey: nil)
      } else {
        self.downStreams.append(processor)
      }
    }
  }
  
  /**
   The prune function should only be called from a down stream that has terminated on it's own (not a termination pushed from upstream).  
   It's intended for downstreams to notify their parent they are no longer active.
   Current behavior is for a stream to terminate itself if there are no active down streams unless the `persist` option is set.
   This will cause a chain to unravel itself if one of the elements terminates itself.
   */
  func prune(withReason reason: Termination) {
    dispatch.execute {
      guard !self.persist else { return }
      self.downStreams = self.downStreams.filter{ $0.shouldPrune }
      if self.downStreams.count == 0 && self.isActive {
        self._state.set(.terminated(reason: reason))
        self.terminationWork?(reason)
      }
      self.parent?.prune(withReason: reason)
    }
  }
  
  /**
   Used internally to push events into the stream. This will update the stream's state and push the event further down stream.
   Provide a key to pass down stream if one was provided.
   - warning: if the stream is not active, the event will be ignored.
  */
  func push(event: Event<T>, withKey key: String?) {
    dispatch.execute {
      
      // Push the event down stream.  If the stream is reusable, we don't want to filter downstreams.  
      for processor in self.downStreams {
        processor.process(prior: self.queue?.current, next: event, withKey: key) 
      }
      
      // update internal state
      switch event {
      case let .next(value):
        self.queue = (self.queue?.current, value)
      case let .terminate(reason):
        self._state.set(.terminated(reason: reason))
      }
    }
  }
  
  /**
   This will terminate the stream.  It will only push the termination down stream if there is no work currently in progress.
   Otherwise, the termination will be pushed when the work is complete in the `process` fucntion.
   */
  func terminate(reason: Termination) {
    dispatch.execute {
      guard self.isActive else { return }
      self._state.set(.terminated(reason: reason))
      if self.currentWork > 0 {
        self.push(event: .terminate(reason: reason), withKey: nil)
      }
    }
  }
  
  /**
   This is an internal function used to process event work.  It's important that all processing work done for a stream use this function.
   The main point of this is to ensure that work is correctly dispatched and throttled.
   It also holds back any termination events until prior work has been completed, preventing a termination event from being processed before a data event is finished.
   
   - parameter key: A key will restrict processing of the event to only those streams that have a matching key stored.  If `nil` is passed, the event will be processed as normal.
   - parameter event: The event that should be processed
   - parameter work: The work processor that should process the event.
   
   - warning: All work for a stream should use this function to process events.
   */
  func process<U>(key: String?, prior: U?, next: Event<U>, withOp op: @escaping StreamOp<U, T>) {
    guard isActive else { return }
    dispatch.execute {
      // If a key is provided, we can only process the request if we have that key.
      if let key = key {
        guard let _ = self.keys.remove(key) else { return }
      }
      // Make sure we're receiving data, otherwise it's a termination event and we should set the terminateWork
      self.currentWork += 1
      
      // Abstract out the process work so it can be done inline or applied to a throttle
      let workProcessor: ThrottledWork = { completion in
          self.dispatch.execute {
            var opTermination = false
            op(prior, next) { result in
              result >>? { events in
                for event in events {
                  // push each event
                  self.push(event: event, withKey: key)
                  // if the event is a termination, we break and prune if there wasn't already a termination
                  if case .terminate(let reason) = event {
                    opTermination = true
                    self.parent?.prune(withReason: reason)
                    break
                  }
                }
              }
              
            self.currentWork -= 1
            
            // If all current work is done and the stream is terminated and it hasn't been pushed, we need to push that termination downstream
            if !opTermination, self.currentWork == 0, let reason = self.termination {
              self.push(event: .terminate(reason: reason), withKey: key)
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
  
  /**
   Setting this to `true` will cause this stream to persist even if all down streams are removed.  By default, if a stream no longer has any down streams attached to it, it will automatically close itself.
   */
  @discardableResult public func persist(_ persist: Bool = true) -> Self {
    self.persist = persist
    return self
  }
  
}
