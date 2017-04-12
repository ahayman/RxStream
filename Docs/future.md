# Future

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

### Replaying Value

Because a Future represents a single value, it will automatically replay the last (and only) value into new operations.  This is in contrast to other streams (like Hot, Cold, and Observable), which will only replay values if you ask for it.  

This is done to cover the most common case (if you ask a client for a Future, it's assumed you want the value you asked for).  However, you should be aware of this behavior.

### Merge Operations

Just as any stream, both Future and Promise can be merged into other streams. It's important to understand how a Future and Promise work before you attempt merging them into each other or another type of stream.  Specifically, both are designed to emit a single value and then automatically complete.  It's important to realize that when given a Future or Promise from a client, _you can't assume it's not already completed_. This can create behavior different from what you might accept. 

For example