# Dispatch

RxStream includes a wrapper around Grand Central Dispatch called `Rx.Dispatch`, which it uses in streams to ensure that operations are performed in the specified Dispatch Queue using the correct manner (async, sync, etc).

_Why not use Apple's Dispatch natively?_  While Apple's new Dispatch abstraction is much improved over their prior c-like interface, it still falls short in a few areas that `Rx.Dispatch` solves:

 - _Limited Re-entry Detection:_  `Rx.Dispatch` can detect re-entry locks to due sync execution on a serial queue.  For example, using a serial queue as a lock can get tricky as a type's complexity increases (multiple paths to access the locked resource). `Rx.Dispatch` can detect when you attempt to dispatch sync onto a serial queue from that same queue, and instead execute the code inline instead.  This can save a lot of heartache.  However, it should be noted that it's re-entry detection is limited.  Larger deadlocks can still occur if an intermediate queue is being used.  For example: `dispatch sync on serial` -> `dispatch sync on main` -> `dispatch sync on serial` will still deadlock.
 - _Clean Syntax_: `Rx.Dispatch` relies heavily on enums to create a clean syntax that is very auto-complete friendly.  For example, to dispatch async on the main thread: `Rx.Dispatch.async(on: .main).execute{ ... }`.  
 - _Stored Dispatch Method_: `Rx.Dispatch` allows you to store the actual dispatch method as a variable parameter, something that's not possible with `Foundation.Dispatch`. For example, a class can store and expose a `Dispatch` variable, allowing a client to change it.  This allows you to change how and where that class performs it's operations: `myCache.dispatch = .async(on: .main) //My cache now performs all it's operations asynchronously on the main queue`. 
 - _Chained execution:_ It's common to need to switch back and forth between queues.  For example, we may receive data on a custom queue, switch to a background queue to operate on the data, then switch again to the main queue to update the UI.  All of these are nested operations that can work to make the code difficult to read.  `Rx.Dispatch` allows you to chain operations together sequentially as a chain instead of nesting the dispatches.
 - _Custom Queues_: `Rx.Dispatch` wraps around and works with custom queues, storing both them and the dispatch method separately or together.
 - _Dedicated Threading_: By using `DispatchThread`, you can dispatch asynchronously on a specific, single Thread.  This is useful if you need to access resources on a single Thread.  However, because creating Threads is expensive, most of the time it's better to use a Queue, which will operate from a pool of existing Threads.
 
#### Limitations 

There are a few limitations with `Rx.Dispatch` that may cause you to need to use GCD natively:

 - `Rx.Dispatch` currently only covers the common cases.  More advanced GCD usage isn't yet implemented (ex: barrier dispatch on custom async queues)
 - `Rx.Dispatch` _is_ a wrapper.  As such, it will add a small amount of overhead to GCD. In most situations, this is fine.  However, if you are fine tuning for performance, it may be worth it to use GCD directly.
 
 
 ### Stream Dispatch
 
 All Rx Streams have a dispatch property that can be accessed directly or as part of a processing chain.  This allows you to directly control how operations are performed:
   
   ```swift
   stream
    .dispatch(.async(on: .background)).map{ value -> newValue in
      //process value and return the newValue
      //All processing done automatically in the background
    }
    .dispatch(.async(on: .main)).on{ value in
      //Update UI with new method from the main queue
    }
```

This makes for very clear and easy to understand syntax so that you can specify exactly how the operation is to be performed without adding additional nesting.

Sometimes, it may make sense (from a syntax standpoint) to specify the dispatch _after_ the operation.  This can be done with the `dispatched` method:

   ```swift
   stream
    .map{ value -> newValue in
      //process value and return the newValue
      //All processing done automatically in the background
    }.dispatched(.async(on: .background))
    .on{ value in
      //Update UI with new method from the main queue
    }.dispatched(.async(on: .main))
```

While it's purely syntactic sugar, it's there to help you make your code as readable as possible.  But overall it has the exact same effect.

### Notes

 - By default, a stream's `dispatch` is set to `nil`.  While `dispatch` does have an `.inline` option, I discovered that using dispatch creates extra "noise" in the stack trace when debugging, almost tripling the stack trace (because dispatch is used extensively in the stream).  So I rewrote it to only use dispatch if it's there.
 - The corollary to above is that by default a stream does everything inline. If an event is pushed into a stream on the main queue, operations down stream will also be performed on the main queue.  If an operation uses a different queue, then all operations downstream will use that queue by default simply because they will be done inline.  
 - The one exception to to the above point is asynchronous operations.  For example, if you perform an asynchronous mapping operation, the processing chain following that operation will operate on whatever queue the asynchronous operation returned from.
