//
//  Termination.swift
//  RxStream
//
//  Created by Aaron Hayman on 4/20/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

///Termination reason: Defines the reasons a stream can (or did) terminate
public enum Termination : Equatable {
  
  /// The stream has completed without any problems.
  case completed
  
  /// The stream has been explicitly cancelled.
  case cancelled
  
  /// An error has occurred and the stream is no longer viable.
  case error(Error)
}

public func ==(lhs: Termination, rhs: Termination) -> Bool {
  switch (lhs, rhs) {
  case (.completed, .completed),
       (.cancelled, .cancelled),
       (.error, .error): return true
  default: return false
  }
}

extension Termination : CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .completed: return ".completed"
    case .cancelled: return ".cancelled"
    case .error(let error): return ".error(\(error))"
    }
  }
}
