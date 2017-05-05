//
//  CircularBufferTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/22/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

class CircularBufferTests: XCTestCase {
  
  func testAppendingElements() {
    var buffer = CircularBuffer<Int>(size: 3)
    XCTAssertEqual(buffer.count, 0)
    
    buffer.append(0)
    XCTAssertEqual(buffer.count, 1)
    XCTAssertEqual(buffer[0], 0)
    
    buffer.append(1)
    XCTAssertEqual(buffer.count, 2)
    XCTAssertEqual(buffer[0], 0)
    XCTAssertEqual(buffer[1], 1)
    
    buffer.append(2)
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 0)
    XCTAssertEqual(buffer[1], 1)
    XCTAssertEqual(buffer[2], 2)
    
    buffer.append(3)
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 1)
    XCTAssertEqual(buffer[1], 2)
    XCTAssertEqual(buffer[2], 3)
    
    buffer.append(4)
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 2)
    XCTAssertEqual(buffer[1], 3)
    XCTAssertEqual(buffer[2], 4)
    
    buffer.append(5)
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 3)
    XCTAssertEqual(buffer[1], 4)
    XCTAssertEqual(buffer[2], 5)
  }
  
  func testInitialDataLessThanBuffer() {
    var buffer = CircularBuffer(size: 3, data: [0, 1])
    XCTAssertEqual(buffer.count, 2)
    XCTAssertEqual(buffer[0], 0)
    XCTAssertEqual(buffer[1], 1)
    
    buffer.append(2)
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 0)
    XCTAssertEqual(buffer[1], 1)
    XCTAssertEqual(buffer[2], 2)
    
    buffer.append(3)
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 1)
    XCTAssertEqual(buffer[1], 2)
    XCTAssertEqual(buffer[2], 3)
  }
  
  func testInitialDataEqualToBuffer() {
    var buffer = CircularBuffer(size: 3, data: [0, 1, 2])
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 0)
    XCTAssertEqual(buffer[1], 1)
    XCTAssertEqual(buffer[2], 2)
    
    buffer.append(3)
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 1)
    XCTAssertEqual(buffer[1], 2)
    XCTAssertEqual(buffer[2], 3)
    
    buffer.append(4)
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 2)
    XCTAssertEqual(buffer[1], 3)
    XCTAssertEqual(buffer[2], 4)
  }
  
  func testInitialDataGreaterThanBuffer() {
    var buffer = CircularBuffer(size: 3, data: [0, 1, 2, 3, 4])
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 2)
    XCTAssertEqual(buffer[1], 3)
    XCTAssertEqual(buffer[2], 4)
    
    buffer.append(5)
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 3)
    XCTAssertEqual(buffer[1], 4)
    XCTAssertEqual(buffer[2], 5)
    
    buffer.append(6)
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(buffer[0], 4)
    XCTAssertEqual(buffer[1], 5)
    XCTAssertEqual(buffer[2], 6)
  }
  
  func testReversal() {
    let buffer = CircularBuffer(size: 3, data: [0, 1, 2])
    var results = [Int]()
    for i in buffer.reversed() {
      results.append(i)
    }
    XCTAssertEqual(results, [2, 1, 0])
  }

  func testEmptyData() {
    let buffer = CircularBuffer<Int>(size: 3, data: [])
    XCTAssertEqual(buffer.count, 0)
  }
    
}
