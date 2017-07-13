//
//  DispatchThreadTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 7/13/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

class DispatchThreadTests: XCTestCase {
    
  func testQueuedWork() {
    var updates = [String]()
    let thread = DispatchThread()
    thread.enqueue {
      updates.append("First Block")
    }
    thread.enqueue {
      updates.append("Second Block")
    }
    wait(for: 0.2)
    XCTAssertEqual(updates.count, 2)
  }

  func testPauseResume() {
    var updates = [String]()
    let thread = DispatchThread(name: "Test DispatchThread Pause")
    let first = expectation(description: "First Block run")
    
    thread.enqueue{
      updates.append("First")
      first.fulfill()
    }
    waitForExpectations(timeout: 10.0)
    XCTAssertEqual(updates, ["First"])

    thread.pause()
    XCTAssertTrue(thread.paused)

    thread.enqueue{
      updates.append("Second")
    }

    wait(for: 0.25)
    XCTAssertEqual(updates, ["First"])

    let third = expectation(description: "Second Block run")
    thread.enqueue{
      updates.append("Third")
      third.fulfill()
    }
    thread.resume()
    waitForExpectations(timeout: 10.0)
    XCTAssertEqual(updates, ["First", "Second", "Third"])
  }

  func testCancelled() {
    var updates = [String]()
    let thread = DispatchThread(name: "Test DispatchThread Cancelled")
    let first = expectation(description: "First Block run")
    thread.enqueue{
      updates.append("First")
      first.fulfill()
    }
    waitForExpectations(timeout: 10.0)
    XCTAssertEqual(updates, ["First"])

    thread.cancel()

    thread.enqueue{
      updates.append("Second")
    }

    wait(for: 0.1)
    XCTAssertEqual(updates, ["First"])
  }

  func testDelayedStart() {
    var updates = [String]()
    let thread = DispatchThread(start: false, name: "Test DispatchThread Delayed Start")
    thread.enqueue{
      updates.append("First")
    }

    wait(for: 0.1)
    XCTAssertEqual(updates, [])

    let second = expectation(description: "First Block run")
    thread.enqueue{
      updates.append("Second")
      second.fulfill()
    }

    thread.start()

    waitForExpectations(timeout: 10.0)
    XCTAssertEqual(updates, ["First", "Second"])
  }

  func testExecutionThread() {
    let thread = DispatchThread(start: false, name: "Test Execution Thread")
    let expect = expectation(description: "Execution Thread is same as the DispatchThread")
    thread.enqueue{
      if Thread.current.name == thread.name {
        expect.fulfill()
      }
    }
    thread.start()
    waitForExpectations(timeout: 10.0)
  }
    
}
