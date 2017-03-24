//
//  ObservableTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/23/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
import Rx

class ObservableTests: XCTestCase {
  
  func testInitialValue() {
    let observable = ObservableInput(0)
    
    XCTAssertEqual(observable.value, 0)
  }
  
  func testDownstreamValues() {
    let observable = ObservableInput(0)
    var observed = [Int]()
    
    XCTAssertEqual(observable.on{ observed.append($0) }.value, 0)
    XCTAssertEqual(observed, [])
  }
  
  func testPushedDownstreamValues() {
    let observable = ObservableInput(0)
    var observed = [String]()
    
    let lastObserved = observable
      .map{ "\($0)" }
      .on{ observed.append($0) }
    
    XCTAssertEqual(observable.value, 0)
    XCTAssertEqual(lastObserved.value, "0")
    XCTAssertEqual(observed, [])
    
    observable.set(1)
    XCTAssertEqual(observable.value, 1)
    XCTAssertEqual(lastObserved.value, "1")
    XCTAssertEqual(observed, ["1"])
    
    observable.set(2)
    XCTAssertEqual(observable.value, 2)
    XCTAssertEqual(lastObserved.value, "2")
    XCTAssertEqual(observed, ["1", "2"])
  }
  
  func testReplay() {
    let observable = ObservableInput(0)
    var observed = [String]()
    
    let lastObserved = observable
      .replayNext()
      .map{ "\($0)" }
      .on{ observed.append($0) }
    
    XCTAssertEqual(observable.value, 0)
    XCTAssertEqual(lastObserved.value, "0")
    XCTAssertEqual(observed, ["0"])
    
    observable.set(1)
    XCTAssertEqual(observable.value, 1)
    XCTAssertEqual(lastObserved.value, "1")
    XCTAssertEqual(observed, ["0", "1"])
    
    observable.set(2)
    XCTAssertEqual(observable.value, 2)
    XCTAssertEqual(lastObserved.value, "2")
    XCTAssertEqual(observed, ["0", "1", "2"])
  }
  
  
}
