<img src="/Docs/badges/future.jpg" height=75 alt="Future Stream">

A Future is a simple stream that returns a single value (or an error) and then terminates.  At it’s core, it’s a replacement for the callback closures frequently used to return asynchronous values.  But as a stream, you get this asynchronous value with the ability to process it just as you would a normal stream.  This not only gives you the power and flexibility that streams provide, but also helps prevent nested code and increase the readability of your project.

A Future is a “throw away” stream, meaning you don’t have to retain it.  Simple initialize it with the task that produces the value and pass it on.  The Future will retain itself (lock itself in memory) until it is filled.  For this reason, it’s frequently the return from what would normally be an asynchronous function with a callback.  Using callbacks tends to involve nesting:

	func network(request: NetWorkRequest, completion: (String) -> Void)
	 
	client.network(request) { response in
	  let json = response.jsonValue
	  DispatchQueue.global().async {
	     let object = json.convertToObject. 
	     DispatchQueue.main.async {
	       // update self
	     }
	  }
	}

Compared to using callback handler, this is a much cleaner approach:

	func network(request: NetworkRequest) -> Future<String>
	 
	 client.network(request: request)
	   .map{ $0.jsonValue }
	   .dispatch(.async(on: .background)).map{ 
	      // convert json to an object in background
		   }
	   .dispatch(.async(on: .main)).on{ 
	      // Update self with new object on main
	   }


By using `dispatch`, you can ensure the operation you add next will be done on the Dispatch Queue you’ve specified.  This allows you to flatten out what would normally be a lot of nested closures.

Future allows the task to also return an Error, at which point the Future stream will be terminated with that error (note: there are no non-terminating errors for a future stream).  This allows you to easily handle errors in the processing chain:

	 client.network(request: request)
	   .map{ $0.jsonValue }
	   .dispatch(.async(on: .background)).map{ 
	      // convert json to an object in background
		   }
	   .dispatch(.async(on: .main)).on{ 
	      // Update self with new object on main
	   }
	    .onError{ 
	      // handle error
	    }


Note: Where you place the `onError` in the processing chain matters.  If you place it at the beginning of the chain, it will only be called for errors returned by the network request.  If you place it at the end of the chain, it will also pick up errors that could be emitted by the processing chain itself.

### Lazy

Lazy is a type of Future that _only_ runs the task given to it when it's needed... when a child stream (an operation) is attached to it.  In contrast, a normal Future will execute it's task immediately so that it's ready as soon as possible. Once the task is executed the value is kept but the task is discarded in order to free up resources.

Normally, you'd use Lazy when generating a value is expensive and you want to provide access to that value only if it's needed.

### Replaying Value

When you receive a Future, you can never know whether the Future has been completed or not. If the Future has completed, the completed value will replay after a short amount of time.  The delay is there to ensure the processing chain has had a chance to be added.  Otherwise, if you need the value immediately, you can call `replay()` at the end of the processing chain and the completed value will immediately be pushed into the new processing chain.  If the Future hasn't been filled, calling `replay()` will do nothing.

### Merge Operations

Just as any stream, both Future and Promise can be merged into other streams. It's important to understand how a Future and Promise work before you attempt merging them into each other or another type of stream.  

Because merge operations always return the left-hand Stream type (the stream being merged into, or the stream on which `merge/combine/zip` is called), then merging _any_ stream into a Future or Promise will return a Future or Promise.  This creates very specific behavior:

 - `merge(_)` - Merge operations will emit 1 value from _either_ stream and then complete.  
 - `combine(_)` and `zip(_)`: Both combine and zip will end up doing the exact same thing.  They will emit 1 combination of values, 1 from each stream and then complete.  

