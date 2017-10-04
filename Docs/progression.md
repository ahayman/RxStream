<img src="/Docs/badges/future.jpg" height=75 alt="Future Stream">

A Progression is a type of Future that allows a client to observe the progress of some task that will eventually terminate in a `Result`.  As a `Future` only one `Result` can be returned, but until then a multitude of `ProgressEvents` can be observed by the client.  The most obvious use of this is to update a user interface with the progression until the result can be returned.  For example, downloading or processing a file.

  At it's core, the Progression stream replaces the standard two handler function signature with a single return value.  For example, this:

      func downloadImage(at url: URL, progressHandler: ((Progression) -> Void)?, completion: (URL) -> Void)

  can be replaced with:

      func downloadImage(at url: URL) -> Progression<Double, URL>

  The client can then choose to observe the progress on their own terms:

      downloadImage(at: someURL)
         .onProgress{ p in self.updateUIWith(progress: p) }
         .on{ url in self.handleDownloadedImage(at: url) }

A `Progression` is defined by two types, the type that represents the "progress" and the final return type of the `Future`.  It's common to use `Double`, `Float`, `Int` or some numeric type to represent Progress, but you can use any type that fits your needs.


### Initialization

A Progression is instantiated by providing a Progress Task closure in the initializer.  This closure will be called immediately, and itself will pass in another closure that is used to both update the progress of the task and complete the task with a result.  It's very important that the task always return a Result eventually.  If it does not, then both the Task's closure, anything it captures and the Progression stream itself will be retained in memory as a memory leak.   

The closure passed into Task will need to be called to both update the progress and return the final result:

    (Either<ProgressEvent<ProgressUnit>, Result<T>>) -> Void

Note that it requires an `Either`.  This mean you can pass in _either_ a Progress Event, or the final result.  You can pass in as many Progress Events as you'd like _until_ you pass in a Result _or_ the stream is cancelled (more on that below).  Once you pass in a Result, the result will propogate through the stream and the stream will terminate.

### Progress Event

When the progress of a task is updated, it's done so through a `ProgressEvent<T>`.  The type of the event will match the first type of the Progression.  So, if you have a `Progression<Double, URL>` stream, it will emit `ProgressEvent<Double>` events.  A progress event includes the basic information needed to display the progress of the task:

 - `title`: This should normally not change much (or at all), but should be a user-friendly string that defines what the progression represents.
 - `unitName`: Represents the progression unit.  Example: `mb`, `%`, etc.  Should be a short string that is easily appended and displayed as part of the progress.
 - `current`: The current progression, normally should be less than the `total`.
 - `total`: The total of the progression when complete.  When `current` == `total`, it's expected that the progression is done.
 
 ### Cancellation 
 
 The Progress Task will also pass in a `Box<Bool>` value that represents whether or not the stream has been cancelled.  It's highly recommended, especially with tasks that might be intensive, to check this value frequently to prevent unnecessary load.  If the stream has been cancelled, it cannot receive any further progress events or the final result.  Any call to the completion closure will be ignored.  
 
 ### Observing
 
 Observing the progress is as simple as using the `onProgress` function to register for progress updates. For example:
 
      downloadImage(at: someURL)
         .onProgress{ p in self.updateUIWith(progress: p) }
 
 Every time the task updates the progress, a new event will be called with the closure, allowing you to respond to it.
 
Additionally, because a Progression is also a Future, all the observations, mapping, filtering, etc available to a Future is also available to a Progression.

### Mapping and Combining

There are a couple of extra functions for mapping a progress event and combining one progression with another.  Mapping a progression event  is almost exactly like mapping a standard value and simply involves providing a closure that takes a ProgressEvent of one value and returns a ProgressEvent of another value.

Combining two Progression streams together involves more work.  To do this, you need to take the Progress events of each stream and map them to a new one.  Since this could include events from one or both streams, an `EitherAnd` construct is used.  As an example:

    left
      .combineProgress(stream: right) { (events: EitherAnd<ProgressEvent<Int>, ProgressEvent<Double>>) -> ProgressEvent<Double> in
        switch events {
        case let .right(e): return ProgressEvent(title: e.title, unitName: e.unitName, current: e.current / e.total * 100.0, total: 100.0)
        case let .left(e): return ProgressEvent(title: e.title, unitName: e.unitName, current: Double(e.current) / Double(e.total) * 100.0, total: 100.0)
        case let .both(l, r):
          return ProgressEvent(
            title: l.title + ", " + r.title,
            unitName: "%",
            current: (Double(l.current) / Double(l.total)) * 50.0 + (r.current / r.total) * 50.0,
            total: 100.0)
        }
      }

The combined stream will emit Progress Events of the mapped type and will emit the results from _both_ streams _at the same time_ as a tuple.  