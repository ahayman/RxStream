<img src="/Docs/badges/observable.jpg" height=100 alt="Observable Stream">

An `Observable` can be though of as a kind of Hot Stream who’s value is guaranteed and can be directly observed and accessed outside of the stream.  The difference between an `Observable` and a `Hot` stream basically comes down to state.  A `Hot` stream is normally dealing with _transient_ data, whereas an `Observable` is used when you’re tracking persistent state.  It’s frequently used to store variables in a class or struct, and access them as you normally would otherwise, but with the added benefit of being able to _observe_ changes in that variable (thus the name).  Using an `Observable` in Swift is just about the closest thing you can get KVO without using KVO.

_ - note: Be careful to note that my use of the word “Observable” is not the same as ReactiveX.  In their parlance, an Observable is essentially what we are calling a Stream.  While we specifically use the word Observable to denote a stateful value that can be observed.  If you’re coming from the RxSwift or ReactiveX world, this might be a little confusing._

Observables are initiated with an initial value (thus guaranteeing the value) using `ObservableInput`, which is a mutable subclass of `Observable`.  An `Observable` itself cannot be altered directly (ensuring immutability):

	let count = ObservableInput(0)

Whenever you need to access the value, you simply call:

	let myCount = self.count.value

Updating the value is as simple as calling:

	count.set(10) // count.value is now 10

Whenever a new value is set on the `ObservableInput` it will trigger that value to be sent down whatever processing chains are attached to it.

	self.count
	  .map{ "New Count: \($0)" }
	  .on{ print($0) }
	 
	self.count.set(10) // prints "New Count: 10"


## Hot Stream Operations

While an Observable can be thought of as a type of Hot stream, it does _not descend directly_ from `Hot`.  The main reason for this is just due to a limitation in Swift’s type system.  Once they fix it, I intend on making `Observable` a subclass of `Hot`.  For now, if you need to provide an `Observable` for a `Hot` stream, you can convert it by using the `Observable.hot()` function.

It should also be noted that because of the need to always have a valid value, many operations on `Observable` will return an `Hot` stream.  Basically, any operation that cannot guarantee an initial value (like using async version of `map`) will return a `Hot` stream.  In practice, this should cause too many problems but it’s something you should be aware of.
