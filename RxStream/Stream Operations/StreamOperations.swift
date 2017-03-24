//
//  StreamOperations.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/10/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
 Merge Errors are thrown when one of the inputs to a merged stream is terminated.  
 */
public enum MergeError : Error {
  case left(Termination)
  case right(Termination)
}

/**
 This file contains all the base stream operations that can be appended to another stream.
 */

// Mark: Operations
extension Stream {
  
  func appendNewStream<U: BaseStream>(stream: U) -> U where U.Data == T {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next, .error: completion([next])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendOnError<U: BaseStream>(stream: U, handler: @escaping (Error) -> Void) -> U where U.Data == T {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next: completion([next])
      case .error(let error):
        handler(error)
        completion([next])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendMapError<U: BaseStream>(stream: U, handler: @escaping (Error) -> Termination?) -> U where U.Data == T {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next: completion([next])
      case .error(let error):
        if let termination = handler(error) {
          completion([.terminate(reason: termination)])
        } else {
          completion([next])
        }
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendOn<U: BaseStream>(stream: U, handler: @escaping (U.Data) -> Void) -> U where U.Data == T {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        handler(value)
        completion([next])
      case .error: completion([next])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendTransition<U: BaseStream>(stream: U, handler: @escaping (U.Data?, U.Data) -> Void) -> U where U.Data == T {
    return append(stream: stream) { (prior, next, completion) in
      switch next {
      case let .next(value):
        handler(prior, value)
        completion([next])
      case .error: completion([next])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendOnTerminate<U: BaseStream>(stream: U, handler: @escaping (Termination) -> Void) -> U where U.Data == T {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next: completion([next])
      case .error: completion([next])
      case let .terminate(reason):
        handler(reason)
        completion(nil)
      }
    }
  }
  
  func appendMap<U: BaseStream>(stream: U, withMapper mapper: @escaping (T) -> U.Data?) -> U {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value): completion((mapper(value) >>? { [.next($0)] }) ?? nil )
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendMap<U: BaseStream>(stream: U, withMapper mapper: @escaping (T) -> Result<U.Data>) -> U {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        mapper(value)
          .onSuccess{ completion([.next($0)]) }
          .onFailure{ completion([.error($0)]) }
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendMap<U: BaseStream>(stream: U, withMapper mapper: @escaping (T, @escaping (Result<U.Data>?) -> Void) -> Void) -> U {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        mapper(value) {
          if let result = $0 {
            result
              .onSuccess{ completion([.next($0)]) }
              .onFailure{ completion([.error($0)]) }
          } else {
            completion(nil)
          }
        }
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendFlatMap<U: BaseStream>(stream: U, withFlatMapper mapper: @escaping (T) -> [U.Data]) -> U {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value): completion(mapper(value).map{ .next($0) })
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendScan<U: BaseStream>(stream: U, initial: U.Data, withScanner scanner: @escaping (U.Data, T) -> U.Data) -> U {
    var reduction: U.Data = initial
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
          reduction = scanner(reduction, value)
          completion([.next(reduction)])
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendFirst<U: BaseStream>(stream: U, then: Termination) -> U where U.Data == T {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value): completion([.next(value), .terminate(reason: then)])
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendFirst<U: BaseStream>(stream: U, count: Int, then: Termination) -> U where U.Data == T {
    let first = max(1, count)
    var count = 0
    return append(stream: stream) { (_, next, completion) in
      var events: [Event<T>] = []
      switch next {
      case let .next(value):
        count += 1
        if count <= first {
          events.append(.next(value))
        }
        if count > first {
          events.append(.terminate(reason: then))
        }
        completion(events)
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendLast<U: BaseStream>(stream: U) -> U where U.Data == T {
    var last: Event<U.Data>? = nil
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next:
        last = next
        completion(nil)
      case .error(let error): completion([.error(error)])
      case .terminate:
        completion(last >>? { [$0] })
      }
    }
  }
  
  func appendLast<U: BaseStream>(stream: U, count: Int, partial: Bool) -> U where U.Data == T {
    var buffer = CircularBuffer<T>(size: max(1, count))
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        buffer.append(value)
        completion(nil)
      case .error(let error): completion([.error(error)])
      case .terminate:
        guard buffer.count == count || partial else { return completion(nil) }
        completion(buffer.map{ .next($0) })
      }
    }
  }
  
  func appendBuffer<U: BaseStream>(stream: U, bufferSize: Int, partial: Bool) -> U where U.Data == [T] {
    let size = Int(max(1, bufferSize)) - 1
    var buffer: U.Data = []
    buffer.reserveCapacity(size)
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        if buffer.count < size {
          buffer.append(value)
          completion(nil)
        } else {
          let filledBuffer = buffer + [value]
          buffer.removeAll(keepingCapacity: true)
          completion([.next(filledBuffer)])
        }
      case .error(let error): completion([.error(error)])
      case .terminate:
      guard partial else { return completion(nil) }
      completion([.next(buffer)])
      }
    }
  }
  
  func appendWindow<U: BaseStream>(stream: U, windowSize: Int, partial: Bool) -> U where U.Data == [T] {
    let windowSize = max(1, windowSize)
    var buffer = CircularBuffer<T>(size: windowSize)
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        buffer.append(value)
        if buffer.count < windowSize && !partial {
          completion(nil)
        } else {
          let window = buffer.map{ $0 } as U.Data
          completion([.next(window)])
        }
      case .error(let error): completion([.error(error)])
      case .terminate:
        if partial && buffer.count < windowSize {
          let window = buffer.map{ $0 } as U.Data
          completion([.next(window)])
        } else {
          completion(nil)
        }
      }
    }
  }
  
  func appendWindow<U: BaseStream>(stream: U, windowSize: TimeInterval, limit: Int?) -> U where U.Data == [T] {
    var buffer = [(TimeInterval, T)]()
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        let now = Date.timeIntervalSinceReferenceDate
        buffer.append((now, value))
        buffer = buffer.filter{ now - $0.0 < windowSize }
        if let limit = limit, buffer.count > limit {
          buffer = ((buffer.count - limit)..<buffer.count).map{ buffer[$0] }
        }
        completion([.next(buffer.map { $0.1 } as U.Data)])
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendFilter<U: BaseStream>(stream: U, include: @escaping (T) -> Bool) -> U where U.Data == T {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value): completion(include(value) ? [next] : nil)
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendStride<U: BaseStream>(stream: U, stride: Int) -> U where U.Data == T {
    let stride = max(1, stride)
    var current = 0
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next:
        current += 1
        if stride == current {
          current = 0
          completion([next])
        } else {
          completion(nil)
        }
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendStamp<U: BaseStream, V>(stream: U, stamper: @escaping (T) -> V) -> U where U.Data == (value: T, stamp: V) {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value): completion([.next(value: value, stamp: stamper(value))])
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendDistinct<U: BaseStream>(stream: U, isDistinct: @escaping (T, T) -> Bool) -> U where U.Data == T {
    return append(stream: stream) { (prior, next, completion) in
      switch next {
      case let .next(value):
        guard let prior = prior else { return completion([next]) }
        completion(isDistinct(prior, value) ? [next] : nil)
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendMin<U: BaseStream>(stream: U, lessThan: @escaping (T, T) -> Bool) -> U where U.Data == T {
    var min: T? = nil
    return append(stream: stream) { (prior, next, completion) in
      switch next {
      case let .next(value):
        guard let prior = min ?? prior, !lessThan(value, prior) else {
          min = value
          return (completion([next]))
        }
        completion(nil)
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendMax<U: BaseStream>(stream: U, greaterThan: @escaping (T, T) -> Bool) -> U where U.Data == T {
    var max: T? = nil
    return append(stream: stream) { (prior, next, completion) in
      switch next {
      case let .next(value):
          guard let prior = max ?? prior, !greaterThan(value, prior) else {
            max = value
            return (completion([next]))
          }
          completion(nil)
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendCount<U: BaseStream>(stream: U) -> U where U.Data == UInt {
    var count: UInt = 0
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next:
        count += 1
        completion([.next(count)])
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendDelay<U: BaseStream>(stream: U, delay: TimeInterval) -> U where U.Data == T {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next: Dispatch.after(delay: delay, on: .main).execute{ completion([next]) }
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendSkip<U: BaseStream>(stream: U, count: Int) -> U where U.Data == T {
    var count = max(0, count)
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next:
        guard count > 0 else { return completion([next]) }
        count -= 1
        completion(nil)
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendNext<U: BaseStream>(stream: U, count: UInt, then: Termination) -> U where U.Data == T {
    var count = max(1, count)
    
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next:
        guard count > 0 else { return completion(nil) }
        count -= 1
        var events = [next]
        if count == 0 {
          events.append(.terminate(reason: then))
        }
        completion(events)
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendStart<U: BaseStream>(stream: U, startWith: [T]) -> U where U.Data == T {
    var start: [T]? = startWith
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next:
        if let events = start {
          completion(events.map{ .next($0) } + [next])
          start = nil
        } else {
          completion([next])
        }
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendConcat<U: BaseStream>(stream: U, concat: [T]) -> U where U.Data == T {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next: completion([next])
      case .error(let error): completion([.error(error)])
      case .terminate: completion(concat.map{ .next($0) })
      }
    }
  }
  
  func appendDefault<U: BaseStream>(stream: U, value: T) -> U where U.Data == T {
    var empty = true
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case .next:
        empty = false
        completion([next])
      case .error(let error): completion([.error(error)])
      case let .terminate(reason):
        guard empty, case .completed = reason else { return completion(nil) }
        completion([.next(value)])
      }
    }
  }
}

// MARK: Combining Operators
extension Stream {
  
  func appendMerge<U: BaseStream, V>(stream: Stream<V>, intoStream: U) -> U where U.Data == Either<T, V> {
    stream.append(stream: intoStream) { [weak self] (_, next, completion) in
      switch next {
      case let .next(value): completion([.next(.right(value))])
      case .error(let error): completion([.error(error)])
      case let .terminate(reason): completion(self?.isActive ?? false ? [.error(MergeError.right(reason))] : nil)
      }
    }
    return append(stream: intoStream) { [weak stream] (_, next, completion) in
      switch next {
      case let .next(value): completion([.next(.left(value))])
      case .error(let error): completion([.error(error)])
      case let .terminate(reason): completion(stream?.isActive ?? false ? [.error(MergeError.left(reason))] : nil)
      }
    }
  }
  
  func appendMerge<U: BaseStream>(stream: Stream<T>, intoStream: U) -> U where U.Data == T {
    stream.append(stream: intoStream) { [weak self] (_, next, completion) in
      switch next {
      case let .next(value): completion([.next(value)])
      case .error(let error): completion([.error(error)])
      case let .terminate(reason): completion(self?.isActive ?? false ? [.error(MergeError.right(reason))] : nil)
      }
    }
    return append(stream: intoStream) { [weak stream] (_, next, completion) in
      switch next {
      case let .next(value): completion([.next(value)])
      case .error(let error): completion([.error(error)])
      case let .terminate(reason): completion(stream?.isActive ?? false ? [.error(MergeError.left(reason))] : nil)
      }
    }
  }
  
  func appendZip<U: BaseStream, V>(stream: Stream<V>, intoStream: U, buffer: Int?) -> U where U.Data == (T, V) {
    var leftBuffer = [T]()
    var rightBuffer = [V]()
    
    // Right Stream
    stream.append(stream: intoStream) { (_, next, completion) in
      switch next {
      case let .next(value):
        if leftBuffer.count > 0 {
          completion([.next(leftBuffer.removeFirst(), value)])
        } else {
          if let buffer = buffer, rightBuffer.count >= buffer {
            return completion(nil)
          }
          rightBuffer.append(value)
          completion(nil)
        }
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
    
    // Left Stream
    return append(stream: intoStream) { (_, next, completion) in
      switch next {
      case let .next(value):
        if rightBuffer.count > 0 {
          completion([.next(value, rightBuffer.removeFirst())])
        } else {
          if let buffer = buffer, leftBuffer.count >= buffer {
            return completion(nil)
          }
          leftBuffer.append(value)
          completion(nil)
        }
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendCombine<U: BaseStream, V>(stream: Stream<V>, intoStream: U, latest: Bool) -> U where U.Data == (T, V) {
    var left: T? = nil
    var right: V? = nil
    
    // Right Stream
    stream.append(stream: intoStream) { [weak self] (_, next, completion) in
      switch next {
      case let .next(value):
        guard let leftValue = left else {
          right = value
          return completion(nil)
        }
        if latest {
          right = value
        } else {
          left = nil
          right = nil
        }
        completion([.next(leftValue, value)])
      case .error(let error): completion([.error(error)])
      case let .terminate(reason):
        if latest && self?.isActive ?? false && left != nil {
          // Even thought the right stream has terminated, we still have a left value that can be used to emit combinations. So the termination is converted into an error.
          completion([.error(MergeError.right(reason))])
        } else {
          completion(nil)
        }
      }
    }
    
    // Left Stream
    return append(stream: intoStream) { [weak stream] (_, next, completion) in
      switch next {
      case let .next(value):
        guard let rightValue = right else {
          left = value
          return completion(nil)
        }
        if latest {
          left = value
        } else {
          left = nil
          right = nil
        }
        completion([.next(value, rightValue)])
      case .error(let error): completion([.error(error)])
      case let .terminate(reason):
        if latest && stream?.isActive ?? false && right != nil {
          // Even thought the left stream has terminated, we still have a right value that can be used to emit combinations. So the termination is converted into an error.
          completion([.error(MergeError.left(reason))])
        } else {
          completion(nil)
        }
      }
    }
  }
  
}

// MARK: Lifetime Operators
extension Stream {
  
  func appendWhile<U: BaseStream>(stream: U, handler: @escaping (U.Data) -> Bool, then: Termination) -> U where U.Data == T {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        var events = [next]
        if !handler(value) {
          events = [.terminate(reason: then)]
        }
        completion(events)
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendUntil<U: BaseStream>(stream: U, handler: @escaping (U.Data) -> Bool, then: Termination) -> U where U.Data == T {
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        var events = [next]
        if handler(value) {
          events = [.terminate(reason: then)]
        }
        completion(events)
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendWhile<U: BaseStream>(stream: U, handler: @escaping (U.Data?, U.Data) -> Bool, then: Termination) -> U where U.Data == T {
    return append(stream: stream) { (prior, next, completion) in
      switch next {
      case let .next(value):
        var events = [next]
        if !handler(prior, value) {
          events = [.terminate(reason: then)]
        }
        completion(events)
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendUntil<U: BaseStream>(stream: U, handler: @escaping (U.Data?, U.Data) -> Bool, then: Termination) -> U where U.Data == T {
    return append(stream: stream) { (prior, next, completion) in
      switch next {
      case let .next(value):
        var events = [next]
        if handler(prior, value) {
          events = [.terminate(reason: then)]
        }
        completion(events)
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendUsing<U: BaseStream, V: AnyObject>(stream: U, object: V, then: Termination) -> U where U.Data == (V, T) {
    let box = WeakBox(object)
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        if let object = box.object {
          completion([.next(object, value)])
        } else {
          completion([.terminate(reason: then)])
        }
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendLifeOf<U: BaseStream, V: AnyObject>(stream: U, object: V, then: Termination) -> U where U.Data == T {
    let box = WeakBox(object)
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        if let _ = box.object {
          completion([.next(value)])
        } else {
          completion([.terminate(reason: then)])
        }
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
}

extension Stream where T: Arithmetic {
  
  func appendAverage<U: BaseStream>(stream: U) -> U where U.Data == Data {
    var total = T(0)
    var count = T(0)
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        count = count + T(1)
        total = total + value
        completion([.next(total / count)])
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
  func appendSum<U: BaseStream>(stream: U) -> U where U.Data == Data {
    var current = T(0)
    return append(stream: stream) { (_, next, completion) in
      switch next {
      case let .next(value):
        current = value + current
        completion([.next(current)])
      case .error(let error): completion([.error(error)])
      case .terminate: completion(nil)
      }
    }
  }
  
}
