//
//  Cold.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/15/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

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
  private var shared: Bool = false
  
  /// The promise needed to pass into the promise task.
  lazy private var stateObservable: ObservableInput<StreamState> = ObservableInput(self.state)
  
  /// Override and observe didSet to update the observable
  override public var state: StreamState {
    didSet {
      stateObservable.set(state)
    }
  }
  
  func newSubStream<U>() -> Cold<Request, U> {
    return Cold<Request, U>{ [weak self] (request, key) in
      self?.process(request: request, withKey: key)
    }
  }
  
  public init(task: @escaping ColdTask) {
    self.requestProcessor = Either(task)
  }
  
  init(processor: @escaping ParentProcessor) {
    self.requestProcessor = Either(processor)
  }
  
  override func push(event: Event<Response>, withKey key: String?) {
    super.push(event: event, withKey: shared ? nil : key)
  }
  
  private func process(event: Event<Response>, withKey key: String?) {
    self.process(key: shared ? nil : key, prior: nil, next: event) { (_, event, completion) in
      switch event {
      case .next, .error: completion([event])
      case .terminate: completion(nil)
      }
    }
  }
  
  private func make(request: Request, withKey key: String, withTask task: ColdTask) {
    var key: String? = key
    task(self.stateObservable, request) {
      guard let requestKey = key else { return }
      key = nil
      $0
        .onFailure{ self.process(event: .error($0), withKey: requestKey) }
        .onSuccess{ self.process(event: .next($0), withKey: requestKey) }
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
    self.shared = share
    return self
  }
  
  /// Terminate the Cold Stream with a reason.
  public func terminate(withReason reason: Termination) {
    self.process(event: .terminate(reason: reason), withKey: nil)
  }
  
}
