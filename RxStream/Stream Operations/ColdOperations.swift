//
//  ColdOperations.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/16/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

extension Cold {
  
  /**
   ## Branching
   
   This will map an upstream Request to a new Request type so that down stream client can use a different Request.  
   Because Requests travel upstream, the mapper must map the from the new Type to the original Request type.
   
   - parameter mapper: Maps the new Type to the upstreamd Request type.
   
   - returns: A new Cold stream
   */
  public func mapRequest<U>(_ mapper: @escaping (U) -> Request) -> Cold<U, Response> {
    return appendNewStream(stream: newMappedRequestStream(mapper: mapper))
  }
  
  /**
   ## Branching
   
   This will call the handler when the stream receives a _non-terminating_ error.
   
   - parameter handler: Handler will be called when an error is received.
   - parameter error: The error thrown by the stream
   
   - returns: a new Cold stream
   */
  @discardableResult public func onError(_ handler: @escaping (_ error: Error) -> Void) -> Cold<Request, Response> {
    return appendOnError(stream: newSubStream("onError"), handler: handler)
  }
  
  /**
   ## Branching
   
   This will call the handler when the stream receives a _non-terminating_ error.
   The handler can optionally return a Termination, which will cause the stream to terminate.
   
   - parameter handler: Receives an error and can optionally return a Termination.  If `nil` is returned, the stream will continue to be active.
   - parameter error: The error thrown by the stream
   
   - returns: a new Cold stream
   */
  @discardableResult public func mapError(_ handler: @escaping (_ error: Error) -> Termination?) -> Cold<Request, Response> {
    return appendMapError(stream: newSubStream("mapError"), handler: handler)
  }

  /**
   ## Branching
   
   Attach a simple observation handler to the stream to observe new values.
 
   - parameter handler: The handler used to observe new values.
   - parameter value: The next value in the stream
   
   - returns: A new Cold stream
   */
  @discardableResult public func on(_ handler: @escaping (_ value: Response) -> Void) -> Cold<Request, Response> {
    return appendOn(stream: newSubStream("on"), handler: handler)
  }
  
  /**
   ## Branching
   
   Attach an observation handler to the stream to observe transitions to new values. The handler includes the old value (if any) along with the new one.
   
   - parameter handler: The handler used to observe transitions between values.
   - parameter prior: The last value emitted from the stream
   - parameter next: The next value in the stream
   
   - returns: A new Cold Stream
   */
  @discardableResult public func onTransition(_ handler: @escaping (_ prior: Response?, _ next: Response) -> Void) -> Cold<Request, Response> {
    return appendTransition(stream: newSubStream("onTransition"), handler: handler)
  }
  
  /**
   ## Branching
   
   Attach an observation handler to observe termination events for the stream.
    
   - parameter handler: The handler used to observe the stream's termination.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func onTerminate(_ handler: @escaping (Termination) -> Void) -> Cold<Request, Response> {
    return appendOnTerminate(stream: newSubStream("onTerminate"), handler: handler)
  }
  
  /**
   ## Branching
    
   Map values in the current stream to new values returned in a new stream.
   
   - note: The mapper returns an optional type.  If the mapper returns `nil`, nothing will be passed down the stream, but the stream will continue to remain active.
   
   - parameter mapper: The handler to map the current type to a new type.
   - parameter value: The current value in the stream
   
   - returns: A new Cold Stream
   */
  @discardableResult public func map<U>(_ mapper: @escaping (_ value: Response) -> U?) -> Cold<Request, U> {
    let stream: Cold<Request, U> = newSubStream("map")
    return appendMap(stream: stream, withMapper: mapper)
  }
  
  /**
   ## Branching
   
   Map values in the current stream to new values returned in a new stream. 
   The mapper returns a result type that can return an error or a mapped value.  
   
   - parameter mapper: The handler to map the current value either to a new value or an error.
   - parameter value: The current value in the stream
   
   - returns: A new Cold Stream
   */
  @discardableResult public func resultMap<U>(_ mapper: @escaping (_ value: Response) -> Result<U>) -> Cold<Request, U> {
    let stream: Cold<Request, U> = newSubStream("resultMap")
    return appendMap(stream: stream, withMapper: mapper)
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
   
   - returns: A new Cold Stream
   */
  @discardableResult public func asyncMap<U>(_ mapper: @escaping (_ value: Response, _ completion: @escaping (Result<U>?) -> Void) -> Void) -> Cold<Request, U> {
    let stream: Cold<Request, U> = newSubStream("asyncMap")
    return appendMap(stream: stream, withMapper: mapper)
  }
  
  /**
   ## Branching
   
   Map values to an array of values that are emitted sequentially in a new stream.
   
   - parameter mapper: The mapper should take a value and map it to an array of new values. The array of values will be emitted sequentially in the returned stream.
   - parameter value: The next value in the stream.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func flatMap<U>(_ mapper: @escaping (_ value: Response) -> [U]) -> Cold<Request, U> {
    let stream: Cold<Request, U> = newSubStream("flatMap")
    return appendFlatMap(stream: stream, withFlatMapper: mapper)
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
   
   - returns: A new Cold Stream
   */
  @discardableResult public func scan<U>(initial: U, scanner: @escaping (_ current: U, _ next: Response) -> U) -> Cold<Request, U> {
    let stream: Cold<Request, U> = newSubStream("scan(initial: \(initial))")
    return appendScan(stream: stream, initial: initial, withScanner: scanner)
  }
  
  /**
   ## Branching
   
   Returns the first "n" values emitted and then terminate the stream.
   By default the stream is `.cancelled`, but this can be overriden by specifying the termination.
   
   - parameter count: The number of values to emit before terminating the stream.
   - parameter then: **Default:** `.cancelled`. After the values have been emitted, the stream will terminate with this reason.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func first(_ count: Int = 1, then: Termination = .cancelled) -> Cold<Request, Response> {
    return appendFirst(stream: newSubStream("first(\(count), then: \(then))"), count: count, then: then)
  }
  
  /**
   ## Branching
   
   Emits the last "n" values of the stream when it terminates.
   The values are emitted sequentialy in the order they were received.
   
   - parameter count: The number of values to emit.
   - parameter partial: **Default:** `true`. If the stream terminates before the full count has been received, partial determines whether the partial set should be emitted.  
   
   - returns: A new Cold Stream
   */
  @discardableResult public func last(_ count: Int = 1, partial: Bool = true) -> Cold<Request, Response> {
    if count < 2 {
      return appendLast(stream: newSubStream("last"))
    }
    return appendLast(stream: newSubStream("last(\(count), partial: \(partial))"), count: count, partial: partial)
  }
  
  /**
   ## Branching
   
   This will reduce all values in the stream using the `reducer` passed in.  The reduction is emitted when the stream terminates.
   This has the same format as `scan` and, in fact, does the same thing except intermediate values are not emitted.
   
   - parameter initial: The initial value.  Will be passed into the handler as `current` for the first new value that arrives from the current stream.
   - parameter reducer: Take the current reduction (either initial or last value returned from the handler), the next value from the stream and returns a new value.
   - parameter current: The current reduction
   - parameter reducer: The next value in the stream
   
   - returns: A new Cold Stream
   */
  @discardableResult public func reduce<U>(initial: U, reducer: @escaping (_ current: U, _ next: Response) -> U) -> Cold<Request, U> {
    return scan(initial: initial, scanner: reducer).last()
  }
  
  /**
   ## Branching
   
   Buffer values received from the stream until it's full and emit the values in a group as an array.
   
   - parameter size: The size of the buffer.
   - parameter partial: **Default:** `true`. If the stream is terminated before the buffer is full, emit the partial buffer.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func buffer(size: Int, partial: Bool = true) -> Cold<Request, [Response]> {
    return appendBuffer(stream: newSubStream("buffer(\(size), partial: \(partial))"), bufferSize: size, partial: partial)
  }
  
  /**
   ## Branching
   
   Create a moving window of the last "n" values.
   For each new value received, emit the last "n" values as a group.
   
   - parameter size: The size of the window.  Minimum: 1
   - parameter partial: **Default:** `true`.  If the stream completes and the window buffer isn't full, emit all the partial buffer.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func window(size: Int, partial: Bool = false) -> Cold<Request, [Response]> {
    return appendWindow(stream: newSubStream("sizedWindow(\(size), partial: \(partial))"), windowSize: size, partial: partial)
  }
  
  /**
   ## Branching
   
   Create a moving window of the last values within the provided time array.
   For each new value received, emit all the values within the time frame as a group.
   
   - parameter size: The window size in seconds
   - parameter limit: _(Optional)_ limit the number of values that are buffered and emitted.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func window(size: TimeInterval, limit: Int? = nil) -> Cold<Request, [Response]> {
    return appendWindow(stream: newSubStream("timedWindow(\(size), limit: \(limit ?? -1))"), windowSize: size, limit: limit)
  }
  
  /**
   ## Branching
   
   Filter out values if the handler returns `false`.
   
   - parameter include: Handler to determine whether the value should filtered out (`false`) or included in the stream (`true`)
   - parameter value: The next value to be emitted by the stream.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func filter(include: @escaping (_ value: Response) -> Bool) -> Cold<Request, Response> {
    return appendFilter(stream: newSubStream("filter"), include: include)
  }
  
  /**
   ## Branching
   
   Emit only each nth value, determined by the "stride" provided.  All other values are ignored.
   
   - parameter stride: _Minimum:_ 1. The distance between each value emitted. 
   For example: `1` will emit all values, `2` will emit every other value, `3` will emit every third value, etc.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func stride(_ stride: Int) -> Cold<Request, Response> {
    return appendStride(stream: newSubStream("stride(\(stride))"), stride: stride)
  }
  
  /**
   ## Branching
   
   Append a stamp to each item emitted from the stream.  The Stamp and the value will be emitted as a tuple.
   
   - parameter stamper: Takes a value emitted from the stream and returns a stamp for that value.
   - parameter value: The next value for the stream.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func stamp<U>(_ stamper: @escaping (_ value: Response) -> U) -> Cold<Request, (value: Response, stamp: U)> {
    let stream: Cold<Request, (value: Response, stamp: U)> = newSubStream("stamp")
    return appendStamp(stream: stream, stamper: stamper)
  }
  
  /**
   ## Branching
   
   Append a timestamp to each value and return both as a tuple.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func timeStamp() -> Cold<Request, (value: Response, stamp: Date)> {
    return stamp{ _ in return Date() }
  }
  
  /**
   ## Branching
   
   Emits a value only if the distinct handler returns that the new item is distinct from the previous item.
   
   - warning: The first value is _always_ distinct and will be emitted without passing through the handler.
   
   - parameters: 
     - isDistinct: Takes the prior, and next values and should return whether the next value is distinct from the prior value.
   If `true`, the next value will be emitted, otherwise it will be ignored.
     - prior: The prior value last emitted from the stream.
     - next: The next value to be emitted from the stream.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func distinct(_ isDistinct: @escaping (_ prior: Response, _ next: Response) -> Bool) -> Cold<Request, Response> {
    return appendDistinct(stream: newSubStream("distinct"), isDistinct: isDistinct)
  }
 
  /**
   ## Branching
   
   Only emits items that are less than all previous items, as determined by the handler.
   
   - warning: The first value is always mininum and will be emitted without passing through the handler.
   
   - parameters:
     - lessThan: Handler should take the first item, and return whether it is less than the second item.
     - isValue: The next value to be compared.
     - lessThan: The current "min" value.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func min(lessThan: @escaping (_ isValue: Response, _ lessThan: Response) -> Bool) -> Cold<Request, Response> {
    return appendMin(stream: newSubStream("min"), lessThan: lessThan)
  }
  
  /**
   ## Branching
   
   Only emits items that are greater than all previous items, as determined by the handler.
   
   - warning: The first value is always maximum and will be emitted without passing through the handler.
   
   - parameters:
     - greaterThan: Handler should take the first item, and return whether it is less than the second item.
     - isValue: The next value to be compared.
     - greaterThan: The current "max" value.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func max(greaterThan: @escaping (_ isValue: Response, _ greaterThan: Response) -> Bool) -> Cold<Request, Response> {
    return appendMax(stream: newSubStream("max"), greaterThan: greaterThan)
  }
  
  /**
   ## Branching
   
   Emits the current count of values emitted from the stream.  It does not emit the values themselves.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func count() -> Cold<Request, UInt> {
    return appendCount(stream: newSubStream("count"))
  }
  
  /**
   ## Branching
   
   This will stamp the values in the stream with the current count and emit them as a tuple.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func countStamp() -> Cold<Request, (value: Response, stamp: UInt)> {
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
   
   - returns: A new Cold Stream
   */
  @discardableResult public func delay(_ delay: TimeInterval) -> Cold<Request, Response> {
    return appendDelay(stream: newSubStream("delay(\(delay))"), delay: delay)
  }
  
  /**
   ## Branching
   
   Skip the first "n" values emitted from the stream.  All values afterwards will be emitted normally.
   
   - parameter count: The number of values to skip.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func skip(_ count: Int) -> Cold<Request, Response> {
    return appendSkip(stream: newSubStream("skip(\(count))"), count: count)
  }
  
  /**
   ## Branching
   
   Emit provided values immediately before the first value received by the stream.
   
   - note: These values are only emitted when the stream receives its first value.  If the stream receives no values, these values won't be emitted.
   - parameter with: The values to emit before the first value
   
   - returns: A new Cold Stream
   */
  @discardableResult public func start(with: [Response]) -> Cold<Request, Response> {
    return appendStart(stream: newSubStream("start(with: \(with.count) values)"), startWith: with)
  }
  
  /**
   ## Branching
   
   Emit provided values after the last item, right before the stream terminates.
   These values will be the last values emitted by the stream.
   
   - parameter conat: The values to emit before the stream terminates.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func concat(_ concat: [Response]) -> Cold<Request, Response> {
    return appendConcat(stream: newSubStream("concat(\(concat.count) values)"), concat: concat)
  }
  
  /**
   ## Branching
   
   Define a default value to emit if the stream terminates without emitting anything.
   
   - parameter value: The default value to emit.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func defaultValue(_ value: Response) -> Cold<Request, Response> {
    return appendDefault(stream: newSubStream("defaultValue(\(value))"), value: value)
  }
}

// MARK: Combining operators
extension Cold {
  
  /**
   ## Branching
   
   Merge a separate stream into this one, returning a new stream that emits values from both streams sequentially as an Either
   
   - parameter stream: The stream to merge into this one.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func merge<U>(_ stream: Stream<U>) -> Cold<Request, Either<Response, U>> {
    return appendMerge(stream: stream, intoStream: newSubStream("merge(\(stream))"))
  }
  
  /**
   ## Branching
   
   Merge into this stream a separate stream with the same type, returning a new stream that emits values from both streams sequentially.
   
   - parameter stream: The stream to merge into this one.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func merge(_ stream: Stream<Response>) -> Cold<Request, Response> {
    return appendMerge(stream: stream, intoStream: newSubStream("merge(\(stream))"))
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
   
   - returns: A new Cold Stream
   */
  @discardableResult public func zip<U>(_ stream: Stream<U>, buffer: Int? = nil) -> Cold<Request, (Response, U)> {
    return appendZip(stream: stream, intoStream: newSubStream("zip(stream: \(stream), buffer: \(buffer ?? -1))"), buffer: buffer)
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
   
   - returns: A new Cold Stream
   */
  @discardableResult public func combine<U>(latest: Bool = true, stream: Stream<U>) -> Cold<Request, (Response, U)> {
    return appendCombine(stream: stream, intoStream: newSubStream("combine(latest: \(latest), stream: \(stream))"), latest: latest)
  }
  
}

// MARK: Lifetime operators
extension Cold {
  
  /**
   ## Branching
   
   Emit values from stream until the handler returns `false`, and then terminate the stream with the provided termination.
   
   - parameter then: **Default:** `.cancelled`. When the handler returns `false`, then terminate the stream with this termination.
   - parameter handler: Takes the next value and returns `false` to terminate the stream or `true` to remain active.
   - parameter value: The current value being passed down the stream.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func doWhile(then: Termination = .cancelled, handler: @escaping (_ value: Response) -> Bool) -> Cold<Request, Response> {
    return appendWhile(stream: newSubStream("doWhile(then: \(then))"), handler: handler, then: then)
  }
  
  /**
   ## Branching
   
   Emit values from stream until the handler returns `true`, and then terminate the stream with the provided termination.
   
   - note: This is the inverse of `doWhile`, in that the stream remains active _until_ it returns `true` whereas `doWhile` remains active until the handler return `false`.
   
   - parameter then: **Default:** `.cancelled`. When the handler returns `true`, then terminate the stream with this termination.
   - parameter handler: Takes the next value and returns `true` to terminate the stream or `false` to remain active.
   - parameter value: The current value being passed down the stream.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func until(then: Termination = .cancelled, handler: @escaping (Response) -> Bool) -> Cold<Request, Response> {
    return appendUntil(stream: newSubStream("until(then: \(then))"), handler: handler, then: then)
  }
  
  /**
   ## Branching
   
   Emit values from stream until the handler returns a `Termination`, at which the point the stream will Terminate.
   
   - parameter handler: Takes the next value and returns a `Termination` to terminate the stream or `nil` to continue as normal.
   - parameter value: The current value being passed down the stream.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func until(_ handler: @escaping (_ value: Response) -> Termination?) -> Cold<Request, Response> {
    return appendUntil(stream: newSubStream("until"), handler: handler)
  }
  
  /**
   ## Branching
   
   Emit values from stream until the handler returns `false`, and then terminate the stream with the provided termination.
   
   - parameter then: **Default:** `.cancelled`. When the handler returns `false`, then terminate the stream with this termination.
   - parameter handler: Takes the next value and returns `false` to terminate the stream or `true` to remain active.
   - parameter prior: The prior value, if any.
   - parameter next: The current value being passed down the stream.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func doWhile(then: Termination = .cancelled, handler: @escaping (_ prior: Response?, _ next: Response) -> Bool) -> Cold<Request, Response> {
    return appendWhile(stream: newSubStream("doWhile(then: \(then))"), handler: handler, then: then)
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
   
   - returns: A new Cold Stream
   */
  @discardableResult public func until(then: Termination = .cancelled, handler: @escaping (_ prior: Response?, _ next: Response) -> Bool) -> Cold<Request, Response> {
    return appendUntil(stream: newSubStream("untilTransition(then: \(then))"), handler: handler, then: then)
  }
  
  /**
   ## Branching
   
   Emit values from stream until the handler returns a `Termination`, and then terminate the stream with the provided termination.
   
   - parameter handler: Takes the next value and returns `true` to terminate the stream or `false` to remain active.
   - parameter prior: The prior value, if any.
   - parameter next: The current value being passed down the stream.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func until(handler: @escaping (_ prior: Response?, _ next: Response) -> Termination?) -> Cold<Request, Response> {
    return appendUntil(stream: newSubStream("untilTransition"), handler: handler)
  }
  
  /**
   ## Branching
   
   Keep a weak reference to an object, emitting both the object and the current value as a tuple.
   Terminate the stream on the next event that finds object `nil`.
   
   - parameter object: The object to keep a week reference.  The stream will terminate on the next even where the object is `nil`.
   - parameter then: The termination to apply after the reference has been found `nil`.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   - warning: This stream will return a stream that _cannot_ be replayed.  This prevents the stream of retaining the object and extending its lifetime.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func using<U: AnyObject>(_ object: U, then: Termination = .cancelled) -> Cold<Request, (U, Response)> {
    return appendUsing(stream: newSubStream("using(\(object), then: \(then))"), object: object, then: then).canReplay(false)
  }
  
  /**
   ## Branching
   
   Tie the lifetime of the stream to that of the object.
   Terminate the stream on the next event that finds object `nil`.
   
   - parameter object: The object to keep a week reference.  The stream will terminate on the next even where the object is `nil`.
   - parameter then: The termination to apply after the reference has been found `nil`.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func lifeOf<U: AnyObject>(_ object: U, then: Termination = .cancelled) -> Cold<Request, Response> {
    return appendLifeOf(stream: newSubStream("lifeOf(\(object), then: \(then))"), object: object, then: then)
  }
  
  /**
   ## Branching
   
   Emit the next "n" values and then terminate the stream.
   
   - parameter count: The number of values to emit before terminating the stream.
   - parameter then: **Default:** `.cancelled`. How the stream is terminated after the events are emitted.
   
   - warning: Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func next(_ count: UInt = 1, then: Termination = .cancelled) -> Cold<Request, Response> {
    return appendNext(stream: newSubStream("next(\(count), then: \(then))"), count: count, then: then)
  }
  
}

extension Cold where Response : Sequence {
  
  /**
   ## Branching
   
   Convenience function that takes an array of values and flattens them into sequential values emitted from the stream.
   This is the same as (and uses) `flatMap`, without the need to specify the handler.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func flatten() -> Cold<Request, Response.Iterator.Element> {
    return flatMap{ $0.map{ $0 } }
  }
  
}

extension Cold where Response : Arithmetic {
  
  /**
   ## Branching
   
   Takes values emitted, averages them, and returns the average in the new stream.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func average() -> Cold<Request, Response> {
    return appendAverage(stream: newSubStream("average"))
  }
  
  /**
   ## Branching
   
   Sums values emitted and emit them in the new stream.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func sum() -> Cold<Request, Response> {
    return appendSum(stream: newSubStream("sum"))
  }
  
}

extension Cold where Response : Equatable {
  
  /**
   ## Branching
   
   Convenience function to only emit distinct equatable values.
   This has the same effect as using `distinct { $0 != $1 }` function.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func distinct() -> Cold<Request, Response> {
    return appendDistinct(stream: newSubStream("distinct"), isDistinct: { $0 != $1 })
  }
}

extension Cold where Response : Comparable {
  
  /**
   ## Branching
   
   Convenience function that only emits the minimum values.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func min() -> Cold<Request, Response> {
    return appendMin(stream: newSubStream("min")) { $0 < $1 }
  }
  
  /**
   ## Branching
   
   Convenience function that only emits the maximum values.
   
   - returns: A new Cold Stream
   */
  @discardableResult public func max() -> Cold<Request, Response> {
    return appendMax(stream: newSubStream("max")) { $0 > $1 }
  }
}
