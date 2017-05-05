# RxStream

RxStream is a simpler kind of Reactive framework for Swift that seeks to integrate well into existing language and architectural paradigms instead of replacing them.

If you’re looking for a full Reactive framework, you’d probably be best taking a look at [RxSwift](https://github.com/ReactiveX/RxSwift) or [ReactiveCocoa](https://github.com/ReactiveCocoa/ReactiveCocoa).  In contrast to these, RxStream is a much pared down version of React.  The motivation for this is several fold:

- With a simpler paradigm, the learning curve is a lot shorter. It’s easier to get other developers to invest into using it.
- RxStream tries hard to divest itself of some of the more obscure syntax and complications that seem inherent in most Reactive frameworks.  This can help create more readable and maintainable code.
- Whereas many proponents of React advocate it as a replacement for many existing architectures and software solutions, RxStream was designed mostly as a supplement to the paradigms you’re already using.  It’s designed to _enhance_ and integrate into Swift’s inherit language features instead of ignoring or replacing them.  Use RxStream as little or as much as you’d like.  It won’t get in your way.


## Overview

_Note: If you’re new to React, you may want take a look at the introduction to Reactive at [ReactiveX](http://reactivex.io/intro.html).  This will help you get a good grasp on some of the core principles of React. However, some terms they use may be different than what RxStream uses._

RxStream operates around the idea of a transforming stream of values.  If you’re familiar with ReactiveX, their `Observable<T>` would be the closest comparable to RxStream’s `Stream<T>`.  All streams have a variety of relevant operations that observe and transform the stream’s values.  However, with RxStream, there is a very clear distinction between the _types_ of streams created and returned.  This removes any uncertainty about what the stream is, how it operates, and what the client can expect from it:

- **[Hot](/Docs/hot.md)**: A Hot stream is a kind of stream that produces values with no regard or input from it’s clients.  When a client registers operations on a Hot stream, it will receive values as they come.
- **[Cold](/Docs/cold.md)**: A Cold stream only produces values when a client makes a `Request`.  Unlike all other streams, a Cold stream has two types: `Request` and `Response`.  A client makes a `Request` and receive a `Response` from the Cold stream.  
- **[Future](/Docs/future.md)**: A future is a stream that produces _only_ one value and then closes.  
- **[Promise](/Docs/promise.md)**: A type of future that produces only one value, but it can be cancelled and retried by it’s client until it produces an error or a valid value.
- **[Observable](/Docs/observable.md)**: An observable is a kind of Hot Stream who’s value is guaranteed and can be directly observed and accessed outside of the stream.
- **[Timer](/Docs/timer.md)**: This is a concrete Hot Stream that emits an event repeatedly on a predefined interval.  While you can create your own timer by creating a `HotTask`, because of `Foundation.Timer`'s retaining behavior, it can be tricky to do this without creating a retain cycle.  So `Rx.Timer` has been created to provide an easier way.

Hot and Observable streams have subclasses used for producing the values.  While Cold, Promise and Future streams can only be initialized with a Task (that generates the value).

## Features

RxStream has several features that help you manage and use them easily.

- **[Dispatch](/Docs/dispatch.md)**: All streams can have their operations done on a specified dispatch (which uses GCD under the hood).  This allows you to easily perform your operations on the main queue, a background queue or a custom queue you create.
- **[Throttle](/Docs/throttle.md)**: A throttle allows you to control the flow of data being passed own the streams.  One of the most useful is a Pressure Throttle, which will buffer processing and prevent too many values from being processed based on the current work load.
- **Disposal**:  Instead of using separate object(s) to dispose of processing chains, RxStream allows you to dispose of streams intuitively and specifically within the chain itself.  When any part of a stream terminates, that entire branch will be pruned.  Plus, you can easily specify when a branch terminates by using explicit `doWhile` or `until` operators or even tie the lifetime of the branch to a specific object.
-  **Replay**: Streams can optionally be replayed, which will pull down the last value of a stream (if any) when creating a processing chain from an existing stream. Simply call `replay()` at the end of a processing chain, if there is a prior value available it will be pulled into the processing chain. Both Future and Promise streams will auto-replay a completed value into any new processing chain by default.
- **Operations**: Each stream features a wide range of operations you can use to process your data.  However, we have avoided more complex operators, specifically those operators that produce or work on streams that contain other streams.  This is the primary area that RxStream differs from other Reactive frameworks.  
- **Clear Terminators**: Each stream terminates with clear language, defined by an enum:
	- `case .cancelled`: The stream has been cancelled.
	- `case .completed`: The stream has been completed.
	- `case .error(Error)`: The stream has terminated with an error.
- **Non-terminating Errors**: In addition to the normal values, non-terminating errors can also be pushed into the stream and observed.  These errors can be turned into terminating errors down stream.
- **Construction**: Constructing processing chains on a stream is the process of subscribing.  There’s no need manually call `subscribe` to start receiving values.  It’s rare for a developer to need to construct a chain without actually using it, so instead of forcing you to call `subscribe`, if you _don’t_ want to receive values, instead use `filter` to filter them out until you are ready.
