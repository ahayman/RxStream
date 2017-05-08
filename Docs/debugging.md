# Debugging

Debugging Reactive code can be notoriously difficult. Often, Reactive frameworks will add significant size to a stack trace that add "noise" at best and at worst can make it almost impossible to debug.  For this reason, it is common for developers to start sprinkling `print` statements throughout their code while debugging in an attempt to figure out what's going on.  While RxStream cannot fix all of this, it does have some features can can help make it a lot easier to debug.


## Debug Description

All Streams/Operations have a custom debug description that includes:
   - The type of the Stream, ex: `Hot<Int>`, `Cold<String, Int>`, `Future<String>`, etc.
   - The name of the operations and relevant info: `map<Int>`, `on`, etc.
   
So if you had a Hot stream with a map operation that takes an `Int` and outputs a `String`, it's debug description would be:

```swift
let hot = HotInput<Int>()
let operation = hot.map{ String($0) }
print(operation) // prints: "Hot<String>.map<Int>"
```

You can also override a description using the `.named` function, to give you more insight and control over how operations and streams are displayed:

```swift
let hot = HotInput<Int>()
let operation = hot.map{ String($0) }.named("My Operation")
print(operation) // prints: "My Operation"
```

## Logging

RxStream includes two different levels to log debug information.  How the information gets logged is up to you.  In all cases, you enable logging by setting a log handler so that you can choose how to log the debug info. By default, all log handlers are `nil`.

There are several kinds of information that is logged:
 - When a Stream begins processing an event: `begin processing <event>`
 - When a Stream pushes an event down stream: `push event <event>`
 - When a Stream stops processing an event: `end processing <event>`
 - When a stream Terminates: `terminating with <termination reason>`
 - When a Throttle cancels an event (or drops values): `throttle cancelled <event>`
 - When an event is replayed down stream: `replay event <event>`

#### Global Logging

You can ask RxStream to log everything by setting the global debug printer.  There is only one debug handler (set as a static constant) that all streams will use if the handler is present. This means you only need to set it once, and overwriting it will overwrite the debug handler for all streams.

```swift
Hot<Void>.debugPrinter = { info in
  print(info)
}
```
_Will print all info the console_.

_Note:_ The global debug printer is set using a class variable on `Stream<T>`.  But because `Stream` is a generic, you have to provide some kind of type info, even though it will set the printer for all types.  This means you can't expect different handlers for `Hot<Void>`, `Hot<Int>`, or `Future<String>`... they all use the same handler.

#### Stream logging

Depending on your project, global logging will likely produce a lot of extra noise.  Instead, you can ask individual streams/operations to log their debug info.

For example this:

```swift
let hot = HotInput<Int>()
hot
  .map{ String($0) }.onDebugInfo{ print($0) }
  .on{ /* update state */ }

hot.push(0)
hot.push(1)
hot.terminate(withReason: .completed)
```

produces the following logs:

```
Hot<String>.map<Int>: begin processing .next(0)
Hot<String>.map<Int>: push event: .next(0)
Hot<String>.map<Int>: end Processing .next(0) 
Hot<String>.map<Int>: begin processing .next(1)
Hot<String>.map<Int>: push event: .next(1)
Hot<String>.map<Int>: end Processing .next(1) 
Hot<String>.map<Int>: begin processing .terminate(reason: .completed)
Hot<String>.map<Int>: Terminating with .completed
Hot<String>.map<Int>: end Processing .terminate(reason: .completed) 
```

Only the specified streams will log debug information.  This should help you narrow down and see what exactly what's going on in the stream.

### Tip

You can use the `onDebugInfo` to create a breakpoint that breaks immediately before a value is going to be processed, right the processed value will be pushed down stream, and right after processing has completed.  This can be useful for debugging operations.