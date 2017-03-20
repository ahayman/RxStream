//
//  HotTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/20/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
import Rx

struct TestError : Error { }

class HotTests: XCTestCase {
  
  func testOn() {
    var value: Int? = nil
    var onCount = 0
    let stream = HotInput<Int>()
    
    stream.on {
      value = $0
      onCount += 1
    }
    
    stream.push(0)
    XCTAssertEqual(value, 0)
    XCTAssertEqual(onCount, 1)
    
    stream.push(1)
    XCTAssertEqual(value, 1)
    XCTAssertEqual(onCount, 2)
    
    stream.push(2)
    XCTAssertEqual(value, 2)
    XCTAssertEqual(onCount, 3)
  }
  
  func testOnTransition() {
    var prior: Int? = nil
    var value: Int? = nil
    var onCount = 0
    let stream = HotInput<Int>()
    
    stream.onTransition {
      prior = $0
      value = $1
      onCount += 1
    }
    
    stream.push(0)
    XCTAssertNil(prior)
    XCTAssertEqual(value, 0)
    XCTAssertEqual(onCount, 1)
    
    stream.push(1)
    XCTAssertEqual(prior, 0)
    XCTAssertEqual(value, 1)
    XCTAssertEqual(onCount, 2)
    
    stream.push(2)
    XCTAssertEqual(prior, 1)
    XCTAssertEqual(value, 2)
    XCTAssertEqual(onCount, 3)
  }
  
  func testOnTermination() {
    var terminations = [Termination]()
    let stream = HotInput<Int>()
    
    stream.onTerminate{
      terminations.append($0)
    }
    
    stream.push(0)
    XCTAssertEqual(terminations.count, 0)
    
    stream.push(1)
    XCTAssertEqual(terminations.count, 0)
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(terminations.count, 1, "The stream should only terminate once.")
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(terminations.last, Termination.completed, "The stream should only terminate once.")
    XCTAssertEqual(terminations.count, 1, "The stream should only terminate once.")
  }
  
  func testTermination() {
    var terminations = [Termination]()
    var values = [Int]()
    let stream = HotInput<Int>()
    
    stream
      .onTerminate{
        terminations.append($0)
      }
      .on {
        values.append($0)
      }
    
    stream.push(0)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 0)
    XCTAssertEqual(terminations.count, 0)
    XCTAssertEqual(stream.state, .active)
    
    stream.push(1)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 1)
    XCTAssertEqual(terminations.count, 0)
    XCTAssertEqual(stream.state, .active)
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 1)
    XCTAssertEqual(terminations.last, Termination.completed, "The stream should only terminate once.")
    XCTAssertEqual(terminations.count, 1, "The stream should only terminate once.")
    XCTAssertEqual(stream.state, .terminated(reason: .completed))
    
    stream.push(2)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 1)
    XCTAssertEqual(terminations.last, Termination.completed, "The stream should only terminate once.")
    XCTAssertEqual(terminations.count, 1, "The stream should only terminate once.")
    XCTAssertEqual(stream.state, .terminated(reason: .completed))
    
    stream.push(3)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 1)
    XCTAssertEqual(terminations.last, Termination.completed, "The stream should only terminate once.")
    XCTAssertEqual(terminations.count, 1, "The stream should only terminate once.")
    XCTAssertEqual(stream.state, .terminated(reason: .completed))
    
    stream.terminate(withReason: .cancelled)
    XCTAssertEqual(terminations.last, Termination.completed, "The stream should only terminate once.")
    XCTAssertEqual(terminations.count, 1, "The stream should only terminate once.")
    XCTAssertEqual(stream.state, .terminated(reason: .completed))
  }
  
  func testMap() {
    var mapped: String? = nil
    var mapCount = 0
    var onCount = 0
    let stream = HotInput<Int>()
    
    stream
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
    
    stream.push(0)
    XCTAssertEqual(mapped, "0")
    XCTAssertEqual(mapCount, 1)
    XCTAssertEqual(onCount, 1)
    mapped = nil
    
    stream.push(1)
    XCTAssertEqual(mapped, "1")
    XCTAssertEqual(mapCount, 2)
    XCTAssertEqual(onCount, 2)
    mapped = nil
    
    stream.push(2)
    XCTAssertEqual(mapped, "2")
    XCTAssertEqual(mapCount, 3)
    XCTAssertEqual(onCount, 3)
    mapped = nil
    
    stream.push(3)
    XCTAssertNil(mapped)
    XCTAssertEqual(mapCount, 4)
    XCTAssertEqual(onCount, 3)
  }
  
  func testMapResult() {
    var mapped: String? = nil
    var error: Error? = nil
    var mapCount = 0
    var onCount = 0
    let stream = HotInput<Int>()
    
    stream
      .map{ value -> Result<String> in
        mapCount += 1
        if value == 2 {
          return .failure(TestError())
        }
        return .success("\(value)")
      }
      .on{
        onCount += 1
        mapped = $0
      }
      .onError {
        error = $0
        return nil
      }
    
    stream.push(0)
    XCTAssertEqual(mapped, "0")
    XCTAssertEqual(mapCount, 1)
    XCTAssertEqual(onCount, 1)
    XCTAssertNil(error)
    
    stream.push(1)
    XCTAssertEqual(mapped, "1")
    XCTAssertEqual(mapCount, 2)
    XCTAssertEqual(onCount, 2)
    XCTAssertNil(error)
    mapped = nil
    
    stream.push(2)
    XCTAssertNil(mapped)
    XCTAssertEqual(mapCount, 3)
    XCTAssertEqual(onCount, 2)
    XCTAssertNotNil(error)
  }
  
  func testAsyncMap() {
    var mapped: String? = nil
    var mapCount = 0
    var onCount = 0
    var error: Error?
    var nextMap: (value: Int, callback: (Result<String>) -> Void)? = nil
    let stream = HotInput<Int>()
    
    stream
      .map { (value: Int, completion: @escaping (Result<String>) -> Void) in
        mapCount += 1
        nextMap = (value, completion)
      }
      .on {
        mapped = $0
        onCount += 1
      }
      .onError{
        error = $0
        return nil
      }
    
    stream.push(0)
    XCTAssertEqual(mapCount, 1)
    XCTAssertEqual(onCount, 0)
    XCTAssertNil(mapped)
    guard let mapper = nextMap else { return XCTFail("Mapper was never set") }
    mapper.callback(.success("\(mapper.value)"))
    XCTAssertEqual(onCount, 1)
    XCTAssertEqual(mapped, "0")
    XCTAssertNil(error)
    mapped = nil
    nextMap = nil
    
    stream.push(1)
    XCTAssertEqual(mapCount, 2)
    XCTAssertEqual(onCount, 1)
    XCTAssertNil(mapped)
    guard let mapper2 = nextMap else { return XCTFail("Mapper was never set") }
    mapper2.callback(.success("\(mapper2.value)"))
    XCTAssertEqual(onCount, 2)
    XCTAssertEqual(mapped, "1")
    XCTAssertNil(error)
    mapped = nil
    
    stream.push(2)
    XCTAssertEqual(mapCount, 3)
    XCTAssertEqual(onCount, 2)
    XCTAssertNil(mapped)
    guard let mapper3 = nextMap else { return XCTFail("Mapper was never set") }
    mapper3.callback(.failure(TestError()))
    XCTAssertEqual(onCount, 2)
    XCTAssertNil(mapped)
    XCTAssertNotNil(error)
  }
  
  func testFlatMap() {
    var mapped = [String]()
    let stream = HotInput<String>()
    
    stream
      .flatMap { $0.components(separatedBy: " ") }
      .on { mapped.append($0) }
    
    stream.push("Hello world")
    guard mapped.count == 2 else { return XCTFail("Didn't receive expected mapped output count.") }
    XCTAssertEqual(mapped[0], "Hello")
    XCTAssertEqual(mapped[1], "world")
    mapped = []
    
    stream.push("Test a multitude of words in a sentence.")
    guard mapped.count == 8 else { return XCTFail("Didn't receive expected mapped output count.") }
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
    let stream = HotInput<[Int]>()
    
    stream
      .flatten()
      .on { mapped.append($0) }
    
    stream.push([0, 1, 2, 3, 4])
    guard mapped.count == 5 else { return XCTFail("Didn't receive expected mapped output count.") }
    for i in 0..<5 {
      XCTAssertEqual(mapped[i], i)
    }
    mapped = []
    
    
    stream.push([10, 11, 12, 13, 14])
    guard mapped.count == 5 else { return XCTFail("Didn't receive expected mapped output count.") }
    for (index, i) in (10..<15).enumerated() {
      XCTAssertEqual(mapped[index], i)
    }
  }
  
  func testScan() {
    var current = 0
    let stream = HotInput<Int>()
    
    stream
      .scan(initial: current) { $0 + $1 }
      .map { current = $0 }
    
    stream.push(1)
    XCTAssertEqual(current, 1)
    
    stream.push(2)
    XCTAssertEqual(current, 3)
    
    stream.push(3)
    XCTAssertEqual(current, 6)
    
    stream.push(4)
    XCTAssertEqual(current, 10)
    
    stream.push(-10)
    XCTAssertEqual(current, 0)
  }
  
  func testReduce() {
    var reduction = 0
    let stream = HotInput<Int>()
    
    stream
      .reduce(initial: reduction) { $0 + $1 }
      .last()
      .map { reduction = $0 }
    
    stream.push(1)
    XCTAssertEqual(reduction, 0)
    
    stream.push(2)
    XCTAssertEqual(reduction, 0)
    
    stream.push(3)
    XCTAssertEqual(reduction, 0)
    
    stream.push(4)
    XCTAssertEqual(reduction, 0)
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(reduction, 10)
  }
  
  func testFirst() {
    var values = [Int]()
    var term: Termination? = nil
    let stream = HotInput<Int>()
    
    stream
      .first()
      .on { values.append($0) }
      .onTerminate{ term = $0 }
    
    stream.push(1)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 1)
    XCTAssertEqual(term, .cancelled)
    
    stream.push(2)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 1)
    XCTAssertEqual(term, .cancelled)
  }
  
  func testFirstCount() {
    var values = [Int]()
    var term: Termination? = nil
    let stream = HotInput<Int>()
    
    stream
      .first(3)
      .on { values.append($0) }
      .onTerminate{ term = $0 }
    
    stream.push(1)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 1)
    
    stream.push(2)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 2)
    
    stream.push(3)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last, 3)
    
    stream.push(4)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last, 3)
    XCTAssertEqual(term, .cancelled)
    
    stream.push(5)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last, 3)
    XCTAssertEqual(term, .cancelled)
  }
  
  func testLast() {
    var last = [Int]()
    let stream = HotInput<Int>()
    
    stream.last().on{ last.append($0) }
    
    stream.push(1)
    XCTAssertEqual(last.count, 0)
    
    stream.push(2)
    XCTAssertEqual(last.count, 0)
    
    stream.push(3)
    XCTAssertEqual(last.count, 0)
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(last.count, 1)
    XCTAssertEqual(last.first, 3)
  }
  
  func testLastCount() {
    var last = [Int]()
    let stream = HotInput<Int>()
    
    stream.last(3).on{ last.append($0) }
    
    stream.push(1)
    XCTAssertEqual(last.count, 0)
    stream.push(2)
    XCTAssertEqual(last.count, 0)
    stream.push(3)
    XCTAssertEqual(last.count, 0)
    stream.push(4)
    XCTAssertEqual(last.count, 0)
    stream.push(5)
    XCTAssertEqual(last.count, 0)
    
    stream.terminate(withReason: .completed)
    guard last.count == 3 else { return XCTFail("Expected 3 values.") }
    XCTAssertEqual(last[0], 3)
    XCTAssertEqual(last[1], 4)
    XCTAssertEqual(last[2], 5)
  }
  
}
