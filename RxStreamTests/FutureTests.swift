//
//  FutureTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/22/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
import Rx

class FutureTests: XCTestCase {
  
  func testCompletion() {
    var completion: ((Result<Int>) -> Void)? = nil
    var results = [Int]()
    var terminations = [Termination]()
    let future = Future<Int> { onCompletion in
      completion = onCompletion
    }
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0) }
    
    XCTAssertTrue(future.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Future task to be called") }
    
    completionTask(.success(0))
    
    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(future.state, .terminated(reason: .completed))
    
    completionTask(.success(1))
    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(future.state, .terminated(reason: .completed))
  }
  
  func testError() {
    var completion: ((Result<Int>) -> Void)? = nil
    var results = [Int]()
    var terminations = [Termination]()
    let future = Future<Int> { onCompletion in
      completion = onCompletion
    }
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0) }
    
    XCTAssertTrue(future.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Future task to be called") }
    
    completionTask(.failure(TestError()))
    
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(future.state, .terminated(reason: .error(TestError())))
    
    completionTask(.success(1))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(future.state, .terminated(reason: .error(TestError())))
    
    completionTask(.success(2))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(future.state, .terminated(reason: .error(TestError())))
    
    completionTask(.failure(TestError()))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(future.state, .terminated(reason: .error(TestError())))
  }

  func testPreCompleteValue() {
    let future = Future.completed(10)
    var values = [Int]()

    future.on{ values.append($0) }
    XCTAssertEqual(values, [10])
  }

  func testPreCompletedError() {
    let future = Future<Int>.completed(TestError())
    var errors = [Error]()

    future.onError{ errors.append($0) }
    XCTAssertEqual(errors.count, 1)
  }

  func testFutureInputValue() {
    let future = FutureInput<Int>()
    var values = [Int]()

    future.on{ values.append($0) }

    XCTAssertEqual(values, [])

    future.complete(10)

    XCTAssertEqual(values, [10])
  }

  func testFutureInputError() {
    let future = FutureInput<Int>()
    var errors = [Error]()

    future.onError{ errors.append($0) }

    XCTAssertEqual(errors.count, 0)

    future.complete(TestError())
    XCTAssertEqual(errors.count, 1)
  }
    
}
