//
//  FutureOperations.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/14/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

extension Future {
  
  /**
   ## Branching
   
   Attach a simple observation handler to the stream to observe new values.
   
   - parameter handler: The handler used to observe new values.
   - parameter value: The next value in the stream
   
   - returns: A new Future stream
   */
  @discardableResult public func on(_ handler: @escaping (_ value: T) -> Void) -> Future<T> {
    return appendOn(stream: Future<T>(op: "on"), handler: handler)
  }
  
  /**
   ## Branching
   
   This will call the handler when the stream receives any error.
   
   - parameter handler: Handler will be called when an error is received.
   - parameter error: The error thrown by the stream
   
   - note: The behavior of this operation is slightly different from other streams in that an error is _always_ reported, whether it is terminating or not.  Other streams only report non-terminating errors.
   
   - returns: a new Future stream
   */
  @discardableResult public func onError(_ handler: @escaping (_ error: Error) -> Void) -> Future<T> {
    return append(stream: Future<T>(op: "onError")) { (next, completion) in
      switch next {
      case .error(let error): handler(error)
      case .terminate(.error(let error)): handler(error)
      default: break
      }
      completion(next.signal)
    }
  }
  
  /**
   ## Branching
   
   Attach an observation handler to observe termination events for the stream.
    
   - parameter handler: The handler used to observe the stream's termination.
   
   - returns: A new Future Stream
   */
  @discardableResult public func onTerminate(_ handler: @escaping (Termination) -> Void) -> Future<T> {
    return appendOnTerminate(stream: Future<T>(op: "onTerminate"), handler: handler)
  }
  
  /**
   ## Branching
    
   Map values in the current stream to new values returned in a new stream.
   
   - note: The mapper returns an optional type.  If the mapper returns `nil`, nothing will be passed down the stream, but the stream will continue to remain active.
   
   - parameter mapper: The handler to map the current type to a new type.
   - parameter value: The current value in the stream
   
   - returns: A new Future Stream
   */
  @discardableResult public func map<U>(_ mapper: @escaping (_ value: T) -> U?) -> Future<U> {
    return appendMap(stream: Future<U>(op: "map<\(String(describing: T.self))>"), withMapper: mapper)
  }
  
  /**
   ## Branching
   
   Map values in the current stream to new values returned in a new stream. 
   The mapper returns a result type that can return an error or the mapped value.
   
   - parameter mapper: The handler to map the current value either to a new value or an error.
   - parameter value: The current value in the stream
   
   - returns: A new Future Stream
   */
  @discardableResult public func resultMap<U>(_ mapper: @escaping (_ value: T) -> Result<U>) -> Future<U> {
    return appendMap(stream: Future<U>(op: "resultMap<\(String(describing: T.self))>"), withMapper: mapper)
  }
  
  /**
   ## Branching
   
   Map values _asynchronously_ to either a new value, or else an error.
   The handler should take the current value along with a completion handler.
   Once ready, the completion handler should be called with:
   
    - New Value:  New values will be passed down stream
    - Error: An error will be passed down stream.  If you wish the error to terminate, add `onError` down stream and return a termination for it.
    - `nil`: Passing `nil` into will complete the handler but pass nothing down stream.
   
   - warning: The completion handler must _always_ be called, even if it's called with `nil`.  Failing to call the completion handler will block the stream, prevent it from being terminated, and will result in memory leakage.
   
   - parameter mapper: The mapper takes a value and a comletion handler.
   - parameter value: The current value in the stream
   - parameter completion: The completion handler; takes an optional Result type passed in.  _Must always be called only once_.
   
   - returns: A new Future Stream
   */
  @discardableResult public func asyncMap<U>(_ mapper: @escaping (_ value: T, _ completion: @escaping (Result<U>?) -> Void) -> Void) -> Future<U> {
    return appendMap(stream: Future<U>(op: "asyncMap<\(String(describing: T.self))>"), withMapper: mapper)
  }
  
  /**
   ## Branching
   
   Map values to an array of values that are emitted sequentially in a new stream.
   
   - parameter mapper: The mapper should take a value and map it to an array of new values. The array of values will be emitted sequentially in the returned stream.
   - parameter value: The next value in the stream.
   
   - note: Because a future can only return 1 value, using flatmap will instead return a Hot Stream that emits the mapped values and then terminates.
   
   - returns: A new Hot Stream
   */
  @discardableResult public func flatMap<U>(_ mapper: @escaping (_ value: T) -> [U]) -> Hot<U> {
    return appendFlatMap(stream: Hot<U>(op: "flatMap<\(String(describing: T.self))>"), withFlatMapper: mapper)
  }
  
  /**
   ## Branching
   
   Filter out values if the handler returns `false`.
   
   - parameter include: Handler to determine whether the value should filtered out (`false`) or included in the stream (`true`)
   - parameter value: The next value to be emitted by the stream.
   
   - returns: A new Future Stream
   */
  @discardableResult public func filter(include: @escaping (_ value: T) -> Bool) -> Future<T> {
    return appendFilter(stream: Future<T>(op: "filter"), include: include)
  }
  
  /**
   ## Branching
   
   Append a stamp to each item emitted from the stream.  The Stamp and the value will be emitted as a tuple.
   
   - parameter stamper: Takes a value emitted from the stream and returns a stamp for that value.
   - parameter value: The next value for the stream.
   
   - returns: A new Future Stream
   */
  @discardableResult public func stamp<U>(_ stamper: @escaping (_ value: T) -> U) -> Future<(value: T, stamp: U)> {
    return appendStamp(stream: Future<(value: T, stamp: U)>(op: "stamp"), stamper: stamper)
  }
  
  /**
   ## Branching
   
   Append a timestamp to each value and return both as a tuple.
   
   - returns: A new Future Stream
   */
  @discardableResult public func timeStamp() -> Future<(value: T, stamp: Date)> {
    return stamp{ _ in return Date() }
  }
  
  /**
   ## Branching
   
   This will delay the values emitted from the stream by the time specified.
   
   - warning: The stream cannot terminate until all events are terminated.
   
   - parameter delay: The time, in seconds, to delay emitting events from the stream.
   
   - returns: A new Future Stream
   */
  @discardableResult public func delay(_ delay: TimeInterval) -> Future<T> {
    return appendDelay(stream: Future<T>(op: "delay(\(delay))"), delay: delay)
  }
  
  /**
   ## Branching
   
   Emit provided values immediately before the first value received by the stream.
   
   - note: These values are only emitted when the stream receives its first value.  If the stream receives no values, these values won't be emitted.
   - note: Since a Future can only emit 1 item, flatten will return a hot stream instead, emit the flattened values and then terminate.
   
   - parameter with: The values to emit before the first value
   
   - returns: A new Future Stream
   */
  @discardableResult public func start(with: [T]) -> Hot<T> {
    return appendStart(stream: Hot<T>(op: "start(with: \(with.count) values)"), startWith: with)
  }
  
  /**
   ## Branching
   
   Emit provided values after the last item, right before the stream terminates.
   These values will be the last values emitted by the stream.
   
   - parameter concat: The values to emit before the stream terminates.
   
   - note: Since a Future can only emit 1 item, flatten will return a hot stream instead, emit the flattened values and then terminate.
   
   - returns: A new Future Stream
   */
  @discardableResult public func concat(_ concat: [T]) -> Hot<T> {
    return appendConcat(stream: Hot<T>(op: "concat(\(concat.count) values)"), concat: concat)
  }
  
  /**
   ## Branching
   
   Define a default value to emit if the stream terminates without emitting anything.
   
   - parameter value: The default value to emit.
   
   - returns: A new Future Stream
   */
  @discardableResult public func defaultValue(_ value: T) -> Future<T> {
    return appendDefault(stream: Future<T>(op: "defaultValue(\(value))"), value: value)
  }
  
}

// MARK: Combining operators
extension Future {
  
  /**
   ## Branching
   
   Merge a separate stream into this one, returning a new stream that emits values from both streams sequentially as an Either
   
   - parameter stream: The stream to merge into this one.
   
   - returns: A new Future Stream
   */
  @discardableResult public func merge<U>(_ stream: Stream<U>) -> Future<Either<T, U>> {
    return appendMerge(stream: stream, intoStream: Future<Either<T, U>>(op: "merge(stream:\(stream))"))
  }
  
  /**
   ## Branching
   
   Merge into this stream a separate stream with the same type, returning a new stream that emits values from both streams sequentially.
   
   - parameter stream: The stream to merge into this one.
   
   - returns: A new Future Stream
   */
  @discardableResult public func merge(_ stream: Stream<T>) -> Future<T> {
    return appendMerge(stream: stream, intoStream: Future<T>(op: "merge(stream:\(stream))"))
  }
  
  /**
   ## Branching
   
   Merge another stream into this one, _zipping_ the values from each stream into a tuple that's emitted from a new stream.
   
   - note: Zipping combines a stream of two values by their _index_.
   In order to do this, the new stream keeps a buffer of values emitted by either stream if one stream emits more values than the other.
   In order to prevent unconstrained memory growth, you can specify the maximum size of the buffer.
   If you do not specify a buffer, the buffer will continue to grow if one stream continues to emit values more than another.
   
   - parameter stream: The stream to zip into this one
   - parameter buffer: _(Optional)_, **Default:** `nil`. The maximum size of the buffer. If `nil`, then no maximum is set (the buffer can grow indefinitely).
   
   - returns: A new Future Stream
   */
  @discardableResult public func zip<U>(_ stream: Stream<U>, buffer: Int? = nil) -> Future<(T, U)> {
    return appendZip(stream: stream, intoStream: Future<(T, U)>(op: "zip(stream: \(stream), buffer: \(buffer ?? -1))"), buffer: buffer)
  }
  
  /**
   ## Branching
   
   Merge another stream into this one, emitting the values as a tuple.
   
   - warning: The behavior of this function changes significantly on the `latest` parameter.  
   
   Specifying `latest = true` (the default) will cause the stream to enumerate _all_ changes in both streams.
   If one stream emits more values than another, the lastest value in that other stream will be emitted multiple times, thus enumerating each combinmation.
   
   If `latest = false`, then a value can only be emitted _once_, even if the other stream emits multiple values.
   This means if one stream emits a single value while the other emits multiple values, all but one of those multiple values will be dropped.
   
   - parameter latest: **Default:** `true`. Whether to emit all values, using the latest value from the other stream as necessary.  If false, values may be dropped.
   - parameter stream: The stream to combine into this one.
   
   - returns: A new Future Stream
   */
  @discardableResult public func combine<U>(stream: Stream<U>) -> Future<(T, U)> {
    return appendCombine(stream: stream, intoStream: Future<(T, U)>(op: "combine(stream: \(stream))"), latest: true)
  }
  
}

// MARK: Lifetime operators
extension Future {

  /**
   ## Branching

   Emit values from stream until the handler returns `false`, and then terminate the stream with the provided termination.

   - parameter then: **Default:** `.cancelled`. When the handler returns `false`, then terminate the stream with this termination.
   - parameter handler: Takes the next value and returns `false` to terminate the stream or `true` to remain active.
   - parameter value: The current value being passed down the stream.

   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.

   - returns: A new Hot Stream
   */
  @discardableResult public func doWhile(then: Termination = .cancelled, handler: @escaping (_ value: T) -> Bool) -> Future<T> {
    return appendWhile(stream: Future<T>(op: "doWhile(then: \(then))"), handler: handler, then: then)
  }

  /**
   ## Branching

   Emit values from stream until the handler returns `true`, and then terminate the stream with the provided termination.

   - note: This is the inverse of `doWhile`, in that the stream remains active _until_ it returns `true` whereas `doWhile` remains active until the handler return `false`.

   - parameter then: **Default:** `.cancelled`. When the handler returns `true`, then terminate the stream with this termination.
   - parameter handler: Takes the next value and returns `true` to terminate the stream or `false` to remain active.
   - parameter value: The current value being passed down the stream.

   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.

   - returns: A new Hot Stream
   */
  @discardableResult public func until(then: Termination = .cancelled, handler: @escaping (T) -> Bool) -> Future<T> {
    return appendUntil(stream: Future<T>(op: "until(then: \(then)"), handler: handler, then: then)
  }

  /**
   ## Branching

   Emit values from stream until the handler returns a `Termination`, at which the point the stream will Terminate.

   - parameter handler: Takes the next value and returns a `Termination` to terminate the stream or `nil` to continue as normal.
   - parameter value: The current value being passed down the stream.

   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.

   - returns: A new Hot Stream
   */
  @discardableResult public func until(_ handler: @escaping (_ value: T) -> Termination?) -> Future<T> {
    return appendUntil(stream: Future<T>(op: "until"), handler: handler)
  }

  /**
   ## Branching

   Keep a weak reference to an object, emitting both the object and the current value as a tuple.
   Terminate the stream on the next event that finds object `nil`.

   - parameter object: The object to keep a week reference.  The stream will terminate on the next even where the object is `nil`.
   - parameter then: The termination to apply after the reference has been found `nil`.

   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   - warning: This stream will return a stream that _cannot_ be replayed.  This prevents the stream of retaining the object and extending its lifetime.

   - returns: A new Hot Stream
   */
  @discardableResult public func using<U: AnyObject>(_ object: U, then: Termination = .cancelled) -> Future<(U, T)> {
    return appendUsing(stream: Future<(U, T)>(op: "using(\(object), then: \(then))"), object: object, then: then).canReplay(false)
  }

  /**
   ## Branching
   
   Tie the lifetime of the stream to that of the object.
   Terminate the stream on the next event that finds object `nil`.
   
   - parameter object: The object to keep a week reference.  The stream will terminate on the next even where the object is `nil`.
   - parameter then: The termination to apply after the reference has been found `nil`.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   - warning: This stream will return a stream that _cannot_ be replayed.  This prevents the stream of retaining the object and extending its lifetime.
   
   - returns: A new Future Stream
   */
  @discardableResult public func lifeOf<U: AnyObject>(_ object: U, then: Termination = .cancelled) -> Future<T> {
    return appendLifeOf(stream: Future<T>(op: "lifeOf(\(object), then: \(then))"), object: object, then: then)
  }
  
}

extension Future where T : Sequence {
  
  /**
   ## Branching
   
   Convenience function that takes an array of values and flattens them into sequential values emitted from the stream.
   This is the same as (and uses) `flatMap`, without the need to specify the handler.
   
   - note: Since a Future can only emit 1 item, flatten will return a hot stream instead, emit the flattened values and then terminate.
   
   - returns: A new Hot Stream
   */
  @discardableResult public func flatten() -> Hot<T.Iterator.Element> {
    return flatMap{ $0.map{ $0 } }
  }
  
}
