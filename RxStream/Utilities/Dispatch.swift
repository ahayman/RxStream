//
//  Dispatch.swift
//  RxStream
//
//  Created by Aaron Hayman on 2/23/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
 The following Types represent a kind of wrapper around Grand Central Dispatch to make it easier to handle interaction with GCD. It allows for expressive execution of GCD code, storage of that expression as a variable, and finally execution chains to help prevent nesting dispatches.
 
 This paradigm doesn't attempt to capture everything GCD can do, but instead the most common items.
 
  This combination of enum help to be expressive in exactly how operations are executed. For instance, to dispatch on the main queue:
 
 ```
   Dispatch.async(on: .main).execute {
     // Do work asynchronously on main
   }
 ```
 
 You can also set Dispatch as a parameter:
 
 ```
 class CustomCache {
   public var dispatch: Dispatch = .async(on: .background)
 }
 ```
 
 It's immediately obvious that this class dispatches operations by default asynchronously on the background.  But this may be at odds with how the client wants to use the cache (for instance, if it's a small cache and operations won't be expensive).  In that case, the client can _change_ how operations are dispatched:
 
 ```
    var cache = CustomCache()
    cache.dispatch = .sync(on: .background)
 ```
 
 Whenever the cache needs to dispatch operations, it does so by calling: `dispatch.execute { ... }`. This allows the client to define how the operations will be handled.  It could even create a queue shared between itself and the cache so the cache is always in sync.  Consider:
 
 ```
    self.disatch = Dispatch.Async(on: .Custom(DispatchQueue(.Serial, "My Custom Queue")))
    var cache = CustomCache()
    cache.dispatch = self.dispatch
 ```
 
 We can now be certain the cache will remain in sync with it's client because it's operations will be performed asynchronously on it's client's serial queue.
 
 Execution chains can be created that allow you to perform actions sequentially.  For example:
 
 ```
   Dispatch
     .after(delay: 1.0, on: .main).execute {
       // Do Something after a delay
     }.then(.async(on: .background)) {
       // Do something else on the background
     }.then(.async(on: .main)) {
       // Finally return the results on main
     }
 ```
 
 - note: that context will need to be defined outside the execution context since the dispatches are no longer nested.  It cascading context capturing is necessary, you may need to create a context or else simply nest the dispatches.
 - warning: Dispatch will attempt to detect re-entry on synchronous queues. It does so by using `setSpecific` and `getSpecific` on the serial queues created with this system.  However, it's always recommended to use good design when using serial queues to minimize the risk of reentry locks.  Reentry lock can still occur if you nest sync operations across threads.
*/
public enum Dispatch {
  
  /// Dispatches asynchronously on the Queue provided
  case async(on: Queue)
  
  /** 
   Dispatches synchronously on the Queue provided.  
   
   Note: This will attempt to detect reentry and dispatch safely if you're dispatching onto a serial queue. Reentry detection can only work if if you're using labelled queues. Reentry detection on .Main always works (because we check `NSThread.isMainThead`).  Otherwise, it will attempt to retrieve the label of the current queue and compare it against the label of the requested queue.  If they're the same, it will execute the block in-line.  In all other cases, the block will execute using `dispatch_sync`.
  */
  case sync(on: Queue)
  
  /// This will dispatch on the queue provided after the specified delay (in seconds)
  case after(delay: TimeInterval, on: Queue)

  /**
    This will dispatch on a specific DispatchThread.

    In most cases, it will make more sense to use a normal async Queue instead (GCD).  Creating separate threads is expensive,
      and in most case you'll want to use another abstraction.  However, there are cases where it makes sense or it's necessary
      to restrict access of a resource to a single thread.  In those cases, using DispatchThread can be very useful.
    
    - warning: An execution chain is separate from the thread's queue. While executions are queued into the DispatchThread,
      they are only done so after the prior execution has occurred in the execution chain.  Be aware that creating an execution
      chain will always be processed serially, but it's possible (likely?) other work will be interpolated between the items in
      the chain if the thread is shared.
  */
  case on(thread: DispatchThread)
  
  /// This executes inline.  Mostly, it's a convenience to use this as simply executing a closure is the same as using this dispatch action.  However, it can reduce code complexity and simplify syntax to use `.inline` instead of optionally handling a dispatch.
  case inline
  
  /// Returns the queue the work will be run on.  Only returns `nil` if `.inline` is specified
  public var queue: Queue? {
    switch self {
    case let .sync(queue): return queue
    case let .async(queue): return queue
    case let .after(_, queue): return queue
    case .on, .inline: return nil
    }
  }
  
  /// This will execute work using the dispatch action provided.  It returns an ExecutionChain, that can be used to further dispatch more work after this work has finished.
  @discardableResult public func execute(_ work: @escaping () -> Void) -> ExecutionChain {
    let chain = ExecutionChain(action: self, work: work, parent: nil)
    chain.execute()
    return chain
  }
  
  /// This will execute statements on the given queue and callback the `onReturn` when the work has completed.
  fileprivate func execute(_ work: @escaping () -> Void, onReturn: @escaping () -> Void) {
    
    // A wrapper closure that executes the block, and then calls the `onReturn` closure, with the intent to notify the ExecutionChain that it can execute the next chain item.
    let doWorkAndReturn = {
      work()
      onReturn()
    }
    switch self {
      
    case let .sync(queue):
      // If the queue isn't serial, re-entry isn't a concern
      guard queue.isSerial else {
        queue.queueT.sync(execute: doWorkAndReturn)
        return
      }
      
      // The queue is serial, and reentry is detected, perform the work inline.  Otherwise, perform normally.
      if case .main = queue, Thread.isMainThread {
        // We're on the main thread, so we execute inline
        doWorkAndReturn()
      } else if
        case .custom(let customQueue) = queue,
        let key = customQueue.queueT.getSpecific(key: customQueue.dispatchKey),
        key == customQueue.key
      {
        // We've detected re-entry, so we perform the work inline
        doWorkAndReturn()
      } else {
        // No reentry detected, so we dispatch_sync
        queue.queueT.sync(execute: doWorkAndReturn)
      }
      
    case let .async(queue):
      queue.queueT.async(execute: doWorkAndReturn)
      
    case let .after(delay, queue):
      queue.queueT.asyncAfter(deadline: DispatchTime.now() + Double(Int64(delay * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC), execute: doWorkAndReturn)

    case let .on(thread):
      thread.enqueue(doWorkAndReturn)
      
    case .inline:
      doWorkAndReturn()
    }
  }
  
}

/**
 The execution chain allows you to chain together pieces of work that should execute sequentially, but not necessarily on the same queues or dispatches.  It cannot be instantiated directly.  Instead, `Dispatch` will emit an `ExecutionChain` on the `exec` function to allow chaining.  Use the `then` function to chain more work. Any chained work will not begin until the prior work has completed.  Use this to flatten out nested dispatches.
 */
public class ExecutionChain {
  /// The dispatch action the work will be executed on
  private let action: Dispatch
  
  /// The work to execute.  It is released once the work is done.
  private var work: (() -> Void)?
  
  /**
   The chain maintains a strong reference to it's parent and it's child (if any).  This creates a cyclical reference intended to keep the chain in memory until it has completed.  
   - note:  Because parents are released immediately after the work is done, the chain is dissassembled as the work is completed.
  */
  private var parent: ExecutionChain? = nil
  
  /// The next work in the chain.  If it exists, it will be executed after the work for this chain has finished.
  private var next: ExecutionChain? = nil
  
  /// Once the work has been completed, this is marked true.  If a chain is attached after work is complete, that chain will execute immediately.
  private var complete = false
  
  /// private initializer intended for chaining work together.
  fileprivate init(action: Dispatch, work: @escaping () -> Void, parent: ExecutionChain?) {
    self.action = action
    self.work = work
    self.parent = parent
  }
  
  /** 
   This will attach work to the chain and provide a new chain item to attach additional work.
   - warning: This function is not inteded to be called multiple times. Execution chains run deep, not wide. Attempting to call this function multiple times will fail to add the work requested.
  */
  @discardableResult public func then(_ action: Dispatch, next: @escaping () -> Void) -> ExecutionChain {
    guard self.next == nil else { return self }
    let chain = ExecutionChain(action: action, work: next, parent: self)
    self.next = chain
    if complete { chain.execute() }
    return chain
  }
  
  /// This executes the work.  Note that the chain essentially locks itself until the execution is complete, then calls
  fileprivate func execute() {
    guard let work = work else { return }
    self.work = nil
    action.execute(work) {
      self.complete = true
      self.parent = nil
      self.next?.execute()
    }
  }
}


/// This defines a custom queue type, currently either serial or concurrent.
public enum QueueType {
  case serial
  case concurrent
}

/// This represents a custom DispatchQueue.  Privately it wraps and is functionally equivelent to a dispatch_queue_t type in GCD. It's used as a parameter for Queue.Custom(_) to wrap a custom queue
open class CustomQueue {
  fileprivate let queueT: DispatchQueue
  fileprivate let type: QueueType
  fileprivate let key: String = String.newUUID()
  fileprivate let dispatchKey = DispatchSpecificKey<String>()
  
  /// Mus be initialized with a name and a QueueType
  public init(type: QueueType, name: String) {
    self.type = type
    if case .serial = type {
      queueT = DispatchQueue(label: name, attributes: [])
    } else {
      queueT = DispatchQueue(label: name, attributes: DispatchQueue.Attributes.concurrent)
    }
    queueT.setSpecific(key: dispatchKey, value: key)
  }
}

/// Represents the Priority for a background queue. Note: Default is not represented here.  Use the Queue enum case .Background for a .Default priority background queue.
public enum Priority : Equatable {
  /// Same as: DispatchQoS.bakground
  case background
  /// Same as: DispatchQoS.utility
  case low
  /// Same as: DispatchQoS.userInitiated
  case high
  
  var qos: DispatchQoS {
    switch self {
    case .background: return DispatchQoS.background
    case .low: return DispatchQoS.utility
    case .high: return DispatchQoS.userInitiated
    }
  }
}
public func == (lhs: Priority, rhs: Priority) -> Bool {
  switch (lhs, rhs) {
  case (.background, .background), (.low, .low), (.high, .high): return true
  default: return false
  }
}

/** This represents a Queue that can be dispatched onto.
*/
public enum Queue : Equatable {
  /// The main queue
  case main
  /// The background, global queue at default priority. Saves us from always specifying a priority when dispatching in the background.
  case background
  /// The background, global queue at the specified priority.
  case priorityBackground(Priority)
  /// A custom dispatch to to execute on
  case custom(CustomQueue)
  
  /// Returns the GCD dispatch queue to execute on
  fileprivate var queueT: DispatchQueue {
    switch self {
    case .main: return DispatchQueue.main
    case .background: return DispatchQueue.global(qos: .background)
    case let .priorityBackground(priority): return DispatchQueue.global(qos: priority.qos.qosClass)
    case let .custom(queue): return queue.queueT
    }
  }
  
  /// Returns whether this queue is a serial queue or not.
  fileprivate var isSerial: Bool {
    switch self {
    case .main: return true
    case .background: return false
    case .priorityBackground(_): return false
    case let .custom(queue):
      if case .serial = queue.type {
        return true
      } else {
        return false
      }
    }
  }
}
public func ==(lhs: Queue, rhs: Queue) -> Bool {
  switch (lhs, rhs) {
  case (.main, .main): return true
  case (.background, .background): return true
  case let (.priorityBackground(lPriority), .priorityBackground(rPriority)): return lPriority == rPriority
  case let (.custom(lCustom), .custom(rCustom)): return lCustom.key == rCustom.key
  default: return false
  }
}
