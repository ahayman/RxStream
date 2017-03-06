//
//  DispatchTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/6/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
import Rx

class DispatchTests: XCTestCase {
  
  func testDelayedDispatch() {
    let now = NSDate.timeIntervalSinceReferenceDate
    var done = NSDate.timeIntervalSinceReferenceDate
    let expectUpdate = expectation(description: "expect the date to be updated")
    Dispatch.after(delay: 2.0, on: .main).execute {
      done = NSDate.timeIntervalSinceReferenceDate
      expectUpdate.fulfill()
    }
    waitForExpectations(timeout: 3.0)
    XCTAssert(done - now >= 2.0)
  }
  
  func testDispatchMain() {
    let expectMain = expectation(description: "dispatched on main.")
    
    DispatchQueue.global().async {
      Dispatch.async(on: .main).execute {
        if Thread.isMainThread {
          expectMain.fulfill()
        }
      }
    }
    
    waitForExpectations(timeout: 5.0)
  }
  
  func testDispatchBackground() {
    let expectMain = expectation(description: "dispatched in background.")
    
    Dispatch.async(on: .background).execute {
      if !Thread.isMainThread {
        expectMain.fulfill()
      }
    }
    
    waitForExpectations(timeout: 5.0)
  }
  
  func testChaining() {
    var dispatches = [String]()
    let expectChain = expectation(description: "chain execution complete")
    
    Dispatch
      .async(on: .background).execute {
        guard !Thread.isMainThread else { return }
        dispatches.append("background1")
      }.then(.async(on: .main)) {
        guard Thread.isMainThread else { return }
        dispatches.append("main1")
      }.then(.async(on: .background)) {
        guard !Thread.isMainThread else { return }
        dispatches.append("background2")
        expectChain.fulfill()
      }
    
    waitForExpectations(timeout: 5.0)
    guard dispatches.count == 3 else { return XCTFail("The dispatch chain did not complete. Expected 3 dispatches, received \(dispatches.count)") }
    XCTAssertEqual(dispatches[0], "background1")
    XCTAssertEqual(dispatches[1], "main1")
    XCTAssertEqual(dispatches[2], "background2")
  }
  
  func testImmediateChaining() {
    var dispatches = [String]()
    let expectChain = expectation(description: "chain execution complete")
    
    // Using `sync` will make sure work is executed prior to additional work being added.  We just want to make sure the chain isn't broken.
    Dispatch
      .sync(on: .main).execute {
        guard Thread.isMainThread else { return }
        dispatches.append("main1")
      }.then(.sync(on: .main)) {
        guard Thread.isMainThread else { return }
        dispatches.append("main2")
      }.then(.sync(on: .main)) {
        guard Thread.isMainThread else { return }
        dispatches.append("main3")
        expectChain.fulfill()
      }
    
    waitForExpectations(timeout: 5.0)
    guard dispatches.count == 3 else { return XCTFail("The dispatch chain did not complete. Expected 3 dispatches, received \(dispatches.count)") }
    XCTAssertEqual(dispatches[0], "main1")
    XCTAssertEqual(dispatches[1], "main2")
    XCTAssertEqual(dispatches[2], "main3")
  }
  
  func testSerialReentryDetection() {
    let dispatch = Dispatch.sync(on: .custom(CustomQueue(type: .serial, name: "TestSerialQueue")))
    let outerDispatch = expectation(description: "Outer dispatch executed.")
    let innerDispatch = expectation(description: "Inner dispatch executed without locking.")
    dispatch.execute {
      outerDispatch.fulfill()
      // Re-entry 
      dispatch.execute {
        innerDispatch.fulfill()
      }
    }
    waitForExpectations(timeout: 5.0)
  }
  
}
