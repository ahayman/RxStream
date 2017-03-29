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
    
    wait(for: 0.11) 
    XCTAssertEqual(count, 1, "Expect Timer to fire")
    
    wait(for: 0.11) 
    XCTAssertEqual(count, 2, "Expect Timer to fire")
    
    timer.stop()
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    
    wait(for: 0.11)
    XCTAssertEqual(count, 2, "Expect Timer to have stopped firing.")
  }
  
  func testRestartTimer() {
    var count = 0
    let timer = ConditionalTimer(interval: 0.1) { () -> Bool in
      count += 1
      return true
    }
    
    timer.start()
    
    wait(for: 0.11) 
    XCTAssertEqual(count, 1, "Expect Timer to fire")
    
    timer.restart(withInterval: 0.2)
    wait(for: 0.11)
    XCTAssertEqual(count, 1, "Interval has changed, so timer should not fire yet.")
    
    wait(for: 0.1)
    XCTAssertEqual(count, 2, "Expect timer to have fired.")
    
    timer.stop()
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    wait(for: 0.21)
    XCTAssertEqual(count, 2, "Timer has been stopped and shouldn't fire.")
  }
  
  func testTimerCondition() {
    var count = 0
    var continueFiring = true
    let timer = ConditionalTimer(interval: 0.1) { () -> Bool in
      count += 1
      return continueFiring
    }
    
    timer.start()
    
    wait(for: 0.11) 
    XCTAssertEqual(count, 1, "Expect Timer to fire")
    
    wait(for: 0.11) 
    XCTAssertEqual(count, 2, "Expect Timer to fire")
    
    continueFiring = false
    
    wait(for: 0.11) 
    XCTAssertEqual(count, 3, "Expect Timer to fire, last time.")
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    
    wait(for: 0.11) 
    XCTAssertEqual(count, 3, "Timer shouldn't fire again")
  }
  
  func testTimerConditionRestart() {
    var count = 0
    var continueFiring = true
    let timer = ConditionalTimer(interval: 0.1) { () -> Bool in
      count += 1
      return continueFiring
    }
    
    timer.start()
    
    wait(for: 0.11) 
    XCTAssertEqual(count, 1, "Expect Timer to fire")
    
    wait(for: 0.11) 
    XCTAssertEqual(count, 2, "Expect Timer to fire")
    
    continueFiring = false
    
    wait(for: 0.11) 
    XCTAssertEqual(count, 3, "Expect Timer to fire, last time.")
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    
    timer.restart()
    
    wait(for: 0.11)
    XCTAssertEqual(count, 4, "Expect Timer to fire, one before being discontinued.")
    XCTAssertFalse(timer.isActive, "Timer should be inactive")
    
    wait(for: 0.11)
    XCTAssertEqual(count, 4, "Timer should not fire again.")
  }
  
}
