//
//  EitherTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 5/5/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

class EitherTests: XCTestCase {

  func testLeft() {
    let either: Either<Int, String> = .left(0)
    XCTAssertEqual(either.left, 0)
    XCTAssertNil(either.right)
  }

  func testOnLeft() {
    let either: Either<Int, String> = .left(0)
    var results = [Int]()
    either.onLeft{ results.append($0) }
    XCTAssertEqual(results, [0])
    either.onLeft{ results.append($0) }
    XCTAssertEqual(results, [0, 0])
  }

  func testRight() {
    let either: Either<Int, String> = .right("zero")
    XCTAssertEqual(either.right, "zero")
    XCTAssertNil(either.left)
  }

  func testOnRight() {
    let either: Either<Int, String> = .right("zero")
    var results = [String]()
    either.onRight{ results.append($0) }
    XCTAssertEqual(results, ["zero"])
    either.onRight{ results.append($0) }
    XCTAssertEqual(results, ["zero", "zero"])
  }

}
