//
//  Thread.swift
//  RxStream
//
//  Created by Aaron Hayman on 7/11/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

public typealias VoidBlock = () -> Void

import Foundation

extension NSCondition {

  /**
    This is a convenience method that will perform some task withing a lock.
    It's mostly here to cut down on the redundant code necessary to lock the resource,
    perform the task, signal the resource and then unlock it.
  */
  func perform(_ block: VoidBlock) {
    self.lock()
    block()
    self.signal()
    self.unlock()
  }

  func get<T>(_ block: () -> T) -> T {
    self.lock()
    let value = block()
    self.signal()
    self.unlock()
    return value
  }

}

/**
  DispatchThread is a single Thread that processes a queue of work in FIFO order.
  The thread will be kept alive until it's cancelled or the thread is removed from memory.

  In most cases, it would be better to use GCD, Operation Queues or some other abstraction
  instead of creating a DispatchThread.  However, some resources _require_ that all access
  occur through a single thread, and none of the standard concurrency APIs like GCD, NSOperation,
  etc do that (they maintain a flexible pool of threads instead). So DispatchThread is a great
  way to maintain this single-thread access requirement.

  Threads are expensive to create and maintain, which is a large reason why GCD and NSOperation
  are recommended concurrency abstractions.  So it's recommended that you create one and keep it
  around instead of creating and destroying a thread frequently.
*/
final public class DispatchThread: Thread {

  /**
    Used to maintain safe access to the queue and paused states.
    -warning: All access to any state within this thread should always use the lock.
  */
  private let lock = NSCondition()

  /**
    Maintains the work that needs to be done on the thread. Note that work is performed in batches.
    So this queue may not represent all the work currently being done on the thread.  Once work begins,
    the queue is retrieved in it's entirety and replaced with an empty queue.  The retrieved work is
    then performed in a single batch while new work is added to the instance queue for the next batch.
  */
  private var queue = [VoidBlock]()

  // Runloop associated with the Thread.  We're only keeping a reference to detach the loop port when we're done.
  private var runLoop: RunLoop? = nil

  // When paused, the thread may be active but no work will be done from the queue.
  private(set) public var paused: Bool = false

  /**
    Used to keep track of when the thread is started.
    We're using a separate variable because the `isExecuting` variable
    is only keeps track of when the thread is actually executing.  There
    is a delay between when you start a thread and when it actually executes.
  */
  private(set) public var isStarted: Bool = false

  /**
    A run loop requires at least one source, or it will immediately terminate.
    So we will add this port to the run loop as it's source.
    The port is also used to "wake" up the run loop when we're ready to actually
    perform some work.
  */
  private let loopPort = NSMachPort()

  /**
    Override for the standard init in order to start the thread by default.
    Doing this to prevent confusion between the "normal" initializer, which can
    be invoked without any parameters, and whose default behavior is to start the thread.
    Since I'm not sure what the Swift compiler will do in that case, this just ensures
    the expected behavior will occur.
  */
  public override init() {
    super.init()
    self.start()
  }

  /**
   Designated initializer.
   - parameters:
      - start: Whether thread should start immediately. Default: `true`
      - queue: Initial array of blocks to add to enqueue. Executed in order of objects in array.
      - name: The name of the thread.  Useful for debugging and stack traces.
  */
  public init(start: Bool = true, queue: [VoidBlock]? = nil, name: String? = nil) {
    super.init()
    self.name = name

    if let work = queue, work.count > 0 {
      self.queue = work
    }

    if start {
      self.start()
    }
  }

  /**
    Main override for running the work. Intended to be overridden by Thread.
    This should not be called directly.  Instead, use `start` to run the thread.
    This keep alive a the thread's runloop in order to process queued blocks.
   */
  final public override func main() {
    let runLoop = RunLoop.current
    runLoop.add(self.loopPort, forMode: .commonModes)
    self.runLoop = runLoop

    /**
     The run loop to process data. By using a RunLoop as part of our while loop, we allow the system
     to put the thread to sleep when it's not being used.  This is a much better system than using
     an "naive" while loop to keep the thread alive, which would use extraneous CPU cycles for the duration
     of it's life.

     A run loop is only "activated" when one of it's "sources" receives an event.  Our run loop has only one such
     source: `loopPort`.  This is an unattached NSMachPort that we use to manually send an event to to wake up the run loop.
     The RunLoop will wake up to process the event (which involves exactly nothing), unblock our loop so that we can process our queue,
     and then our `while` loop will re-schedule the runloop to to check for the next "event" it receives.
    */
    while !isCancelled && (lock.get{ queue.count } > 0 || runLoop.run(mode: .defaultRunLoopMode, before: Date.distantFuture)) {
      lock.lock()
      guard queue.count > 0 && !paused else {
        lock.signal()
        lock.unlock()
        continue
      }

      var blocks = queue
      queue = []
      lock.signal()
      lock.unlock()

      autoreleasepool {
        while blocks.count > 0 {
          guard !paused else { return lock.perform { queue = blocks + queue } }
          guard !isCancelled else { return }
          blocks.removeFirst()()
        }
      }
    }
  }

  /**
    This will wakeup the RunLoop, causing any and all blocks to be processed so long as the
    thread is not paused or cancelled.
    The loopPort is attached to the runloop specifically to wake it up and keep the RunLoop alive.
    We use that port to wake the run loop by sending it a message... any message, doesn't matter.
    The message will wake the run loop, which will cause our code to run and process the queued blocks.
  */
  private func wakeLoop() {
    guard isStarted else { return }
    loopPort.send(before: Date.distantFuture, components: nil, from: nil, reserved: 0)
  }

  /**
   Queue up a work to be run on the thread. Work is queued up in a Fifo queue and processed
    serially in order.
   - parameter work: The code to be run on the thread.
   */
  final public func enqueue(_ work: @escaping VoidBlock) {
    lock.perform {
      guard !isCancelled else { return }
      queue.append(work)
      if !paused {
        wakeLoop()
      }
    }
  }

  /**
    Start the thread. Won't do anything if the thread has already been started.
   */
  final public override func start() {
    guard !self.isStarted else { return }
    self.isStarted = true
    super.start()
  }

  /**
    Cancels the thread.  This is the standard way to "end" a thread.
   */
  final public override func cancel() {
    lock.perform {
      guard !self.isCancelled else { return }
      super.cancel()
      //Removing the loop port should cause the run loop to terminate since it's the only source
      runLoop?.remove(self.loopPort, forMode: .defaultRunLoopMode)
      // The run loop is set to nil as a signal that we're done with it.
      runLoop = nil
    }
  }

  /**
    Pause the thread. The RunLoop will continue, but no blocks will be processed.
   */
  final public func pause() {
    lock.perform{
      paused = true
    }
  }

  /**
    Resume the execution of blocks from the queue on the thread is paused.
    - Warning: Can't resume if thread was cancelled/stopped.
   */
  final public func resume() {
    lock.perform{
      paused = false
      wakeLoop()
    }
  }

  /**
    Empty the queue for any blocks that hasn't been run yet.
    - warning: A queue is run in its entirety on each run loop.  Emptying
     a queue won't prevent a queue that's currently processing from running.
   */
  final public func emptyQueue() {
    lock.perform {
      queue.removeAll()
    }
  }

  /**
    We want to ensure the run loop exits by removing the loop port if it's still attached to the
    the run loop.
    - note: This code assumes that the runloop will be nil after the thread is cancelled.
      Thus, we expect the runloop to be nil if there is no loop port attached.  That's the only reason
      we're keeping a reference to it anyway.
  */
  deinit {
    runLoop?.remove(self.loopPort, forMode: .defaultRunLoopMode)
  }

}
