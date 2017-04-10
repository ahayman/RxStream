//
//  Cold.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/15/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

private enum Share {
  case shared
  case keyed
  case inherit
}

/// Type erasure protocol to make it easy to detect down stream ColdProcessors and increment/decrement their load.
protocol ColdLoadHandler {
  func incrementLoad(forKey key: String?)
  func decrementLoad(forKey key: String?)
}

/// Using this primarily to clean up event keys after the processing is down.  The down stream cold processors need to know that we've finished sending them streams for a key, so they can remove the key.
private class ColdProcessor<Request, Response, U> : DownstreamProcessor<Response, U>, ColdLoadHandler {
  
  func incrementLoad(forKey key: String?) {
    (stream as? Cold<Request, U>)?.incrementLoad(forKey: key)
  }

  func decrementLoad(forKey key: String?) {
    (stream as? Cold<Request, U>)?.decrementLoad(forKey: key)
  }
  
}

/**
 A Cold stream is a kind of stream that only produces values when it is asked to.
 A cold stream can be asked to produce a value by making a `request` anywhere down stream.
 It differs from other types of stream in that a cold stream will only produce one value per request.
 Moreover, the result of a request will _only_ be passed back down the chain that originally requested it.  
 This prevents other branches from receiving requests they did not ask for.
 */
public class Cold<Request, Response> : Stream<Response> {
  
  public typealias ColdTask = (_ state: Observable<StreamState>, _ request: Request, _ response: (Result<Response>) -> Void) -> Void

  typealias ParentProcessor = (Request, String) -> Void
  
  /// The processor responsible for filling a request.  It can either be a ColdTask or a ParentProcessor (a Parent stream that can handle fill the request).
  private var requestProcessor: Either<ColdTask, ParentProcessor>
  
  /// If this is set true, responses will be passed down to _all_ substreams
  private var shared: Share
  
  /** 
   Keys are stored until a appropriate event is received with the provided key, at which point it's removed.
   If a key is passed down with an event, that key must be present here in order to process.  Otherwise, the event should be ignored.
  */
  private var keys = Set<String>()
  
  /**
   Key pruning should only occur when the parent says it's done _and_ when this processor is done.
   This keeps track of the current processing level.
  */
  private var processing = [String:Int]()
  
  /// The promise needed to pass into the promise task.
  lazy private var stateObservable: ObservableInput<StreamState> = ObservableInput(self.state)
  
  /// Override and observe didSet to update the observable
  override public var state: StreamState {
    didSet {
      stateObservable.set(state)
    }
  }
  
  func newSubStream<U>(_ op: String) -> Cold<Request, U> {
    return Cold<Request, U>(op: op) { [weak self] (request, key) in
      self?.process(request: request, withKey: key)
    }
  }
  
  func newMappedRequestStream<U>(mapper: @escaping (U) -> Request) -> Cold<U, Response> {
    return Cold<U, Response>(op: "mapRequest"){ [weak self] (request: U, key: String) in
      self?.process(request: mapper(request), withKey: key)
    }
  }
  
  /**
   A cold stream must be initialized with a Task that takes a request and returns a response. 
   A task should return only 1 response for each request.  All other responses will be ignored.
   */
  public init(task: @escaping ColdTask) {
    self.requestProcessor = Either(task)
    self.shared = .keyed
    super.init(op: "Task")
  }
  
  init(op: String, processor: @escaping ParentProcessor) {
    self.requestProcessor = Either(processor)
    self.shared = .inherit
    super.init(op: op)
  }
  
  /**
   This will increment the current processing load for the provided key.
   If no prior load is set, we call all children in increment the load for the key.
   This prevents children from removing their keys until we are done processing, just as our parent, if any, will have done for us with the same code.
   */
  fileprivate func incrementLoad(forKey key: String?) {
    guard let key = key else { return }
    guard let current = processing[key] else {
      processing[key] = 1
      for case let processor as ColdLoadHandler in downStreams {
        processor.incrementLoad(forKey: key)
      }
      return
    }
    processing[key] = current + 1
  }
  
  /**
   Decrements the processing load for a key.
   This is called internally, when a keyed event is being processed, and it called by the parent when it's finished with all it's processing.
   Once the load reaches 0, this will decrement the load on all it's children.  
   */
  fileprivate func decrementLoad(forKey key: String?) {
    guard let key = key else { return }
    let current = (processing[key] ?? 1) - 1
    if current == 0 {
      processing[key] = nil
      keys.remove(key)
      for case let processor as ColdLoadHandler in downStreams {
        processor.decrementLoad(forKey: key)
      }
    } else {
      processing[key] = current
    }
  }
  
  /// We return a ColdProcessor to ensure proper load handling for keys
  override func newDownstreamProcessor<U>(forStream stream: Stream<U>, withProcessor processor: @escaping (Event<Response>, @escaping ([Event<U>]?) -> Void) -> Void) -> StreamProcessor<Response> {
    return ColdProcessor<Request, Response, U>(stream: stream, processor: processor)
  }
  
  /// Override the preprocessor to convert a key to properly respect whether or not this stream should share
  override func preProcess<U>(event: Event<U>, withKey key: EventKey) -> (key: EventKey, event: Event<U>)? {
    var eventToProcess: (key: EventKey, event: Event<U>)? = nil
    switch (shared, key) {
    case (.keyed, .shared(let id)):
      guard keys.contains(id) else { return nil }
      eventToProcess = (.keyed(id), event)
    case (.keyed, .keyed(let id)):
      guard keys.contains(id) else { return nil }
      eventToProcess = (key, event)
    case (.shared, .shared):
      eventToProcess = (key, event)
    case (.shared, .keyed(let id)):
      eventToProcess = (.shared(id), event)
    case (.inherit, .shared):
      eventToProcess = (key, event)
    case (.inherit, .keyed(let id)):
      guard keys.contains(id) else { return nil }
      eventToProcess = (key, event)
    case (_, .none):
      eventToProcess = (key, event)
    }
    
    incrementLoad(forKey: eventToProcess?.key.key)
    return eventToProcess
  }
  
  override func postProcess<U>(event: Event<U>, withKey key: EventKey, producedEvents events: [Event<Response>], withTermination termination: Termination?) {
    decrementLoad(forKey: key.key)
  }
  
  private func make(request: Request, withKey key: String, withTask task: ColdTask) {
    var key: String? = key
    task(self.stateObservable, request) {
      guard let requestKey = key else { return }
      key = nil
      $0
        .onFailure{ self.process(event: .error($0), withKey: .keyed(requestKey)) }
        .onSuccess{ self.process(event: .next($0), withKey: .keyed(requestKey)) }
    }
  }
  
  private func process(request: Request, withKey key: String) {
    guard isActive else { return }
    keys.insert(key)
    
    requestProcessor
      .onLeft{ self.make(request: request, withKey: key, withTask: $0) }
      .onRight{ $0(request, key) }
  }
  
  public func request(_ request: Request) {
   process(request: request, withKey: String.newUUID())
  }
  
  /**
   By default, only streams that make a request will receive a response. By setting `shared` to true, this stream will share its response to all down streams of it.
   
   - parameter share: Whether to share all responses with all downstreams
   
   - returns: Self
   */
  public func share(_ share: Bool = true) -> Self {
    self.shared = share ? .shared : .keyed
    return self
  }
  
  /// Terminate the Cold Stream with a reason.
  public func terminate(withReason reason: Termination) {
    self.process(event: .terminate(reason: reason), withKey: .none)
  }
  
  deinit {
    if self.isActive {
      self.process(event: .terminate(reason: .completed))
    }
  }
}
