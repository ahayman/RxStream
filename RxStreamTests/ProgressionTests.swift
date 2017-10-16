//
//  ProgressTests.swift
//  RxStream iOS
//
//  Created by Aaron Hayman on 9/29/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

class ProgressionTests : XCTestCase {

  func testCompletion() {
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)? = nil
    var results = [Int]()
    var terminations = [Termination]()
    let progress = Progression<Double, Int> { cancelled, onCompletion in
      completion = onCompletion
    }
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0) }

    XCTAssertTrue(progress.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Future task to be called") }

    completionTask(.right(.success(0)))

    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(progress.state, .terminated(reason: .completed))

    completionTask(.right(.success(1)))
    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(progress.state, .terminated(reason: .completed))
  }

  func testError() {
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)? = nil
    var results = [Int]()
    var terminations = [Termination]()
    let progress = Progression<Double, Int> { cancelled, onCompletion in
        completion = onCompletion
    }
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0) }

    XCTAssertTrue(progress.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Future task to be called") }

    completionTask(.right(.failure(TestError())))

    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(progress.state, .terminated(reason: .error(TestError())))

    completionTask(.right(.success(1)))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(progress.state, .terminated(reason: .error(TestError())))

    completionTask(.right(.success(2)))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(progress.state, .terminated(reason: .error(TestError())))

    completionTask(.right(.failure(TestError())))
    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(progress.state, .terminated(reason: .error(TestError())))
  }
  
  func testInputValue() {
    var result = [String]()
    var terminations = [Termination]()
    var progressEvents = [Int]()
    let progress = ProgressionInput<Int, String>()
    
    progress
      .on{ result.append($0) }
      .onTerminate{ terminations.append($0) }
      .onProgress{ progressEvents.append($0.current) }
    
    XCTAssertEqual(result, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(progressEvents, [])
    
    progress.complete("Hello")
    XCTAssertEqual(result, ["Hello"])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(progressEvents, [])
    
    progress.complete("World")
    XCTAssertEqual(result, ["Hello"])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(progressEvents, [])
  }
  
  func testInputError() {
    var result = [String]()
    var terminations = [Termination]()
    var progressEvents = [Int]()
    let progress = ProgressionInput<Int, String>()
    
    progress
      .on{ result.append($0) }
      .onTerminate{ terminations.append($0) }
      .onProgress{ progressEvents.append($0.current) }
    
    XCTAssertEqual(result, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(progressEvents, [])
    
    progress.complete(TestError())
    XCTAssertEqual(result, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(progressEvents, [])
    
    progress.complete("World")
    XCTAssertEqual(result, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(progressEvents, [])
  }
  
  func testInputProgress() {
    var result = [String]()
    var terminations = [Termination]()
    var progressEvents = [Int]()
    let progress = ProgressionInput<Int, String>()
    
    progress
      .on{ result.append($0) }
      .onTerminate{ terminations.append($0) }
      .onProgress{ progressEvents.append($0.current) }
    
    XCTAssertEqual(result, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(progressEvents, [])
    
    var currentProgress = ProgressEvent(title: "Progress", unit: "int", current: 0, total: 100)
    progress.updateProgress(to: currentProgress)
    XCTAssertEqual(result, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(progressEvents, [0])
    
    currentProgress.current = 50
    progress.updateProgress(to: currentProgress)
    XCTAssertEqual(result, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(progressEvents, [0, 50])
    
    currentProgress.current = 100
    progress.updateProgress(to: currentProgress)
    XCTAssertEqual(result, [])
    XCTAssertEqual(terminations, [])
    XCTAssertEqual(progressEvents, [0, 50, 100])

    progress.complete("Hello")
    XCTAssertEqual(result, ["Hello"])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(progressEvents, [0, 50, 100])

    progress.complete("World")
    XCTAssertEqual(result, ["Hello"])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(progressEvents, [0, 50, 100])
  }
  
  func testCompletedValue() {
    var result = [String]()
    var terminations = [Termination]()
    var progressEvents = [Int]()
    let progress: Progression<Int, String> = Progression<Int, String>.completed("Hello")
    
    progress
      .on{ result.append($0) }
      .onTerminate{ terminations.append($0) }
      .onProgress{ progressEvents.append($0.current) }
      .replay()
    
    XCTAssertEqual(result, ["Hello"])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(progressEvents, [])
  }
  
  func testCompletedError() {
    var result = [String]()
    var terminations = [Termination]()
    var progressEvents = [Int]()
    let progress: Progression<Int, String> = Progression<Int, String>.completed(TestError())
    
    progress
      .on{ result.append($0) }
      .onTerminate{ terminations.append($0) }
      .onProgress{ progressEvents.append($0.current) }
      .replay()
    
    XCTAssertEqual(result, [])
    XCTAssertEqual(terminations, [.error(TestError())])
    XCTAssertEqual(progressEvents, [])
  }
  
  func testProgress() {
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)? = nil
    var results = [Int]()
    var progressEvents = [Double]()
    let total = 100.0
    let title = "Test Progression"
    let unit = "%"

    func validateProgress(event: ProgressEvent<Double>) -> Bool {
      return event.total == total && event.title == title && event.unit == unit
    }
    var terminations = [Termination]()
    let progress = Progression<Double, Int> { cancelled, onCompletion in
        completion = onCompletion
      }
      .onProgress {
        progressEvents.append($0.current)
        XCTAssertTrue(validateProgress(event: $0))
      }
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0) }

    XCTAssertTrue(progress.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Future task to be called") }

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 0.1, total: total)))
    XCTAssertEqual(progressEvents, [0.1])

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 50.0, total: total)))
    XCTAssertEqual(progressEvents, [0.1, 50.0])

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 75.2, total: total)))
    XCTAssertEqual(progressEvents, [0.1, 50.0, 75.2])

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 100.0, total: total)))
    XCTAssertEqual(progressEvents, [0.1, 50.0, 75.2, 100.0])

    completionTask(.right(.success(0)))

    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(progress.state, .terminated(reason: .completed))

    completionTask(.right(.success(1)))
    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(progress.state, .terminated(reason: .completed))

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 100.0, total: total)))
    XCTAssertEqual(progressEvents, [0.1, 50.0, 75.2, 100.0])
  }

  func testProgressThrottle() {
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)? = nil
    var results = [Int]()
    var progressEvents = [Double]()
    let total = 100.0
    let title = "Test Progression"
    let unit = "%"

    func validateProgress(event: ProgressEvent<Double>) -> Bool {
      return event.total == total && event.title == title && event.unit == unit
    }
    var terminations = [Termination]()
    let progress = Progression<Double, Int> { cancelled, onCompletion in
        completion = onCompletion
      }
      .throttle(TimedThrottle(interval: 1.0, delayFirst: false))
      .onProgress {
        progressEvents.append($0.current)
        XCTAssertTrue(validateProgress(event: $0))
      }
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0) }

    XCTAssertTrue(progress.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Future task to be called") }

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 10.0, total: total)))
    XCTAssertEqual(progressEvents, [10.0])

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 50.0, total: total)))
    XCTAssertEqual(progressEvents, [10.0])

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 75.2, total: total)))
    XCTAssertEqual(progressEvents, [10.0])

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 100.0, total: total)))
    XCTAssertEqual(progressEvents, [10.0])

    completionTask(.right(.success(0)))

    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(progress.state, .terminated(reason: .completed))

    completionTask(.right(.success(1)))
    XCTAssertEqual(results, [0])
    XCTAssertEqual(terminations, [.completed])
    XCTAssertEqual(progress.state, .terminated(reason: .completed))

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 100.0, total: total)))
    XCTAssertEqual(progressEvents, [10.0])
  }

  func testProgressDispatch() {
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)? = nil
    var results = [Int]()
    var progressEvents = [Double]()
    let total = 100.0
    let title = "Test Progression"
    let unit = "%"

    func validateProgress(event: ProgressEvent<Double>) -> Bool {
      return event.total == total && event.title == title && event.unit == unit
    }
    var terminations = [Termination]()
    let expectProgress = expectation(description: "Progression Event Received")
    let progress = Progression<Double, Int> { cancelled, onCompletion in
        completion = onCompletion
      }
      .dispatch(.async(on: .background))
      .onProgress {
        XCTAssertFalse(Thread.isMainThread)
        progressEvents.append($0.current)
        XCTAssertTrue(validateProgress(event: $0))
        expectProgress.fulfill()
      }
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0) }

    XCTAssertTrue(progress.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Future task to be called") }

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 10.0, total: total)))
    wait(for: [expectProgress], timeout: 5.0)
    XCTAssertEqual(progressEvents, [10.0])
  }

  func testProgressCancel() {
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)? = nil
    var results = [Int]()
    var progressEvents = [Double]()
    var cancelled = Box(false)
    let total = 100.0
    let title = "Test Progression"
    let unit = "%"

    func validateProgress(event: ProgressEvent<Double>) -> Bool {
      return event.total == total && event.title == title && event.unit == unit
    }
    var terminations = [Termination]()
    let progress = Progression<Double, Int> { isCancelled, onCompletion in
      completion = onCompletion
      cancelled = isCancelled
    }
      .onProgress {
        progressEvents.append($0.current)
        XCTAssertTrue(validateProgress(event: $0))
      }
      .on{ results.append($0) }
      .onTerminate{ terminations.append($0) }

    XCTAssertTrue(progress.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Future task to be called") }

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 0.1, total: total)))
    XCTAssertEqual(progressEvents, [0.1])
    XCTAssertFalse(cancelled.value)

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 50.0, total: total)))
    XCTAssertEqual(progressEvents, [0.1, 50.0])
    XCTAssertFalse(cancelled.value)

    progress.cancel()

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 75.2, total: total)))
    XCTAssertEqual(progressEvents, [0.1, 50.0])
    XCTAssertTrue(cancelled.value)

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 100.0, total: total)))
    XCTAssertEqual(progressEvents, [0.1, 50.0])

    completionTask(.right(.success(0)))

    XCTAssertEqual(results, [])
    XCTAssertEqual(terminations, [.cancelled])
    XCTAssertEqual(progress.state, .terminated(reason: .cancelled))

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 100.0, total: total)))
    XCTAssertEqual(progressEvents, [0.1, 50.0])
  }

}

