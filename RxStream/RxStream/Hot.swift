//
//  Hot.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/8/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

public class Hot<T> : Stream<T> {
  
  public func on(handler: @escaping (T) -> Bool) -> Hot<T> {
    return append(stream: Hot<T>(), handler: handler)
  }
  
  public func onTransition(handler: @escaping (_ prior: T?, _ next: T) -> Bool) -> Hot<T> {
    return append(stream: Hot<T>(), handler: handler)
  }
  
  public func map<U>(mapper: @escaping (T) -> U?) -> Hot<U> {
    return append(stream: Hot<U>(), withMapper: mapper)
  }
  
  public func map<U>(mapper: @escaping (T) -> Result<U>) -> Hot<U> {
    return append(stream: Hot<U>(), withMapper: mapper)
  }
  
  public func map<U>(mapper: @escaping (_ value: T, _ completion: (Result<U>) -> Void) -> Void) -> Hot<U> {
    return append(stream: Hot<U>(), withMapper: mapper)
  }
  
  public func flatMap<U>(_ mapper: @escaping (T) -> [U]) -> Hot<U> {
    return append(stream: Hot<U>(), withFlatMapper: mapper)
  }
  
  public func scan<U>(initial: U, scanner: @escaping (_ current: U, _ next: T) -> U) -> Hot<U> {
    return append(stream: Hot<U>(), initial: initial, withScanner: scanner)
  }
  
  public func first() -> Hot<T> {
    return appendFirst(stream: Hot<T>())
  }
  
  public func first(_ count: Int, partial: Bool = false) -> Hot<[T]> {
    return appendFirst(stream: Hot<[T]>(), count: count, partial: partial)
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

class HotInput<T> : Hot<T> {
  
}
