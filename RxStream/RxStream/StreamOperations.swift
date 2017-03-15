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

/// The main function used to attach a stream to a parent stream along with the child's stream work
func append<T: BaseStream, U: BaseStream>(_ stream: U, toParent parent: T, op: @escaping StreamOp<T.Data, U.Data>) -> U {
  guard
    let child = stream as? Stream<U.Data>,
    let parent = parent as? Stream<T.Data>
    else { fatalError("Error attaching streams: All Streams must descencend from CoreStream.") }
  
  child.dispatch = parent.dispatch
  child.replay = parent.replay
  child.parent = parent
  
  if
    let cancelChild = stream as? Cancelable,
    let cancelParent = stream as? Cancelable
  {
    cancelChild.cancelParent = cancelParent
  }
  
  if
    let retryChild = stream as? Retriable,
    let retryParent = parent as? Retriable
  {
    retryChild.retryParent = retryParent
  }
  
  parent.appendDownStream { (prior, next) -> Bool in
    guard let next = next else { return child.isActive }
    return child.process(prior: prior, next: next, withOp: op)
  }
  child.terminationWork = { reason in
    op(nil, .terminate(reason: reason)) { _ in }
  }
  return stream
}

// Mark: Operations
extension Stream {
  
  func appendOn<U: BaseStream>(stream: U, handler: @escaping (U.Data) -> Void) -> U where U.Data == T {
    return append(stream, toParent: self) { (_, next, completion) in
      next.onValue { handler($0) }
      completion([next])
    }
  }
  
  func appendTransition<U: BaseStream>(stream: U, handler: @escaping (U.Data?, U.Data) -> Void) -> U where U.Data == T {
    return append(stream, toParent: self) { (prior, next, completion) in
      next.onValue { handler(prior, $0)  }
      completion([next])
    }
  }
  
  func appendOnTerminate<U: BaseStream>(stream: U, handler: @escaping (Termination) -> Void) -> U where U.Data == T {
    return append(stream, toParent: self) { (_, next, completion) in
      next.onTerminate{ handler($0) }
      completion(nil)
    }
  }
  
  func appendMap<U: BaseStream>(stream: U, withMapper mapper: @escaping (T) -> U.Data?) -> U {
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ mapper($0) >>? { completion([.next($0)]) } }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendMap<U: BaseStream>(stream: U, withMapper mapper: @escaping (T) -> Result<U.Data>) -> U {
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue {
          mapper($0)
            .onSuccess{ completion([.next($0)]) }
            .onFailure{ completion([.terminate(reason: .error($0))]) }
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendMap<U: BaseStream>(stream: U, withMapper mapper: @escaping (T, (Result<U.Data>?) -> Void) -> Void) -> U {
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue {
          mapper($0) {
            if let result = $0 {
              result
                .onSuccess{ completion([.next($0)]) }
                .onFailure{ completion([.terminate(reason: .error($0))]) }
            } else {
              completion(nil)
            }
          }
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendFlatMap<U: BaseStream>(stream: U, withFlatMapper mapper: @escaping (T) -> [U.Data]) -> U {
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ completion(mapper($0).map{ .next($0) }) }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendScan<U: BaseStream>(stream: U, initial: U.Data, withScanner scanner: @escaping (U.Data, T) -> U.Data) -> U {
    var reduction: U.Data = initial
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{
          reduction = scanner(reduction, $0)
          completion([.next(reduction)])
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendFirst<U: BaseStream>(stream: U, then: Termination) -> U where U.Data == T {
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ completion([.next($0), .terminate(reason: then)]) }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendFirst<U: BaseStream>(stream: U, count: Int, then: Termination) -> U where U.Data == T {
    let first = max(1, count)
    var count = 0
    return append(stream, toParent: self) { (_, next, completion) in
      var events: [Event<T>] = []
      next
        .onValue{
          count += 1
          if count < first {
            events.append(.next($0))
          }
          if count >= first {
            events.append(.terminate(reason: then))
          }
        }
      completion(events)
    }
  }
  
  func appendLast<U: BaseStream>(stream: U) -> U where U.Data == T {
    var last: Event<U.Data>? = nil
    return append(stream, toParent: self) { (_, next, completion) in
      switch next {
      case .next:
        last = next
        completion(nil)
      case .terminate:
        completion(last >>? { [$0] })
      }
    }
  }
  
  func appendLast<U: BaseStream>(stream: U, count: Int, partial: Bool) -> U where U.Data == T {
    var buffer = CircularBuffer<T>(size: max(1, count))
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{
          buffer.append($0)
          completion(nil)
        }
        .onTerminate{ _ in
          guard buffer.count == count || partial else { return completion(nil) }
          completion(buffer.map{ .next($0) })
      }
    }
  }
  
  func appendBuffer<U: BaseStream>(stream: U, bufferSize: Int, partial: Bool) -> U where U.Data == [T] {
    let size = Int(max(1, bufferSize)) - 1
    var buffer: U.Data = []
    buffer.reserveCapacity(size)
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue {
          if buffer.count < size {
            buffer.append($0)
            completion(nil)
          } else {
            let filledBuffer = buffer + [$0]
            buffer.removeAll(keepingCapacity: true)
            completion([.next(filledBuffer)])
          }
        }
        .onTerminate{ _ in
          guard partial else { return completion(nil) }
          completion([.next(buffer)])
      }
    }
  }
  
  func appendWindow<U: BaseStream>(stream: U, windowSize: Int, partial: Bool) -> U where U.Data == [T] {
    let windowSize = max(1, windowSize)
    var buffer = CircularBuffer<T>(size: windowSize)
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{
          buffer.append($0)
          if buffer.count < windowSize {
            completion(nil)
          } else {
            let window = buffer.map{ $0 } as U.Data
            completion([.next(window)])
          }
        }
        .onTerminate{ _ in
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
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{
          let now = Date.timeIntervalSinceReferenceDate
          buffer.append((now, $0))
          buffer = buffer.filter{ now - $0.0 < windowSize }
          if let limit = limit, buffer.count > limit {
            buffer = ((buffer.count - limit)..<buffer.count).map{ buffer[$0] }
          }
          completion([.next(buffer.map { $0.1 } as U.Data)])
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendFilter<U: BaseStream>(stream: U, include: @escaping (T) -> Bool) -> U where U.Data == T {
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ completion(include($0) ? [next] : nil) }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendStride<U: BaseStream>(stream: U, stride: Int) -> U where U.Data == T {
    let stride = max(1, stride)
    var current = 0
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ _ in
          current += 1
          if stride == current {
            current = 0
            completion([next])
          } else {
            completion(nil)
          }
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendStamp<U: BaseStream, V>(stream: U, stamper: @escaping (T) -> V) -> U where U.Data == (T, V) {
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ completion([.next($0, stamper($0))]) }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendDistinct<U: BaseStream>(stream: U, isDistinct: @escaping (T, T) -> Bool) -> U where U.Data == T {
    return append(stream, toParent: self) { (prior, next, completion) in
      next
        .onValue{
          guard let prior = prior else { return completion([next]) }
          completion(isDistinct(prior, $0) ? [next] : nil)
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendMin<U: BaseStream>(stream: U, lessThan: @escaping (T, T) -> Bool) -> U where U.Data == T {
    var min: T? = nil
    return append(stream, toParent: self) { (prior, next, completion) in
      next
        .onValue{
          guard let prior = min ?? prior, !lessThan($0, prior) else {
            min = $0
            return (completion([next]))
          }
          completion(nil)
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendMax<U: BaseStream>(stream: U, greaterThan: @escaping (T, T) -> Bool) -> U where U.Data == T {
    var max: T? = nil
    return append(stream, toParent: self) { (prior, next, completion) in
      next
        .onValue{
          guard let prior = max ?? prior, !greaterThan($0, prior) else {
            max = $0
            return (completion([next]))
          }
          completion(nil)
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendCount<U: BaseStream>(stream: U) -> U where U.Data == UInt {
    var count: UInt = 0
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ _ in
          count += 1
          completion([.next(count)])
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendDelay<U: BaseStream>(stream: U, delay: TimeInterval) -> U where U.Data == T {
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ _ in
          Dispatch.after(delay: delay, on: .main).execute{ completion([next]) }
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendSkip<U: BaseStream>(stream: U, count: Int) -> U where U.Data == T {
    var count = max(0, count)
    
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ _ in
          guard count > 0 else { return completion([next]) }
          count -= 1
          completion(nil)
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendNext<U: BaseStream>(stream: U, count: UInt, then: Termination) -> U where U.Data == T {
    var count = max(1, count)
    
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ _ in
          guard count > 0 else { return completion(nil) }
          count -= 1
          var events = [next]
          if count == 0 {
            events.append(.terminate(reason: then))
          }
          completion(events)
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendStart<U: BaseStream>(stream: U, startWith: [T]) -> U where U.Data == T {
    var start: [T]? = startWith
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ _ in
          if let events = start {
            completion(events.map{ .next($0) } + [next])
            start = nil
          } else {
            completion([next])
          }
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendConcat<U: BaseStream>(stream: U, concat: [T]) -> U where U.Data == T {
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ _ in completion([next]) }
        .onTerminate{ _ in completion(concat.map{ .next($0) }) }
    }
  }
  
  func appendDefault<U: BaseStream>(stream: U, value: T) -> U where U.Data == T {
    var empty = true
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ _ in
          empty = false
          completion([next])
        }
        .onTerminate{ reason in
          guard empty, case .completed = reason else { return completion(nil) }
          completion([.next(value)])
        }
    }
  }
}

// MARK: Combining Operators
extension Stream {
  
  func appendMerge<U: BaseStream, V>(stream: Stream<V>, intoStream: U) -> U where U.Data == Either<T, V> {
    _ = append(intoStream, toParent: self) { (_, next, completion) in
      next
        .onValue{ completion([.next(.left($0))]) }
        .onTerminate{ _ in completion(nil) }
    }
    return append(intoStream, toParent: stream) { (_, next, completion) in
      next
        .onValue{ completion([.next(.right($0))]) }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendMerge<U: BaseStream>(stream: Stream<T>, intoStream: U) -> U where U.Data == T {
    _ = append(intoStream, toParent: stream) { (_, next, completion) in
      next
        .onValue{ completion([.next($0)]) }
        .onTerminate{ _ in completion(nil) }
    }
    return append(intoStream, toParent: self) { (_, next, completion) in
      next
        .onValue{ completion([.next($0)]) }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendZip<U: BaseStream, V>(stream: Stream<V>, intoStream: U, buffer: Int?) -> U where U.Data == (T, V) {
    var leftBuffer = [T]()
    var rightBuffer = [V]()
    
    // Right Stream
    _ = append(intoStream, toParent: stream) { (_, next, completion) in
      next
        .onValue{
          if leftBuffer.count > 0 {
            completion([.next(leftBuffer.removeFirst(), $0)])
          } else {
            if let buffer = buffer, rightBuffer.count >= buffer {
              return completion(nil)
            }
            rightBuffer.append($0)
            completion(nil)
          }
        }
        .onTerminate{ _ in completion(nil) }
    }
    
    // Left Stream
    return append(intoStream, toParent: self) { (_, next, completion) in
      next
        .onValue{
          if rightBuffer.count > 0 {
            completion([.next($0, rightBuffer.removeFirst())])
          } else {
            if let buffer = buffer, leftBuffer.count >= buffer {
              return completion(nil)
            }
            leftBuffer.append($0)
            completion(nil)
          }
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendCombine<U: BaseStream, V>(stream: Stream<V>, intoStream: U, latest: Bool) -> U where U.Data == (T, V) {
    var left: T? = nil
    var right: V? = nil
    
    // Right Stream
    _ = append(intoStream, toParent: stream) { (_, next, completion) in
      next
        .onValue{
          guard let leftValue = left else {
            right = $0
            return completion(nil)
          }
          if latest {
            right = $0
          } else {
            left = nil
            right = nil
          }
          completion([.next(leftValue, $0)])
        }
        .onTerminate{ _ in completion(nil) }
    }
    
    // Left Stream
    return append(intoStream, toParent: self) { (_, next, completion) in
      next
        .onValue{
          guard let rightValue = right else {
            left = $0
            return completion(nil)
          }
          if latest {
            left = $0
          } else {
            left = nil
            right = nil
          }
          completion([.next($0, rightValue)])
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
}

// MARK: Lifetime Operators
extension Stream {
  
  func appendWhile<U: BaseStream>(stream: U, handler: @escaping (U.Data) -> Bool, then: Termination) -> U where U.Data == T {
    return append(stream, toParent: self) { (_, next, completion) in
      var events = [next]
      next.onValue { value in
        if !handler(value) {
          events = [.terminate(reason: then)]
        }
      }
      completion(events)
    }
  }
  
  func appendUntil<U: BaseStream>(stream: U, handler: @escaping (U.Data) -> Bool, then: Termination) -> U where U.Data == T {
    return append(stream, toParent: self) { (_, next, completion) in
      var events = [next]
      next.onValue { value in
        if handler(value) {
          events = [.terminate(reason: then)]
        }
      }
      completion(events)
    }
  }
  
  func appendWhile<U: BaseStream>(stream: U, handler: @escaping (U.Data?, U.Data) -> Bool, then: Termination) -> U where U.Data == T {
    return append(stream, toParent: self) { (prior, next, completion) in
      var events = [next]
      next.onValue { value in
        if !handler(prior, value) {
          events = [.terminate(reason: then)]
        }
      }
      completion(events)
    }
  }
  
  func appendUntil<U: BaseStream>(stream: U, handler: @escaping (U.Data?, U.Data) -> Bool, then: Termination) -> U where U.Data == T {
    return append(stream, toParent: self) { (prior, next, completion) in
      var events = [next]
      next.onValue { value in
        if handler(prior, value) {
          events = [.terminate(reason: then)]
        }
      }
      completion(events)
    }
  }
  
  func appendUsing<U: BaseStream, V: AnyObject>(stream: U, object: V, then: Termination) -> U where U.Data == (V, T) {
    let box = WeakBox(object)
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ value in
          if let object = box.object {
            completion([.next(object, value)])
          } else {
            completion([.terminate(reason: then)])
          }
          
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
}

extension Stream where T: Arithmetic {
  
  func appendAverage<U: BaseStream>(stream: U) -> U where U.Data == Data {
    var total = T(0)
    var count = T(0)
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ value in
          count = count + T(1)
          total = total + value
          completion([.next(total / count)])
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
  func appendSum<U: BaseStream>(stream: U) -> U where U.Data == Data {
    var current = T(0)
    return append(stream, toParent: self) { (_, next, completion) in
      next
        .onValue{ value in
          current = value + current
          completion([.next(current)])
        }
        .onTerminate{ _ in completion(nil) }
    }
  }
  
}
