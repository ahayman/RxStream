//
//  ArrayExtensionsTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 4/21/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

class ArrayExtensionsTests: XCTestCase {

  func testIndexOf() {
    let array = [0, 1, 2, 3, 4, 5, 6]
    XCTAssertEqual(array.indexOf{ $0 == 3 }, 3)
    XCTAssertEqual(array.indexOf{ $0 == 5 }, 5)

    let strings = ["hello", "world", "1", "2", "3"]
    XCTAssertEqual(strings.indexOf{ $0 == "world" }, 1)
    XCTAssertEqual(strings.indexOf{ $0 == "2" }, 3)
    XCTAssertNil(strings.indexOf{ $0 == "4" })
  }

  func testRemoving() {
    XCTAssertEqual([0, 0, 1, 1, 1, 1, 0, 0, 1].removing([1]), [0, 0, 0, 0])
    XCTAssertEqual([0, 0, 1, 1, 1, 1, 0, 0, 1].removing([0]), [1, 1, 1, 1, 1])
    XCTAssertEqual(["hello", "world", "world", "1", "2", "3"].removing(["world", "2", "3"]), ["hello", "1"])
  }

  func testTakeUntil() {
    XCTAssertEqual([0, 1, 2, 3, 4, 5].takeUntil{ $0 == 3 }, [0, 1, 2])
    XCTAssertEqual([0, 1, 2, 3, 4, 5].takeUntil{ $0 == 5 }, [0, 1, 2, 3, 4])
    XCTAssertEqual([0, 1, 2, 3, 4, 5].takeUntil{ $0 == 10 }, [0, 1, 2, 3, 4, 5])
  }

  func testFilled() {
    XCTAssertNil([].filled)
    XCTAssertNotNil([1].filled)
  }

}
