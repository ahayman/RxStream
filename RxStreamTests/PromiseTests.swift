//
//  PromiseTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/22/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

private enum RetryError : Error {
  case retry
  case noRetry
}

class PromiseTests: XCTestCase {
  
  func testCompletion() {
    var completion: ((Result<Int>) -> Void)? = nil
    var results = [Int]()
    var terminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completion = onCompletion
    }
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0) }
    
    XCTAssertTrue(promise.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Promise task to be called") }
    
    completionTask(.success(0))
    
    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(promise.state, .terminated(reason: .completed))
    
    completionTask(.success(1))
    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(promise.state, .terminated(reason: .completed))
    
    completionTask(.success(2))
    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(promise.state, .terminated(reason: .completed))
    
    completionTask(.failure(TestError()))
    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(promise.state, .terminated(reason: .completed))
  }
  
  func testError() {
    var completion: ((Result<Int>) -> Void)? = nil
    var results = [Int]()
    var terminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completion = onCompletion
    }
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0) }
    
    XCTAssertTrue(promise.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Promise task to be called") }
    
    completionTask(.failure(TestError()))
    
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(promise.state, .terminated(reason: .error(TestError())))
    
    completionTask(.success(1))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(promise.state, .terminated(reason: .error(TestError())))
    
    completionTask(.success(2))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(promise.state, .terminated(reason: .error(TestError())))
    
    completionTask(.failure(TestError()))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(promise.state, .terminated(reason: .error(TestError())))
  }
  
  ///Testing: A promise fills results _down_ the chain, but then completes results back _up_ the chain.
  func testCompletionOrder() {
    var completion: ((Result<Int>) -> Void)? = nil
    var results = [(index: Int, value: Int)]()
    var terminations = [(index: Int, term: Termination)]()
    let promise = Promise<Int> { _, onCompletion in
      completion = onCompletion
    }
      .on{ results.append((0, $0)) }
      .onTerminate{ terminations.append((0, $0)) }
      .on{ results.append((1, $0)) }
      .onTerminate{ terminations.append((1, $0)) }
      .on{ results.append((2, $0)) }
      .onTerminate{ terminations.append((2, $0)) }
      .on{ results.append((3, $0)) }
      .onTerminate{ terminations.append((3, $0)) }
    
    XCTAssertTrue(promise.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Promise task to be called") }
    
    completionTask(.success(0))
    
    guard results.count == 4 else { return XCTFail("Expected 4 results, got \(results.count)") }
    guard terminations.count == 4 else { return XCTFail("Expected 4 terminations, got \(terminations.count)") }
    
    XCTAssertEqual(terminations[0].index, 3)
    XCTAssertEqual(terminations[0].term, .completed)
    XCTAssertEqual(results[0].index, 0)
    XCTAssertEqual(results[0].value, 0)
    
    XCTAssertEqual(terminations[1].index, 2)
    XCTAssertEqual(terminations[1].term, .completed)
    XCTAssertEqual(results[1].index, 1)
    XCTAssertEqual(results[1].value, 0)
    
    XCTAssertEqual(terminations[2].index, 1)
    XCTAssertEqual(terminations[2].term, .completed)
    XCTAssertEqual(results[2].index, 2)
    XCTAssertEqual(results[2].value, 0)
    
    XCTAssertEqual(terminations[3].index, 0)
    XCTAssertEqual(terminations[3].term, .completed)
    XCTAssertEqual(results[3].index, 3)
    XCTAssertEqual(results[3].value, 0)
  }
  
  func testRetryThenSuccess() {
    var completion: ((Result<Int>) -> Void)? = nil
    var results = [Int]()
    var preTerms = [Termination]()
    var terminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completion = onCompletion
    }
      .onTerminate{ preTerms.append($0) }
      .on{ results.append($0) }
      .retryOn{ _, error -> Bool in
        guard
          let error = error as? RetryError,
          case .retry = error
        else {
          return false
        }
        return true
      }
      .onTerminate{ terminations.append($0) }
    
    guard let completion1 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion1(.failure(RetryError.retry))
    
    XCTAssertEqual(results, [])
    XCTAssertEqual(preTerms, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(promise.state, .active)
    
    guard let completion2 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion2(.success(100))
    
    XCTAssertEqual(results, [100])
    XCTAssertEqual(preTerms, [.completed])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(promise.state, .terminated(reason: .completed))
  }
  
  func testRetryThenError() {
    var completion: ((Result<Int>) -> Void)? = nil
    var results = [Int]()
    var preTerms = [Termination]()
    var terminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completion = onCompletion
    }
      .onTerminate{ preTerms.append($0) }
      .on{ results.append($0) }
      .retryOn{ _, error -> Bool in
        guard
          let error = error as? RetryError,
          case .retry = error
        else {
          return false
        }
        return true
      }
      .onTerminate{ terminations.append($0) }
    
    guard let completion1 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion1(.failure(RetryError.retry))
    
    XCTAssertEqual(results, [])
    XCTAssertEqual(preTerms, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(promise.state, .active)
    
    guard let completion2 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion2(.failure(RetryError.noRetry))
    
    XCTAssertEqual(results, [])
    XCTAssertEqual(preTerms, [.error(RetryError.noRetry)])
    XCTAssertEqual(terminations, [.error(RetryError.noRetry)])
    XCTAssertEqual(promise.state, .terminated(reason: .error(RetryError.noRetry)))
  }
  
  func testAsyncRetryThenSuccess() {
    var completion: ((Result<Int>) -> Void)? = nil
    var onRetry: ((Bool) -> Void)? = nil
    var results = [Int]()
    var preTerms = [Termination]()
    var terminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completion = onCompletion
    }
      .onTerminate{ preTerms.append($0) }
      .on{ results.append($0) }
      .retryOn{ _, _, retry in
        onRetry = retry
      }
      .onTerminate{ terminations.append($0) }
    
    guard let completion1 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion1(.failure(RetryError.retry))
    
    XCTAssertNotNil(onRetry)
    XCTAssertEqual(results, [])
    XCTAssertEqual(preTerms, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(promise.state, .active)
    
    onRetry?(true)
    
    guard let completion2 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion2(.success(100))
    
    XCTAssertEqual(results, [100])
    XCTAssertEqual(preTerms, [.completed])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(promise.state, .terminated(reason: .completed))
  }
  
  func testAsyncRetryThenFailure() {
    var completion: ((Result<Int>) -> Void)? = nil
    var onRetry: ((Bool) -> Void)? = nil
    var results = [Int]()
    var preTerms = [Termination]()
    var terminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completion = onCompletion
    }
      .onTerminate{ preTerms.append($0) }
      .on{ results.append($0) }
      .retryOn{ _, _, retry in
        onRetry = retry
      }
      .onTerminate{ terminations.append($0) }
    
    guard let completion1 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion1(.failure(RetryError.retry))
    
    XCTAssertNotNil(onRetry)
    XCTAssertEqual(results, [])
    XCTAssertEqual(preTerms, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(promise.state, .active)
    
    onRetry?(true)
    
    guard let completion2 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    onRetry = nil
    
    completion2(.failure(RetryError.noRetry))
    XCTAssertNotNil(onRetry)
    
    onRetry?(false)
    
    XCTAssertEqual(results, [])
    XCTAssertEqual(preTerms, [.error(RetryError.noRetry)])
    XCTAssertEqual(terminations, [.error(RetryError.noRetry)])
    XCTAssertEqual(promise.state, .terminated(reason: .error(RetryError.noRetry)))
  }
  
  func testRetryLimitedFailure() {
    var completion: ((Result<Int>) -> Void)? = nil
    var results = [Int]()
    var preTerms = [Termination]()
    var terminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completion = onCompletion
    }
      .onTerminate{ preTerms.append($0) }
      .on{ results.append($0) }
      .retry(2)
      .onTerminate{ terminations.append($0) }
    
    guard let completion1 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion1(.failure(RetryError.retry))
    
    XCTAssertEqual(results, [])
    XCTAssertEqual(preTerms, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(promise.state, .active)
    
    guard let completion2 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion2(.failure(RetryError.retry))
    
    XCTAssertEqual(results, [])
    XCTAssertEqual(preTerms, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(promise.state, .active)
    guard let completion3 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion3(.failure(RetryError.noRetry))
    
    XCTAssertEqual(results, [])
    XCTAssertEqual(preTerms, [.error(RetryError.noRetry)])
    XCTAssertEqual(terminations, [.error(RetryError.noRetry)])
    XCTAssertEqual(promise.state, .terminated(reason: .error(RetryError.noRetry)))
  }
  
  func testRetryLimitedSuccess() {
    var completion: ((Result<Int>) -> Void)? = nil
    var results = [Int]()
    var preTerms = [Termination]()
    var terminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completion = onCompletion
    }
      .onTerminate{ preTerms.append($0) }
      .on{ results.append($0) }
      .retry(2)
      .onTerminate{ terminations.append($0) }
    
    guard let completion1 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion1(.failure(RetryError.retry))
    
    XCTAssertEqual(results, [])
    XCTAssertEqual(preTerms, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(promise.state, .active)
    
    guard let completion2 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion2(.failure(RetryError.retry))
    
    XCTAssertEqual(results, [])
    XCTAssertEqual(preTerms, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(promise.state, .active)
    guard let completion3 = completion else { return XCTFail("Expected task to be called, but it wasn't") }
    completion = nil
    
    completion3(.success(100))
    
    XCTAssertEqual(results, [100])
    XCTAssertEqual(preTerms, [.completed])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(promise.state, .terminated(reason: .completed))
  }
  
  func testCancel() {
    var completion: ((Result<Int>) -> Void)? = nil
    var results = [Int]()
    var terminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completion = onCompletion
    }
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0) }
    
    XCTAssertTrue(promise.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Promise task to be called") }
    
    promise.cancel()
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.cancelled])
    XCTAssertEqual(promise.state, .terminated(reason: .cancelled))
    
    completionTask(.success(0))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.cancelled])
    XCTAssertEqual(promise.state, .terminated(reason: .cancelled))
    
    completionTask(.failure(TestError()))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.cancelled])
    XCTAssertEqual(promise.state, .terminated(reason: .cancelled))
  }

  func testRetryReuse() {
    var completions = [((Result<Int>) -> Void)]()
    var results = [Int]()
    var errors = [Error]()
    var terminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completions.append(onCompletion)
    }

    promise
      .reuse()
      .resultMap{ _ in return .failure(TestError()) }
      .onError{ errors.append($0) }
      .retry(3)
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0)}

    XCTAssertEqual(completions.count, 1)
    XCTAssertEqual(errors.count, 0)
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(results, [])

    completions.last?(.success(10))
    XCTAssertEqual(completions.count, 1)
    XCTAssertEqual(errors.count, 4)
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(results, [])
  }

  func testCancelledRetry() {
    var completions = [((Result<Int>) -> Void)]()
    var results = [Int]()
    var errors = [Error]()
    var terminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completions.append(onCompletion)
    }

    promise
      .reuse()
      .resultMap{ _ in return .failure(TestError()) }
      .onError{ errors.append($0) }
      .retry(3)
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0)}

    XCTAssertEqual(completions.count, 1)
    XCTAssertEqual(errors.count, 0)
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(results, [])

    promise.cancel()
    XCTAssertEqual(completions.count, 1)
    XCTAssertEqual(errors.count, 0)
    XCTAssertEqual(terminations, [.cancelled])
    XCTAssertEqual(results, [])

    promise.retry()
    XCTAssertEqual(completions.count, 1)
    XCTAssertEqual(errors.count, 0)
    XCTAssertEqual(terminations, [.cancelled])
    XCTAssertEqual(results, [])
  }

  func testAutoRetry() {
    var completion: ((Result<Int>) -> Void)? = nil
    var results = [Int]()
    var terminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completion = onCompletion
    }

    guard let completionTask = completion else {
      return XCTFail("Expected the Promise task to be called")
    }

    completionTask(.success(0))

    promise
      .on { results.append($0) }
      .onTerminate { terminations.append($0) }

    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(promise.state, .terminated(reason: .completed))

    wait(for: 0.1)

    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(promise.state, .terminated(reason: .completed))
  }

  func testMultiBranchAutoRetry() {
    var completion: ((Result<Int>) -> Void)? = nil
    var aResults = [Int]()
    var aTerminations = [Termination]()
    var bResults = [Int]()
    var bTerminations = [Termination]()
    let promise = Promise<Int> { _, onCompletion in
      completion = onCompletion
    }

    guard let completionTask = completion else {
      return XCTFail("Expected the Promise task to be called")
    }

    completionTask(.success(0))

    promise
      .on { aResults.append($0) }
      .onTerminate { aTerminations.append($0) }

    promise
      .on { bResults.append($0) }
      .onTerminate { bTerminations.append($0) }

    XCTAssertEqual(aResults, [])
    XCTAssertEqual(aTerminations, [])
    XCTAssertEqual(bResults, [])
    XCTAssertEqual(bTerminations, [])
    XCTAssertEqual(promise.state, .terminated(reason: .completed))

    wait(for: 0.1)

    XCTAssertEqual(aResults, [0])
    XCTAssertEqual(aTerminations, [.completed])
    XCTAssertEqual(bResults, [0])
    XCTAssertEqual(bTerminations, [.completed])
    XCTAssertEqual(promise.state, .terminated(reason: .completed))
  }
  
  func testPromiseCleanup() {
    let future: Promise<Int> = Promise { (_, result) in result(.success(1)) }
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
