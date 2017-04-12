# Timer

Rx.Timer is unusual in that it's the only concrete Rx stream that doesn't require a task or external input.  In truth, you could create your own "timer" stream by embedding a `Foundation.Timer` into a `HotTask` and having it emit events.  The problem is that controlling the timer and avoiding retain cycles can be problematic.  For this reason, I added this type to make it easy to create Timer streams that emit events at a specified interval.

The timer has several features:

 - No need to worry about retain cycles. `Rx.Timer` will keep the timer alive only as long as itself is retained and the stream is active.
 - Easily start, stop, and restart the timer manually by calling `start()`, `stop()` and `restart()`.
 - By default the Timer will use `Foundation.Timer.scheduledTimer(...)`, which handles the majority needs.  However, the handler that creates this _can_ be replaced with whatever you want, allowing you to use timers on different run loops, etc.
 - Standard Stream operations and processing chains inherent in Hot streams.
 
### Examples

Some simple examples showing how a timer might be used.
 
```swift
let timer = Rx.Timer(interval: 1.0).start()

timer
  .count()
  .on{ print("\($0) sec") }
``` 

Simple example that will count the seconds and print them out.

```swift
let timer = Rx.Timer(interval: 1.0)

timer
  .count()
  .stride(10)
  .on{ print("\($0) sec") }
```

Use a Timer that emits events every second and take only the 10th second and print it out.  Of course, you could just create a Timer with a 10 second interval, but I wanted to show how you might leverage an existing Timer.

```swift
let timer = Rx.Timer(interval: 1.0)

timer
  .map{ Date() }
  .on{ print($0) }
```

Map the timer events into a Date and print it.  

