//
//  Stream.swift
//  RxStream
//
//  Created by Aaron Hayman on 2/23/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

///Termination reason: Defines the reasons a stream can terminate
public enum Termination : Equatable {
  
  /// The stream has completed without any problems.
  case completed
  
  /// The stream has been explicitly cancelled.
  case cancelled
  
  /// An error has occurred and the stream is no longer viable.
  case error(Error)
}

public func ==(lhs: Termination, rhs: Termination) -> Bool {
  switch (lhs, rhs) {
  case (.completed, .completed),
       (.cancelled, .cancelled),
       (.error, .error): return true
  default: return false
  }
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
  case (.active, .active): return true
  case let (.terminated(lReason), .terminated(rReason)): return lReason == rReason
  default: return false
  }
}

public enum Prune : Int {
  case upStream
  case downStream
  case none
}

/// Events are passed down streams for processing
public enum Event<T> {
  /// Next data to be passed down the streams
  case next(T)
  
  /// Stream terminate signal
  case terminate(reason: Termination)
  
  /// A non-terminating error event
  case error(Error)
}

/// Defines work that should be done for an event.  The event is passed in, and the completion handler is called when the work has completed.
typealias StreamOp<U, T> = (_ prior: U?, _ next: Event<U>, _ complete: @escaping ([Event<T>]?) -> Void) -> Void

internal protocol BaseStream : class {
  associatedtype Data
}
extension Stream : BaseStream { }

protocol ParentStream : class {
  func prune(_ prune: Prune, withReason reason: Termination)
}
extension Stream : ParentStream { }

/// Base class for Streams.  It cannot be instantiated directly and should not generally be used as a type directly.
public class Stream<T> {
  typealias Data = T
  
  /// Storage of all down streams.
  var downStreams = [StreamProcessor<T>]()
  
  /// The amount of work currently in progress.  Mostly, it's used to keep track of running work so that termination events are only processed after
  private var currentWork: UInt = 0
  
  /// The queue contains the prior value, if any, and the current value.  The queue will be `nil` when the stream is first created.
  private var queue: (prior: T?, current: T)?
  
  /// If this is set `true`, the next stream attached will have the current values replayed into it, if any.
  var replay: Bool = false
  
  /// If this is set `true`, the stream can replay values.  Otherwise, it cannot.  If a stream cannot replay values, then setting `replay == true` will do nothing.
  fileprivate(set) public var canReplay: Bool = true {
    didSet { if !canReplay { queue = nil } }
  }
  
  /// Defines the parent stream to which this stream is attached.  Currently used for pruning when a child is terminated.
  weak var parent: ParentStream? = nil
  
  /// Determines whether the stream will persist even after all down streams have terminated.
  fileprivate var persist: Bool = false
  
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
  internal(set) public var state: StreamState = .active
  
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
  public var isActive: Bool { return state == .active }
  
  /// A Throttle is used to restrict the flow of information that moves through the stream.
  internal(set) public var throttle: Throttle?
  
  /// Returns the last value to be emitted from the stream
  var last: T? {
    return queue?.current
  }
  
  /**
   When pruning, this will be called so the stream processor can be notified of the termination.
   Other terminations (pushed from up stream) will move through the stream processor as normal,
   but since a stream doesn't have access to it's own processor, it needs a way to alert the processor of a termination.
   */
  var onTerminate: ((Termination) -> Void)?
  
  /** 
   Keys are stored until a appropriate event is received with the provided key, at which point it's removed.
   If a key is passed down with an event, that key must be present here in order to process.  Otherwise, the event should be ignored.
  */
  var keys = Set<String>()
  
  /// By default, this returns a DownstreamProcessor, but it's primarily so that subclasses can override and provide their own custom processors.
  func newDownstreamProcessor<U>(forStream stream: Stream<U>, withProcessor processor: @escaping StreamOp<T, U>) -> StreamProcessor<T> {
    return DownstreamProcessor(stream: stream, processor: processor)
  }
  
  /// The main function used to attach a stream to a parent stream along with the child's stream work
  @discardableResult func append<U: BaseStream>(stream: U, withOp op: @escaping StreamOp<T, U.Data>) -> U {
    guard let child = stream as? Stream<U.Data> else { fatalError("Error attaching streams: All Streams must descencend from Stream.") }
    
    child.dispatch = dispatch
    child.replay = replay
    child.canReplay = canReplay
    child.parent = self
    
    appendDownStream(processor: newDownstreamProcessor(forStream: child, withProcessor: op))
    
    return stream
  }
  
  /**
   Used internally by concrete subclasses to append downstream processors.
   A processor will normally be a closure that captures the subclassed `Stream`, processes the data (possibly transforms it), and passes it on to the down stream.
   Using a closure will erase/hide the subclass type in the closure, which is the easiest way to store it.
   
   - parameter replay: Defines whether items in the current queue should be replayed into the processor.
   - parameter processor: The processor should take an event, process it and pass it into a capture downstream
   - note: Termination will always replay. We don't want an active downstream that's attached to an inactive one.
   */
  private func appendDownStream(processor: StreamProcessor<T>) {
    dispatch.execute {
      let replay = self.replay
      self.replay = false
      
      // If replay is specified, and there are items in the queue, pass those into the processor
      if
        self.canReplay,
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
  func prune(_ prune: Prune, withReason reason: Termination) {
    dispatch.execute {
      guard prune != .none else { return }
      self.downStreams = self.downStreams.filter{ !$0.shouldPrune }
      if case .upStream = prune {
        self.terminate(reason: reason, andPrune: .none)
        self.parent?.prune(prune, withReason: reason)
      }
    }
  }
  
  /**
   Used internally to push events into the stream. This will update the stream's state and push the event further down stream.
   Provide a key to pass down stream if one was provided.
   - warning: if the stream is not active, the event will be ignored.
  */
  func push(event: Event<T>, withKey key: String?) {
    dispatch.execute {
      guard self.isActive else { return }
      
      // Push the event down stream.  If the stream is reusable, we don't want to filter downstreams.  
      for processor in self.downStreams {
        processor.process(prior: self.queue?.current, next: event, withKey: key) 
      }
      
      // update internal state
      if case let .next(value) = event, self.canReplay {
        self.queue = (self.queue?.current, value)
      }
    }
  }
  
  /**
   This will terminate the stream. It will only push the termination down stream if there is no work currently in progress.
   Otherwise, the termination will be pushed when the work is complete in the `process` function.
   */
  func terminate(reason: Termination, andPrune prune: Prune) {
    dispatch.execute {
      if self.isActive {
        self.state = .terminated(reason: reason)
      }
      self.onTerminate?(reason)
      self.onTerminate = nil
      self.prune(prune, withReason: reason)
    }
  }
  
  var pendingTermination: Termination? = nil
  /**
   This is an internal function used to process event work. It's important that all processing work done for a stream use this function.
   The main point of this is to ensure that work is correctly dispatched and throttled.
   It also holds back any termination events until prior work has been completed, preventing a termination event from being processed before a data event is finished.
   How events are processed will depend on what kind of events are called back in the Stream operation:
   
    - `.next(value)` : If the work passes back in next events, those will be processed like normal and pushed down stream like a normal event would. If the triggering event was a termination, it will be processed after the next events are processed.
    - `nil`:  If `nil` is passed back in, no events will be processed, but if the triggering event was a termination, it will be processed like normal.
    - `.termination(reason)` : If a termination event is passed back, it will take priority and _immediately_ be processed and no further events will be accepted.  The termination will progogate both up and down the stream chain.
    - `.error(_)` : Errors will be processed like normal.  However, if the triggering event was a termination, that event will be ignored (the stream will not be terminated).  This effectively converts a termination into an error.  This is primarily used for merged streams, where a termination does not always terminate the stream (because an upstream may still be active).
   
   - parameter key: A key will restrict processing of the event to only those streams that have a matching key stored. If `nil` is passed, the event will be processed as normal.
   - parameter event: The event that should be processed.
   - parameter work: The work processor that should process the event.
   
   - warning: All work for a stream should use this function to process events.
   */
  func process<U>(key: String?, prior: U?, next: Event<U>, withOp op: @escaping StreamOp<U, T>) {
    guard isActive && pendingTermination == nil else { return }
    dispatch.execute {
      // If a key is provided, we can only process the request if we have that key.
      if let key = key {
        guard let _ = self.keys.remove(key) else { return }
      }
      // Make sure we're receiving data, otherwise it's a termination event and we should set the terminateWork
      self.currentWork += 1
      
      if case let .terminate(reason) = next {
        self.pendingTermination = reason
      }
      
      // Abstract out the process work so it can be done inline or applied to a throttle
      let workProcessor: ThrottledWork = { completion in
          self.dispatch.execute {
            var opTermination = false
            // If this is a termination event, we need to `nil` out the `onTerminate` so it's not called when the termination is pushed.  Otherwise, we'll end up with two termination events processed.
            if case .terminate = next {
              self.onTerminate = nil
            }
            op(prior, next) { result in
              if let events = result {
                outer: for event in events {
                  // push each event
                  self.push(event: event, withKey: key)
                  // if the event is a termination, we break.  There's no point in pushing any more events.
                  switch event{
                  case .terminate(let reason):
                    opTermination = true
                    self.terminate(reason: reason, andPrune: .upStream)
                    break outer
                  // A processor can take a termination event and turn it into an error. This will prevent the stream from terminating and instead pass an error down. The only reason to do this is for merged streams.
                  case .error:
                    self.pendingTermination = nil
                  default: break
                  }
                }
              }
              
              self.currentWork -= 1
            
              // If all current work is done and the stream is terminated and it hasn't been pushed, we need to push that termination downstream
              if self.currentWork == 0, let reason = self.pendingTermination {
                if !opTermination {
                  self.push(event: .terminate(reason: reason), withKey: key)
                  self.terminate(reason: reason, andPrune: .downStream)
                }
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
   This will cause the stream to be unable to replay values. This can be useful (and necessary) if you don't want the stream to retain the values passed down.
   This option will propogate to all new downstreams added.  It does not propogate to existing streams already added before the parameter is set. 
   
   - warning: This can directly impact some operations.  For example, transition observations rely on replayable streams.  If you set `canReplay` to false, then transitions will never provide the `prior` value.
   
   - parameter canReplay: If `true`, then the stream can replay values, otherwise it cannot.
   
   - returns: Self, for chaining
   */
  public func canReplay(_ canReplay: Bool) -> Self {
    self.canReplay = canReplay
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
