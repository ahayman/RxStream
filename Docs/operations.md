# Operations

Listed below are all the operations available in RxStream.  It should be noted that different streams will have different operations available.

All operations are branching, meaning they return a new stream that can be used for 

 - `onError(_: (Error) -> Void) -> Stream<T>`
 
   This will call the handler when the stream receives a _non-terminating_ error.
  
 - `mapError(_: (error: Error) -> Termination?) -> Stream<T>`
 
   This will call the handler when the stream receives a _non-terminating_ error.
   The handler can optionally return a Termination, which will cause the stream to terminate.
  
 - `on(_: (T) -> Void) -> Stream<T>`
  
   Attach a simple observation handler to the stream to observe new values.
   
 - `onTransition(_: (T?, T) -> Void) -> Stream<T>`
 
   Attach an observation handler to the stream to observe transitions to new values. The handler includes the old value (if any) along with the new one.
   
 - `onTerminate(_: (Termination) -> Void) -> Stream<T>`
 
   Attach an observation handler to observe termination events for the stream.
  
   
 - `map<U>(_: (T) -> U?) -> Stream<U>`
  
   Map values in the current stream to new values returned in a new stream.
   
   - note: The mapper returns an optional type.  If the mapper returns `nil`, nothing will be passed down the stream, but the stream will continue to remain active.
  
 - `resultMap<U>(_: (T) -> Result<U>) -> Stream<U>`
 
   Map values in the current stream to new values returned in a new stream. 
   The mapper returns a result type that can return an error or the mapped value.
  
 - `asyncMap<U>(_: (T, (Result<U>?) -> Void) -> Void) -> Stream<U>`
 
   Map values _asynchronously_ to either a new value, or else an error.
   The handler should take the current value along with a completion handler.
   Once ready, the completion handler should be called with:
   
    - New Value:  New values will be passed down stream
    - Error: An error will be passed down stream.  If you wish the error to terminate, add `onError` down stream and return a termination for it.
    - `nil`: Passing `nil` into will complete the handler but pass nothing down stream.
   
   - warning: The completion handler must _always_ be called, even if it's called with `nil`.  Failing to call the completion handler will block the stream, prevent it from being terminated, and will result in memory leakage.
   
 - `flatMap<U>(_: (T) -> [U]) -> Stream<U>`
  
   Map values to an array of values that are emitted sequentially in a new stream.
   
  
 - `flatten() -> Stream<T.Iterator.Element>`
   
   Convenience function that takes an array of values and flattens them into sequential values emitted from the stream.
   This is the same as (and uses) `flatMap`, without the need to specify the handler.
  
 - `scan<U>(initial: U, scanner: (current: U, next: T) -> U) -> Stream<U>`
  
   Take an initial current value and pass it into the handler, which should return a new value. 
   This value is passed down stream and used as the new current value that will be passed into the handler when the next value is received.
   This is similar to the functional type `reduce` except each calculation is passed down stream. 
   As an example, you could use this function to create a running balance of the values passed down (by adding `current` to `next`).
   
 - `first(count: Int, then: Termination) -> Stream<T>`
  
   Returns the first "n" values emitted and then terminate the stream.
   By default the stream is `.cancelled`, but this can be overriden by specifying the termination.
   
 - `last(count: Int, partial: Bool) -> Stream<T>`
 
   Emits the last "n" values of the stream when it terminates.
   The values are emitted sequentially in the order they were received.

 - `reduce<U>(initial: U, reducer: (current: U, next: T) -> U) -> Stream<U>`
   
   This will reduce all values in the stream using the `reducer` passed in.  The reduction is emitted when the stream terminates.
   This has the same format as `scan` and, in fact, does the same thing except intermediate values are not emitted.
  
 - `buffer(size: Int, partial: Bool = true) -> Stream<[T]>`
   
   Buffer values received from the stream until it's full and emit the values in a group as an array.
   
 - `window(size: Int, partial: Bool = false) -> Stream<[T]>`
   
   Create a moving window of the last "n" values.
   For each new value received, emit the last "n" values as a group.
   
 - `window(size: TimeInterval, limit: Int) -> Stream<[T]>`
   
   Create a moving window of the last values within the provided time array.
   For each new value received, emit all the values within the time frame as a group.
   
 - `filter(include: (value: T) -> Bool) -> Stream<T>`
   
   Filter out values if the handler returns `false`.
    
 - `stride(stride: Int) -> Stream<T>`
  
   Emit only each nth value, determined by the "stride" provided.  All other values are ignored.
   
 - `stamp<U>(stamper: (value: T) -> U) -> Stream<(value: T, stamp: U)>`
   
   Append a stamp to each item emitted from the stream.  The Stamp and the value will be emitted as a tuple.
   
 - `timeStamp() -> Stream<(value: T, stamp: Date)>`
   
   Append a timestamp to each value and return both as a tuple.
   
 - `distinct(isDistinct: (prior: T, next: T) -> Bool) -> Stream<T>`
   
   Emits a value only if the distinct handler returns that the new item is distinct from the previous item.

 - `distinct() -> Stream<T>`

   Convenience function to only emit distinct equatable values for types that are Equatable
   This has the same effect as using `distinct { $0 != $1 }` function.
   
 - `min(lessThan: (isValue: T, lessThan: T) -> Bool) -> Stream<T>`
   
   Only emits items that are less than all previous items, as determined by the handler.
   
 - `min() -> Stream<T>`
   
   Convenience function that only emits the minimum values for Comparable values types.
   
 - `max(greaterThan: (isValue: T, greaterThan: T) -> Bool) -> Stream<T>`
  
   Only emits items that are greater than all previous items, as determined by the handler.
   
 - `max() -> Stream<T>`
   
   Convenience function that only emits the maximum values for Comparable value types.
   
 - `count() -> Stream<UInt>`
   
   Emits the current count of values emitted from the stream.  It does not emit the values themselves.
   
 - `countStamp() -> Stream<(value: T, stamp: UInt)>`
   
   This will stamp the values in the stream with the current count and emit them as a tuple.
   
 - `delay(delay: TimeInterval) -> Stream<T>`
   
   This will delay the values emitted from the stream by the time specified.
   
 - `skip(count: Int) -> Stream<T>`
   
   Skip the first "n" values emitted from the stream.  All values afterwards will be emitted normally.
   
 - `start(with: [T]) -> Stream<T>`
   
   Emit provided values immediately before the first value received by the stream.
   
   - note: These values are only emitted when the stream receives its first value.  If the stream receives no values, these values won't be emitted.
   
 - `concat(_: [T]) -> Stream<T>`
   
   Emit provided values after the last item, right before the stream terminates.
   These values will be the last values emitted by the stream.
   
 - `defaultValue(_: T) -> Stream<T>`
   
   Define a default value to emit if the stream terminates without emitting anything.

### Combining operators

Combining operators involve joining two different streams together to produce a new single stream that includes the values of both streams.  _How_ you combine these two streams constitutes the difference between the operations.  Some operators will produce tuples, others will produce sequential values of either stream value, while some will produce a single stream of all values of the same type.  Just depends on what you're looking to accomplish.

 - `merge<U>(stream: Stream<U>) -> Stream<Either<T, U>>`

   Merge a separate stream into this one, returning a new stream that emits values from both streams sequentially as an Either
   
 - `merge(stream: Stream<T>) -> Stream<T>`
   
   Merge into this stream a separate stream with the same type, returning a new stream that emits values from both streams sequentially.
   
 - `zip<U>(stream: Stream<U>, buffer: Int) -> Stream<(T, U)>` 
   
   Merge another stream into this one, _zipping_ the values from each stream into a tuple that's emitted from a new stream.
   
   - note: Zipping combines a stream of two values by their _index_.
   In order to do this, the new stream keeps a buffer of values emitted by either stream if one stream emits more values than the other.
   In order to prevent unconstrained memory growth, you can specify the maximum size of the buffer.
   If you do not specify a buffer, the buffer will continue to grow if one stream continues to emit values more than another.
   
 - `combine<U>(latest: Bool, stream: Stream<U>) -> Stream<(T, U)>`
   
   Merge another stream into this one, emitting the values as a tuple.
   
   **warning:** The behavior of this function changes significantly on the `latest` parameter.  
   
   Specifying `latest = true` (the default) will cause the stream to enumerate _all_ changes in both streams.
   If one stream emits more values than another, the lastest value in that other stream will be emitted multiple times, thus enumerating each combinmation.
   
   If `latest = false`, then a value can only be emitted _once_, even if the other stream emits multiple values.
   This means if one stream emits a single value while the other emits multiple values, all but one of those multiple values will be dropped.

### Lifetime operators

Lifetime operators specifically define exactly how long a stream is allowed to remain active before it terminates. All operations allow some way of specifying how exactly a should be terminated (normally, it is cancelled by default).  Some operators tie the lifetime to another object, while others require you to tell the stream if it should terminate on every value it receives and yet others will auto terminate after a specific condition is met.
  
 - `doWhile(then: Termination, handler: (T) -> Bool) -> Stream<T>`
   
   Emit values from stream until the handler returns `false`, and then terminate the stream with the provided termination.
   
  **warning:** Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
 - `until(then: Termination, handler: (T) -> Bool) -> Stream<T>`
   
   Emit values from stream until the handler returns `true`, and then terminate the stream with the provided termination.
   
   *note:* This is the inverse of `doWhile`, in that the stream remains active _until_ it returns `true` whereas `doWhile` remains active until the handler return `false`.
   
   **warning:** Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
 - `until(handler: (T) -> Termination?) -> Stream<T>`
   
   Emit values from stream until the handler returns a `Termination`, at which the point the stream will Terminate.
   **warning:** Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
 - `doWhile(then: Termination, handler: (T?, T) -> Bool) -> Stream<T>`
   
   Emit values from stream until the handler returns `false`, and then terminate the stream with the provided termination.
   **warning:** Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
 - `until(then: Termination, handler: (T?, T) -> Bool) -> Stream<T>`
   
   Emit values from stream until the handler returns `true`, and then terminate the stream with the provided termination.
   
   _note:_ This is the inverse of `doWhile`, in that the stream remains active _until_ it returns `true` whereas `doWhile` remains active until the handler return `false`.
   **warning:** Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
 - `until(handler: (T?, T) -> Termination?) -> Stream<T>`
   
   Emit values from stream until the handler returns a `Termination`, and then terminate the stream with the provided termination.
   **warning:** Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
 - `using<U: AnyObject>(object: U, then: Termination) -> Stream<(U, T)>`
   
   Keep a weak reference to an object, emitting both the object and the current value as a tuple.
   Terminate the stream on the next event that finds object `nil`.
   **warning:** Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   **warning:** This stream will return a stream that _cannot_ be replayed.  This prevents the stream of retaining the object and extending its lifetime.
  
 - `lifeOf<U: AnyObject>(object: U, then: Termination) -> Stream<T>`
   
   Tie the lifetime of the stream to that of the object.
   Terminate the stream on the next event that finds object `nil`.
   **warning:** Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
   
 - `next(count: UInt, then: Termination) -> Stream<T>`
   
   Emit the next "n" values and then terminate the stream.
   
   **warning:** Be aware that terminations propogate _upstream_ until the termination hits a stream that has multiple active branches (attached down streams) _or_ it hits a stream that is marked `persist`.
  

### Math Operations

Most of these operations can be done using other operators and some kind of intermediate state.  However, they're provide as convenience when the stream is emitting values than can be manipulated mathematically.  All of these operations require that the value conform to `Arithmatic` protocol, which defines the normal minimal set of math operations (+, -, /, *).  While all the default types have been extended to conform to `Arithmatic`, you can easily extend your own types if you should so desire.
  
 - `average() -> Stream<T>`
  
   Takes values emitted, averages them, and returns the average in the new stream.
   
 - `sum() -> Stream<T>`
   
   Sums values emitted and emit them in the new stream.

