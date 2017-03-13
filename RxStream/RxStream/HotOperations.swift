//
//  HotOperations.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/10/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

extension Hot {
  
  /**
   ## Branching
   
   Attach a simple observation handler to the stream to observe new values.
   
   - parameter handler: The handler used to observe new values.
   
   - returns: A new Hot stream
   */
  public func on(_ handler: @escaping (T) -> Void) -> Hot<T> {
    return appendOn(stream: Hot<T>(), handler: handler)
  }
  
  /**
   ## Branching
   
   Attach an observation handler to the stream to observe transitions to new values. The handler includes the old value (if any) along with the new one.
   
   - parameter handler: The handler used to observe transitions between values.
   
   - returns: A new Hot Stream
   */
  public func onTransition(_ handler: @escaping (_ prior: T?, _ next: T) -> Void) -> Hot<T> {
    return appendTransition(stream: Hot<T>(), handler: handler)
  }
  
  /**
   ## Branching
   
   Attach an observation handler to observe termination events for the stream.
    
   - parameter handler: The handler used to observe the stream's termination.
   
   - returns: A new Hot Stream
   */
  public func onTerminate(_ handler: @escaping (Termination) -> Void) -> Hot<T> {
    return appendOnTerminate(stream: Hot<T>(), handler: handler)
  }
  
  /**
   ## Branching
    
   Map values in the current stream to new values returned in a new stream.
   
   - note: The mapper returns an optional type.  If the mapper returns `nil`, nothing will be passed down the stream, but the stream will continue to remain active.
   
   - parameter mapper: The handler to map the current type to a new type.
   
   - returns: A new Hot Stream
   */
  public func map<U>(_ mapper: @escaping (T) -> U?) -> Hot<U> {
    return appendMap(stream: Hot<U>(), withMapper: mapper)
  }
  
  /**
   ## Branching
   
   Map values in the current stream to new values returned in a new stream. 
   The mapper returns a result type that can return an error.  If an error is returned, the stream is terminated with that error.
   
   - parameter mapper: The handler to map the current value either to a new value or an error.
   
   - returns: A new Hot Stream
   */
  public func map<U>(_ mapper: @escaping (T) -> Result<U>) -> Hot<U> {
    return appendMap(stream: Hot<U>(), withMapper: mapper)
  }
  
  /**
   ## Branching
   
   Map values _asynchronously_ to either a new value, or else an error.
   The handler should take the current value along with a completion handler.
   Once ready, the completion handler should be called with:
   
    - New Value:  New values will be passed down stream
    - Error: An error will terminate the stream with the error provided
    - `nil`: Passing `nil` into will complete the handler but pass nothing down stream.
   
   - warning: The completion handler must _always_ be called, even if it's called with `nil`.  Failing to call the completion handler will block the stream, prevent it from being terminated, and will result in memory leakage.
   
   - parameter mapper: The mapper takes a value and a comletion handler.  
   
   - returns: A new Hot Stream
   */
  public func map<U>(_ mapper: @escaping (_ value: T, _ completion: (Result<U>?) -> Void) -> Void) -> Hot<U> {
    return appendMap(stream: Hot<U>(), withMapper: mapper)
  }
  
  /**
   ## Branching
   
   Map values to an array of values that are emitted sequentially in a new stream.
   
   - parameter mapper: The mapper should take a value and map it to an array of new values. The array of values will be emitted sequentially in the returned stream.
   
   - returns: A new Hot Stream
   */
  public func flatMap<U>(_ mapper: @escaping (T) -> [U]) -> Hot<U> {
    return appendFlatMap(stream: Hot<U>(), withFlatMapper: mapper)
  }
  
  /**
   ## Branching
   
   Take an initial current value and pass it into the handler, which should return a new value. 
   This value is passed down stream and used as the new current value that will be passed into the handler when the next value is received.
   This is similar to the functional type `reduce` except each calculation is passed down stream. 
   As an example, you could use this function to create a running balance of the values passed down (by adding `current` to `next`).
   
   - parameter initial: The initial value.  Will be passed into the handler as `current` for the first new value that arrives from the current stream.
   - parameter scanner: Take the current reduction (either initial or last value returned from the handler), the next value from the stream and returns a new value.
   
   - returns: A new Hot Stream
   */
  public func scan<U>(initial: U, scanner: @escaping (_ current: U, _ next: T) -> U) -> Hot<U> {
    return appendScan(stream: Hot<U>(), initial: initial, withScanner: scanner)
  }
  
  /**
   ## Branching
   
   Returns the first value emitted from the stream and terminates the stream.
   By default the stream is `.cancelled`, but this can be overriden by specifying the termination.
   
   - parameter then: **Default**: `.cancelled`. After the value has emitted, the stream will be terminated with this reason.
   
   - returns: A new Hot Stream
   */
  public func first(then: Termination = .cancelled) -> Hot<T> {
    return appendFirst(stream: Hot<T>(), then: then)
  }
  
  /**
   ## Branching
   
   Returns the first "n" values emitted and then terminate the stream.
   By default the stream is `.cancelled`, but this can be overriden by specifying the termination.
   
   - parameter count: The number of values to emit before terminating the stream.
   - parameter then: **Default:** `.cancelled`. After the values have been emitted, the stream will terminate with this reason.
   
   - returns: A new Hot Stream
   */
  public func first(_ count: Int, then: Termination = .cancelled) -> Hot<T> {
    return appendFirst(stream: Hot<T>(), count: count, then: then)
  }
  
  /**
   ## Branching
   
   Emits only the last value of the stream when it terminates.
   
   - returns: A new Hot Stream
   */
  public func last() -> Hot<T> {
    return appendLast(stream: Hot<T>())
  }
  
  /**
   ## Branching
   
   Emits the last "n" values of the stream when it terminates.
   The values are emitted sequentialy in the order they were received.
   
   - parameter count: The number of items to emit.
   - parameter partial: **Default:** `true`. If the stream terminates before the full count has been received, partial determines whether the partial set should be emitted.  
   
   - returns: A new Hot Stream
   */
  public func last(_ count: Int, partial: Bool = true) -> Hot<T> {
    return appendLast(stream: Hot<T>(), count: count, partial: partial)
  }
  
  /**
   ## Branching
   
   This will reduce all values in the stream using the `reducer` passed in.  The reduction is emitted when the stream terminates.
   This has the same format as `scan` and, in fact, does the same thing except intermediate values are not emitted.
   
   - parameter initial: The initial value.  Will be passed into the handler as `current` for the first new value that arrives from the current stream.
   - parameter reducer: Take the current reduction (either initial or last value returned from the handler), the next value from the stream and returns a new value.
   
   - returns: A new Hot Stream
   */
  public func reduce<U>(initial: U, reducer: @escaping (_ current: U, _ next: T) -> U) -> Hot<U> {
    return scan(initial: initial, scanner: reducer).last()
  }
  
  /**
   ## Branching
   
   Buffer items received from the stream until it's full and emit the items in a group as an array.
   
   - parameter size: The size of the buffer.
   - parameter partial: **Default:** `true`. If the stream is terminated before the buffer is full, emit the partial buffer.
   
   - returns: A new Hot Stream
   */
  public func buffer(size: Int, partial: Bool = true) -> Hot<[T]> {
    return appendBuffer(stream: Hot<[T]>(), bufferSize: size, partial: partial)
  }
  
  /**
   ## Branching
   
   Create a moving window of the last "n" items.
   For each new item received, emit the last "n" items as a group.
   
   - parameter size: The size of the window
   - parameter partial: **Default:** `true`.  If the stream completes and the window buffer isn't full, emit all the partial buffer.
   
   - returns: A new Hot Stream
   */
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
  
  public func doWhile(then: Termination = .cancelled, handler: @escaping (T) -> Bool) -> Hot<T> {
    return appendWhile(stream: Hot<T>(), handler: handler, then: then)
  }
  
  public func until(then: Termination = .cancelled, handler: @escaping (T) -> Bool) -> Hot<T> {
    return appendUntil(stream: Hot<T>(), handler: handler, then: then)
  }
  
  public func doWhile(then: Termination = .cancelled, handler: @escaping (_ prior: T?, _ next: T) -> Bool) -> Hot<T> {
    return appendWhile(stream: Hot<T>(), handler: handler, then: then)
  }
  
  public func until(then: Termination = .cancelled, handler: @escaping (_ prior: T?, _ next: T) -> Bool) -> Hot<T> {
    return appendUntil(stream: Hot<T>(), handler: handler, then: then)
  }
  
  public func using<U: AnyObject>(_ object: U, then: Termination = .cancelled) -> Hot<(U, T)> {
    return appendUsing(stream: Hot<(U, T)>(), object: object, then: then)
  }
  
  public func lifeOf<U: AnyObject>(_ object: U, then: Termination = .cancelled) -> Hot<T> {
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
