//
//  PromiseOperationsTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 4/12/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

private class TestClass { }

class PromiseOperationsTests: XCTestCase {

  func testOn() {
    var value: Int? = nil
    var onCount = 0
    let promise = Promise<Int>{ _, result in result(.success(0)) }
    
    promise.on {
      value = $0
      onCount += 1
    }
    
    XCTAssertEqual(value, 0)
    XCTAssertEqual(onCount, 1)
  }
  
  func testOnTermination() {
    var terminations = [Termination]()
    let promise = Promise<Int>{ _, result in result(.success(0)) }
    
    promise.onTerminate{
      terminations.append($0)
    }
    
    XCTAssertEqual(terminations.count, 1, "The promise should only terminate once.")
  }
  
  func testMap() {
    var mapped: String? = nil
    var mapCount = 0
    var onCount = 0
    let promise = Promise<Int>{ _, result in result(.success(0)) }
    
    promise
      .map{ value -> String? in
        mapCount += 1
        if value == 3 {
          return nil
        }
        return "\(value)"
      }
      .on{
        onCount += 1
        mapped = $0
    }
    
    XCTAssertEqual(mapped, "0")
    XCTAssertEqual(mapCount, 1)
    XCTAssertEqual(onCount, 1)
  }
  
  func testMapResult() {
    var mapped: [String] = []
    var error: Error? = nil
    let promise = Promise<Int>{ _, result in result(.success(0)) }
    
    promise
      .resultMap{ return .success("\($0)") }
      .on{ mapped.append($0) }
      .onError{ error = $0 }

    XCTAssertEqual(mapped, ["0"])
    XCTAssertNil(error)
  }
  
  func testAsyncMap() {
    var mapped: String? = nil
    var mapCount = 0
    var onCount = 0
    var error: Error?
    var nextMap: (value: Int, callback: (Result<String>) -> Void)? = nil
    let promise = Promise<Int>{ _, result in result(.success(0)) }
    
    promise
      .asyncMap { (value: Int, completion: @escaping (Result<String>) -> Void) in
        mapCount += 1
        nextMap = (value, completion)
      }
      .on {
        mapped = $0
        onCount += 1
      }
      .onError{ error = $0 }
    
    XCTAssertEqual(mapCount, 1)
    XCTAssertEqual(onCount, 0)
    XCTAssertNil(mapped)
    guard let mapper = nextMap else { return XCTFail("Mapper was never set") }
    mapper.callback(.success("\(mapper.value)"))
    XCTAssertEqual(onCount, 1)
    XCTAssertEqual(mapped, "0")
    XCTAssertNil(error)
  }
  
  func testFlatMap() {
    var mapped = [String]()
    let promise = Promise<String> { _, result in result(.success("Test a multitude of words in a sentence.")) }
    
    promise
      .flatMap { $0.components(separatedBy: " ") }
      .on { mapped.append($0) }
    
    guard mapped.count == 8 else { return XCTFail("Didn't receive expected mapped output count. Expected 8, received \(mapped.count)") }
    XCTAssertEqual(mapped[0], "Test")
    XCTAssertEqual(mapped[1], "a")
    XCTAssertEqual(mapped[2], "multitude")
    XCTAssertEqual(mapped[3], "of")
    XCTAssertEqual(mapped[4], "words")
    XCTAssertEqual(mapped[5], "in")
    XCTAssertEqual(mapped[6], "a")
    XCTAssertEqual(mapped[7], "sentence.")
  }
  
  func testFlatten() {
    var mapped = [Int]()
    let promise = Promise<[Int]> { _, result in result(.success([0, 1, 2, 3, 4])) }
    
    promise
      .flatten()
      .on { mapped.append($0) }
    
    guard mapped.count == 5 else { return XCTFail("Didn't receive expected mapped output count. Expected 5, received \(mapped.count)") }
    for i in 0..<5 {
      XCTAssertEqual(mapped[i], i)
    }
  }
  
  func testFilter() {
    var values = [String]()
    let promise = Promise<String>{ _, result in result(.success("hello")) }
    
    promise
      .filter { !$0.contains("a") } //Filter out strings that contain a
      .on{ values.append($0) }
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, "hello")
  }
  
  func testFiltered() {
    var values = [String]()
    let promise = Promise<String>{ _, result in result(.success("apple")) }
    
    promise
      .filter { !$0.contains("a") } //Filter out strings that contain a
      .on{ values.append($0) }
    
    XCTAssertEqual(values.count, 0)
  }
  
  func testStamp() {
    var values = [(Int, String)]()
    let promise = Promise<Int>{ _, result in result(.success(0)) }
    
    promise.stamp{ "\($0)" }.on{ values.append($0) }
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.0, 0)
    XCTAssertEqual(values.last?.1, "0")
  }
  
  func testTimeStamp() {
    var values = [(Int, Date)]()
    let promise = Promise<Int>{ _, result in result(.success(0)) }
    
    promise.timeStamp().on{ values.append($0) }
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.0, 0)
    XCTAssertEqualWithAccuracy(values.last?.1.timeIntervalSinceReferenceDate ?? 0, Date.timeIntervalSinceReferenceDate, accuracy: 0.5)
  }
  
  func testDelay() {
    var values = [Int]()
    let promise = Promise<Int>{ _, result in result(.success(0)) }
    
    promise.delay(0.01).on{ values.append($0) }
    
    XCTAssertEqual(values.count, 0)
    
    wait(for: 0.1)
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 0)
  }
  
  func testStart() {
    var values = [Int]()
    let promise = Promise<Int>{ _, result in result(.success(0)) }
    
    promise
      .start(with: [-3, -2, -1])
      .on{ values.append($0) }
    
    XCTAssertEqual(values, [-3, -2, -1, 0])
  }
  
  func testFilledConcat() {
    var values = [Int]()
    let promise = Promise<Int>{ _, result in result(.success(0)) }
    
    promise
      .concat([98, 99, 100])
      .on{ values.append($0) }
    
    XCTAssertEqual(values, [0, 98, 99, 100])
  }
  
  func testConcat() {
    var values = [Int]()
    var completion: ((Result<Int>) -> Void)?
    let promise = Promise<Int>{ _, result in completion = result }
    
    promise
      .concat([98, 99, 100])
      .on{ values.append($0) }
    
    completion?(.success(0))
    
    XCTAssertEqual(values, [0, 98, 99, 100])
  }
  
  func testDefaultValue() {
    var values = [Int]()
    var promise = Promise<Int>{ _, result in result(.failure(TestError())) }
    
    promise
      .defaultValue(0)
      .on{ values.append($0) }
    
    XCTAssertEqual(values, [0])
    
    promise = Promise<Int>{ _, result in result(.success(1)) }
    values = []
    
    promise.defaultValue(0).on{ values.append($0) }
    
    XCTAssertEqual(values, [1])
  }
  
  func testMerge() {
    var values = [Either<Int, String>]()
    var completion: ((Result<Int>) -> Void)?
    let left = Promise<Int>{ _, result in completion = result }
    let right = HotInput<String>()
    var term: Termination? = nil
    var error: Error? = nil

    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .onError{ error = $0 }
    
    completion?(.success(1))
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)

    XCTAssertNil(error)
    XCTAssertEqual(term, .completed)
  }

  func testMergeIntoHotWithSameType() {
    var values = [Int]()
    let right = Promise<Int>{ _, result in result(.success(0)) }
    let left = HotInput<Int>()
    var term: Termination? = nil

    left
      .merge(right).replayNext()
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    XCTAssertEqual(values, [0])
    XCTAssertNil(term)

    left.push(1)
    XCTAssertEqual(values, [0, 1])
    XCTAssertNil(term)

    left.push(2)
    XCTAssertEqual(values, [0, 1, 2])
    XCTAssertNil(term)

    left.terminate(withReason: .completed)
    XCTAssertEqual(values, [0, 1, 2])
    XCTAssertEqual(term, .completed)
  }
  
  func testMergeHotWithSameType() {
    var values = [Int]()
    let left = Promise<Int>{ _, result in result(.success(0)) }
    let right = HotInput<Int>()
    var term: Termination? = nil
    
    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    XCTAssertEqual(values, [0])
    XCTAssertEqual(term, .completed)

    right.push(1)
    XCTAssertEqual(values, [0])
    XCTAssertEqual(term, .completed)

    right.terminate(withReason: .completed)
    XCTAssertEqual(values, [0])
    XCTAssertEqual(term, .completed)
  }
  
  func testMergeWithTwoCompletedPromises() {
    var values = [Int]()
    let left = Promise<Int>{ _, result in result(.success(0)) }
    let right = Promise<Int>{ _, result in result(.success(1)) }
    var term: Termination? = nil
    
    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    XCTAssertEqual(values, [0], "Both terms are emitted, but only the left term emitted is replayed.")
    XCTAssertEqual(term, .completed)
  }
  
  func testMergeWithLeftCompletedPromise() {
    var values = [Int]()
    var completion: ((Result<Int>) -> Void)?
    let left = Promise<Int>{ _, result in result(.success(0)) }
    let right = Promise<Int>{ _, result in completion = result }
    var term: Termination? = nil
    
    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    XCTAssertEqual(values, [0], "Left Completed should replay.")
    XCTAssertEqual(term, .completed)

    completion?(.success(1))
    
    XCTAssertEqual(values, [0], "Right Promise will emit, but downstream promise is completed.")
    XCTAssertEqual(term, .completed)
  }
  
  func testMergeWithRightCompletedPromise() {
    var values = [Int]()
    var completion: ((Result<Int>) -> Void)?
    let left = Promise<Int>{ _, result in completion = result }
    let right = Promise<Int>{ _, result in result(.success(0)) }
    var term: Termination? = nil
    
    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    XCTAssertEqual(values, [0], "Right Completed should replay.")
    XCTAssertEqual(term, .completed)

    completion?(.success(1))
    
    XCTAssertEqual(values, [0], "Left Promise will emit, but down stream promise is completed.")
    XCTAssertEqual(term, .completed)
  }
  
  func testZipBothPromiseCompleted() {
    var values = [(left: Int, right: String)]()
    let left = Promise<Int>{ _, result in result(.success(1)) }
    let right = Promise<String>{ _, result in result(.success("one")) }
    var term: Termination? = nil
    
    left
      .zip(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    XCTAssertEqual(term, .completed)
  }
  
  func testZipLeftPromiseCompleted() {
    var values = [(left: Int, right: String)]()
    var completion: ((Result<String>) -> Void)?
    let left = Promise<Int>{ _, result in result(.success(1)) }
    let right = Promise<String>{ _, result in completion = result }
    var term: Termination? = nil
    
    left
      .zip(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    XCTAssertEqual(values.count, 0)
    
    completion?(.success("one"))
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    XCTAssertEqual(term, .completed)
  }
  
  func testZipRightPromiseCompleted() {
    var values = [(left: Int, right: String)]()
    var completion: ((Result<Int>) -> Void)?
    let left = Promise<Int>{ _, result in completion = result }
    let right = Promise<String>{ _, result in result(.success("one")) }
    var term: Termination? = nil
    
    left
      .zip(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    XCTAssertEqual(values.count, 0)
    
    completion?(.success(1))
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    XCTAssertEqual(term, .completed)
  }
  
  func testCombine() {
    var values = [(left: Int, right: String)]()
    let left = Promise<Int>{ _, result in result(.success(1)) }
    let right = HotInput<String>()
    var term: Termination? = nil
    
    left
      .combine(stream: right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    right.push("one")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    
    right.push("two")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    
    right.terminate(withReason: .completed)
    XCTAssertEqual(term, .completed)
  }
  
  func testLifeOf() {
    var values = [Int]()
    var completion: ((Result<Int>) -> Void)?
    let promise = Promise<Int>{ _, result in completion = result }
    var term: Termination? = nil
    var object: TestClass? = TestClass()
    
    promise
      .lifeOf(object!)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    XCTAssertNotNil(completion)
    object = nil
    
    wait(for: 0.1) // Allow the object to deinit
    
    completion?(.success(1))
    XCTAssertEqual(values, [])
    XCTAssertEqual(term, .cancelled)
  }
    
}
