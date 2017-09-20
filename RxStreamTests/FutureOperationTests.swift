//
//  FutureOperationTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 4/5/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest

import XCTest
@testable import Rx

private class TestClass { }

class FutureOperationsTests: XCTestCase {
  
  func testOn() {
    var value: Int? = nil
    var onCount = 0
    let future = Future<Int>{ $0(.success(0)) }
    
    future
      .on {
        value = $0
        onCount += 1
      }
      .replay()
    
    XCTAssertEqual(value, 0)
    XCTAssertEqual(onCount, 1)
  }
  
  func testOnTermination() {
    var terminations = [Termination]()
    let future = Future<Int>{ $0(.success(0)) }
    
    future
      .onTerminate{ terminations.append($0) }
      .replay()
    
    XCTAssertEqual(terminations.count, 1, "The future should only terminate once.")
  }
  
  func testMap() {
    var mapped: String? = nil
    var mapCount = 0
    var onCount = 0
    let future = Future<Int>{ $0(.success(0)) }
    
    future
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
      .replay()
    
    XCTAssertEqual(mapped, "0")
    XCTAssertEqual(mapCount, 1)
    XCTAssertEqual(onCount, 1)
  }
  
  func testMapResult() {
    var mapped: [String] = []
    var error: Error? = nil
    let future = Future<Int>{ $0(.success(0)) }
    
    future
      .resultMap{ return .success("\($0)") }
      .on{ mapped.append($0) }
      .onError{ error = $0 }
      .replay()
    
    XCTAssertEqual(mapped, ["0"])
    XCTAssertNil(error)
  }
  
  func testAsyncMap() {
    var mapped: String? = nil
    var mapCount = 0
    var onCount = 0
    var error: Error?
    var nextMap: (value: Int, callback: (Result<String>) -> Void)? = nil
    let future = Future<Int>{ $0(.success(0)) }
    
    future
      .asyncMap { (value: Int, completion: @escaping (Result<String>) -> Void) in
        mapCount += 1
        nextMap = (value, completion)
      }
      .on {
        mapped = $0
        onCount += 1
      }
      .onError{ error = $0 }
      .replay()
    
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
    let future = Future<String> { $0(.success("Test a multitude of words in a sentence.")) }
    
    future
      .flatMap { $0.components(separatedBy: " ") }
      .on { mapped.append($0) }
      .replay()
    
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
    let future = Future<[Int]> { $0(.success([0, 1, 2, 3, 4])) }
    
    future
      .flatten()
      .on { mapped.append($0) }
      .replay()

    guard mapped.count == 5 else { return XCTFail("Didn't receive expected mapped output count. Expected 5, received \(mapped.count)") }
    for i in 0..<5 {
      XCTAssertEqual(mapped[i], i)
    }
  }
  
  func testFilter() {
    var values = [String]()
    let future = Future<String>{ $0(.success("hello")) }
    
    future
      .filter { !$0.contains("a") } //Filter out strings that contain a
      .on{ values.append($0) }
      .replay()
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, "hello")
  }
  
  func testFiltered() {
    var values = [String]()
    let future = Future<String>{ $0(.success("apple")) }
    
    future
      .filter { !$0.contains("a") } //Filter out strings that contain a
      .on{ values.append($0) }
      .replay()

    XCTAssertEqual(values.count, 0)
  }
  
  func testStamp() {
    var values = [(Int, String)]()
    let future = Future<Int>{ $0(.success(0)) }
    
    future
      .stamp{ "\($0)" }
      .on{ values.append($0) }
      .replay()
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.0, 0)
    XCTAssertEqual(values.last?.1, "0")
  }
  
  func testTimeStamp() {
    var values = [(Int, Date)]()
    let future = Future<Int>{ $0(.success(0)) }
    
    future
      .timeStamp()
      .on{ values.append($0) }
      .replay()
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.0, 0)
    XCTAssertEqual(values.last?.1.timeIntervalSinceReferenceDate ?? 0, Date.timeIntervalSinceReferenceDate, accuracy: 0.5)
  }
  
  func testDelay() {
    var values = [Int]()
    let future = Future<Int>{ $0(.success(0)) }
    
    future
      .delay(0.01)
      .on{ values.append($0) }
      .replay()
    
    XCTAssertEqual(values.count, 0)
    
    wait(for: 0.1)
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 0)
  }
  
  func testStart() {
    var values = [Int]()
    let future = Future<Int>{ $0(.success(0)) }
    
    future
      .start(with: [-3, -2, -1])
      .on{ values.append($0) }
      .replay()
    
    XCTAssertEqual(values, [-3, -2, -1, 0])
  }
  
  func testFilledConcat() {
    var values = [Int]()
    let future = Future<Int>{ $0(.success(0)) }
    
    future
      .concat([98, 99, 100])
      .on{ values.append($0) }
      .replay()
    
    XCTAssertEqual(values, [0, 98, 99, 100])
  }
  
  func testConcat() {
    var values = [Int]()
    var completion: ((Result<Int>) -> Void)?
    let future = Future<Int>{ completion = $0 }
    
    future
      .concat([98, 99, 100])
      .on{ values.append($0) }
    
    completion?(.success(0))
    
    XCTAssertEqual(values, [0, 98, 99, 100])
  }
  
  func testDefaultValue() {
    var values = [Int]()
    var future = Future<Int>{ $0(.failure(TestError())) }
    
    future
      .defaultValue(0)
      .on{ values.append($0) }
      .replay()
    
    XCTAssertEqual(values, [0])
    
    future = Future<Int>{ $0(.success(1)) }
    values = []
    
    future
      .defaultValue(0)
      .on{ values.append($0) }
      .replay()
    
    XCTAssertEqual(values, [1])
  }

  func testFutureIntoHotMerge() {
    var values = [Either<String, Int>]()
    var completion: ((Result<Int>) -> Void)?
    let right = Future<Int>{ completion = $0 }
    let left = HotInput<String>()
    var term: Termination? = nil
    var error: Error? = nil

    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .onError{ error = $0 }

    completion?(.success(1))
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.right, 1)

    left.push("first")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, "first")

    left.push("second")
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last?.left, "second")

    XCTAssertNil(term)
    XCTAssertNil(error)

    left.push("third")
    XCTAssertEqual(values.count, 4)
    XCTAssertEqual(values.last?.left, "third")

    left.terminate(withReason: .completed)
    XCTAssertEqual(values.count, 4)

    left.push("fourth")
    XCTAssertEqual(values.count, 4)

    XCTAssertEqual(term, .completed)  }

  func testMerge() {
    var values = [Either<Int, String>]()
    var completion: ((Result<Int>) -> Void)?
    let left = Future<Int>{ completion = $0 }
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
    
    right.push("first")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(term, .completed)

    right.terminate(withReason: .completed)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(term, .completed)
    XCTAssertNil(error)
  }
  
  func testMergeWithSameType() {
    var values = [Int]()
    let left = Future<Int>{ $0(.success(0)) }
    let right = HotInput<Int>()
    var term: Termination? = nil
    
    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()

    XCTAssertEqual(values, [0])
    XCTAssertEqual(term, .completed)

    right.push(1)
    XCTAssertEqual(values, [0])
    XCTAssertEqual(term, .completed)

    right.terminate(withReason: .cancelled)
    XCTAssertEqual(values, [0])
    XCTAssertEqual(term, .completed)
  }

  func testMergeWithTwoCompletedFutures() {
    var values = [Int]()
    let left = Future<Int>{ $0(.success(0)) }
    let right = Future<Int>{ $0(.success(1)) }
    var term: Termination? = nil

    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()

    XCTAssertEqual(values, [0], "Both terms are emitted, but only the last term emitted is replayed.")
    XCTAssertEqual(term, .completed)
  }

  func testMergeWithLeftCompletedFuture() {
    var values = [Int]()
    var completion: ((Result<Int>) -> Void)?
    let left = Future<Int>{ $0(.success(0)) }
    let right = Future<Int>{ completion = $0 }
    var term: Termination? = nil

    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()

    XCTAssertEqual(values, [0], "Left Completed should replay.")
    XCTAssertEqual(term, .completed)

    completion?(.success(1))

    XCTAssertEqual(values, [0])
    XCTAssertEqual(term, .completed)
  }

  func testMergeWithRightCompletedFuture() {
    var values = [Int]()
    var completion: ((Result<Int>) -> Void)?
    let left = Future<Int>{ completion = $0 }
    let right = Future<Int>{ $0(.success(0)) }
    var term: Termination? = nil

    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()

    XCTAssertEqual(values, [0], "Right Completed should replay.")
    XCTAssertEqual(term, .completed)

    completion?(.success(1))

    XCTAssertEqual(values, [0])
    XCTAssertEqual(term, .completed)
  }

  func testZipBothFutureCompleted() {
    var values = [(left: Int, right: String)]()
    let left = Future<Int>{ $0(.success(1)) }
    let right = Future<String>{ $0(.success("one")) }
    var term: Termination? = nil
    
    left
      .zip(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    XCTAssertEqual(term, .completed)
  }

  func testZipLeftFutureCompleted() {
    var values = [(left: Int, right: String)]()
    var completion: ((Result<String>) -> Void)?
    let left = Future<Int>{ $0(.success(1)) }
    let right = Future<String>{ completion = $0 }
    var term: Termination? = nil

    left
      .zip(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()

    XCTAssertEqual(values.count, 0)

    completion?(.success("one"))

    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    XCTAssertEqual(term, .completed)
  }

  func testZipRightFutureCompleted() {
    var values = [(left: Int, right: String)]()
    var completion: ((Result<Int>) -> Void)?
    let left = Future<Int>{ completion = $0 }
    let right = Future<String>{ $0(.success("one")) }
    var term: Termination? = nil

    left
      .zip(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()

    XCTAssertEqual(values.count, 0)

    completion?(.success(1))

    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    XCTAssertEqual(term, .completed)
  }

  func testCombine() {
    var values = [(left: Int, right: String)]()
    let left = Future<Int>{ $0(.success(1)) }
    let right = HotInput<String>()
    var term: Termination? = nil
    
    left
      .combine(stream: right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()

    right.push("one")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    XCTAssertEqual(term, .completed)

    right.push("two")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    XCTAssertEqual(term, .completed)

    right.terminate(withReason: .completed)
    XCTAssertEqual(term, .completed)
  }

  func testWhile() {
    var values = [Int]()
    let stream = FutureInput<Int>()
    var term: Termination? = nil

    stream
      .doWhile{ $0 < 10 }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    stream.complete(10)
    XCTAssertEqual(values, [])
    XCTAssertEqual(term, .cancelled)
  }

  func testWhileCompleted() {
    var values = [Int]()
    let stream = FutureInput<Int>()
    var term: Termination? = nil

    stream
      .doWhile{ $0 < 10 }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    stream.complete(9)
    XCTAssertEqual(values, [9])
    XCTAssertEqual(term, .completed)
  }

  func testUntil() {
    var values = [Int]()
    let stream = FutureInput<Int>()
    var term: Termination? = nil

    stream
      .until{ $0 == 10 }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    stream.complete(10)
    XCTAssertEqual(values, [])
    XCTAssertEqual(term, .cancelled)
  }

  func testUntilCompleted() {
    var values = [Int]()
    let stream = FutureInput<Int>()
    var term: Termination? = nil

    stream
      .until{ $0 == 10 }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    stream.complete(9)
    XCTAssertEqual(values, [9])
    XCTAssertEqual(term, .completed)
  }

  func testUntilTermination(){
    var values = [Int]()
    let stream = FutureInput<Int>()
    var term: Termination? = nil

    stream
      .until{ value -> Termination? in
        return value == 10 ? .cancelled : nil
      }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    stream.complete(10)
    XCTAssertEqual(values, [])

    XCTAssertEqual(term, .cancelled)
  }

  func testUsing() {
    var values = [Int]()
    let stream = FutureInput<Int>()
    var term: Termination? = nil
    var object: TestClass? = TestClass()

    stream
      .using(object!)
      .on{ values.append($0.1) }
      .onTerminate{ term = $0 }

    object = nil

    wait(for: 0.1) // Allow the object to deinit

    stream.complete(1)
    XCTAssertEqual(values, [])
    XCTAssertEqual(term, .cancelled)
  }

  func testUsingComplete() {
    var values = [Int]()
    let stream = FutureInput<Int>()
    var term: Termination? = nil
    var object: TestClass? = TestClass()

    stream
      .using(object!)
      .on{ values.append($0.1) }
      .onTerminate{ term = $0 }

    stream.complete(1)
    object = nil

    wait(for: 0.1) // Allow the object to deinit

    XCTAssertEqual(values, [1])
    XCTAssertEqual(term, .completed)
  }

  func testLifeOf() {
    var values = [Int]()
    var completion: ((Result<Int>) -> Void)?
    let future = Future<Int>{ completion = $0 }
    var term: Termination? = nil
    var object: TestClass? = TestClass()
    
    future
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
