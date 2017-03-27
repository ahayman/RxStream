# Throttle

All Streams support setting a throttle on their operations.  This allows you to control when and how work is processed, and what to do with incoming values while the work is being processed.  There are two basic way to apply a throttle to a stream:

 - `func throttle(_: Throttle) -> Self` - This will apply a throttle to the next stream or operation added.  The returned `self` is not discardable, because you need to add an operation to apply the throttle to.
 - `func throttled(_: Throttle) -> Self` - This will apply a throttle to the _current_ stream.  You can optionally chain off of `self` with more operations or not.

Using either one is a matter of preference in your syntax.  Basically, it comes down to where you with the throttle to appear in your processing chain. 

The actual definition of what constitutes a throttle is actually a very simple protocol.  A Throttle takes a piece of `ThrottledWork` which is basically a closure that passed in a completion handler.  Work is passed into the throttle and when the throttle's logic allows the work to execute, it will call the Work by passing in a completion handler.  The completion handler should be called when the work has completed.  While the completion handler should always be called, not all Throttles will care about the completion handler.  For example, a `TimedThrottle` will only execute work every `X` seconds, but doesn't concern itself with when that work completes.  A `PressureThrottle` however, cares very much about when work completes.

There are currently two concrete throttles:

 - `PressureThrottle`: Takes a `buffer` and a `limit`.  It will concurrently process the amount of work specified by the `limit`.  Any _additional_ work that comes in will be placed in the buffer (if one is specified).  If the buffer is full, that work is dropped.  As work is completed, any pending work is retrieved from the buffer up to the limit specified until the buffer is empty.
 - `TimedThrottle`: Simply allows work to be executed every `X` seconds (whatever is specified).  If additional work comes in before the next allowable execution, the last work is bufferred until it can be executed.  If multiple work comes in before the next interval, only the _last work received_ will execute when the next interval comes.  All the other work will be dropped.

It should be noted that since `Throttle` is a protocol, you can create your own throttles to fit your specific needs.