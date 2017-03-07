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
}

/// Base class for Streams.  It cannot be instantiated directly and should not generally be used as a type directly.
public class Stream<T> {
  /** 
   An event processor takes an event (along with an optional prior), processes it, and passes it into the down stream.
   It should return a `Bool` value to indicate whether the down stream is still active.  It not active, the processor will be removed.
  */
  typealias EventProcessor = (_ prior: T?, _ next: Event<T>) -> Bool
  
  /// Storage of all down streams.
  private var downStreams = [EventProcessor]()
  
  typealias EventWork = (_ event: Event<T>, _ complete: () -> Void) -> Void
  private var currentWork: UInt = 0
  private var terminateWork: (event: Event<T>, work: EventWork)?
  
  /// The queue contains the prior value, if any, and the current value.  The queue will be `nil` when the stream is first created.
  private var queue: (prior: T?, current: T)?
  
  /// When the tream is terminated, this will contain the Terminate reason.  It's primarily used to replay terminate events downstream.
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
  public var dispatch = Dispatch.inline
  
  /// Passthrough: Allows you to set the dispatch as part of a chain operation. Returns `self` to continue the chain.
  public func dispatchOn(_ dispatch: Dispatch) -> Self {
    self.dispatch = dispatch
    return self
  }
  
  /// Convience variable returning whether the stream is currently active
  public var isActive: Bool { return state == .active }
  
  public var throttle: Throttle?
  
  /**
   Used internally by concrete subclasses to append downstream processors.
   A processor will normally be a closure that captures the subclassed `Stream`, processes the data (possibly transforms it), and passes it on to the down stream.
   Using a closure will erase/hide the subclass type in the closure, which is the easiest way to store it.
   
   - parameter replay: Defines whether items in the current queue should be replayed into the processor.
   - parameter processor: The processor should take an event, process it and pass it into a capture downstream
   - note: Termination will always replay. We don't want an active downstream that's attached to an inactive one.
   */
  func appendDownStream(replay: Bool, processor: @escaping EventProcessor) {
    dispatch.execute {
      
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
  func push(event: Event<T>) {
    dispatch.execute {
      guard self.isActive else { return }
      
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
  
  /**
   This is an internal function used to process event work.  It's important that all processing work done for a stream use this function.
   The main point of this is to ensure that work is correctly dispatched and throttled.
   It also holds back any termination events until prior work has been completed, preventing a termination event from being processed before a data event is finished.
   
   - parameter event: The event that should be processed
   - parameter work: The work processor that should process the event.
   */
  func process(event: Event<T>, withWork work: @escaping EventWork) {
    dispatch.execute {
      // If there is terminate work, then a terminate signal has already ocurred and we cannot process more work
      guard self.terminateWork == nil else { return }
      // Make sure we're receiving data, otherwise it's a termination event and we should set the terminateWork
      guard case .next = event else {
        self.terminateWork = (event, work)
        return
      }
      
      self.currentWork += 1
      
      // Abstract out the process work so it can be done inline or applied to a throttle
      let workProcessor: ThrottledWork = { completion in
        work(event) {
          self.dispatch.execute {
            self.currentWork -= 1
            
            // If all current work is done and there is pending terminate work, we want to process the pending terminate work
            if self.currentWork == 0, let work = self.terminateWork{
              work.work(work.event){ }
              self.terminateWork = nil
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
