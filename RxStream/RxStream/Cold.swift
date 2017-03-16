//
//  Cold.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/15/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public class Cold<Request, Response> : Stream<Response> {
  
public typealias ColdTask = (_ state: Observable<StreamState>, _ request: Request, _ response: (Result<Response>) -> Void) -> Void
typealias ParentProcessor = (Request, String) -> Void
  
  private var requestProcessor: Either<ColdTask, ParentProcessor>
  
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
  
  private func push(event: Event<Response>, withKey key: String) {
    self.process(key: key, prior: nil, next: event) { (_, event, completion) in
      completion([event])
    }
  }
  
  private func make(request: Request, withKey key: String, withTask task: ColdTask) {
    var key: String? = key
    task(self.state, request) {
      guard let requestKey = key else { return }
      key = nil
      $0
        .onFailure{ self.push(event: .terminate(reason: .error($0)), withKey: requestKey) }
        .onSuccess{ self.push(event: .next($0), withKey: requestKey) }
    }
  }
  
  private func process(request: Request, withKey key: String) {
    keys.insert(key)
    
    requestProcessor
      .onLeft{ self.make(request: request, withKey: key, withTask: $0) }
      .onRight{ $0(request, key) }
  }
  
  public func request(_ request: Request) {
   process(request: request, withKey: String.newUUID())
  }
  
  
}
