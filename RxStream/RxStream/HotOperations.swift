//
//  HotOperations.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/10/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

extension Hot {
  
  public func on(handler: @escaping (T) -> Void) -> Hot<T> {
    return appendOn(stream: Hot<T>(), handler: handler)
  }
  
  public func onTransition(handler: @escaping (_ prior: T?, _ next: T) -> Void) -> Hot<T> {
    return appendTransition(stream: Hot<T>(), handler: handler)
  }
  
  public func onTerminate(handler: @escaping (Termination) -> Void) -> Hot<T> {
    return appendOnTerminate(stream: Hot<T>(), handler: handler)
  }
  
  public func map<U>(mapper: @escaping (T) -> U?) -> Hot<U> {
    return appendMap(stream: Hot<U>(), withMapper: mapper)
  }
  
  public func map<U>(mapper: @escaping (T) -> Result<U>) -> Hot<U> {
    return appendMap(stream: Hot<U>(), withMapper: mapper)
  }
  
  public func map<U>(mapper: @escaping (_ value: T, _ completion: (Result<U>) -> Void) -> Void) -> Hot<U> {
    return appendMap(stream: Hot<U>(), withMapper: mapper)
  }
  
  public func flatMap<U>(_ mapper: @escaping (T) -> [U]) -> Hot<U> {
    return appendFlatMap(stream: Hot<U>(), withFlatMapper: mapper)
  }
  
  public func scan<U>(initial: U, scanner: @escaping (_ current: U, _ next: T) -> U) -> Hot<U> {
    return appendScan(stream: Hot<U>(), initial: initial, withScanner: scanner)
  }
  
  public func first(then: Termination = .completed) -> Hot<T> {
    return appendFirst(stream: Hot<T>(), then: then)
  }
  
  public func first(_ count: Int, partial: Bool = false, then: Termination = .completed) -> Hot<[T]> {
    return appendFirst(stream: Hot<[T]>(), count: count, partial: partial, then: then)
  }
  
  public func last() -> Hot<T> {
    return appendLast(stream: Hot<T>())
  }
  
  public func last(_ count: Int, partial: Bool = false) -> Hot<[T]> {
    return appendLast(stream: Hot<[T]>(), count: count, partial: partial)
  }
  
  public func reduce<U>(initial: U, reducer: @escaping (_ current: U, _ next: T) -> U) -> Hot<U> {
    return scan(initial: initial, scanner: reducer).last()
  }
  
  public func buffer(size: Int, partial: Bool = false) -> Hot<[T]> {
    return appendBuffer(stream: Hot<[T]>(), bufferSize: size, partial: partial)
  }
  
  public func window(size: Int, partial: Bool = false) -> Hot<[T]> {
    return appendWindow(stream: Hot<[T]>(), windowSize: size, partial: partial)
  }
  
  public func window(size: TimeInterval, limit: Int? = nil) -> Hot<[T]> {
    return appendWindow(stream: Hot<[T]>(), windowSize: size, limit: limit)
  }
  
  public func filter(include: @escaping (T) -> Bool) -> Hot<T> {
    return appendFilter(stream: Hot<T>(), include: include)
  }
  
  public func stride(_ stride: Int) -> Hot<T> {
    return appendStride(stream: Hot<T>(), stride: stride)
  }
  
  public func timeStamp() -> Hot<(Date, T)> {
    return appendTimeStamp(stream: Hot<(Date, T)>())
  }
  
  public func distinct(_ isDistinct: @escaping (T, T) -> Bool) -> Hot<T> {
    return appendDistinct(stream: Hot<T>(), isDistinct: isDistinct)
  }
 
  public func min(lessThan: @escaping (T, T) -> Bool) -> Hot<T> {
    return appendMin(stream: Hot<T>(), lessThan: lessThan)
  }
  
  public func max(greaterThan: @escaping (T, T) -> Bool) -> Hot<T> {
    return appendMax(stream: Hot<T>(), greaterThan: greaterThan)
  }
  
  public func count() -> Hot<UInt> {
    return appendCount(stream: Hot<UInt>())
  }
  
  public func delay(_ delay: TimeInterval) -> Hot<T> {
    return appendDelay(stream: Hot<T>(), delay: delay)
  }
  
  public func next(_ count: UInt = 1) -> Hot<T> {
    return appendNext(stream: Hot<T>(), count: count)
  }
  
  public func start(with: [T]) -> Hot<T> {
    return appendStart(stream: Hot<T>(), startWith: with)
  }
  
  public func concat(_ concat: [T]) -> Hot<T> {
    return appendConcat(stream: Hot<T>(), concat: concat)
  }
  
  public func defaultValue(_ value: T) -> Hot<T> {
    return appendDefault(stream: Hot<T>(), value: value)
  }
}

// MARK: Combining operators
extension Hot {
  
  public func merge<U>(_ stream: Stream<U>) -> Hot<Either<T, U>> {
    return appendMerge(stream: stream, intoStream: Hot<Either<T, U>>())
  }
  
  public func merge(_ stream: Stream<T>) -> Hot<T> {
    return appendMerge(stream: stream, intoStream: Hot<T>())
  }
  
  public func zip<U>(_ stream: Stream<U>, buffer: Int? = nil) -> Hot<(T, U)> {
    return appendZip(stream: stream, intoStream: Hot<(T, U)>(), buffer: buffer)
  }
  
  public func combine<U>(latest: Bool = true, stream: Stream<U>) -> Hot<(T, U)> {
    return appendCombine(stream: stream, intoStream: Hot<(T, U)>(), latest: latest)
  }
  
}

// MARK: Lifetime operators
extension Hot {
  
  public func doWhile(then: Termination = .completed, handler: @escaping (T) -> Bool) -> Hot<T> {
    return appendWhile(stream: Hot<T>(), handler: handler, then: then)
  }
  
  public func until(then: Termination = .completed, handler: @escaping (T) -> Bool) -> Hot<T> {
    return appendUntil(stream: Hot<T>(), handler: handler, then: then)
  }
  
  public func doWhile(then: Termination = .completed, handler: @escaping (_ prior: T?, _ next: T) -> Bool) -> Hot<T> {
    return appendWhile(stream: Hot<T>(), handler: handler, then: then)
  }
  
  public func until(then: Termination = .completed, handler: @escaping (_ prior: T?, _ next: T) -> Bool) -> Hot<T> {
    return appendUntil(stream: Hot<T>(), handler: handler, then: then)
  }
  
  public func using<U: AnyObject>(_ object: U, then: Termination = .completed) -> Hot<(U, T)> {
    return appendUsing(stream: Hot<(U, T)>(), object: object, then: then)
  }
  
  public func lifeOf<U: AnyObject>(_ object: U, then: Termination = .completed) -> Hot<T> {
    return appendUsing(stream: Hot<(U, T)>(), object: object, then: then).map{ $0.1 }
  }
  
}

extension Hot where T : Sequence {
  
  public func flatten() -> Hot<T.Iterator.Element> {
    return flatMap{ $0.map{ $0 } }
  }
  
}

extension Hot where T : Arithmetic {
  
  public func average() -> Hot<T> {
    return appendAverage(stream: Hot<T>())
  }
  
  public func sum() -> Hot<T> {
    return appendSum(stream: Hot<T>())
  }
  
}

extension Hot where T : Comparable {
  
  public func min(lessThan: @escaping (T, T) -> Bool) -> Hot<T> {
    return appendMin(stream: Hot<T>()) { $0 < $1 }
  }
  
  public func max(greaterThan: @escaping (T, T) -> Bool) -> Hot<T> {
    return appendMax(stream: Hot<T>()) { $0 > $1 }
  }
}
