//
// Created by Aaron Hayman on 9/28/17.
// Copyright (c) 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public extension Progress {

  /**
    ## Branching

    Attache a simple handler to observe when new Progress Events are emitted.

    - parameter handler: The handler takes a ProgressEvent and returns `Void`.  A new event will be emitted whenever the progress is updated from the task.

    - returns: A new Progress Stream of the same type.

    - warning: There is no guarantee the handler will be called on the main thread unless you specify the appropriate dispatch.  This is an important
    consideration if you are attempting to update a UI from the handler.
  */
  func onProgress(_ handler: @escaping (ProgressEvent<ProgressUnit>) -> Void) -> Progress<ProgressUnit, T> {
    let stream = append(stream: Progress<ProgressUnit, T>(op: "onProgress")) { (event,  completion) in completion(event.signal) }
    stream.onHandler = handler
    return stream
  }

  /**
    ## Branching

    This will map the progress events of this stream to a new progress event type.
    It does not map the final emitted value of the stream.

    - parameter mapper: Handler should take a progress event and map it to the new type.

    - returns: a new Progress Stream with the new ProgressEvent type.
  */
  func mapProgress<U>(_ mapper: @escaping (ProgressEvent<ProgressUnit>) -> ProgressEvent<U>) -> Progress<U, T> {
    let stream = append(stream: Progress<U, T>(op: "onProgress")) { (event: Event<T>, completion: @escaping (OpSignal<T>) -> Void) in completion(event.signal) }
    stream.progressMapper = { event in
      guard let event = event as? ProgressEvent<ProgressUnit> else { return nil }
      return mapper(event)
    }
    return stream
  }


  /**
   ## Branching

   Merge another Progress stream into this one, emitting the completed values from each string as a single tuple.

   Requires that you also map the progress events of each stream into a new progress event.  In most situations,
   the progress emitted from the mapper should be _additive_, that is, taking the current progress and totals
   of each event and adding them together to produce a total of both.  Of course, you are able to do whatever
   is appropriate for the situation.

   - parameter stream: The stream to combine into this one.
   - parameter progressMapper: Maps the progress of one or both streams into a new progress event.

   - returns: A new Progress Stream
   */
  @discardableResult public func combineProgress<U, R, P>(
    stream: Progress<R, U>,
    progressMapper mapper: @escaping (EitherAnd<ProgressEvent<ProgressUnit>, ProgressEvent<R>>) -> ProgressEvent<P>) -> Progress<P, (T, U)>
  {
    let combined = appendCombine(stream: stream, intoStream: Progress<P, (T, U)>(op: "combine(stream: \(stream))"), latest: true)
    var left: ProgressEvent<ProgressUnit>? = nil
    var right: ProgressEvent<R>? = nil

    self.onHandler = { left = $0 }
    stream.onHandler = { right = $0 }

    combined.progressMapper = { event in
      switch (event, left, right) {
      case let (left as ProgressEvent<ProgressUnit>, _, .some(right)): return mapper(.both(left, right))
      case let (right as ProgressEvent<R>, .some(left), _): return mapper(.both(left, right))
      case let (left as ProgressEvent<ProgressUnit>, _, .none): return mapper(.left(left))
      case let (right as ProgressEvent<R>, .none, _): return mapper(.right(right))
      default: return nil
      }
    }

    return combined
  }

}
