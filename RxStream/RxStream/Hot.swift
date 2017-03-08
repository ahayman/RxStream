//
//  Hot.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/8/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

class Hot<T> : Stream<T> {
  
  fileprivate static func downStream<U,T>(of parent: Hot<U>, replay: Bool, withWork work: @escaping EventWork<U,T>) -> Hot<T> {
    let stream = Hot<T>(dispatch: parent.dispatch)
    parent.appendDownStream(replay: replay) { (prior, next) -> Bool in
      stream.process(prior: prior, next: next, withWork: work)
    }
    return stream
  }
  
  func on(replay: Bool = false, handler: @escaping (T) -> Bool) -> Hot<T> {
    return Hot.downStream(of: self, replay: replay) { (_, next, stream, completion) in
      if !handler(next) {
        stream.terminate(reason: .cancelled)
      }
      completion(next)
    }
  }
  
  func onTransition(replay: Bool = false, handler: @escaping (_ prior: T?, _ next: T) -> Bool) -> Hot<T> {
    return Hot.downStream(of: self, replay: replay) { (prior, next, stream, completion) in
      if !handler(prior, next) {
        stream.terminate(reason: .cancelled)
      }
      completion(next)
    }
  }
  
  func map<U>(replay: Bool = false, mapper: @escaping (T) -> U?) -> Hot<U> {
    return Hot.downStream(of: self, replay: replay) { (_, next, _, completion) in
      mapper(next) >>? { completion($0) }
    }
  }
  
  func map<U>(replay: Bool = false, mapper: @escaping (T) -> Result<U>) -> Hot<U> {
    return Hot.downStream(of: self, replay: replay) { (_, next, _, completion) in
      mapper(next)
        .onSuccess{ completion($0) }
        .onFailure{
          completion(nil)
          self.terminate(reason: .error($0))
        }
    }
  }
  
}

class HotInput<T> : Hot<T> {
  
}
