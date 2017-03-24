# Promise

A Promise is basically a future that can be retried and cancelled.  Like a future, it will only return a single value.  However, unlike a future, a promise can be retried in the case that an error has occurred.  It can also be manually cancelled.  This gives the client much more control over how the promise delivers its value.  By simply returning a Promise, an interface is essentially saying that the task to retrieve the data can be retried on the client’s terms.  

## Retry
A good example of using retry is networking:  

	func network(request: NetworkRequest) -> Promise<String>
	 
	 client.network(request: request)
	   .retry(3, delay: 2.0) // retry 3 times, delayed by 2.0 seconds each time
	   .map{ $0.jsonValue }
	   .dispatch(.async(on: .background)).map{ 
	      // convert json to an object in background
		   }
	   .dispatch(.async(on: .main)).on{ 
	      // Update self with new object on main
	   }


If you want more control, you can control how and when the request is retried:

	func network(request: NetworkRequest) -> Promise<String>
	 
	 client.network(request: request)
	   .retry{ attempt, error, retry in
	     guard attempt < 4, let networkError = error as? NetworkError else { return retry(false) }
	     if networkError.statusCode == 504 {
	       Dispatch.delay(after: 5.0, on: .main).execute {
	         retry(true)
	       }
	     } else {
	       retry(false)
	     }
	   }
	   .map{ $0.jsonValue }
	   .dispatch(.async(on: .background)).map{ 
	      // convert json to an object in background
		   }
	   .dispatch(.async(on: .main)).on{ 
	      // Update self with new object on main
	   }

So in the above case, the processing chain checks if we’ve made less than 4 attempts, the network is returning a `NetworkError`, and if so, retry after 5.0 seconds if the status code is `504`.  

Normally, this kind of retry logic would either need to be baked into the network function itself or the client would have to manually keep track of and re-make a new network request.  Having the logic in the actual processing chain not only make it much clearer, but gives the client much more control over what’s happening.

Retries can cascade and Promises can _reuse_ a valid value.  So, for example, let’s say you have a network request that returns a Promise.  

	func network(request: NetworkRequest) -> Promise<String> {
	  return Promise<String> { _ response in
	    self.apiClient.get(request) { completion in
	      response(completion)
	    }
	  }
	  .retry(3, delay: 2.0)
	  .reuse(true)
	}

So here the network is _already_ making 3 attempts to retry the network request.  Because of this, it may make sense to protect itself against further retry attempts if it’s already retrieved a successful value, and so avoid saturating the network with unnecessary requests.  By calling `reuse(true)`, any attempt to retry from a down stream operation will be filled by the existing retry value, if one exists.

However, note that the retry still does cascade.  If a client does this:

	 client.network(request: request)
	   .retry(3, delay: 2.0)

Then the network request will be attempted _6 times_ at 2 second intervals.  If this is undesirable, it may make sense for the function to use a `Promise` internally, but return a `Future`.  Luckily, this is easy to do:

	func network(request: NetworkRequest) -> Future<String> {
	  return Promise<String> { _ response in
	    self.apiClient.get(request) { completion in
	      response(completion)
	    }
	  }
	  .retry(3, delay: 2.0)
	  .future()
	}

Since a `Future` is being returned, it cannot be retried.  But internally the `Promise` will retry 3 times before fulfilling the `Future`.

I should mention that a `Future` guarantees that all processing chains will only ever receive 1 value or error.  Because of the retry mechanism, a `Promise` can only guarantee that processing chains _after_ the last retry will receive only 1 value or error.  It’s important to realize that if you ever pass a `Promise` to someone else, you can never assume that your observers or operations will only be used once.  If you need that assurance, pass a `Future` instead of a `Promise`.

## Cancelling

A promise can also be cancelled, which will terminate the entire promise with a cancellation event:

	func network(request: NetworkRequest) -> Promise<String>
	 
	 self.currentRequest = client.network(request: request)
	   .retry(3, delay: 2.0) // retry 3 times, delayed by 2.0 seconds each time
	   .map{ $0.jsonValue }
	   .dispatch(.async(on: .background)).map{ 
	      // convert json to an object in background
		   }
	   .dispatch(.async(on: .main)).on{ 
	      // Update self with new object on main
	   }
	   
	  // later:
	  self.currentRequest?.cancel()

It’s pretty simple, really.  The cancellation will be sent up stream until it reaches the task.  The task will have access to this information as an `Observable<StreamState>` object it can observe and react to.  The entire Promise will be cancelled and no further data will be sent.

## Completion

I should note a peculiar behavior of Promise.  Because a Promise can’t be certain it’s finished until the last operation has been performed, it actually terminates itself from the bottom up.  It’s done this way in order to prevent the Promise from prematurely terminating when it’s possible for some chain to attempt a retry.  There’s a few corollaries to this:

1. A `Promise` can have branching processing chains just like any other stream. This means that one branch my terminate successfully, while another might end up retrying because of a processing error.  In normal use, this is probably not a problem, but it’s something you should be aware of.
2. If you were to create a series of `onTerminate` observers, the observers would be executed in the reverse order they were added.  Again, this is because a Promise terminates from the bottom up.  Again, it’s unlikely this will ever present itself as a problem, but it’s something I should note.

