//
//  Stream.swift
//  RxStream
//
//  Created by Aaron Hayman on 2/23/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/// Defines the base protocol for streams
public protocol Stream {
  /// The current data type the stream is handling
  associatedtype Data
  
  /// Provides a handler to observe new data coming through the stream
  func on(_ handler: (Self.Data) -> Bool) -> Self
  
  /// Provides a handler to observe changes in data coming through the stream. It is distinct from the `on` function by providing both the prior value and the new value in the stream.
  func onTransition(_ handler: (Self.Data?, Self.Data) -> Bool) -> Self
  
  /// Provides a handler that will fire when the stream is terminated, and provide the reason in the handler.
  func onTerminate(_ handler: (TerminationReason) -> Void) -> Self
}

///Termination reason: Defines the reasons a stream can terminate
public enum TerminationReason {
  /// The stream has completed without any problems.
  case completed
  
  /// The stream has been explicitly cancelled.
  case cancelled
  
  /// An error has occurred and the stream is no longer viable.
  case error(Error)
}

/// Defines the current state of the stream, which can be active (the stream is emitting data) or terminated with a reason.
public enum StreamState {
  /// The stream is currently active can can emit data
  case active
  
  /// The stream has been terminated with the provided reason.
  case terminated(reason: TerminationReason)
}

enum StreamEvent<T> {
  case next(T)
  case terminate(reason: TerminationReason)
}
