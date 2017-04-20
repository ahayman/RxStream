//
//  WeakTimer.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/28/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

typealias TimerHandler = () -> Bool

/**
 The handler should take an interval, selector and repeats parameter and return a new Foundation.Timer that reflects those parameters.
 - warning: Ignroing _any_ of the parameters will result in Undefined behavior with the Timer and may break the implementation.
 */
public typealias NewTimerHandler = (_ interval: TimeInterval, _ selector: Selector, _ repeats: Bool) -> Foundation.Timer

/**
 This Wraps around `Foundation.Timer` in order to contain the retain cycle inherent in `Foundation.Timer`.  
 It requires an interval and a Handler.  The handler is called whenever the Timer fires and should return whether the timer should continue.
 
 Traditional usage is for the owner to weakly capture `self` and use that as a determinate:
 
 ```
 self.timer = ConditionalTimer(5.0) { [weak self] in
   guard let me = self else { return false }
   // handle the timer fire
   return true
 }
 ```
 
 This makes the lifetime of the ConditionalTimer dependent on it's owner...something that cannot happen with `Foundation.Timer`.
 */
class ConditionalTimer {
  
  /// While a timer is active, we need to hold on to it so we can invalidate it when we're done with it.
  private var timer: Foundation.Timer?
  
  /// The interval the timer should fire on
  public var interval: TimeInterval
  
  /// Handler will fire when the timer does, and should return whether or not the timer should continue.
  public var handler: TimerHandler
  
  /**
   Replace this to produce a custom Foundation.Timer instead of the default.  It
   - warning: The returned Foundation.Timer should use the interval, selector, and repeats parameters provided or else the behavior will be undefined.
   */
  lazy public var newTimer: NewTimerHandler = { interval, selector, repeats in
    return Foundation.Timer.scheduledTimer(
      timeInterval: interval,
      target: self,
      selector: selector,
      userInfo: nil,
      repeats: repeats)
  }
  
  /// Returns `true` if the timer is actively firing
  public var isActive: Bool { return timer != nil }
  
  /**
   Initialization must include the timer interval and the Handler that should handle the firing of the timer.
   
   - parameter interval: The interval the timer firings
   - parameter handler: The handler will be called whenever the timer fires.  It should return `true` if the timer is to continue firing, and `false` to stop the timer.
   */
  public init(interval: TimeInterval, handler: @escaping TimerHandler) {
    self.interval = interval
    self.handler = handler
  }
  
  /// The handler that's called when Foundation.Timer fires
  dynamic func fire() {
    guard isActive else { return }
    if !handler() {
      stop()
    }
  }
  
  /// If the timer hasn't already started, this will start it.  Otherwise, it does nothing. returns `self` for chaining.
  @discardableResult public func start() -> Self {
    guard !isActive else { return self }
    timer = newTimer(interval, #selector(ConditionalTimer.fire), true)
    return self
  }
  
  /// Stops the timer from firing. Returns `self` for chaining.
  @discardableResult public func stop() -> Self {
    timer?.invalidate()
    timer = nil
    return self
  }
  
  /**
   If the timer has been stopped, this will start it with the new interval, if any.  If it's already active, it will stop the current timer, and restart it with the new interval if one is provided.
  */
  @discardableResult public func restart(withInterval interval: TimeInterval? = nil) -> Self {
    stop()
    if let timeInterval = interval {
      self.interval = timeInterval
    }
    start()
    return self
  }
  
}
