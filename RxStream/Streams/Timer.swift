//
//  Timer.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/28/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

private class WeakTimer {
  var timer: Foundation.Timer?
  var handler: (Foundation.Timer) -> Void
  
  init(handler: @escaping (Foundation.Timer) -> Void){
    self.handler = handler
  }
  
  dynamic func fire() {
    guard let timer = timer else { return }
    self.handler(timer)
  }
}

/**
 A Simple Stream that will emit events every `X` seconds according to the specified interval.
 A Timer stream may either be active or not, without affecting the stream state.
 However, once the stream state is no longer active, the timer will also be terminated.
 
 - note: This uses the default `Foundation.Timer.scheduledTimer`.  
 However, if you need a different kind of Timer (for example, on a different run loop) you can replace the `newTimer` closure to provide the appropriate timer.
 
 - warning: It's important that you provide a proper termination for the stream.  
 Because Foundation.Timer retains it's target, the Timer Stream will remain in memory until the Stream is terminated.
 */
public class Timer : Hot<Void> {
  
  /// The timer to handle firing at the correct time.
  lazy private var timer: ConditionalTimer = ConditionalTimer(interval: self.interval) { [weak self] () -> Bool in
    guard let me = self else { return false }
    me.fire()
    return true
  }
  
  /// The interval the timer should fire on
  public var interval: TimeInterval {
    didSet { timer.interval = interval }
  }
  
  /**
   Replace this to produce a custom Foundation.Timer instead of the default.  It
   - warning: The returned Foundation.Timer should use the interval, selector, and repeats parameters provided or else the behavior will be undefined.
   */
  public var newTimer: NewTimerHandler {
    get { return timer.newTimer }
    set { timer.newTimer = newValue }
  }
  
  /// Returns `true` if the timer is still active and firing, `false` if it's not firing.
  public var isTimerActive: Bool { return timer.isActive }
  
  /**
   A Timer must be initialized with an interval.
   However, the Timer will not begin firing until `start()` is called.
   
   - parameter interval: The interval between which the timer will begin firing
   */
  public init(interval: TimeInterval) {
    self.interval = interval
  }
  
  /// Called when the timer fires. Push the fire into the stream so long as the stream is active.
  private func fire() {
    guard isActive else {
      stop()
      return
    }
    self.process(event: .next())
  }
  
  /**
   Start the Timer, which will fire at the specified interval
   
   - parameter delayFirst: _default: true_, If `false`, then fire immediately, otherwise, wait for the next timer to fire.
   
   - returns: Self, for chaining
   */
  @discardableResult public func start(delayFirst: Bool = true) -> Self {
    guard isActive else { return self }
    timer.start()
    if !delayFirst { fire() }
    return self
  }
  
  /**
   Stop the timer, if it's currently running.
   - note: Does _not_ terminate the stream.  It only stop the timer from firing and pushing events into the stream.
   */
  @discardableResult public func stop() -> Self {
    timer.stop()
    return self
  }
  
  /**
   This will restart the timer.  If it's currently running, it will be stopped first.
   If it's not running, it will be started.  You can optionally include a different interval when restarting.
   
   - parameter withInterval: _default: nil_, if provided, this will change the Timer interval to the one specified before restarting.
   
   - returns: self, for chaining
   */
  @discardableResult public func restart(withInterval interval: TimeInterval? = nil) -> Self {
    stop()
    if let timeInterval = interval {
      self.interval = timeInterval
    }
    start()
    return self
  }
  
  /**
   Stop the timer and terminate the strem with the provided reason.
   
   - parameter withReason: The termination reason: .completed, .cancelled or .error
   */
  public func terminate(withReason reason: Termination) {
    stop()
    self.process(event: .terminate(reason: reason))
  }
  
  /// On deinit, we terminate the stream with `.cancelled`
  deinit {
    terminate(withReason: .cancelled)
  }
  
}
