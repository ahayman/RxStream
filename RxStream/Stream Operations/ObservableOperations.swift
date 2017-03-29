//
//  ObservableOperations.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/23/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

// MARK: Transforms
extension Observable {
  
  /// This will return a new immutable Observable attached to this one.
  public func observable() -> Observable<T> {
    return appendNewStream(stream: Observable(self.value))
  }
  
  /// This will return a hot stream attached to the observable.
  public func hot() -> Hot<T> {
    return appendNewStream(stream: Hot<T>())
  }
  
}

extension Observable {
  
  /**
   ## Branching
   
   This will call the handler when the stream receives a _non-terminating_ error.
   
   - parameter handler: Handler will be called when an error is received.
   - parameter error: The error thrown by the stream
   
   - returns: a new Observable stream
   */
  @discardableResult public func onError(_ handler: @escaping (_ error: Error) -> Void) -> Observable<T> {
    return appendOnError(stream: Observable<T>(self.value), handler: handler)
  }
  
  /**
   ## Branching
   
   This will call the handler when the stream receives a _non-terminating_ error.
   The handler can optionally return a Termination, which will cause the stream to terminate.
   
   - parameter handler: Receives an error and can optionally return a Termination.  If `nil` is returned, the stream will continue to be active.
   - parameter error: The error thrown by the stream
   
   - returns: a new Observable stream
   */
  @discardableResult public func mapError(_ handler: @escaping (_ error: Error) -> Termination?) -> Observable<T> {
    return appendMapError(stream: Observable<T>(self.value), handler: handler)
  }
  
  /**
   ## Branching
   
   Attach a simple observation handler to the stream to observe new values.
   
   - parameter handler: The handler used to observe new values.
   - parameter value: The next value in the stream
   
   - returns: A new Observable stream
   */
  @discardableResult public func on(_ handler: @escaping (_ value: T) -> Void) -> Observable<T> {
    return appendOn(stream: Observable<T>(self.value), handler: handler)
  }
  
  /**
   ## Branching
   
   Attach an observation handler to the stream to observe transitions to new values. The handler includes the old value (if any) along with the new one.
   
   - note: The current observable value will be replayed into the new stream for consistency. However, only the current replay will persist further down the stream. 
   
   - parameter handler: The handler used to observe transitions between values.
   - parameter prior: The last value emitted from the stream
   - parameter next: The next value in the stream
   
   - returns: A new Observable Stream
   */
  @discardableResult public func onTransition(_ handler: @escaping (_ prior: T?, _ next: T) -> Void) -> Observable<T> {
    let replay = self.replay
    return replayNext(true).appendTransition(stream: Observable<T>(self.value), handler: handler).replayNext(replay)
  }
  
  /**
   ## Branching
   
   Attach an observation handler to observe termination events for the stream.
    
   - parameter handler: The handler used to observe the stream's termination.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func onTerminate(_ handler: @escaping (Termination) -> Void) -> Observable<T> {
    return appendOnTerminate(stream: Observable<T>(self.value), handler: handler)
  }
  
  /**
   ## Branching
    
   Map values in the current stream to new values returned in a new stream.
   
   - note: The mapper returns an non-optional type.
   
   - parameter mapper: The handler to map the current type to a new type.
   - parameter value: The current value in the stream
   
   - returns: A new Observable with the mapped value type
   */
  public func map<U>(_ mapper: @escaping (_ value: T) -> U) -> Observable<U> {
    return appendMap(stream: Observable<U>(mapper(self.value)), withMapper: mapper)
  }
  
  /**
   ## Branching
    
   Map values in the current stream to new values returned in a new stream.
   
   - note: The mapper returns an optional type.  If the mapper returns `nil`, nothing will be passed down the stream, but the stream will continue to remain active.
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
   
   - parameter mapper: The handler to map the current type to a new type.
   - parameter value: The current value in the stream
   
   - returns: A new Hot Stream
   */
  @discardableResult public func map<U>(_ mapper: @escaping (_ value: T) -> U?) -> Hot<U> {
    return appendMap(stream: Hot<U>(), withMapper: mapper)
  }
  
  /**
   ## Branching
   
   Map values in the current stream to new values returned in a new stream. 
   The mapper returns a result type that can return an error or the mapped value.
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
   
   - parameter mapper: The handler to map the current value either to a new value or an error.
   - parameter value: The current value in the stream
   
   - returns: A new Hot Stream
   */
  @discardableResult public func map<U>(_ mapper: @escaping (_ value: T) -> Result<U>) -> Hot<U> {
    return appendMap(stream: Hot<U>(), withMapper: mapper)
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
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
   
   - parameter mapper: The mapper takes a value and a comletion handler.
   - parameter value: The current value in the stream
   - parameter completion: The completion handler; takes an optional Result type passed in.  _Must always be called only once_.
   
   - returns: A new Hot Stream
   */
  @discardableResult public func map<U>(_ mapper: @escaping (_ value: T, _ completion: @escaping (Result<U>?) -> Void) -> Void) -> Hot<U> {
    return appendMap(stream: Hot<U>(), withMapper: mapper)
  }
  
  /**
   ## Branching
   
   Map values to an array of values that are emitted sequentially in a new stream.
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.

   - parameter mapper: The mapper should take a value and map it to an array of new values. The array of values will be emitted sequentially in the returned stream.
   - parameter value: The next value in the stream.
   
   - returns: A new Hot Stream
   */
  @discardableResult public func flatMap<U>(_ mapper: @escaping (_ value: T) -> [U]) -> Hot<U> {
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
   - parameter current: The current reduction.
   - parameter next: The next value in the stream.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func scan<U>(initial: U, scanner: @escaping (_ current: U, _ next: T) -> U) -> Observable<U> {
    return appendScan(stream: Observable<U>(initial), initial: initial, withScanner: scanner)
  }
  
  /**
   ## Branching
   
   Returns the first value emitted from the stream and terminates the stream.
   By default the stream is `.cancelled`, but this can be overriden by specifying the termination.
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
   
   - parameter then: **Default**: `.cancelled`. After the value has emitted, the stream will be terminated with this reason.
   
   - returns: A new Hot Stream
   */
  @discardableResult public func first(then: Termination = .cancelled) -> Hot<T> {
    return appendFirst(stream: Hot<T>(), then: then)
  }
  
  /**
   ## Branching
   
   Returns the first "n" values emitted and then terminate the stream.
   By default the stream is `.cancelled`, but this can be overriden by specifying the termination.
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
 
   - parameter count: The number of values to emit before terminating the stream.
   - parameter then: **Default:** `.cancelled`. After the values have been emitted, the stream will terminate with this reason.
   
   - returns: A new Hot Stream
   */
  @discardableResult public func first(_ count: Int, then: Termination = .cancelled) -> Hot<T> {
    return appendFirst(stream: Hot<T>(), count: count, then: then)
  }
  
  /**
   ## Branching
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
 
   Emits only the last value of the stream when it terminates.
   
   - returns: A new Hot Stream
   */
  @discardableResult public func last() -> Hot<T> {
    return appendLast(stream: Hot<T>())
  }
  
  /**
   ## Branching
   
   Emits the last "n" values of the stream when it terminates.
   The values are emitted sequentialy in the order they were received.
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
 
   - parameter count: The number of values to emit.
   - parameter partial: **Default:** `true`. If the stream terminates before the full count has been received, partial determines whether the partial set should be emitted.  
   
   - returns: A new Hot Stream
   */
  @discardableResult public func last(_ count: Int, partial: Bool = true) -> Hot<T> {
    return appendLast(stream: Hot<T>(), count: count, partial: partial)
  }
  
  /**
   ## Branching
   
   This will reduce all values in the stream using the `reducer` passed in.  The reduction is emitted when the stream terminates.
   This has the same format as `scan` and, in fact, does the same thing except intermediate values are not emitted.
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
 
   - parameter initial: The initial value.  Will be passed into the handler as `current` for the first new value that arrives from the current stream.
   - parameter reducer: Take the current reduction (either initial or last value returned from the handler), the next value from the stream and returns a new value.
   - parameter current: The current reduction
   - parameter reducer: The next value in the stream
   
   - returns: A new Hot Stream
   */
  @discardableResult public func reduce<U>(initial: U, reducer: @escaping (_ current: U, _ next: T) -> U) -> Hot<U> {
    return scan(initial: initial, scanner: reducer).last()
  }
  
  /**
   ## Branching
   
   Buffer values received from the stream until it's full and emit the values in a group as an array.
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
   
   - parameter size: The size of the buffer.
   - parameter partial: **Default:** `true`. If the stream is terminated before the buffer is full, emit the partial buffer.
   
   - returns: A new Hot Stream
   */
  @discardableResult public func buffer(size: Int, partial: Bool = true) -> Hot<[T]> {
    return appendBuffer(stream: Hot<[T]>(), bufferSize: size, partial: partial)
  }
  
  /**
   ## Branching
   
   Create a moving window of the last "n" values.
   For each new value received, emit the last "n" values as a group.
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
 
   - parameter size: The size of the window.  Minimum: 1
   - parameter partial: **Default:** `true`.  If the stream completes and the window buffer isn't full, emit all the partial buffer.
   
   - returns: A new Hot Stream
   */
  @discardableResult public func window(size: Int, partial: Bool = false) -> Hot<[T]> {
    return appendWindow(stream: Hot<[T]>(), windowSize: size, partial: partial)
  }
  
  /**
   ## Branching
   
   Create a moving window of the last values within the provided time array.
   For each new value received, emit all the values within the time frame as a group.
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
 
   - parameter size: The window size in seconds
   - parameter limit: _(Optional)_ limit the number of values that are buffered and emitted.
   
   - returns: A new Hot Stream
   */
  @discardableResult public func window(size: TimeInterval, limit: Int? = nil) -> Hot<[T]> {
    return appendWindow(stream: Hot<[T]>(), windowSize: size, limit: limit)
  }
  
  /**
   ## Branching
   
   Filter out values if the handler returns `false`.
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
 
   - parameter include: Handler to determine whether the value should filtered out (`false`) or included in the stream (`true`)
   - parameter value: The next value to be emitted by the stream.
   
   - returns: A new Hot Stream
   */
  @discardableResult public func filter(include: @escaping (_ value: T) -> Bool) -> Hot<T> {
    return appendFilter(stream: Hot<T>(), include: include)
  }
  
  /**
   ## Branching
   
   Emit only each nth value, determined by the "stride" provided.  All other values are ignored.
   
   - note: Because this is an Observable, the first value is always included and then the stride begins.
   
   - parameter stride: _Minimum:_ 1. The distance between each value emitted. 
   For example: `1` will emit all values, `2` will emit every other value, `3` will emit every third value, etc.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func stride(_ stride: Int) -> Observable<T> {
    return appendStride(stream: Observable<T>(self.value), stride: stride)
  }
  
  /**
   ## Branching
   
   Append a stamp to each item emitted from the stream.  The Stamp and the value will be emitted as a tuple.
   
   - parameter stamper: Takes a value emitted from the stream and returns a stamp for that value.
   - parameter value: The next value for the stream.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func stamp<U>(_ stamper: @escaping (_ value: T) -> U) -> Observable<(value: T, stamp: U)> {
    return appendStamp(stream: Observable<(value: T, stamp: U)>(value: self.value, stamp: stamper(self.value)), stamper: stamper)
  }
  
  /**
   ## Branching
   
   Append a timestamp to each value and return both as a tuple.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func timeStamp() -> Observable<(value: T, stamp: Date)> {
    return stamp{ _ in return Date() }
  }
  
  /**
   ## Branching
   
   Emits a value only if the distinct handler returns that the new item is distinct from the previous item.
   
   - warning: The first value is _always_ distinct and will be emitted without passing through the handler.
   
   - note: The current observable value will be replayed into the new stream for consistency. However, only the current replay will persist further down the stream. 
   
   - parameters: 
     - isDistinct: Takes the prior, and next values and should return whether the next value is distinct from the prior value.
   If `true`, the next value will be emitted, otherwise it will be ignored.
     - prior: The prior value last emitted from the stream.
     - next: The next value to be emitted from the stream.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func distinct(_ isDistinct: @escaping (_ prior: T, _ next: T) -> Bool) -> Observable<T> {
    let replay = self.replay
    return replayNext(true).appendDistinct(stream: Observable<T>(self.value), isDistinct: isDistinct).replayNext(replay)
  }
 
  /**
   ## Branching
   
   Only emits items that are less than all previous items, as determined by the handler.
   
   - warning: The first value is always mininum and will be emitted without passing through the handler.
   
   - note: The current observable value will be replayed into the new stream for consistency. However, only the current replay will persist further down the stream. 
   
   - parameters:
     - lessThan: Handler should take the first item, and return whether it is less than the second item.
     - isValue: The next value to be compared.
     - lessThan: The current "min" value.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func min(lessThan: @escaping (_ isValue: T, _ lessThan: T) -> Bool) -> Observable<T> {
    let replay = self.replay
    return replayNext(true).appendMin(stream: Observable<T>(self.value), lessThan: lessThan).replayNext(replay)
  }
  
  /**
   ## Branching
   
   Only emits items that are greater than all previous items, as determined by the handler.
   
   - warning: The first value is always maximum and will be emitted without passing through the handler.
   
   - note: The current observable value will be replayed into the new stream for consistency. However, only the current replay will persist further down the stream. 
   
   - parameters:
     - greaterThan: Handler should take the first item, and return whether it is less than the second item.
     - isValue: The next value to be compared.
     - greaterThan: The current "max" value.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func max(greaterThan: @escaping (_ isValue: T, _ greaterThan: T) -> Bool) -> Observable<T> {
    let replay = self.replay
    return replayNext(true).appendMax(stream: Observable<T>(self.value), greaterThan: greaterThan).replayNext(replay)
  }
  
  /**
   ## Branching
   
   Emits the current count of values emitted from the stream.  It does not emit the values themselves.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func count() -> Observable<UInt> {
    return appendCount(stream: Observable<UInt>(1))
  }
  
  /**
   ## Branching
   
   This will stamp the values in the stream with the current count and emit them as a tuple.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func countStamp() -> Observable<(value: T, stamp: UInt)> {
    var count: UInt = 0
    return stamp{ _ in
      count += 1
      return count
    }
  }
  
  /**
   ## Branching
   
   This will delay the values emitted from the stream by the time specified.
   
   - warning: The stream cannot terminate until all events are terminated.
   
   - parameter delay: The time, in seconds, to delay emitting events from the stream.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func delay(_ delay: TimeInterval) -> Observable<T> {
    return appendDelay(stream: Observable<T>(self.value), delay: delay)
  }
  
  /**
   ## Branching
   
   Skip the first "n" values emitted from the stream.  All values afterwards will be emitted normally.
   
   - parameter count: The number of values to skip.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func skip(_ count: Int) -> Observable<T> {
    return appendSkip(stream: Observable<T>(self.value), count: count)
  }
  
  /**
   ## Branching
   
   Emit provided values immediately before the first value received by the stream.
   
   - note: These values are only emitted when the stream receives its first value.  If the stream receives no values, these values won't be emitted.
   - parameter with: The values to emit before the first value
   
   - returns: A new Observable Stream
   */
  @discardableResult public func start(with: [T]) -> Observable<T> {
    return appendStart(stream: Observable<T>(self.value), startWith: with)
  }
  
  /**
   ## Branching
   
   Emit provided values after the last item, right before the stream terminates.
   These values will be the last values emitted by the stream.
   
   - parameter conat: The values to emit before the stream terminates.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func concat(_ concat: [T]) -> Observable<T> {
    return appendConcat(stream: Observable<T>(self.value), concat: concat)
  }
  
}

// MARK: Combining operators
extension Observable {
  
  /**
   ## Branching
   
   Merge a separate stream into this one, returning a new stream that emits values from both streams sequentially as an Either
   
   - parameter stream: The stream to merge into this one.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func merge<U>(_ stream: Stream<U>) -> Observable<Either<T, U>> {
    return appendMerge(stream: stream, intoStream: Observable<Either<T, U>>(.left(self.value)))
  }
  
  /**
   ## Branching
   
   Merge into this stream a separate stream with the same type, returning a new stream that emits values from both streams sequentially.
   
   - parameter stream: The stream to merge into this one.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func merge(_ stream: Stream<T>) -> Observable<T> {
    return appendMerge(stream: stream, intoStream: Observable<T>(self.value))
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
   
   - returns: A new Hot Stream
   */
  @discardableResult public func zip<U>(_ stream: Stream<U>, buffer: Int? = nil) -> Hot<(T, U)> {
    return appendZip(stream: stream, intoStream: Hot<(T, U)>(), buffer: buffer)
  }
  
  /**
   ## Branching
   
   Merge another stream into this one, _zipping_ the values from each stream into a tuple that's emitted from a new stream.
   This is an overload that will return an Observable instead of a Hot stream if the merging stream is an Observable stream.
   
   - note: Zipping combines a stream of two values by their _index_.
   In order to do this, the new stream keeps a buffer of values emitted by either stream if one stream emits more values than the other.
   In order to prevent unconstrained memory growth, you can specify the maximum size of the buffer.
   If you do not specify a buffer, the buffer will continue to grow if one stream continues to emit values more than another.
   
   - parameter stream: The stream to zip into this one
   - parameter buffer: _(Optional)_, **Default:** `nil`. The maximum size of the buffer. If `nil`, then no maximum is set (the buffer can grow indefinitely).
   
   - returns: A new Observable Stream
   */
  @discardableResult public func zip<U>(_ stream: Observable<U>, buffer: Int? = nil) -> Observable<(T, U)> {
    return appendZip(stream: stream, intoStream: Observable<(T, U)>(self.value, stream.value), buffer: buffer)
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
   
   - returns: A new Hot Stream
   */
  @discardableResult public func combine<U>(latest: Bool = true, stream: Stream<U>) -> Hot<(T, U)> {
    return appendCombine(stream: stream, intoStream: Hot<(T, U)>(), latest: latest)
  }
  
  /**
   ## Branching
   
   Merge another stream into this one, emitting the values as a tuple.
   This is an overload that will return an Observable instead of a Hot stream if the merging stream is an Observable stream.
   
   - warning: The behavior of this function changes significantly on the `latest` parameter.  
   
   Specifying `latest = true` (the default) will cause the stream to enumerate _all_ changes in both streams.
   If one stream emits more values than another, the lastest value in that other stream will be emitted multiple times, thus enumerating each combinmation.
   
   If `latest = false`, then a value can only be emitted _once_, even if the other stream emits multiple values.
   This means if one stream emits a single value while the other emits multiple values, all but one of those multiple values will be dropped.
   
   - parameter latest: **Default:** `true`. Whether to emit all values, using the latest value from the other stream as necessary.  If false, values may be dropped.
   - parameter stream: The stream to combine into this one.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func combine<U>(latest: Bool = true, stream: Observable<U>) -> Observable<(T, U)> {
    return appendCombine(stream: stream, intoStream: Observable<(T, U)>(self.value, stream.value), latest: latest)
  }
}

// MARK: Lifetime operators
extension Observable {
  
  /**
   ## Branching
   
   Emit values from stream until the handler returns `false`, and then terminate the stream with the provided termination.
   
   - parameter then: **Default:** `.cancelled`. When the handler returns `false`, then terminate the stream with this termination.
   - parameter handler: Takes the next value and returns `false` to terminate the stream or `true` to remain active.
   - parameter value: The current value being passed down the stream.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func doWhile(then: Termination = .cancelled, handler: @escaping (_ value: T) -> Bool) -> Observable<T> {
    return appendWhile(stream: Observable<T>(self.value), handler: handler, then: then)
  }
  
  /**
   ## Branching
   
   Emit values from stream until the handler returns `true`, and then terminate the stream with the provided termination.
   
   - note: This is the inverse of `doWhile`, in that the stream remains active _until_ it returns `true` whereas `doWhile` remains active until the handler return `false`.
   
   - parameter then: **Default:** `.cancelled`. When the handler returns `true`, then terminate the stream with this termination.
   - parameter handler: Takes the next value and returns `true` to terminate the stream or `false` to remain active.
   - parameter value: The current value being passed down the stream.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func until(then: Termination = .cancelled, handler: @escaping (T) -> Bool) -> Observable<T> {
    return appendUntil(stream: Observable<T>(self.value), handler: handler, then: then)
  }
  
  /**
   ## Branching
   
   Emit values from stream until the handler returns a `Termination`, at which the point the stream will Terminate.
   
   - parameter handler: Takes the next value and returns a `Termination` to terminate the stream or `nil` to continue as normal.
   - parameter value: The current value being passed down the stream.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func until(_ handler: @escaping (_ value: T) -> Termination?) -> Observable<T> {
    return appendUntil(stream: Observable<T>(self.value), handler: handler)
  }
  
  /**
   ## Branching
   
   Emit values from stream until the handler returns `false`, and then terminate the stream with the provided termination.
   
   - parameter then: **Default:** `.cancelled`. When the handler returns `false`, then terminate the stream with this termination.
   - parameter handler: Takes the next value and returns `false` to terminate the stream or `true` to remain active.
   - parameter prior: The prior value, if any.
   - parameter next: The current value being passed down the stream.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func doWhile(then: Termination = .cancelled, handler: @escaping (_ prior: T?, _ next: T) -> Bool) -> Observable<T> {
    return appendWhile(stream: Observable<T>(self.value), handler: handler, then: then)
  }
  
  /**
   ## Branching
   
   Emit values from stream until the handler returns `true`, and then terminate the stream with the provided termination.
   
   - note: This is the inverse of `doWhile`, in that the stream remains active _until_ it returns `true` whereas `doWhile` remains active until the handler return `false`.
   
   - parameter then: **Default:** `.cancelled`. When the handler returns `true`, then terminate the stream with this termination.
   - parameter handler: Takes the next value and returns `true` to terminate the stream or `false` to remain active.
   - parameter prior: The prior value, if any.
   - parameter next: The current value being passed down the stream.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func until(then: Termination = .cancelled, handler: @escaping (_ prior: T?, _ next: T) -> Bool) -> Observable<T> {
    return appendUntil(stream: Observable<T>(self.value), handler: handler, then: then)
  }
  
  /**
   ## Branching
   
   Emit values from stream until the handler returns a `Termination`, and then terminate the stream with the provided termination.
   
   - parameter handler: Takes the next value and returns `true` to terminate the stream or `false` to remain active.
   - parameter prior: The prior value, if any.
   - parameter next: The current value being passed down the stream.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func until(handler: @escaping (_ prior: T?, _ next: T) -> Termination?) -> Observable<T> {
    return appendUntil(stream: Observable<T>(self.value), handler: handler)
  }
  
  /**
   ## Branching
   
   Keep a weak reference to an object, emitting both the object and the current value as a tuple.
   Terminate the stream on the next event that finds object `nil`.
   
   - parameter object: The object to keep a week reference.  The stream will terminate on the next even where the object is `nil`.
   - parameter then: The termination to apply after the reference has been found `nil`.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   - warning: This stream will return a stream that _cannot_ be replayed.  This prevents the stream of retaining the object and extending its lifetime.
   
   - returns: A new Hot Stream.  Cannot return an observable as it will retain the object we're seeking to use the life time of.
   */
  @discardableResult public func using<U: AnyObject>(_ object: U, then: Termination = .cancelled) -> Hot<(U, T)> {
    return appendUsing(stream: Hot<(U, T)>(), object: object, then: then).canReplay(false)
  }
  
  /**
   ## Branching
   
   Tie the lifetime of the stream to that of the object.
   Terminate the stream on the next event that finds object `nil`.
   
   - parameter object: The object to keep a week reference.  The stream will terminate on the next even where the object is `nil`.
   - parameter then: The termination to apply after the reference has been found `nil`.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Observab le Stream
   */
  @discardableResult public func lifeOf<U: AnyObject>(_ object: U, then: Termination = .cancelled) -> Observable<T> {
    return appendLifeOf(stream: Observable<T>(self.value), object: object, then: then)
  }
  
  /**
   ## Branching
   
   Emit the next "n" values and then terminate the stream.
   
   - parameter count: The number of values to emit before terminating the stream.
   - parameter then: **Default:** `.cancelled`. How the stream is terminated after the events are emitted.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Observable Stream
   */
  @discardableResult public func next(_ count: UInt = 1, then: Termination = .cancelled) -> Observable<T> {
    return appendNext(stream: Observable<T>(self.value), count: count, then: then)
  }
  
}

extension Observable where T : Sequence {
  
  /**
   ## Branching
   
   - note: Because an Observable value cannot be gauranteed, this will return a Hot Stream instead of an Observable.
   
   Convenience function that takes an array of values and flattens them into sequential values emitted from the stream.
   This is the same as (and uses) `flatMap`, without the need to specify the handler.
   
   - returns: A new Hot Stream
   */
  @discardableResult public func flatten() -> Hot<T.Iterator.Element> {
    return flatMap{ $0.map{ $0 } }
  }
  
}

extension Observable where T : Arithmetic {
  
  /**
   ## Branching
   
   Takes values emitted, averages them, and returns the average in the new stream.
   
   - note: The current observable value will be replayed into the new stream for consistency. However, only the current replay will persist further down the stream. 
   
   - returns: A new Observable Stream
   */
  @discardableResult public func average() -> Observable<T> {
    let replay = self.replay
    return replayNext(true).appendAverage(stream: Observable<T>(self.value)).replayNext(replay)
  }
  
  /**
   ## Branching
   
   Sums values emitted and emit them in the new stream.
   
   - note: The current observable value will be replayed into the new stream for consistency. However, only the current replay will persist further down the stream. 
   
   - returns: A new Observable Stream
   */
  @discardableResult public func sum() -> Observable<T> {
    let replay = self.replay
    return replayNext(true).appendSum(stream: Observable<T>(self.value)).replayNext(replay)
  }
  
}

extension Observable where T : Equatable {
  
  /**
   ## Branching
   
   Convenience function to only emit distinct equatable values.
   This has the same effect as using `distinct { $0 != $1 }` function.
   
   - note: The current observable value will be replayed into the new stream for consistency. However, only the current replay will persist further down the stream. 
   
   - returns: A new Observable Stream
   */
  @discardableResult public func distinct() -> Observable<T> {
    let replay = self.replay
    return replayNext(true).appendDistinct(stream: Observable<T>(self.value), isDistinct: { $0 != $1 }).replayNext(replay)
  }
}

extension Observable where T : Comparable {
  
  /**
   ## Branching
   
   Convenience function that only emits the minimum values.
   
   - note: The current observable value will be replayed into the new stream for consistency. However, only the current replay will persist further down the stream. 
   
   - returns: A new Observable Stream
   */
  @discardableResult public func min() -> Observable<T> {
    let replay = self.replay
    return replayNext(true).appendMin(stream: Observable<T>(self.value)) { $0 < $1 }.replayNext(replay)
  }
  
  /**
   ## Branching
   
   Convenience function that only emits the maximum values.
   
   - note: The current observable value will be replayed into the new stream for consistency. However, only the current replay will persist further down the stream. 
   
   - returns: A new Observable Stream
   */
  @discardableResult public func max() -> Observable<T> {
    let replay = self.replay
    return replayNext(true).appendMax(stream: Observable<T>(self.value)) { $0 > $1 }.replayNext(replay)
  }
}
