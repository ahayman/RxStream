//
//  HotTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 4/21/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

class HotTests: XCTestCase {

  func testHotInputValue() {
    var values = [Int]()
    let hot = HotInput<Int>()

    hot.on{ values.append($0) }

    hot.push(0)
    XCTAssertEqual(values, [0])
    hot.push(1)
    XCTAssertEqual(values, [0, 1])
  }

  func testHotInputError() {
    var errors = [Error]()
    let hot = HotInput<Int>()

    hot.onError{ errors.append($0) }

    hot.push(TestError())
    XCTAssertEqual(errors.count, 1)

    hot.push(TestError())
    XCTAssertEqual(errors.count, 2)
  }

  func testHotProducerValues() {
    var values = [Int]()
    var producer: ((Event<Int>) -> Void)?
    let hot = HotProducer<Int> {
      producer = $0
    }

    hot.on{ values.append($0) }

    XCTAssertNotNil(producer)

    producer?(.next(0))
    XCTAssertEqual(values, [0])

    producer?(.next(1))
    XCTAssertEqual(values, [0, 1])

    producer?(.next(2))
    XCTAssertEqual(values, [0, 1, 2])
  }

  func testHotProducerErrors() {
    var errors = [Error]()
    var producer: ((Event<Int>) -> Void)?
    let hot = HotProducer<Int> {
      producer = $0
    }

    hot.onError{ errors.append($0) }

    XCTAssertNotNil(producer)

    producer?(.error(TestError()))
    XCTAssertEqual(errors.count, 1)

    producer?(.error(TestError()))
    XCTAssertEqual(errors.count, 2)
  }

  func testHotProducerTerminate(){
    var values = [Int]()
    var terminations = [Termination]()
    var producer: ((Event<Int>) -> Void)?
    let hot = HotProducer<Int> {
      producer = $0
    }

    hot
      .on{ values.append($0) }
      .onTerminate{ terminations.append($0) }

    XCTAssertNotNil(producer)

    producer?(.next(0))
    XCTAssertEqual(values, [0])
    XCTAssertEqual(terminations, [])

    producer?(.next(1))
    XCTAssertEqual(values, [0, 1])
    XCTAssertEqual(terminations, [])

    producer?(.terminate(reason: .completed))
    XCTAssertEqual(terminations, [.completed])
  }

  func testStreamDispatch() {
    var values = [Int]()
    var bValues = [Int]()
    let hot = HotInput<Int>()

    hot
      .dispatch(.sync(on: .main)).on {
        if Thread.isMainThread {
          values.append($0)
        }
      }
      .on{
        if !Thread.isMainThread {
          bValues.append($0)
        }
      }.dispatched(.async(on: .background))

    hot.push(0)
    XCTAssertEqual(values, [0])

    hot.push(1)
    XCTAssertEqual(values, [0, 1])

    wait(for: 0.5)
    XCTAssertTrue(bValues.contains(0))
    XCTAssertTrue(bValues.contains(1))
    XCTAssertEqual(bValues.count, 2)
  }


}
