//
//  ResultTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 4/21/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
import Rx

class ResultTests: XCTestCase {

  func testSuccessValue() {
    let result = Result.success(10)
    XCTAssertEqual(try? result.value(), 10)
  }

  func testFailureValue() {
    let result = Result<Int>.failure(TestError())
    XCTAssertNil(try? result.value())
  }

  func testOnSuccess() {
    let result = Result.success(10)
    var value: Int?
    result.onSuccess{ value = $0 }
    XCTAssertEqual(value, 10)
  }

  func testOnFailure() {
    let result = Result<Int>.failure(TestError())
    var error: Error?

    result.onFailure{ error = $0 }
    XCTAssertNotNil(error)
  }

}
