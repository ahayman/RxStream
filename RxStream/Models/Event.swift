//
//  Event.swift
//  RxStream
//
//  Created by Aaron Hayman on 4/20/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
Events are passed down streams for processing.  They essentially represent either a value, a termination
or an error.
*/
public enum Event<T> {
  
  /// Next data to be passed down the streams
  case next(T)
  
  /// Stream terminate signal
  case terminate(reason: Termination)
  
  /// A non-terminating error event
  case error(Error)
  
  var eventValue: T? {
    if case .next(let value) = self { return value }
    return nil
  }
  
  /// Convenience function to transform the event into a default OpSignal with the same type
  var signal: OpSignal<T> {
    switch self {
    case .next(let value): return .push(.value(value))
    case .error(let error): return .error(error)
    case .terminate(let reason): return .terminate(nil, reason)
    }
  }
  
}

extension Event : CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .next(let value): return ".next(\(value))"
    case .error(let error): return ".error(\(error))"
    case .terminate(let reason): return ".terminate(reason: \(reason))"
    }
  }
}
