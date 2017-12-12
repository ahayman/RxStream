//
//  FutureTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/22/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

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

    future.on{ values.append($0) }.replay()
    XCTAssertEqual(values, [10])
  }

  func testPreCompletedError() {
    let future = Future<Int>.completed(TestError())
    var errors = [Error]()

    future.onError{ errors.append($0) }.replay()
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

  func testAutoReplay() {
    let future = FutureInput<Int>()
    var values = [Int]()
    future.complete(10)

    future.on{ values.append($0) }

    XCTAssertEqual(values, [], "Initially, nothing will happen because the future has already completed.")

    wait(for: 0.1)

    XCTAssertEqual(values, [10], "After a moment, the autoReplay should occur.")
  }

  func testMultiBranchAutoReplay() {
    let future = FutureInput<Int>()
    var aValues = [Int]()
    var bValues = [Int]()
    future.complete(10)

    future.on{ aValues.append($0) }
    future.on{ bValues.append($0) }

    XCTAssertEqual(aValues, [], "Initially, nothing will happen because the future has already completed.")
    XCTAssertEqual(bValues, [], "Initially, nothing will happen because the future has already completed.")

    wait(for: 0.1)

    XCTAssertEqual(aValues, [10], "After a moment, the autoReplay should occur.")
    XCTAssertEqual(bValues, [10], "After a moment, the autoReplay should occur.")
  }

  func testLazy() {
    var generated = [Int]()
    let lazy = Lazy<Int> {
      generated.append(1)
      $0(.success(1))
    }

    XCTAssertEqual(generated, [], "Lazy should not generate a value yet.")

    var observed = [Int]()
    lazy.on{ observed.append($0) }

    XCTAssertEqual(generated, [1], "Adding an op should trigger the value to be generated.")
    XCTAssertEqual(observed, [1], "Generated value should be observed.")
  }

  func testLazyChain() {
    var generated = [Int]()
    let lazy = Lazy<Int> {
      generated.append(1)
      $0(.success(1))
    }

    XCTAssertEqual(generated, [], "Lazy should not generate a value yet.")

    var observed = [String]()
    lazy
      .map{ String($0) }
      .on{ observed.append($0) }
      .replay()

    XCTAssertEqual(generated, [1], "Adding an op should trigger the value to be generated.")
    XCTAssertEqual(observed, ["1"], "Generated value should be observed.")
  }
  
  func testFutureCleanup() {
    let future: Future<Int> = Future.completed(1)
    var values = [Int]()
    
    let done = expectation(description: "Complete")
    
    future.on{ values.append($0)}
    future.on{ values.append($0)}
    future.on{ values.append($0)}
    future.on{ values.append($0)}
    future.on{ values.append($0)}
    future.on{ values.append($0)}
    future.on{ values.append($0)}
    future
      .on{ values.append($0)}
      .onTerminate { _ in done.fulfill() }
    
    XCTAssertEqual(future.downStreams.count, 8)
    XCTAssertEqual(values.count, 0)
    
    waitForExpectations(timeout: 10.0)
    
    XCTAssertEqual(values.count, 8)
    XCTAssertEqual(future.downStreams.count, 0)
  }

}
