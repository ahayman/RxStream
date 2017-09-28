//
//  Stream.swift
//  RxStream
//
//  Created by Aaron Hayman on 2/23/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation


/**
Internal protocol defines a stream that can be canceled and/or pass the cancellation request on to the parent.
Generally, when the cancelTask() function is called, the implementation should check to see if it has a task
to cancel.  If so, it should cancel the task and the stream.  If not, then it should pass the cancellation up
to the parent.  If there is no parent, then the stream should be cancelled.

- note: By default, the base class Stream should assign `cancelParent` by default if both the child and parent
streams are both Cancelable
*/
protocol Cancelable : class {
  weak var cancelParent: Cancelable? { get set }
  func cancelTask()
}

/**
Internal protocol that defines a stream that be retried.  This requires that there be some task that is retriable.
Generally, when the `retry()` function is called, the implementation should first check if there is a task it can cancel,
and if there is, cancel the task and the stream. If not, then the cancellation should be passed up to the a parent.

- note: By default, the base class Stream should assign `retryParent` by default if both the child and parent
streams are both Retriable
*/
protocol Retriable : class {
  weak var retryParent: Retriable? { get set }
  func retry()
}

/**
 Stream types are used to detect and alter behavior for specific types.
 Because all streams are generics, determining the underlying types can be difficult
 and require a lot of type erasure, which frankly is a pain.  This provides a simple but effective
 way to determine a base type.
 - note: This is mostly used to detect down stream types.  In order to appropriately send events to correct types.
*/
enum StreamType : Int {
  static func all() -> [StreamType] {
    return [ .hot, .cold, .future, .promise ]
  }
  case base
  case hot
  case cold
  case future
  case promise
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

/// Defines how and if a stream should prune.
enum Prune : Int {
  case upStream
  case none
}

/// Defines work that should be done for an event.  The event is passed in, and the completion handler is called when the work has completed.
typealias StreamOp<U, T> = (_ next: Event<U>, _ complete: @escaping (OpSignal<T>) -> Void) -> Void

/**
Type erasure to store streams without regard to their type.
*/
internal protocol CoreStream : class {
  var streamType: StreamType { get }
  var shouldPrune: Bool { get }
}

/**
A secondary type erasure to apply type constraints to a stream.
Since this protocol has an associated type, it cannot be used to store streams.
For this reason, we have a "staged" protocol.
Kinda wish Swift would provide a simpler way to accomplish this.
*/
internal protocol BaseStream : CoreStream {
  associatedtype Data
}
extension Stream : BaseStream { }

/**
Parent Stream protocol allow us to pass up pruning information from leaf branches up to the branch that
actually needs to do the pruning.
*/
protocol ParentStream : class {
  func prune(_ prune: Prune, withReason reason: Termination)
  func replayLast(key: EventPath)
}

/// Indirection because we can't store class variables in a Generic
private var globalDebugPrinter: ((String) -> Void)? = nil

extension Stream : ParentStream, CustomDebugStringConvertible { }

/// Base class for Streams.  It cannot be instantiated directly and should not generally be used as a type directly.
public class Stream<T> {
  typealias Data = T

  /// Unique ID for this stream to allow creating and validation of keys
  let id = String.newUUID()

  /// Stream types are used to determine down stream types. This helps avoid complex type erasure just to test the base type.
  var streamType: StreamType { return .base }

  /** 
   If set, debug information will be passed into this closure.
   For example, setting this to:
   
   ```
   Stream<Int>.debugPrinter = { print($0) }
   ```
   
   will cause all debug info to be printed to standard output.  This can really help when debugging something inside a stream.
   
   - warning: This is a _global_ setting, so setting this will replace any existing printer.  
   It is not specific to any particular Stream type, even though you have to specify one to set it (due to how generics are constructed).
   
   By default, it's set to `nil` so no debug info will be generated.
  */
  public class var debugPrinter: ((String) -> Void)? {
    set { globalDebugPrinter = newValue }
    get { return globalDebugPrinter }
  }
  
  /**
   If set, then only this stream will print debug information.  
   - note: This overrides `Stream<_>.debugPrinter`.  If this is `nil` and `Stream<_>.debugPrinter` is set, the latter will be used.
  */
  public var debugPrinter : ((String) -> Void)?
  
  /**
   Primarily used for debugging purposes, it describes the current stream.
   By default, this will display the type of stream (Hot, Cold, Future, etc) along with the operation it performs.
   It can be overridden to provide custom information by setting this property or using the `named(_)` function.
   This helps make it easier when debugging to tell what is going on.
  */
  public var descriptor: String

  public var debugDescription: String { return descriptor }
  
  /// Storage of all down streams.
  var downStreams = [StreamProcessor<T>]()
  
  /// The amount of work currently in progress.  Mostly, it's used to keep track of running work so that termination events are only processed after
  private var currentWork: Int = 0 {
    didSet {
      if currentWork <= 0, let term = pendingTermination {
        if term.callTermHandler == false {
          onTerminate = nil
        }
        terminate(reason: term.reason, andPrune: term.prune, pushDownstreamTo: StreamType.all())
      }
    }
  }

  /// The queue contains the prior value, if any, and the current value.  The queue will be `nil` when the stream is first created.
  var current: [T]? = nil

  /// If this is set `true`, the stream can replay values.  Otherwise, it cannot.  If a stream cannot replay values, then setting `replay == true` will do nothing.
  fileprivate(set) public var canReplay: Bool = true {
    didSet { if !canReplay { current = nil } }
  }
  
  /// Defines the parent stream to which this stream is attached.  Currently used for pruning when a child is terminated.
  weak var parent: ParentStream? = nil

  /// Secondary parent stream for merged streams representing the right side parent
  weak var rParent: ParentStream? = nil
  
  /// Determines whether the stream will persist even after all down streams have terminated.
  fileprivate var persist: Bool = false
  
  /// When the stream is terminated, this will contain the Terminate reason.  It's primarily used to replay terminate events downstream when a stream is attached.
  var termination: Termination? {
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
   */
  internal(set) public var dispatch: Dispatch?
  
  fileprivate var nextDispatch: Dispatch?
  
  /// Convenience variable returning whether the stream is currently active
  public var isActive: Bool { return state == .active }
  
  /** 
   By default, a stream should be pruned if it's not marked persist, and the state is no longer active.
   However, this may be overridden by subclasses to create custom conditions.
   */
  var shouldPrune: Bool { return !persist && state != .active }
  
  /// A Throttle is used to restrict the flow of information that moves through the stream.
  public var throttle: Throttle?
  
  /// If set, the next stream added will have their throttle set to this.
  fileprivate var nextThrottle: Throttle?
  
  /**
   When pruning, this will be called so the stream processor can be notified of the termination.
   Other terminations (pushed from up stream) will move through the stream processor as normal,
   but since a stream doesn't have access to it's own processor, it needs a way to alert the processor of a termination.
   */
  var onTerminate: ((Termination) -> Void)?
  
  init(op: String) {
    self.descriptor = "\(String(describing: type(of: self)))." + op
  }
  
  private func printDebug(info: String) {
    guard let printer = debugPrinter ?? globalDebugPrinter else { return }
    printer("\(descriptor): \(info)")
  }
  
  @discardableResult func configureStreamAsChild<U: BaseStream>(stream: U, leftParent: Bool) -> U {
    guard let child = stream as? Stream<U.Data> else { fatalError("Error attaching streams: All Streams must descend from Stream.") }

    let work = {
      if leftParent {
        if let dispatch = self.nextDispatch {
          child.dispatch = dispatch
          self.nextDispatch = nil
        }
        if let throttle = self.nextThrottle {
          child.throttle = throttle
          self.nextThrottle = nil
        }
        child.canReplay = self.canReplay
        child.parent = self
      } else {
        child.rParent = self
      }
    }

    if let dispatch = self.dispatch {
      dispatch.execute(work)
    } else {
      work()
    }

    return stream
  }

  @discardableResult func attachChildStream<U: BaseStream>(stream: U, withOp op: @escaping StreamOp<T, U.Data>) -> U {
    guard let child = stream as? Stream<U.Data> else { fatalError("Error attaching streams: All Streams must descend from Stream.") }

    (child as? Retriable)?.retryParent = (self as? Retriable)
    (child as? Cancelable)?.cancelParent = (self as? Cancelable)

    let downStream = DownstreamProcessor(stream: child, processor: op)
    if let dispatch = self.dispatch {
      dispatch.execute{
        self.downStreams.append(downStream)
        self.didAttachStream(stream: child)
      }
    } else {
      self.downStreams.append(downStream)
      self.didAttachStream(stream: child)
    }

    return stream
  }

  /// This is primarily for subclasses to be notified when a child stream is attached.
  func didAttachStream<U>(stream: Stream<U>) { }

  /// The main function used to attach a stream to a parent stream along with the child's stream work
  @discardableResult func append<U: BaseStream>(stream: U, withOp op: @escaping StreamOp<T, U.Data>) -> U {
    configureStreamAsChild(stream: stream, leftParent: true)
    attachChildStream(stream: stream, withOp: op)
    return stream
  }

  /**
   The prune function should only be called from a down stream that has terminated on it's own (not a termination pushed from upstream).  
   It's intended for downstreams to notify their parent they are no longer active.
   Current behavior is for a stream to terminate itself if there are no active down streams unless the `persist` option is set.
   This will cause a chain to unravel itself if one of the elements terminates itself.
   */
  func prune(_ prune: Prune, withReason reason: Termination) {
    let work = {
      guard prune != .none else { return }
      self.downStreams = self.downStreams.filter{ !$0.stream.shouldPrune }
      if case .upStream = prune {
        self.terminate(reason: reason, andPrune: .none, pushDownstreamTo: [])
        self.parent?.prune(prune, withReason: reason)
      }
    }

    if let dispatch = self.dispatch {
      dispatch.execute(work)
    } else {
      work()
    }
  }
  
  /**
   Used internally to push events into the stream. This will update the stream's state and push the event further down stream.
   Provide a key to pass down stream if one was provided.
   - warning: if the stream is not active, the event will be ignored.
  */
  private func push(events: [Event<T>], withKey key: EventPath) {

    // update internal state with values from event
    if self.canReplay, let values = events.oMap({ $0.eventValue }).filled {
      self.current = values
    }

    for event in events {
      printDebug(info: "push event \(event)")
    
      // Push the event down stream.  If the stream is reusable, we don't want to filter downstreams.  
      for processor in self.downStreams {
        processor.process(next: event, withKey: key)
      }
    }
    

  }
  
  /**
   This will terminate the stream, call the onTerminate handler and if any downstream types are present, push
   the termination into those downstreams.
   */
  func terminate(reason: Termination, andPrune prune: Prune, pushDownstreamTo types: [StreamType]) {
    let work = {
      self.printDebug(info: "terminating with \(reason)")
      if self.isActive {
        self.state = .terminated(reason: reason)
      }
      self.onTerminate?(reason)
      self.onTerminate = nil
      if types.count > 0 {
        let termination = Event<T>.terminate(reason: reason)
        for processor in self.downStreams where types.contains(processor.stream.streamType){
          processor.process(next: termination, withKey: .share)
        }
      }
      self.prune(prune, withReason: reason)
    }

    if let dispatch = self.dispatch {
      dispatch.execute(work)
    } else {
      work()
    }
  }
  
  /**
   Should be used by producing subclass to process a new event.  
   This should only be used by subclasses that are generating new events to push these events into the stream.
   
   - parameter event: The event to push into the stream
   - parameter key: _(Optional)_, the key to restrict the event.
   */
  func process(event: Event<T>, withKey key: EventPath = .share) {
    self.process(key: key, next: event) { (event, completion) in completion(event.signal) }
  }
  
  /**
   Preprocessing override function for subclasses. 
   Many subclasses need to access and sometime override or otherwise process incoming events & keys.
   This function allows them to do this. Whatever values are returned from this function will be used to processes.
   The function is called before the processing is occurred or events are passed into the stream op.
   
   - note: The Stream base class does not do any preprocessing, so there's no need to call `super` when overriding this function.
   
   - parameter event: the incoming event
   - parameter key: _Optional_.  The key for the incoming event.
   
   - returns: tuple<key: String?, event: Event<U>> : The key and event returned will be used for processing. If no event is returned, nothing will be processed.
   */
  func preProcess<U>(event: Event<U>) -> Event<U>? {
    return event
  }

  /**
    Designed to be overridden by subclasses that are being used as a pass through, normally to manipulate some other data.
    If this function returns false, the event will not be throttled even if a throttle is present.
    This really should only be used if the actual StreamOp is a passthrough and some other event type (ex: A ProgressEvent)
    needs to use the throttle.
  */
  func shouldThrottle<U>(event: Event<U>) -> Bool { return true }

  /**
    Designed to be overridden by subclasses that are being used as a pass through, normally to manipulate some other data.
    If this function returns false, the event will not be dispatched, but executed inline even if a dispatch is present.
    This really should only be used if the actual StreamOp is a passthrough and some other event type (ex: A ProgressEvent)
    needs to use the dispatch instead.
  */
  func shouldDispatch<U>(event: Event<U>) -> Bool { return true }

  /// Held to keep track of a termination that has entered the process, but has yet to finish processing.  It'll prevent other events from entering the process.
  var pendingTermination: (reason: Termination, prune: Prune, callTermHandler: Bool)? = nil
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
  func process<U>(key: EventPath, next: Event<U>, withOp op: @escaping StreamOp<U, T>) {
    guard isActive && pendingTermination == nil else { return }

    let work = {
      self.printDebug(info: "begin processing \(next)")
      var nextKey = key
      switch key {
      case .share: break
      case .end: return
      case .key(let key, let next):
        nextKey = next
        guard key == self.id else { return }
      }
      guard let event = self.preProcess(event: next) else { return }

      // Make sure we're receiving data, otherwise it's a termination event and we should set the terminateWork
      self.currentWork += 1
      
      // Abstract out the process work so it can be done inline or applied to a throttle
      let workProcessor: ThrottledWork = { signal in
        let throttleWork = {
          // If the throttle signal `.cancel` (not .perform), then we need to decrement current work and process the termination, if any
          guard case .perform(let completion) = signal else {
            let opSignal: OpSignal<T>
            if self.pendingTermination == nil, case .terminate(let term) = event {
              self.pendingTermination = (term, .none, false)
              opSignal = .terminate(nil, term)
            } else {
              opSignal = .cancel
            }
            self.currentWork -= 1

            self.postProcess(event: event, producedSignal: opSignal)
            self.printDebug(info: "throttle cancelled \(event)")
            return
          }

          op(event) { opSignal in
            let signalWork = {
              switch opSignal {
              case .push(let value): self.push(events: value.events, withKey: nextKey)
              case .error(let error): self.push(events: [.error(error)], withKey: nextKey)
              case let .terminate(value, term):
                if let events = value?.events {
                  self.push(events: events, withKey: nextKey)
                }
                if self.pendingTermination == nil {
                  if case .terminate = event {
                    self.pendingTermination = (term, .none, false)
                  } else {
                    self.pendingTermination = (term, .upStream, true)
                  }
                }
              case .cancel, .merging: break
              }

              self.currentWork -= 1

              self.postProcess(event: event, producedSignal: opSignal)
              self.printDebug(info: "end Processing \(event) ")

              completion()
            }

            if let dispatch = self.dispatch {
              dispatch.execute(signalWork)
            } else {
              signalWork()
            }

          }
        }

        if let dispatch = self.dispatch, self.shouldDispatch(event: next) {
          dispatch.execute(throttleWork)
        } else {
          throttleWork()
        }
      }
      
      if let throttle = self.throttle, self.shouldThrottle(event: next) {
        throttle.process(work: workProcessor)
      } else {
        workProcessor(.perform{ })
      }
    }

    if let dispatch = self.dispatch, self.shouldDispatch(event: next) {
      dispatch.execute(work)
    } else {
      work()
    }
  }
  
  /**
   Post-processing override function for subclassing.
   Many subclasses need access to the post-processed values that are returned from the stream's processor work.
   This function is called _after_ all values have been processed, pushed downstream and termination (if any) are processed.
   Override this class to gain access to these values.
   
   - parameter event: The initial event that was processed.
   - parameter events: All events returned from the stream processor.
   - parameter termination: _Optional_,  if a termination was processed, it will be returned here.  Note: If this is non-nil, then the stream has been terminated.
   */
  func postProcess<U>(event: Event<U>, producedSignal signal: OpSignal<T>) { }

  /// This will attempt to replay the last events, if any are found.  Otherwise, it will pass the request to it's parent.
  func replayLast(key: EventPath) {
    let work = {
      var events = self.current?.map{ Event.next($0) } ?? []
      self.termination >>? { events.append(.terminate(reason: $0)) }

      guard events.count > 0 else {
        self.parent?.replayLast(key: .key(self.id, next: key))
        self.rParent?.replayLast(key: .key(self.id, next: key))
        return
      }

      for event in events {
        self.printDebug(info: "replay event \(event)")

        for processor in self.downStreams {
          processor.process(next: event, withKey: key)
        }
      }
    }

    if let dispatch = self.dispatch {
      dispatch.execute(work)
    } else {
      work()
    }
  }
}

// MARK: Mutating Functions
extension Stream {
  
  /** 
   Allows you to set the dispatch as part of a chain operation to set the dispatch of the _next_ stream attached to this one.
   This is used so that whatever operation you chain _after_ this one, will be dispatched on the Dispatch you provide.
   This does not affect the _current_ stream.
   
   - parameter dispatch: The dispatch you wish the _next_ stream operation added to this one to operate on.
   
   - warning: The return `self` is not optional. A stream operation should be added after this.
   
   - returns: self
   */
  public func dispatch(_ dispatch: Dispatch) -> Self {
    self.nextDispatch = dispatch
    return self
  }
  
  /**
   This allows you to set dispatch on the _current_ stream.
   It does not affect any further operations added.
   
   - parameter dispatch: The dispatch you wish the _current_ stream to operate on.
   
   - returns: self
   */
  @discardableResult func dispatched(_ dispatch: Dispatch) -> Self {
    self.dispatch = dispatch
    return self
  }
  
  /**
   This will set a Throttle on the next stream/operation appended to this one.  
   It does not affect the _current_ stream.
   
   - parameter throttle: The throttle you wish to apply to the next stream.
   
   - returns: Self, for chaining
   */
  public func throttle(_ throttle: Throttle) -> Self {
    self.nextThrottle = throttle
    return self
  }

  /**
  This will crawl up the processing chain until it finds a valid last value and replay that value down the proessing chain.
  */
  @discardableResult public func replay(shared: Bool = true) -> Self {
    replayLast(key: shared ? .share : .end)
    return self
  }
  
  /**
   This will apply a throttle to the _current_ stream.
   
   - parameter throttle: The throttle to apply to this stream
   
   - returns: self, for chaining
   */
  @discardableResult public func throttled(_ throttle: Throttle) -> Self {
    self.throttle = throttle
    return self
  }
  
  /**
   This will cause the stream to be unable to replay values. This can be useful (and necessary) if you don't want the stream to retain the values passed down.
   This option will propagate to all new down streams added.  It does not propagate to existing streams already added before the parameter is set.
   
   - warning: This can directly impact some operations.  For example, transition observations rely on replayable streams.  If you set `canReplay` to false, then transitions will never provide the `prior` value needed.  Also, this will not block a replay request, so stored events upstream from this one can still replay back into this stream.
   
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
  
  /**
   Setting this to a closure will cause all debug information for this stream to be passed into the closure.
   - note: Set the `debugPrinter` property on this stream.
   - returns: Self for chaining
  */
  @discardableResult public func onDebugInfo(_ printer: ((String) -> Void)?) -> Self {
    self.debugPrinter = printer
    return self
  }


  /**
  This will override the debug description for the the stream, using for printing and for printing out debug info.
  */
  @discardableResult public func named(_ descriptor: String) -> Self {
    self.descriptor = descriptor
    return self
  }
  
}
