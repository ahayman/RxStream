//
//  PromiseTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/22/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
import Rx

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
    
    completionTask(.failure(NSError()))
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
    
    completionTask(.failure(NSError()))
    
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(NSError())])
    XCTAssertEqual(promise.state, .terminated(reason: .error(NSError())))
    
    completionTask(.success(1))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(NSError())])
    XCTAssertEqual(promise.state, .terminated(reason: .error(NSError())))
    
    completionTask(.success(2))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(NSError())])
    XCTAssertEqual(promise.state, .terminated(reason: .error(NSError())))
    
    completionTask(.failure(NSError()))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(NSError())])
    XCTAssertEqual(promise.state, .terminated(reason: .error(NSError())))
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
      .retryOn{ error -> Bool in
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
      .retryOn{ error -> Bool in
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
      .retryOn{ _, retry in
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
      .retryOn{ _, retry in
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
    
    completionTask(.failure(NSError()))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.cancelled])
    XCTAssertEqual(promise.state, .terminated(reason: .cancelled))
  }
  
}
