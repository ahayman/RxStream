//
//  StreamThrottleTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 5/4/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
import Rx

class StreamThrottleTests: XCTestCase {

  func testPressureThrottleLimit() {
    var completions = [(value: Int, result: (Result<Int>?) -> Void)]()
    var results = [Int]()
    let stream = HotInput<Int>()

    stream
      .asyncMap { (i: Int, result: @escaping (Result<Int>?) -> Void) in
        completions.append((i, result))
      }.throttled(PressureThrottle(buffer: 0, limit: 2))
      .on{ results.append($0) }


    // Pressure: 1
    stream.push(0)

    XCTAssertEqual(completions.count, 1, "First Work within limit should execute.")
    XCTAssertEqual(results, [])

    // Pressure: 2
    stream.push(1)

    XCTAssertEqual(completions.count, 2, "Second Work within limit should execute.")
    XCTAssertEqual(results, [])

    stream.push(3)

    XCTAssertEqual(completions.count, 2, "Third Work within exceeds limit shouldn't execute.")
    XCTAssertEqual(results, [])

    // Pressure: 1
    completions[0].1(.success(completions[0].0))

    XCTAssertEqual(completions.count, 2, "Third Work shouldn't be buffered. Shouldn't execute.")
    XCTAssertEqual(results, [0])

    // Pressure: 2
    stream.push(4)

    XCTAssertEqual(completions.count, 3, "Fourth Work within limit, should execute.")
    XCTAssertEqual(results, [0])

    // Pressure: 1
    completions[1].1(.success(completions[1].0))
    // Pressure: 0
    completions[2].1(.success(completions[2].0))

    XCTAssertEqual(completions.count, 3, "Fourth Work within limit, should execute.")
    XCTAssertEqual(results, [0, 1, 4])
  }

  func testPressureThrottleBuffer() {
    var completions = [(value: Int, result: (Result<Int>?) -> Void)]()
    var results = [Int]()
    let stream = HotInput<Int>()

    stream
      .asyncMap { (i: Int, result: @escaping (Result<Int>?) -> Void) in
        completions.append((i, result))
      }.throttled(PressureThrottle(buffer: 2, limit: 1))
      .on{ results.append($0) }

    // Pressure: 1, Buffer: 0
    stream.push(0)
    XCTAssertEqual(completions.count, 1, "First Work within limit should execute.")
    XCTAssertEqual(results, [])

    stream.push(1)
    XCTAssertEqual(completions.count, 1, "Second Work should be buffered.")
    XCTAssertEqual(results, [])

    // Pressure: 1, Buffer: 2
    stream.push(2)
    XCTAssertEqual(completions.count, 1, "Second Work should be buffered.")
    XCTAssertEqual(results, [])

    // Pressure: 1, Buffer: 2, Drop: 1
    stream.push(3)
    XCTAssertEqual(completions.count, 1, "Second Work should be buffered.")
    XCTAssertEqual(results, [])

    // Pressure: 1, Buffer: 1
    completions[0].1(.success(completions[0].0))
    XCTAssertEqual(completions.count, 2, "Second work should be pulled from buffer and executed.")
    XCTAssertEqual(results, [0])

    // Pressure: 1, Buffer: 0
    completions[1].1(.success(completions[1].0))

    XCTAssertEqual(completions.count, 3, "Third work should be pulled from buffer and executed.")
    XCTAssertEqual(results, [0, 1])

    // Pressure: 0, Buffer: 0
    completions[2].1(.success(completions[2].0))

    XCTAssertEqual(completions.count, 3, "Buffer empty, nothing else should execute. Fourth work should have been dropped.")
    XCTAssertEqual(results, [0, 1, 2])
  }

}
