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

}
