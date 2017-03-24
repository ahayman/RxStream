# Hot Stream
A Hot stream is a kind of stream that produces values with no regard or input from it’s clients.  When a client registers operations on a Hot stream, it will receive values as they come as soon as the client adds operations to it.

Hot streams are created in one of two ways:

1.  `HotInput<T>()`: A standalone subclass of `Hot` that allows you to manually push new values into the stream.
	- `func push(_ value: T)`: Push a new value into the stream.
	- `func push(_ error: Error)`: Push a non-terminating error into the stream.
2. `HotProducer<T>(task: (Event<T>) -> Void)`: A Hot class that receives it’s events from a closure associated with the task. The closure call the task handler to push new values, errors, and termination.

In each case, once a client has added operations to a Hot stream, it will immediately begin receiving data from the stream as they are produced.  

As a simple example:

	let input = HotInput<Int>()
	
	input
	   .map{ "Integer: \($0)" }
	   .on{ print($0) }
	 
	 input.push(0)  //prints: "Integer: 0"
	 input.push(10) // prints: "Integer: 10"

This creates a `HotInput` that handles `Int` values.  Each value is mapped to a `String`, and then printed.  While this is a contrived example, it show the basics of how the Hot stream works and there are a wide variety of operations you can do on a `Hot` stream.

Both the `HotInput` and `HotProducer` types need to be retained in order to work.  Once they `deinit`, all streams that are attached to them will be terminated.

All streams can have multiple branches.  So after creating the first branch (or processing chain) we can easily add another:

	let input = HotInput<Int>()
	
	 // Branch 1
	input
	   .map{ "Integer: \($0)" }
	   .on{ print($0) }
	 
	 // Branch 2
	 input
	   .next(2)
	   .countStamp()
	   .map{ "Value # \($1) is Integer \($0)" }
	   .on{ print($0) }
	 
	 input.push(0)  //prints: "Integer: 0" & "Value # 1 is Integer 1"
	 input.push(10) // prints: "Integer: 10" & "Value # 2 is Integer 10"
	 input.push(100) // prints: "Integer: 10".  The second branch has been terminated and pruned.

Here’s we’ve added a second branch that will only process the next 2 events and then terminate.  The first branch will only terminate when the `HotInput` is terminated.

Hot streams are normally used when you have something that automatically generates events that others need to respond to.  Examples include things like touch, tap or click events.  Also notifications an object might want to emit are another good example.  
