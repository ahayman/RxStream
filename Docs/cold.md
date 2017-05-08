<img src="/Docs/badges/cold.jpg" height=100 alt="Cold Stream"> 

A Cold stream only produces values when a client makes a `Request`.  Unlike all other streams, a Cold stream has two types: `Request` and `Response`. A client makes a `Request` and receive a `Response` from the Cold stream. A cold stream is initialized with a task that should take a `Request` and return a `Response` in the task’s completion handler.

Where the request is made plays an important role in a Cold stream as, by default, the response to a request will _only_ be passed down into the processing chain that originally made the request.  This is a significant departure from the other streams in that it allows a clear separation between the branches in the stream.  Specifically, this means that a call made in one branch will not affect a different processing chain, which avoids creating unintended side effects and implicit dependencies.  However, there are situations where a request from _any_ chain should be passed to all branches.  So a Cold stream can be told to share a `Response` it receives with all it’s branches.

Example:

	let coldTask = Cold<Int, Int> { _, request, respond in
	   respond(.success(request + request % 2)) // Only return even numbers
	 }
	 
	 // Branch A
	 let branchA = coldTask
	   .map{ "Branch A: \($0)" }
	   .on{ print($0) }
	 
	 // Branch B
	 let branchB = coldTask
	   .map{ "Branch B: \($0)" }
	   .on{ print($0) }
	 
	 branchA.request(3) // prints: "Branch A: 4"
	 branchB.request(4) // prints: "Branch B: 4"
	 branchA.request(6) // prints: "Branch A: 6"

The same task serves all requests, but the response from that task only travels down the branches that made the request.  However, we could easily change this so that the response travels down _all_ branches:

	let coldTask = Cold<Int, Int> { _, request, respond in
	   respond(.success(request + request % 2)) // Only return even numbers
	 }
	 
	 // Branch A
	 let branchA = coldTask
	   .map{ "Branch A: \($0)" }
	   .on{ print($0) }
	 
	 // Branch B
	 let branchB = coldTask
	   .map{ "Branch B: \($0)" }
	   .on{ print($0) }
	 
	 branchA.request(3) // prints: "Branch A: 4"
	 branchB.request(4) // prints: "Branch B: 4"
	 branchA.request(6) // prints: "Branch A: 6"
	 
	 coldTask.request(7, share: true) // prints: "Branch A: 7" & "Branch B: 7"

Because we’ve told the `coldTask` to share it’s response, they now travel down all branches after the request.  This allows you to prune the branches that receive the request and those that do not.  This adds a lot of flexility in how, when, and where the data processing should occur.

Like all the other streams, Cold streams allows you to perform a variety of operations on the values (Responses) of the stream.  However, Cold streams also give you the option to map the `Request` as well.  This gives you an enormous amount of flexibility in how you structure your processing chains.

Again another contrived example:

	let coldTask = Cold<Double, Double> { _, request, respond in
	  respond(.success(request + 0.5))
	}
	    
	let branch = coldTask
	  .mapRequest{ (request: Int) in
	    return Double(request)
	  }
	  .map{ "\($0)" }
	  .on{ print($0) }
	 
	branch.request(1) // print: "1.5"
	branch.request(10) // print: "10.5"
	branch.request(15) // print: "15.5" 


The original Cold stream take a `Double` value as a request, but we want to provide `Int` instead.  So we map the Request `Int -> Double` so that when we make the request, it’s converted into a `Double`.  Allowing the transformations to occur on both the `Request` and `Response` types provide a lot of flexibility.

In addition to providing values, a Cold Stream task can also respond with an error.  By default, errors are non-terminating, so while they are propagated down the processing chains, they do not terminate the chains.  Processing chains can optionally choose to map these errors into a termination if they choose (which will only terminate that chain), using `mapError(_ mapper: Error -> Termination?)`.  

It should be noted that the Cold Stream’s _state_ is passed into the task as an `Observable` every time it’s called.  This allows the task to periodically check the or respond to the stream’s state and cancel itself if the stream is no longer active.  While we’ve ignored this aspect in the examples, it can help some tasks avoid unnecessary processing in the case the stream is terminated.