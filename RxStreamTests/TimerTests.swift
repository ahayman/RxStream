//
//  TimerTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/29/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
import Rx

class TimerTests: XCTestCase {
  
  func testBasicTimer() {
    let timer = Rx.Timer(interval: 0.1)
    
    var count: UInt = 0
    timer.count().on{
      count = $0
    }
    XCTAssertEqual(count, 0)

    let start = Date.timeIntervalSinceReferenceDate
    timer.start()
    
    wait(for: 0.21)

    let end = Date.timeIntervalSinceReferenceDate
    let expected = UInt((end - start) / 0.1)
    XCTAssertEqual(count, expected)
    
    timer.terminate(withReason: .completed)
    
    wait(for: 0.11)
    XCTAssertEqual(count, expected, "Timer should no longer be firing")
  }
  
  func testTimerActive() {
    let timer = Rx.Timer(interval: 0.1)
    
    var count: UInt = 0
    timer.count().on{
      count = $0
    }
    XCTAssertEqual(count, 0)
    XCTAssertTrue(timer.isActive, "The stream should be active.")
    XCTAssertFalse(timer.isTimerActive, "The Timer should not be active.")

    let start = Date.timeIntervalSinceReferenceDate
    timer.start()
    XCTAssertTrue(timer.isActive, "The stream should be active.")
    XCTAssertTrue(timer.isTimerActive, "The Timer should now be active.")
    
    wait(for: 0.15)
    let end = Date.timeIntervalSinceReferenceDate
    let expected = UInt((end - start) / 0.1)
    XCTAssertEqual(count, expected, "Wait for at least 1 fire.")
    
    timer.stop()
    XCTAssertTrue(timer.isActive, "The stream should be active.")
    XCTAssertFalse(timer.isTimerActive, "The Timer should not be active.")
    
    timer.start()
    XCTAssertTrue(timer.isActive, "The stream should be active.")
    XCTAssertTrue(timer.isTimerActive, "The Timer should now be active.")
    
    timer.terminate(withReason: .completed)
    XCTAssertFalse(timer.isActive, "The stream should no longer be active.")
    XCTAssertFalse(timer.isTimerActive, "The Timer should not be active.")
  }
  
  func testTimerRestart() {
    let timer = Rx.Timer(interval: 0.1)
    
    var count: UInt = 0
    timer.count().on{
      count = $0
    }
    XCTAssertEqual(count, 0)

    var start = Date.timeIntervalSinceReferenceDate
    timer.start()
    
    wait(for: 0.15)
    var end = Date.timeIntervalSinceReferenceDate
    var expected = UInt((end - start) / 0.1)
    XCTAssertEqual(count, expected)

    start = Date.timeIntervalSinceReferenceDate
    timer.restart(withInterval: 0.2)
    
    wait(for: 0.25)
    end = Date.timeIntervalSinceReferenceDate
    expected = UInt((end - start) / 0.1)
    XCTAssertEqual(count, expected)
    
    timer.terminate(withReason: .completed)
  }
  
  func testTimerWithNoFirstDelay() {
    let timer = Rx.Timer(interval: 0.1)
    
    var count: UInt = 0
    timer.count().on{
      count = $0
    }
    XCTAssertEqual(count, 0)

    let start = Date.timeIntervalSinceReferenceDate
    timer.start(delayFirst: false)
    XCTAssertEqual(count, 1)
    
    wait(for: 0.15)
    let end = Date.timeIntervalSinceReferenceDate
    let expected = UInt((end - start) / 0.1) + 1
    XCTAssertEqual(count, expected)
    
    timer.terminate(withReason: .completed)
  }
  
  func testTimerDealloc() {
    var timer: Rx.Timer? = Rx.Timer(interval: 0.1)
    
    var count: UInt = 0
    timer?.count().on{
      count = $0
    }

    let start = Date.timeIntervalSinceReferenceDate
    timer?.start()
    
    wait(for: 0.15)
    let end = Date.timeIntervalSinceReferenceDate
    let expected = UInt((end - start) / 0.1)
    XCTAssertEqual(count, expected, "Timer should have fired")
    
    timer = nil
    
    wait(for: 0.2)
    XCTAssertEqual(count, expected, "The timer should have been deallocated and no longer firing.")
  }

  func testNewTimerHandler() {
    class TimerTester {
      var fired: Int = 0
      dynamic func fire() { fired += 1 }
    }

    let timer = Rx.Timer(interval: 0.1)
    let tester = TimerTester()
    XCTAssertNotNil(timer.newTimer)

    timer.newTimer = { (interval: TimeInterval, selector: Selector, repeats: Bool) -> Foundation.Timer in
      return Timer.scheduledTimer(timeInterval: interval, target: tester, selector: #selector(TimerTester.fire), userInfo: nil, repeats: false)
    }
    XCTAssertNotNil(timer.newTimer)

    let start = Date.timeIntervalSinceReferenceDate
    timer.start()

    wait(for: 0.15)

    let end = Date.timeIntervalSinceReferenceDate
    let expected = Int((end - start) / 0.1)
    XCTAssertEqual(tester.fired, expected)
  }

  func testMultiStart() {
    let timer = Rx.Timer(interval: 0.1)
    var fired = 0
    timer.on{ fired += 1 }

    let start = Date.timeIntervalSinceReferenceDate
    timer.start()
    timer.start()
    timer.start()
    timer.start()

    wait(for: 0.15)

    let end = Date.timeIntervalSinceReferenceDate
    let expected = Int((end - start) / 0.1)
    XCTAssertEqual(fired, expected)
  }
    
}
