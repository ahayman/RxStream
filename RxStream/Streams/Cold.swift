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

  typealias ParentProcessor = (Request, EventPath) -> Void

  override var streamType: StreamType { return .cold }

  /// The processor responsible for filling a request.  It can either be a ColdTask or a ParentProcessor (a Parent stream that can handle fill the request).
  private var requestProcessor: Either<ColdTask, ParentProcessor>
  
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
    return Cold<U, Response>(op: "mapRequest<\(String(describing: Request.self))>"){ [weak self] (request: U, key: EventPath) in
      self?.process(request: mapper(request), withKey: key)
    }
  }
  
  /**
   A cold stream must be initialized with a Task that takes a request and returns a response. 
   A task should return only 1 response for each request.  All other responses will be ignored.
   */
  public init(task: @escaping ColdTask) {
    self.requestProcessor = Either(task)
    super.init(op: "Task")
  }
  
  init(op: String, processor: @escaping ParentProcessor) {
    self.requestProcessor = Either(processor)
    super.init(op: op)
  }
  
  private func make(request: Request, withKey key: EventPath, withTask task: @escaping ColdTask) {
    let work = {
      var key: EventPath? = key
      task(self.stateObservable, request) {
        guard let requestKey = key else { return }
        key = nil
        $0
          .onFailure { self.process(event: .error($0), withKey: requestKey) }
          .onSuccess { self.process(event: .next($0), withKey: requestKey) }
      }
    }

    if let dispatch = self.dispatch {
      dispatch.execute(work)
    } else {
      work()
    }
  }
  
  private func process(request: Request, withKey key: EventPath) {
    guard isActive else { return }
    let key: EventPath = .key(id, next: key)

    requestProcessor
      .onLeft{ self.make(request: request, withKey: key, withTask: $0) }
      .onRight{ $0(request, key) }
  }

  /**
    Make a request from this stream. The response will be passed back once the task has completed.
    - parameters:
      - request: The request object to submit to the stream's task
      - share: **default:** false: If false, then the response will end here.  If true, then the response will be passed to all attached streams.
  */
  public func request(_ request: Request, share: Bool = false) {
    process(request: request, withKey: share ? .share : .end)
  }

  /**
    Make a request from this stream. The response will be passed back once the task has completed.
    - parameter request: The request object to submit to the stream's task
  */
  public func request(_ request: Request) {
    process(request: request, withKey: .end)
  }
  
  /// Terminate the Cold Stream with a reason.
  public func terminate(withReason reason: Termination) {
    self.process(event: .terminate(reason: reason), withKey: .share)
  }
  
  deinit {
    if self.isActive {
      self.process(event: .terminate(reason: .completed))
    }
  }
}
