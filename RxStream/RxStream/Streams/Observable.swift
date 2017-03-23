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
  
  override func postProcess<U>(event: Event<U>, producedEvents events: [Event<T>], withTermination termination: Termination?) {
    if let value = events.lastEventValue {
      self.value = value
    }
  }
  
  /// The current value of the observable
  private(set) public var value: T
  
  /// Private initilization.  An Observable is not intended to be initialized directly, except by it's subclass.
  init(_ value: T) {
    self.value = value
    super.init()
    self.queue = (nil, value)
    persist()
  }
  
}

/**
 Is a producer for Observables.  This is the only class where an observable can have it's value set and pushed down stream.
  
 - note: When the ObservableInput is deinit, it will send a .complete termination event if the observable isn't already terminated.
 */
public class ObservableInput<T> : Observable<T> {
  
  /**
   Updates the Observable with the
   
   - parameter value: The value to set the observable to.
   - warning: If the Observable has been terminated, this function will fail to update the value
   - returns: self
   */
  @discardableResult public func set(_ value: T) -> Self {
    guard isActive else { return self }
    self.process(event: .next(value))
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
  
  public func terminate(withReason reason: Termination) {
    self.process(event: .terminate(reason: reason))
  }
  
  deinit {
    if self.isActive {
      self.process(event: .terminate(reason: .completed))
    }
  }
  
}
