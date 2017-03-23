//
//  Observable.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/10/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
 An Observable is a kind of Hot stream that retains and gives access to it's current value.
 
 - note: All operations of an observable will resolve to a Hot Stream, except for an extra `map` operation that returns a non-optional type, allowing you to map observables.
 - note: Observables will automatically persist themselves.
 */
public class Observable<T> : Stream<T> {
  
  /// Privately used to push new events down stream
  func push(event: Event<T>) {
    self.process(key: nil, prior: nil, next: event) { (_, event, completion) in
      if case .next(let value) = event {
        self.value = value
      }
      completion([event])
    }
  }
  
  /// The current value of the observable
  fileprivate(set) public var value: T
  
  /// Private initilization.  An Observable is not intended to be initialized directly, except by it's subclass.
  init(_ value: T) {
    self.value = value
    super.init()
    persist()
  }
  
}

public class ObservableInput<T> : Observable<T> {
  
  /**
   Updates the Observable with the
   
   - parameter value: The value to set the observable to.
   - warning: If the Observable has been terminated, this function will fail to update the value
   - returns: self
   */
  @discardableResult public func set(_ value: T) -> Self {
    guard isActive else { return self }
    self.push(event: .next(value))
    return self
  }
  
  /**
   Initialize the Observable with an initial value
   
   - parameter value: The initial value of the observable.
   
   - returns: A persistent observable
   */
  public override init(_ value: T) {
    super.init(value)
  }
  
}
