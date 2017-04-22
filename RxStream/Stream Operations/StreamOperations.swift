//
//  StreamOperations.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/10/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
 This file contains all the base stream operations that can be appended to another stream.
 */

// Mark: Operations
extension Stream {
  
  func appendNewStream<U: BaseStream>(stream: U) -> U where U.Data == T {
    return append(stream: stream) { (next, completion) in
      completion(next.signal)
    }
  }
  
  func appendOnError<U: BaseStream>(stream: U, handler: @escaping (Error) -> Void) -> U where U.Data == T {
    return append(stream: stream) { (next, completion) in
      switch next {
      case .next, .terminate: completion(next.signal)
      case .error(let error):
        handler(error)
        completion(.error(error))
      }
    }
  }
  
  func appendMapError<U: BaseStream>(stream: U, handler: @escaping (Error) -> Termination?) -> U where U.Data == T {
    return append(stream: stream) { (next, completion) in
      switch next {
      case .next, .terminate: completion(next.signal)
      case .error(let error):
        if let termination = handler(error) {
          completion(.terminate(nil, termination))
        } else {
          completion(.error(error))
        }
      }
    }
  }
  
  func appendOn<U: BaseStream>(stream: U, handler: @escaping (U.Data) -> Void) -> U where U.Data == T {
    return append(stream: stream) { (next, completion) in
      if case .next(let value) = next {
        handler(value)
      }
      completion(next.signal)
    }
  }
  
  func appendTransition<U: BaseStream>(stream: U, handler: @escaping (U.Data?, U.Data) -> Void) -> U where U.Data == T {
    var prior: T? = nil
    return append(stream: stream) { (next, completion) in
      if case .next(let value) = next {
        handler(prior, value)
        prior = value
      }
      completion(next.signal)
    }
  }
  
  func appendOnTerminate<U: BaseStream>(stream: U, handler: @escaping (Termination) -> Void) -> U where U.Data == T {
    return append(stream: stream) { (next, completion) in
      if case .terminate(let reason) = next {
        handler(reason)
      }
      completion(next.signal)
    }
  }
  
  func appendTerminateOn<U: BaseStream>(stream: U, handler: @escaping (T) -> Termination?) -> U where U.Data == T {
    return append(stream: stream) { (next, completion) in
      if
        case .next(let value) = next,
        let term = handler(value)
      {
        completion(.terminate(nil, term))
      } else {
        completion(next.signal)
      }
    }
  }
  
  func appendMap<U: BaseStream>(stream: U, withMapper mapper: @escaping (T) -> U.Data?) -> U {
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value): completion((mapper(value) >>? { .push(.value($0)) }) ?? .cancel )
      case .error(let error): completion(.error(error))
      case .terminate(let term): completion(.terminate(nil, term))
      }
    }
  }
  
  func appendMap<U: BaseStream>(stream: U, withMapper mapper: @escaping (T) -> Result<U.Data>) -> U {
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        mapper(value)
          .onSuccess{ completion(.push(.value($0))) }
          .onFailure{ completion(.error($0)) }
      case .error(let error): completion(.error(error))
      case .terminate(let term): completion(.terminate(nil, term))
      }
    }
  }
  
  func appendMap<U: BaseStream>(stream: U, withMapper mapper: @escaping (T, @escaping (Result<U.Data>?) -> Void) -> Void) -> U {
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        mapper(value) {
          switch $0 {
          case .some(.success(let value)): completion(.push(.value(value)))
          case .some(.failure(let error)): completion(.error(error))
          case .none: completion(.cancel)
          }
        }
      case .error(let error): completion(.error(error))
      case .terminate(let term): completion(.terminate(nil, term))
      }
    }
  }
  
  func appendFlatMap<U: BaseStream>(stream: U, withFlatMapper mapper: @escaping (T) -> [U.Data]) -> U {
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value): completion(.push(.flatten(mapper(value))))
      case .error(let error): completion(.error(error))
      case .terminate(let term): completion(.terminate(nil, term))
      }
    }
  }
  
  func appendScan<U: BaseStream>(stream: U, initial: U.Data, withScanner scanner: @escaping (U.Data, T) -> U.Data) -> U {
    var reduction: U.Data = initial
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
          reduction = scanner(reduction, value)
          completion(.push(.value(reduction)))
      case .error(let error): completion(.error(error))
      case .terminate(let term): completion(.terminate(nil, term))
      }
    }
  }
  
  func appendFirst<U: BaseStream>(stream: U, count: Int, then: Termination) -> U where U.Data == T {
    let first = max(1, count)
    var count = 0
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        count += 1
        switch count {
        case 0..<first: completion(next.signal)
        case first: completion(.terminate(.value(value), then))
        default: completion(.cancel)
        }
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendLast<U: BaseStream>(stream: U) -> U where U.Data == T {
    var last: T? = nil
    return append(stream: stream) { (next, completion) in
      switch next {
      case .next(let value):
        last = value
        completion(.cancel)
      case .error(let error):
        completion(.error(error))
      case .terminate(let term):
        completion(.terminate(last >>? { .value($0) }, term))
      }
    }
  }
  
  func appendLast<U: BaseStream>(stream: U, count: Int, partial: Bool) -> U where U.Data == T {
    var buffer = CircularBuffer<T>(size: max(1, count))
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        buffer.append(value)
        completion(.cancel)
      case .error(let error): completion(.error(error))
      case .terminate(let term):
        guard buffer.count == count || partial else { return completion(next.signal) }
        completion(.terminate(.flatten(buffer.map{$0}), term))
      }
    }
  }
  
  func appendBuffer<U: BaseStream>(stream: U, bufferSize: Int, partial: Bool) -> U where U.Data == [T] {
    let size = Int(max(1, bufferSize)) - 1
    var buffer: U.Data = []
    buffer.reserveCapacity(size)
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        if buffer.count < size {
          buffer.append(value)
          completion(.cancel)
        } else {
          let filledBuffer = buffer + [value]
          buffer.removeAll(keepingCapacity: true)
          completion(.push(.value(filledBuffer)))
        }
      case .error(let error): completion(.error(error))
      case .terminate(let term): completion(.terminate(partial ? .value(buffer) : nil, term))
      }
    }
  }
  
  func appendWindow<U: BaseStream>(stream: U, windowSize: Int, partial: Bool) -> U where U.Data == [T] {
    let windowSize = max(1, windowSize)
    var buffer = CircularBuffer<T>(size: windowSize)
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        buffer.append(value)
        if buffer.count < windowSize && !partial {
          completion(.cancel)
        } else {
          let window = buffer.map{ $0 } as U.Data
          completion(.push(.value(window)))
        }
      case .error(let error): completion(.error(error))
      case .terminate(let term):
        completion(.terminate( partial && buffer.count < windowSize ? .value(buffer.map{$0}) : nil, term))
      }
    }
  }
  
  func appendWindow<U: BaseStream>(stream: U, windowSize: TimeInterval, limit: Int?) -> U where U.Data == [T] {
    var buffer = [(TimeInterval, T)]()
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        let now = Date.timeIntervalSinceReferenceDate
        buffer.append((now, value))
        buffer = buffer.filter{ now - $0.0 < windowSize }
        if let limit = limit, buffer.count > limit {
          buffer = ((buffer.count - limit)..<buffer.count).map{ buffer[$0] }
        }
        completion(.push(.value(buffer.map{$0.1})))
      case .error(let error): completion(.error(error))
      case .terminate(let term): completion(.terminate(nil, term))
      }
    }
  }
  
  func appendFilter<U: BaseStream>(stream: U, include: @escaping (T) -> Bool) -> U where U.Data == T {
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value): completion(include(value) ? .push(.value(value)) : .cancel)
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendStride<U: BaseStream>(stream: U, stride: Int) -> U where U.Data == T {
    let stride = max(1, stride)
    var current = 0
    return append(stream: stream) { (next, completion) in
      switch next {
      case .next:
        current += 1
        if stride == current {
          current = 0
          completion(next.signal)
        } else {
          completion(.cancel)
        }
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendStamp<U: BaseStream, V>(stream: U, stamper: @escaping (T) -> V) -> U where U.Data == (value: T, stamp: V) {
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value): completion(.push(.value(value: value, stamp: stamper(value))))
      case .error(let error): completion(.error(error))
      case .terminate(let term): completion(.terminate(nil, term))
      }
    }
  }
  
  func appendDistinct<U: BaseStream>(stream: U, isDistinct: @escaping (T, T) -> Bool) -> U where U.Data == T {
    var prior: T? = nil
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        guard let priorVal = prior else {
          prior = value
          return completion(next.signal)
        }
        prior = value
        completion(isDistinct(priorVal, value) ? next.signal : .cancel)
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendMin<U: BaseStream>(stream: U, lessThan: @escaping (T, T) -> Bool) -> U where U.Data == T {
    var min: T? = nil
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        guard let prior = min, !lessThan(value, prior) else {
          min = value
          return completion(next.signal)
        }
        completion(.cancel)
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendMax<U: BaseStream>(stream: U, greaterThan: @escaping (T, T) -> Bool) -> U where U.Data == T {
    var max: T? = nil
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
          guard let prior = max, !greaterThan(value, prior) else {
            max = value
            return (completion(next.signal))
          }
          completion(.cancel)
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendCount<U: BaseStream>(stream: U) -> U where U.Data == UInt {
    var count: UInt = 0
    return append(stream: stream) { (next, completion) in
      switch next {
      case .next:
        count += 1
        completion(.push(.value(count)))
      case .error(let error): completion(.error(error))
      case .terminate(let term): completion(.terminate(nil, term))
      }
    }
  }
  
  func appendDelay<U: BaseStream>(stream: U, delay: TimeInterval) -> U where U.Data == T {
    return append(stream: stream) { (next, completion) in
      Dispatch.after(delay: delay, on: .main).execute{ completion(next.signal) }
    }
  }
  
  func appendSkip<U: BaseStream>(stream: U, count: Int) -> U where U.Data == T {
    var count = max(0, count)
    return append(stream: stream) { (next, completion) in
      switch next {
      case .next:
        guard count > 0 else { return completion(next.signal) }
        count -= 1
        completion(.cancel)
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendNext<U: BaseStream>(stream: U, count: UInt, then: Termination) -> U where U.Data == T {
    var count = max(1, count)
    
    return append(stream: stream) { (next, completion) in
      switch next {
      case .next(let value):
        count -= 1
        if count > 0 {
          completion(next.signal)
        } else if count == 0 {
          completion(.terminate(.value(value), then))
        } else {
          completion(.cancel)
        }
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendShift<U: BaseStream>(stream: U, shifted: Int, flush: Bool) -> U where U.Data == T {
    var buffer = CircularBuffer<T>(size: shifted)
    return append(stream: stream) { (next, completion) in
      switch next {
      case .next(let value):
        guard
          buffer.count == buffer.size,
          let shiftedValue = buffer.last
        else {
          return completion(.cancel)
        }
        buffer.append(value)
        completion(.push(.value(shiftedValue)))
      case .error(let error):
        completion(.error(error))
      case .terminate(let term):
        completion(.terminate(flush && !buffer.isEmpty ? .flatten(buffer.map{$0}) : nil, term))
      }
    }
  }
  
  func appendStart<U: BaseStream>(stream: U, startWith: [T]) -> U where U.Data == T {
    var start: [T]? = startWith
    return append(stream: stream) { (next, completion) in
      switch next {
      case .next(let value):
        if let events = start {
          completion(.push(.flatten(events + [value])))
          start = nil
        } else {
          completion(next.signal)
        }
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendConcat<U: BaseStream>(stream: U, concat: [T]) -> U where U.Data == T {
    return append(stream: stream) { (next, completion) in
      switch next {
      case .next, .error: completion(next.signal)
      case .terminate(let term): completion(.terminate(.flatten(concat), term))
      }
    }
  }
  
  func appendDefault<U: BaseStream>(stream: U, value: T) -> U where U.Data == T {
    var empty = true
    return append(stream: stream) { (next, completion) in
      switch next {
      case .next:
        empty = false
        completion(next.signal)
      case .error: completion(next.signal)
      case .terminate(let term):
        guard empty else { return completion(next.signal) }
        completion(.terminate(.value(value), term))
      }
    }
  }
}

// MARK: Combining Operators
extension Stream {
  
  func appendMerge<U: BaseStream, V>(stream: Stream<V>, intoStream mergedStream: U) -> U where U.Data == Either<T, V> {
    /*
     We manually keep track of terminations in order to preserve replay behavior.
     Terminations are always replayed so they won't be missed.
     Prior attempts to use the "other" stream's active state caused replay to fail if both streams were already terminated,
     which can happen frequently for types like Promise or Future.
    */
    var rightTerm: Termination? = nil
    var leftTerm: Termination? = nil

    configureStreamAsChild(stream: mergedStream, leftParent: true)
    stream.configureStreamAsChild(stream: mergedStream, leftParent: false)

    // Left Stream
    attachChildStream(stream: mergedStream) { (next, completion) in
      switch next {
      case let .next(value): completion(.push(.value(.left(value))))
      case .error(let error): completion(.error(error))
      case let .terminate(reason):
        leftTerm = reason
        completion(rightTerm == nil ? .merging : .terminate(nil, reason))
      }
    }

    // Right Stream
    return stream.attachChildStream(stream: mergedStream) { (next, completion) in
      switch next {
      case let .next(value): completion(.push(.value(.right(value))))
      case .error(let error): completion(.error(error))
      case let .terminate(reason):
        rightTerm = reason
        completion(leftTerm == nil ? .merging : .terminate(nil, reason))
      }
    }
  }
  
  func appendMerge<U: BaseStream>(stream: Stream<T>, intoStream mergedStream: U) -> U where U.Data == T {
    /*
     We manually keep track of terminations in order to preserve replay behavior.
     Terminations are always replayed so they won't be missed.
     Prior attempts to use the "other" stream's active state caused replay to fail if both streams were already terminated,
     which can happen frequently for types like Promise or Future.
    */
    var rightTerm: Termination? = nil
    var leftTerm: Termination? = nil

    configureStreamAsChild(stream: mergedStream, leftParent: true)
    stream.configureStreamAsChild(stream: mergedStream, leftParent: false)

    //Left Stream
    attachChildStream(stream: mergedStream) { (next, completion) in
      switch next {
      case .next, .error: completion(next.signal)
      case let .terminate(reason):
        leftTerm = reason
        completion(rightTerm == nil ? .merging : .terminate(nil, reason))
      }
    }

    //Right Stream
    return stream.attachChildStream(stream: mergedStream) { (next, completion) in
      switch next {
      case .next, .error: completion(next.signal)
      case let .terminate(reason):
        rightTerm = reason
        completion(leftTerm == nil ? .merging : .terminate(nil, reason))
      }
    }

  }
  
  func appendZip<U: BaseStream, V>(stream: Stream<V>, intoStream mergedStream: U, buffer: Int?) -> U where U.Data == (T, V) {
    var leftBuffer = [T]()
    var rightBuffer = [V]()
    /*
     We manually keep track of terminations in order to preserve replay behavior.
     Terminations are always replayed so they won't be missed.
     Prior attempts to use the "other" stream's active state caused replay to fail if both streams were already terminated,
     which can happen frequently for types like Promise or Future.
    */
    var rightTerm: Termination? = nil
    var leftTerm: Termination? = nil

    configureStreamAsChild(stream: mergedStream, leftParent: true)
    stream.configureStreamAsChild(stream: mergedStream, leftParent: false)

    // Left Stream
    attachChildStream(stream: mergedStream) { (next, completion) in
      switch next {
      case let .next(value):
        if rightBuffer.count > 0 {
          completion(.push(.value(value, rightBuffer.removeFirst())))
        } else {
          if let buffer = buffer, leftBuffer.count >= buffer {
            return completion(.merging)
          }
          leftBuffer.append(value)
          completion(.merging)
        }
      case .error(let error): completion(.error(error))
      case .terminate(let term):
        leftTerm = term
        if leftBuffer.count > 0 && rightTerm == nil {
          completion(.merging)
        } else {
          completion(.terminate(nil, term))
        }
      }
    }

    // Right Stream
    return stream.attachChildStream(stream: mergedStream) { (next, completion) in
      switch next {
      case let .next(value):
        if leftBuffer.count > 0 {
          completion(.push(.value(leftBuffer.removeFirst(), value)))
        } else {
          if let buffer = buffer, rightBuffer.count >= buffer {
            return completion(.merging)
          }
          rightBuffer.append(value)
          completion(.merging)
        }
      case .error(let error): completion(.error(error))
      case .terminate(let term):
        rightTerm = term
        if rightBuffer.count > 0 && leftTerm == nil {
          completion(.merging)
        } else {
          completion(.terminate(nil, term))
        }
      }
    }
    
  }
  
  func appendCombine<U: BaseStream, V>(stream: Stream<V>, intoStream mergedStream: U, latest: Bool) -> U where U.Data == (T, V) {
    var left: T? = nil
    var right: V? = nil
    /*
     We manually keep track of terminations in order to preserve replay behavior.
     Terminations are always replayed so they won't be missed.
     Prior attempts to use the "other" stream's active state caused replay to fail if both streams were already terminated,
     which can happen frequently for types like Promise or Future.
    */
    var rightTerm: Termination? = nil
    var leftTerm: Termination? = nil

    configureStreamAsChild(stream: mergedStream, leftParent: true)
    stream.configureStreamAsChild(stream: mergedStream, leftParent: false)

    // Left Stream
    attachChildStream(stream: mergedStream) { (next, completion) in
      switch next {
      case let .next(value):
        guard let rightValue = right else {
          left = value
          return completion(.merging)
        }
        if latest {
          left = value
        } else {
          left = nil
          right = nil
        }
        completion(.push(.value(value, rightValue)))
      case .error(let error): completion(.error(error))
      case let .terminate(term):
        leftTerm = term
        if latest && rightTerm == nil && left != nil {
          // Even thought the left stream has terminated, we still have a left value that can be used to emit combinations from new right values.
          completion(.merging)
        } else {
          completion(.terminate(nil, term))
        }
      }
    }

    // Right Stream
    return stream.attachChildStream(stream: mergedStream) { (next, completion) in
      switch next {
      case let .next(value):
        guard let leftValue = left else {
          right = value
          return completion(.merging)
        }
        if latest {
          right = value
        } else {
          left = nil
          right = nil
        }
        completion(.push(.value(leftValue, value)))
      case .error(let error): completion(.error(error))
      case .terminate(let term):
        rightTerm = term
        if latest && leftTerm == nil && right != nil {
          // Even thought the right stream has terminated, we still have a right value that can be used to emit combinations from new left values.
          completion(.merging)
        } else {
          completion(.terminate(nil, term))
        }
      }
    }
    
  }
  
}

// MARK: Lifetime Operators
extension Stream {
  
  func appendWhile<U: BaseStream>(stream: U, handler: @escaping (U.Data) -> Bool, then: Termination) -> U where U.Data == T {
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        if !handler(value) {
           completion(.terminate(nil, then))
        } else {
          completion(next.signal)
        }
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendUntil<U: BaseStream>(stream: U, handler: @escaping (U.Data) -> Bool, then: Termination) -> U where U.Data == T {
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        if handler(value) {
          completion(.terminate(nil, then))
        } else {
          completion(next.signal)
        }
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendUntil<U: BaseStream>(stream: U, handler: @escaping (T) -> Termination?) -> U where U.Data == T {
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        if let termination = handler(value) {
          completion(.terminate(nil, termination))
        } else {
          completion(next.signal)
        }
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendWhile<U: BaseStream>(stream: U, handler: @escaping (U.Data?, U.Data) -> Bool, then: Termination) -> U where U.Data == T {
    var prior: T? = nil
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        if !handler(prior, value) {
           completion(.terminate(nil, then))
        } else {
          completion(next.signal)
        }
        prior = value
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendUntil<U: BaseStream>(stream: U, handler: @escaping (U.Data?, U.Data) -> Bool, then: Termination) -> U where U.Data == T {
    var prior: T? = nil
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        if handler(prior, value) {
          completion(.terminate(nil, then))
        } else {
          completion(next.signal)
        }
        prior = value
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendUntil<U: BaseStream>(stream: U, handler: @escaping (T?, T) -> Termination?) -> U where U.Data == T {
    var prior: T? = nil
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        if let termination = handler(prior, value) {
          completion(.terminate(nil, termination))
        } else {
          completion(next.signal)
        }
        prior = value
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendUsing<U: BaseStream, V: AnyObject>(stream: U, object: V, then: Termination) -> U where U.Data == (V, T) {
    let box = WeakBox(object)
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        if let object = box.object {
          completion(.push(.value(object, value)))
        } else {
          completion(.terminate(nil, then))
        }
      case .error(let error): completion(.error(error))
      case .terminate(let term): completion(.terminate(nil, term))
      }
    }
  }
  
  func appendLifeOf<U: BaseStream, V: AnyObject>(stream: U, object: V, then: Termination) -> U where U.Data == T {
    let box = WeakBox(object)
    return append(stream: stream) { (next, completion) in
      switch next {
      case .next, .error:
        if box.object != nil {
          completion(next.signal)
        } else {
          completion(.terminate(nil, then))
        }
      case .terminate: completion(next.signal)
      }
    }
  }
  
}

extension Stream where T: Arithmetic {
  
  func appendAverage<U: BaseStream>(stream: U) -> U where U.Data == Data {
    var total = T(0)
    var count = T(0)
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        count = count + T(1)
        total = total + value
        completion(.push(.value(total / count)))
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
  func appendSum<U: BaseStream>(stream: U) -> U where U.Data == Data {
    var current = T(0)
    return append(stream: stream) { (next, completion) in
      switch next {
      case let .next(value):
        current = value + current
        completion(.push(.value(current)))
      case .error, .terminate: completion(next.signal)
      }
    }
  }
  
}
