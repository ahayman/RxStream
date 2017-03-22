//
//  Throttle.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/7/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/// Handler that should be called when a piece of throttled work is complete
public typealias WorkCompletion = () -> Void

/// Throttled work is a simple closure that passes in a completion handler that should be called when the work is complete.  Failing to call the completion handler may result in a Throttle becoming locked up.
public typealias ThrottledWork = (@escaping WorkCompletion) -> Void

/**
  A throttle is a simple protocol that defines a function to take a piece of work and process it according the specific throttle's internal rules.
 
  - note: Depending on the throttle, not all work may end up being processed.
  - warning: Many throttles will retain the work for processing later.  Be careful about creating retain cycles.
  - warning: All work should call the WorkCompletion handler when finished or else risk locking up the throttle. Some throttles will retain themself (create a lock) while work is being processed, which may cause leaks if the WorkCompletion handler isn't called.
 */
public protocol Throttle {
  /// A throttle should take the work provided and process it according to it's internal rules.  The work closure should call the completion handler when it's finished.
  func process(work: @escaping ThrottledWork)
}

/**
 A timed throttle will only process work on a specific interval.
 Any additional work that is added will replace whatever work is in the current queue and that work will be dropped.
 Once the interval has passed, whatever work is currently in the queue will be processed and discarded.
 */
public final class TimedThrottle : Throttle {
  /// The last time work was processed.  Used to calculate the next time work can be processed.
  private var last: Double?
  /// The interval between the last time a work was processed and the next time new work can be processed.
  private let interval: Double
  /// Current work waiting for processing.
  private var work: ThrottledWork?
  /// Used to keep track of when a dispatch was sent to process the next work so we don't send a new dispatch.
  private var dispatched = false
  /// If `true`, the first work presented will be delayed by the interval.  Otherwise, the first work will be processed immeditialy and all subsequent work will be timed.
  private let delayFirst: Bool
  
  /**
   Initializes a new TimedThrottle with an interval and optionally whether the first work should be delayed.
   
   - note: all work is dispatched on the main thread.
   
   - parameter interval: The allowable interval between which work can be processed.
   - parameter delayFirst: Whether the first work should be processed immediately or delayed by the interval
   
   - returns: TimedThrottle
   */
  public init(interval: Double, delayFirst: Bool = false) {
    self.delayFirst = delayFirst
    self.interval = interval
  }
  
  /// Calculates the remaining interval left before new work can be processed.  If negative or 0, work can be processed immediately.
  private var remainingInterval: Double {
    guard let last = self.last else {
      return delayFirst ? interval : 0.0
    }
    let next = last + interval
    return next - Date.timeIntervalSinceReferenceDate
  }
  
  public func process(work: @escaping ThrottledWork) {
    let remaining = remainingInterval
    guard remaining > 0.0 else {
      last = Date.timeIntervalSinceReferenceDate
      Dispatch.sync(on: .main).execute{
        work {}
      }
      return
    }
    
    self.work = work
    
    guard !dispatched else { return }
    dispatched = true
    Dispatch.after(delay: remaining, on: .main).execute {
      self.last = Date.timeIntervalSinceReferenceDate
      self.work?{ }
      self.work = nil
      self.dispatched = false
    }
  }
  
}

public final class StrideThrottle : Throttle {
  private let stride: UInt
  private var index: UInt = 1
  
  public init(stride: UInt) {
    self.stride = stride
  }
  
  public func process(work: @escaping ThrottledWork) {
    guard stride > 1 else { return work{ } }
    if index >= stride {
      work{ }
      index = 1
    } else {
      index += 1
    }
  }
}

/**
 A Pressure Throttle limits the amount of work that can be processed by defining a limit of current work that can be run and using a buffer to store extra work. As work is finished, new work is pulled from the buffer. All incoming work will be dropped if both the buffer and working queue limits are reached.
 
 - Note: The `pressureLimit` essentially defines the maximum number of concurrent tasks/work that can be performed.
 - Warning: You cannot set a `pressureLimit` below 1.
 - Warning: Setting the `buffer` to `0` means all work will be dropped if the pressure limit is reached.
 */
public final class PressureThrottle : Throttle {
  private let bufferSize: Int
  private let limit: Int
  private var working = [String: ThrottledWork]()
  private var buffer = [ThrottledWork]()
  private let lockQueue = Dispatch.sync(on: .custom(CustomQueue(type: .serial, name: "PressureThrottleLockQueue")))
  
  /**
   Initialize a PressureThrottle with a buffer and a limit.
   
   - parameter buffer: The size of the buffer to hold work when the pressure limit is reached.  If a buffer is full, then work will be dropped until there is room.
   - parameter limit:  Basically represents the number of concurrent work that can be processed.  Default: 1
   
   - returns: PressureThrottle
   */
  public init(buffer: Int, limit: Int = 1) {
    self.bufferSize = max(0, buffer)
    self.limit = max(1, limit)
  }
  
  /// This will queue work into the working buffer.  Once work is finished, it's removed from working and work is pulled from the buffer until the pressure limit is filled or the buffer is empty.
  private func queue(work: @escaping ThrottledWork) {
    let key = String.newUUID()
    self.working[key] = work
    Dispatch.async(on: .main).execute {
      work{
        self.lockQueue.execute {
          self.working[key] = nil
          while self.buffer.count > 0 && self.working.count < self.limit {
            self.queue(work: self.buffer.removeFirst())
          }
        }
      }
    }
  }
  
  /// Work is either queued up for processing if the pressure is less than the limit, appended to the buffer if it has room, or else dropped.
  public func process(work: @escaping ThrottledWork) {
    lockQueue.execute {
      guard self.working.count >= self.limit else {
        return self.queue(work: work)
      }
      if self.buffer.count < self.bufferSize {
        self.buffer.append(work)
      }
    }
  }
}

