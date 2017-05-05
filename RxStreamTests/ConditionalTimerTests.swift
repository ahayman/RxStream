//
//  ConditionalTimerTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/28/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

class ConditionalTimerTests : XCTestCase {
  
  func testBasicTimer() {
    var count = 0
    let timer = ConditionalTimer(interval: 0.1) { () -> Bool in
      count += 1
      return true
    }

    timer.start()

    wait(for: 0.25)
    XCTAssertGreaterThan(count, 0, "Expect Timer to fire twice")
    let stopped = count

    timer.stop()
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    
    wait(for: 0.15)
    XCTAssertEqual(count, stopped, "Expect Timer to have stopped firing.")
  }
  
  func testRestartTimer() {
    var count = 0
    let timer = ConditionalTimer(interval: 0.1) { () -> Bool in
      count += 1
      return true
    }

    timer.start()
    
    wait(for: 0.15)
    XCTAssertGreaterThan(count, 0, "Expect Timer to fire")
    var last = count

    timer.restart(withInterval: 0.2)
    wait(for: 0.11)
    XCTAssertEqual(count, last, "Interval has changed, so timer should not fire yet.")

    wait(for: 0.14)
    XCTAssertGreaterThan(count, last, "Expect timer to have fired.")
    last = count
    
    timer.stop()
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    wait(for: 0.21)
    XCTAssertEqual(count, last, "Timer has been stopped and shouldn't fire.")
  }
  
  func testTimerCondition() {
    var count = 0
    var continueFiring = true
    let timer = ConditionalTimer(interval: 0.1) { () -> Bool in
      count += 1
      return continueFiring
    }

    timer.start()
    
    wait(for: 0.25)
    XCTAssertGreaterThan(count, 0, "Expect Timer to fire")
    var last = count
    
    continueFiring = false
    
    wait(for: 0.15)
    XCTAssertGreaterThan(count, last, "Expect Timer to fire, last time.")
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    last = count
    
    wait(for: 0.1)
    XCTAssertEqual(count, last, "Timer shouldn't fire again")
  }
  
  func testTimerConditionRestart() {
    var count = 0
    var continueFiring = true
    let timer = ConditionalTimer(interval: 0.1) { () -> Bool in
      count += 1
      return continueFiring
    }

    timer.start()
    
    wait(for: 0.21)
    XCTAssertGreaterThan(count, 0, "Expect Timer to fire")
    var last = count
    
    continueFiring = false
    
    wait(for: 0.2)
    XCTAssertEqual(count, last + 1, "Expect Timer to fire, last time.")
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    last = count

    timer.restart()
    
    wait(for: 0.2)
    XCTAssertGreaterThan(count, last, "Expect Timer to fire, one before being discontinued.")
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    last = count
    
    wait(for: 0.2)
    XCTAssertEqual(count, last, "Timer should not fire again.")
  }
  
}
