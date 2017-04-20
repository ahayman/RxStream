//
//  OpSignal.swift
//  RxStream
//
//  Created by Aaron Hayman on 4/20/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
 OpValue represents a value or flattened array of values returned as part of a OpSignal.
 We're using this enum embedded into the OpSignal in order to represent what events should be pushed down stream.
 It's necessary because both the .push and the .terminate can push events
 */
enum OpValue<T> {
  /// Represents a single value that should be pushed down stream
  case value(T)
  /// Represents an array of values that should be sequentially pushed down stream as individual events
  case flatten([T])
  
  /// Convenience function used to retrieve an array of the event
  var events: [Event<T>] {
    switch self {
    case .value(let value): return [.next(value)]
    case .flatten(let values): return values.map{ .next($0) }
    }
  }
}

/// Signal returned from stream operations. The Stream processor will use the signal to determine what it should do with the triggering event
enum OpSignal<T> {
  /// Map the event to a new value or a flattened
  case push(OpValue<T>)
  /// Event triggered an error
  case error(Error)
  /// Cancel the event.  Don't terminate or push anything into the down streams.
  case cancel
  /// Mainly used my merged Future, used to signal that a merge is pending
  case merging
  /// Event triggered termination with optional OpValue to be first pushed
  case terminate(OpValue<T>?, Termination)
}
