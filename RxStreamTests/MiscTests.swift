//
//  MiscTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 5/5/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

/// For testing misc objects that don't really need separate files
class MiscTests: XCTestCase {

  func testTermination() {
    XCTAssertEqual(Termination.completed, Termination.completed)
    XCTAssertEqual(Termination.cancelled, Termination.cancelled)
    XCTAssertEqual(Termination.error(TestError()), Termination.error(TestError()))
    XCTAssertNotEqual(Termination.completed, Termination.cancelled)
    XCTAssertNotEqual(Termination.completed, Termination.error(TestError()))
    XCTAssertNotEqual(Termination.cancelled, Termination.error(TestError()))
  }

  func testDebug() {
    let hot = HotInput<Int>()
    var logs = [String]()

    hot.debugPrinter = { logs.append($0) }

    hot.push(0)
    XCTAssertGreaterThan(logs.count, 0)
  }

  func testGlobalDebug() {
    let hot = HotInput<Int>()
    var logs = [String]()

    Hot<Int>.debugPrinter = { logs.append($0) }

    hot.push(0)
    XCTAssertGreaterThan(logs.count, 0)
    Hot<Int>.debugPrinter = nil
  }

  func testNamedDebug() {
    let hot = HotInput<Int>().named("Custom Name")
    XCTAssertEqual(hot.debugDescription, "Custom Name")
  }

  func testDesccriptor() {
    let hot = HotInput<Int>()
    hot.descriptor = "Custom Name"
    XCTAssertEqual(hot.debugDescription, "Custom Name")
  }

}
