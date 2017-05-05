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

    let start = Date.timeIntervalSinceReferenceDate
    timer.start()

    wait(for: 0.25)
    let end = Date.timeIntervalSinceReferenceDate
    let expected = Int((end - start) / 0.1)
    XCTAssertEqual(count, expected, "Expect Timer to fire twice")
    
    timer.stop()
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    
    wait(for: 0.1)
    XCTAssertEqual(count, expected, "Expect Timer to have stopped firing.")
  }
  
  func testRestartTimer() {
    var count = 0
    let timer = ConditionalTimer(interval: 0.1) { () -> Bool in
      count += 1
      return true
    }

    var start = Date.timeIntervalSinceReferenceDate
    timer.start()
    
    wait(for: 0.11)

    var end = Date.timeIntervalSinceReferenceDate
    var expected = Int((end - start) / 0.1)
    XCTAssertEqual(count, expected, "Expect Timer to fire")

    start = Date.timeIntervalSinceReferenceDate
    timer.restart(withInterval: 0.2)
    wait(for: 0.21)
    end = Date.timeIntervalSinceReferenceDate
    expected += Int((end - start) / 0.2)
    XCTAssertEqual(count, expected, "Expect timer to have fired.")
    
    timer.stop()
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    wait(for: 0.21)
    XCTAssertEqual(count, expected, "Timer has been stopped and shouldn't fire.")
  }
  
  func testTimerCondition() {
    var count = 0
    var continueFiring = true
    let timer = ConditionalTimer(interval: 0.1) { () -> Bool in
      count += 1
      return continueFiring
    }

    let start = Date.timeIntervalSinceReferenceDate
    timer.start()
    
    wait(for: 0.25)
    let end = Date.timeIntervalSinceReferenceDate
    var expected = Int((end - start) / 0.1)
    XCTAssertEqual(count, expected, "Expect Timer to fire")
    
    continueFiring = false
    expected += 1
    
    wait(for: 0.1)
    XCTAssertEqual(count, expected, "Expect Timer to fire, last time.")
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    
    wait(for: 0.1)
    XCTAssertEqual(count, expected, "Timer shouldn't fire again")
  }
  
  func testTimerConditionRestart() {
    var count = 0
    var continueFiring = true
    let timer = ConditionalTimer(interval: 0.1) { () -> Bool in
      count += 1
      return continueFiring
    }

    let start = Date.timeIntervalSinceReferenceDate
    timer.start()
    
    wait(for: 0.21)
    let end = Date.timeIntervalSinceReferenceDate
    var expected = Int((end - start) / 0.1)
    XCTAssertEqual(count, expected, "Expect Timer to fire")
    
    continueFiring = false
    expected += 1
    
    wait(for: 0.11) 
    XCTAssertEqual(count, expected, "Expect Timer to fire, last time.")
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    
    timer.restart()
    expected += 1
    
    wait(for: 0.11)
    XCTAssertEqual(count, expected, "Expect Timer to fire, one before being discontinued.")
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    
    wait(for: 0.11)
    XCTAssertEqual(count, expected, "Timer should not fire again.")
  }
  
}
