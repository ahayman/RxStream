//
//  FutureOperationsTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 4/5/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

private class TestClass { }

class ObservableOperationsTests: XCTestCase {
  
  func testOn() {
    var value: Int? = nil
    var onCount = 0
    let stream = ObservableInput<Int>(0)
    
    stream.on {
      value = $0
      onCount += 1
    }
    
    stream.set(0)
    XCTAssertEqual(value, 0)
    XCTAssertEqual(onCount, 1)
    
    stream.set(1)
    XCTAssertEqual(value, 1)
    XCTAssertEqual(onCount, 2)
    
    stream.set(2)
    XCTAssertEqual(value, 2)
    XCTAssertEqual(onCount, 3)
  }
  
  func testOnTransition() {
    var prior: Int? = nil
    var value: Int? = nil
    var onCount = 0
    let stream = ObservableInput<Int>(0)
    
    stream
      .onTransition {
        prior = $0
        value = $1
        onCount += 1
      }
      .replay()
    
    stream.set(1)
    XCTAssertEqual(prior, 0)
    XCTAssertEqual(value, 1)
    XCTAssertEqual(onCount, 2)
    
    stream.set(2)
    XCTAssertEqual(prior, 1)
    XCTAssertEqual(value, 2)
    XCTAssertEqual(onCount, 3)
  }
  
  func testOnTermination() {
    var terminations = [Termination]()
    let stream = ObservableInput<Int>(0)
    
    stream.onTerminate{
      terminations.append($0)
    }
    
    stream.set(0)
    XCTAssertEqual(terminations.count, 0)
    
    stream.set(1)
    XCTAssertEqual(terminations.count, 0)
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(terminations.count, 1, "The stream should only terminate once.")
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(terminations.last, .completed, "The stream should only terminate once.")
    XCTAssertEqual(terminations.count, 1, "The stream should only terminate once.")
  }
  
  func testTermination() {
    var terminations = [Termination]()
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    
    stream
      .onTerminate{
        terminations.append($0)
      }
      .on {
        values.append($0)
      }
    
    stream.set(0)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 0)
    XCTAssertEqual(terminations.count, 0)
    XCTAssertEqual(stream.state, .active)
    
    stream.set(1)
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
    
    stream.set(2)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 1)
    XCTAssertEqual(terminations.last, Termination.completed, "The stream should only terminate once.")
    XCTAssertEqual(terminations.count, 1, "The stream should only terminate once.")
    XCTAssertEqual(stream.state, .terminated(reason: .completed))
    
    stream.set(3)
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

  func testOnError() {
    var errors = [Error]()
    let stream = ObservableInput<Int>(0)

    stream.onError{ errors.append($0)}

    stream.set(0)
    XCTAssertEqual(errors.count, 0)

    stream.push(error: TestError())
    XCTAssertEqual(errors.count, 1)

    stream.push(error: TestError())
    XCTAssertEqual(errors.count, 2)
  }

  func testMapError() {
    var errors = [Error]()
    var terms = [Termination]()
    let stream = ObservableInput<Int>(0)

    stream
      .onError{ errors.append($0)}
      .mapError{ _ in return errors.count == 2 ? .completed : nil }
      .onTerminate{ terms.append($0) }

    stream.set(0)
    XCTAssertEqual(errors.count, 0)
    XCTAssertEqual(terms, [])

    stream.push(error: TestError())
    XCTAssertEqual(errors.count, 1)
    XCTAssertEqual(terms, [])

    stream.push(error: TestError())
    XCTAssertEqual(errors.count, 2)
    XCTAssertEqual(terms, [.completed])
  }

  func testMap() {
    var mapped: String? = nil
    var mapCount = 0
    var onCount = 0
    let stream = ObservableInput<Int>(0)
    
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
    
    stream.set(0)
    XCTAssertEqual(mapped, "0")
    XCTAssertEqual(mapCount, 1)
    XCTAssertEqual(onCount, 1)
    mapped = nil
    
    stream.set(1)
    XCTAssertEqual(mapped, "1")
    XCTAssertEqual(mapCount, 2)
    XCTAssertEqual(onCount, 2)
    mapped = nil
    
    stream.set(2)
    XCTAssertEqual(mapped, "2")
    XCTAssertEqual(mapCount, 3)
    XCTAssertEqual(onCount, 3)
    mapped = nil
    
    stream.set(3)
    XCTAssertNil(mapped)
    XCTAssertEqual(mapCount, 4)
    XCTAssertEqual(onCount, 3)
  }
  
  func testMapResult() {
    var mapped: String? = nil
    var error: Error? = nil
    var mapCount = 0
    var onCount = 0
    let stream = ObservableInput<Int>(0)
    
    stream
      .resultMap{ value -> Result<String> in
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
      .onError{ error = $0 }
    
    stream.set(0)
    XCTAssertEqual(mapped, "0")
    XCTAssertEqual(mapCount, 1)
    XCTAssertEqual(onCount, 1)
    XCTAssertNil(error)
    
    stream.set(1)
    XCTAssertEqual(mapped, "1")
    XCTAssertEqual(mapCount, 2)
    XCTAssertEqual(onCount, 2)
    XCTAssertNil(error)
    mapped = nil
    
    stream.set(2)
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
    let stream = ObservableInput<Int>(0)
    
    stream
      .asyncMap { (value: Int, completion: @escaping (Result<String>) -> Void) in
        mapCount += 1
        nextMap = (value, completion)
      }
      .on {
        mapped = $0
        onCount += 1
      }
      .onError{ error = $0 }
    
    stream.set(0)
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
    
    stream.set(1)
    XCTAssertEqual(mapCount, 2)
    XCTAssertEqual(onCount, 1)
    XCTAssertNil(mapped)
    guard let mapper2 = nextMap else { return XCTFail("Mapper was never set") }
    mapper2.callback(.success("\(mapper2.value)"))
    XCTAssertEqual(onCount, 2)
    XCTAssertEqual(mapped, "1")
    XCTAssertNil(error)
    mapped = nil
    
    stream.set(2)
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
    let stream = ObservableInput<String>("")
    
    stream
      .flatMap { $0.components(separatedBy: " ") }
      .on { mapped.append($0) }
    
    stream.set("Hello world")
    guard mapped.count == 2 else { return XCTFail("Didn't receive expected mapped output count.") }
    XCTAssertEqual(mapped[0], "Hello")
    XCTAssertEqual(mapped[1], "world")
    mapped = []
    
    stream.set("Test a multitude of words in a sentence.")
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
    let stream = ObservableInput<[Int]>([])
    
    stream
      .flatten()
      .on { mapped.append($0) }
    
    stream.set([0, 1, 2, 3, 4])
    guard mapped.count == 5 else { return XCTFail("Didn't receive expected mapped output count.") }
    for i in 0..<5 {
      XCTAssertEqual(mapped[i], i)
    }
    mapped = []
    
    
    stream.set([10, 11, 12, 13, 14])
    guard mapped.count == 5 else { return XCTFail("Didn't receive expected mapped output count.") }
    for (index, i) in (10..<15).enumerated() {
      XCTAssertEqual(mapped[index], i)
    }
  }
  
  func testScan() {
    var current = 0
    let stream = ObservableInput<Int>(0)
    
    stream
      .scan(initial: current) { $0 + $1 }
      .on { current = $0 }
    
    stream.set(1)
    XCTAssertEqual(current, 1)
    
    stream.set(2)
    XCTAssertEqual(current, 3)
    
    stream.set(3)
    XCTAssertEqual(current, 6)
    
    stream.set(4)
    XCTAssertEqual(current, 10)
    
    stream.set(-10)
    XCTAssertEqual(current, 0)
  }
  
  func testReduce() {
    var reduction = 0
    let stream = ObservableInput<Int>(0)
    
    stream
      .reduce(initial: reduction) { $0 + $1 }
      .last()
      .map { reduction = $0 }
    
    stream.set(1)
    XCTAssertEqual(reduction, 0)
    
    stream.set(2)
    XCTAssertEqual(reduction, 0)
    
    stream.set(3)
    XCTAssertEqual(reduction, 0)
    
    stream.set(4)
    XCTAssertEqual(reduction, 0)
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(reduction, 10)
  }
  
  func testFirst() {
    var values = [Int]()
    var term: Termination? = nil
    let stream = ObservableInput<Int>(0)
    
    stream
      .first()
      .on { values.append($0) }
      .onTerminate{ term = $0 }
    
    stream.set(1)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 1)
    XCTAssertEqual(term, .cancelled)
    
    stream.set(2)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 1)
    XCTAssertEqual(term, .cancelled)
  }
  
  func testFirstCount() {
    var values = [Int]()
    var term: Termination? = nil
    let stream = ObservableInput<Int>(0)
    
    stream
      .first(3)
      .on { values.append($0) }
      .onTerminate{ term = $0 }
    
    stream.set(1)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 1)
    
    stream.set(2)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 2)
    
    stream.set(3)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last, 3)
    XCTAssertEqual(term, .cancelled)
    
    stream.set(4)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last, 3)
    XCTAssertEqual(term, .cancelled)
    
    stream.set(5)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last, 3)
    XCTAssertEqual(term, .cancelled)
  }
  
  func testLast() {
    var last = [Int]()
    let stream = ObservableInput<Int>(0)
    
    stream.last().on{ last.append($0) }
    
    stream.set(1)
    XCTAssertEqual(last.count, 0)
    
    stream.set(2)
    XCTAssertEqual(last.count, 0)
    
    stream.set(3)
    XCTAssertEqual(last.count, 0)
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(last.count, 1)
    XCTAssertEqual(last.first, 3)
  }
  
  func testLastCount() {
    var last = [Int]()
    let stream = ObservableInput<Int>(0)
    
    stream.last(3).on{ last.append($0) }
    
    stream.set(1)
    XCTAssertEqual(last.count, 0)
    stream.set(2)
    XCTAssertEqual(last.count, 0)
    stream.set(3)
    XCTAssertEqual(last.count, 0)
    stream.set(4)
    XCTAssertEqual(last.count, 0)
    stream.set(5)
    XCTAssertEqual(last.count, 0)
    
    stream.terminate(withReason: .completed)
    guard last.count == 3 else { return XCTFail("Expected 3 values.") }
    XCTAssertEqual(last[0], 3)
    XCTAssertEqual(last[1], 4)
    XCTAssertEqual(last[2], 5)
  }
  
  func testLastCountPartial() {
    var noPartial = [Int]()
    var partial = [Int]()
    let stream = ObservableInput<Int>(0)
    
    stream.last(3).on{ partial.append($0) }
    stream.last(3, partial: false).on{ noPartial.append($0) }
    
    stream.set(1)
    XCTAssertEqual(noPartial.count, 0)
    XCTAssertEqual(partial.count, 0)
    stream.set(2)
    XCTAssertEqual(noPartial.count, 0)
    XCTAssertEqual(partial.count, 0)
    stream.terminate(withReason: .completed)
    XCTAssertEqual(noPartial.count, 0)
    XCTAssertEqual(partial.count, 2)
  }
  
  func testBuffer() {
    var buffer = [[Int]]()
    var noPartial = [[Int]]()
    let stream = ObservableInput<Int>(0)
    
    stream.buffer(size: 3).on{ buffer.append($0) }
    stream.buffer(size: 3, partial: false).on{ noPartial.append($0) }
    
    stream.set(1)
    XCTAssertEqual(buffer.count, 0)
    XCTAssertEqual(noPartial.count, 0)
    stream.set(2)
    XCTAssertEqual(buffer.count, 0)
    XCTAssertEqual(noPartial.count, 0)
    stream.set(3)
    XCTAssertEqual(buffer.count, 1)
    XCTAssertEqual(noPartial.count, 1)
    XCTAssertEqual(buffer.last ?? [], [1, 2, 3])
    XCTAssertEqual(noPartial.last ?? [], [1, 2, 3])
    
    stream.set(4)
    XCTAssertEqual(buffer.count, 1)
    XCTAssertEqual(noPartial.count, 1)
    stream.set(5)
    XCTAssertEqual(buffer.count, 1)
    XCTAssertEqual(noPartial.count, 1)
    stream.set(6)
    XCTAssertEqual(buffer.count, 2)
    XCTAssertEqual(noPartial.count, 2)
    XCTAssertEqual(buffer.last ?? [], [4, 5, 6])
    XCTAssertEqual(noPartial.last ?? [], [4, 5, 6])
    
    stream.set(7)
    XCTAssertEqual(buffer.count, 2)
    XCTAssertEqual(noPartial.count, 2)
    stream.set(8)
    XCTAssertEqual(buffer.count, 2)
    XCTAssertEqual(noPartial.count, 2)
    stream.terminate(withReason: .completed)
    XCTAssertEqual(buffer.count, 3)
    XCTAssertEqual(noPartial.count, 2)
    XCTAssertEqual(buffer.last ?? [], [7, 8])
    XCTAssertEqual(noPartial.last ?? [], [4, 5, 6])
  }
  
  func testSizedWindow() {
    var window = [[Int]]()
    var partial = [[Int]]()
    let stream = ObservableInput<Int>(0)
    
    stream.window(size: 3).on{ window.append($0) }
    stream.window(size: 3, partial: true).on{ partial.append($0) }
    
    stream.set(1)
    XCTAssertEqual(window.count, 0)
    XCTAssertEqual(partial.count, 1)
    XCTAssertEqual(partial.last ?? [], [1])
    stream.set(2)
    XCTAssertEqual(window.count, 0)
    XCTAssertEqual(partial.count, 2)
    XCTAssertEqual(partial.last ?? [], [1, 2])
    stream.set(3)
    XCTAssertEqual(window.count, 1)
    XCTAssertEqual(partial.count, 3)
    XCTAssertEqual(window.last ?? [], [1, 2, 3])
    XCTAssertEqual(partial.last ?? [], [1, 2, 3])
    stream.set(4)
    XCTAssertEqual(window.count, 2)
    XCTAssertEqual(partial.count, 4)
    XCTAssertEqual(window.last ?? [], [2, 3, 4])
    XCTAssertEqual(partial.last ?? [], [2, 3, 4])
    stream.set(5)
    XCTAssertEqual(window.count, 3)
    XCTAssertEqual(partial.count, 5)
    XCTAssertEqual(window.last ?? [], [3, 4, 5])
    XCTAssertEqual(partial.last ?? [], [3, 4, 5])
    stream.terminate(withReason: .completed)
    XCTAssertEqual(window.count, 3)
    XCTAssertEqual(partial.count, 5)
    XCTAssertEqual(window.last ?? [], [3, 4, 5])
    XCTAssertEqual(partial.last ?? [], [3, 4, 5])
  }
  
  func testTimedWindow() {
    var window = [[Int]]()
    var limited = [[Int]]()
    let stream = ObservableInput<Int>(0)
    
    stream.window(size: 1.0).on{ window.append($0) }
    stream.window(size: 1.0, limit: 3).on{ limited.append($0) }
    
    stream.set(1)
    XCTAssertEqual(window.count, 1)
    XCTAssertEqual(limited.count, 1)
    XCTAssertEqual(window.last ?? [], [1])
    XCTAssertEqual(limited.last ?? [], [1])
    
    stream.set(2)
    XCTAssertEqual(window.count, 2)
    XCTAssertEqual(limited.count, 2)
    XCTAssertEqual(window.last ?? [], [1, 2])
    XCTAssertEqual(limited.last ?? [], [1, 2])
    
    stream.set(3)
    XCTAssertEqual(window.count, 3)
    XCTAssertEqual(limited.count, 3)
    XCTAssertEqual(window.last ?? [], [1, 2, 3])
    XCTAssertEqual(limited.last ?? [], [1, 2, 3])
    
    stream.set(4)
    XCTAssertEqual(window.count, 4)
    XCTAssertEqual(limited.count, 4)
    XCTAssertEqual(window.last ?? [], [1, 2, 3, 4])
    XCTAssertEqual(limited.last ?? [], [2, 3, 4])
    
    wait(for: 0.5)
    
    stream.set(5)
    XCTAssertEqual(window.count, 5)
    XCTAssertEqual(limited.count, 5)
    XCTAssertEqual(window.last ?? [], [1, 2, 3, 4, 5])
    XCTAssertEqual(limited.last ?? [], [3, 4, 5])
    
    stream.set(6)
    XCTAssertEqual(window.count, 6)
    XCTAssertEqual(limited.count, 6)
    XCTAssertEqual(window.last ?? [], [1, 2, 3, 4, 5, 6])
    XCTAssertEqual(limited.last ?? [], [4, 5, 6])
    
    wait(for: 0.75)
    
    stream.set(7)
    XCTAssertEqual(window.count, 7)
    XCTAssertEqual(limited.count, 7)
    XCTAssertEqual(window.last ?? [], [5, 6, 7])
    XCTAssertEqual(limited.last ?? [], [5, 6, 7])
    
    stream.set(8)
    XCTAssertEqual(window.count, 8)
    XCTAssertEqual(limited.count, 8)
    XCTAssertEqual(window.last ?? [], [5, 6, 7, 8])
    XCTAssertEqual(limited.last ?? [], [6, 7, 8])
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(window.count, 8)
    XCTAssertEqual(limited.count, 8)
    XCTAssertEqual(window.last ?? [], [5, 6, 7, 8])
    XCTAssertEqual(limited.last ?? [], [6, 7, 8])
  }
  
  func testFilter() {
    var values = [String]()
    let stream = ObservableInput<String>("")
    
    stream
      .filter { !$0.contains("a") } //Filter out strings that contain a
      .on{ values.append($0) }
    
    stream.set("hello")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, "hello")
    
    stream.set("stream")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, "hello")
    
    stream.set("for")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, "for")
    
    stream.set("ever")
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last, "ever")
    
    stream.set("value")
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last, "ever")
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last, "ever")
  }
  
  func testDistinct() {
    var distinct = [String]()
    var distinctEquality = [String]()
    let stream = ObservableInput<String>("")
    
    stream.distinct{ $0 != $1 }.on{ distinct.append($0) }.replay()
    stream.distinct().on{ distinctEquality.append($0) }.replay()
    
    XCTAssertEqual(distinct.count, 1)
    XCTAssertEqual(distinctEquality.count, 1)
    XCTAssertEqual(distinct.last, "")
    XCTAssertEqual(distinctEquality.last, "")
    
    
    stream.set("hello")
    XCTAssertEqual(distinct.count, 2)
    XCTAssertEqual(distinctEquality.count, 2)
    XCTAssertEqual(distinct.last, "hello")
    XCTAssertEqual(distinctEquality.last, "hello")
    
    stream.set("stream")
    XCTAssertEqual(distinct.count, 3)
    XCTAssertEqual(distinctEquality.count, 3)
    XCTAssertEqual(distinct.last, "stream")
    XCTAssertEqual(distinctEquality.last, "stream")
    
    stream.set("stream")
    XCTAssertEqual(distinct.count, 3)
    XCTAssertEqual(distinctEquality.count, 3)
    XCTAssertEqual(distinct.last, "stream")
    XCTAssertEqual(distinctEquality.last, "stream")
    
    stream.set("for")
    XCTAssertEqual(distinct.count, 4)
    XCTAssertEqual(distinctEquality.count, 4)
    XCTAssertEqual(distinct.last, "for")
    XCTAssertEqual(distinctEquality.last, "for")
    
    stream.set("for")
    XCTAssertEqual(distinct.count, 4)
    XCTAssertEqual(distinctEquality.count, 4)
    XCTAssertEqual(distinct.last, "for")
    XCTAssertEqual(distinctEquality.last, "for")
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(distinct.count, 4)
    XCTAssertEqual(distinctEquality.count, 4)
    XCTAssertEqual(distinct.last, "for")
    XCTAssertEqual(distinctEquality.last, "for")
  }
  
  func testStride() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    
    stream.stride(3).on{ values.append($0) }
    
    stream.set(1)
    XCTAssertEqual(values.count, 0)
    
    stream.set(2)
    XCTAssertEqual(values.count, 0)
    
    stream.set(3)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 3)
    
    stream.set(4)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 3)
    
    stream.set(5)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 3)
    
    stream.set(6)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 6)
    
    stream.set(7)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 6)
    
    stream.set(8)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 6)
    
    stream.set(9)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last, 9)
  }
  
  func testStamp() {
    var values = [(Int, String)]()
    let stream = ObservableInput<Int>(0)
    
    stream.stamp{ "\($0)" }.on{ values.append($0) }
    
    stream.set(1)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.0, 1)
    XCTAssertEqual(values.last?.1, "1")
    
    stream.set(2)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.0, 2)
    XCTAssertEqual(values.last?.1, "2")
    
    stream.set(3)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last?.0, 3)
    XCTAssertEqual(values.last?.1, "3")
  }
  
  func testTimeStamp() {
    var values = [(Int, Date)]()
    let stream = ObservableInput<Int>(0)
    
    stream.timeStamp().on{ values.append($0) }
    
    stream.set(1)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.0, 1)
    XCTAssertEqual(values.last?.1.timeIntervalSinceReferenceDate ?? 0, Date.timeIntervalSinceReferenceDate, accuracy: 0.5)
    
    stream.set(2)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.0, 2)
    XCTAssertEqual(values.last?.1.timeIntervalSinceReferenceDate ?? 0, Date.timeIntervalSinceReferenceDate, accuracy: 0.5)
    
    wait(for: 0.5)
    
    stream.set(3)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last?.0, 3)
    XCTAssertEqual(values.last?.1.timeIntervalSinceReferenceDate ?? 0, Date.timeIntervalSinceReferenceDate, accuracy: 0.5)
  }
  
  func testCountStamp() {
    var values = [(String, UInt)]()
    let stream = ObservableInput<String>("Hello")
    
    stream
      .countStamp()
      .on{ values.append($0) }
      .replay()
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.0, "Hello")
    XCTAssertEqual(values.last?.1, 1)
    
    stream.set("World")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.0, "World")
    XCTAssertEqual(values.last?.1, 2)
  }
  
  func testMin() {
    var minValues = [Int]()
    var minComparable = [Int]()
    let stream = ObservableInput<Int>(10)
    
    stream.min{ $0 < $1 }.on{ minValues.append($0) }.replay()
    stream.min().on{ minComparable.append($0) }.replay()
    
    XCTAssertEqual(minValues.count, 1)
    XCTAssertEqual(minComparable.count, 1)
    XCTAssertEqual(minValues.last, 10)
    XCTAssertEqual(minComparable.last, 10)
    
    stream.set(12)
    XCTAssertEqual(minValues.count, 1)
    XCTAssertEqual(minComparable.count, 1)
    XCTAssertEqual(minValues.last, 10)
    XCTAssertEqual(minComparable.last, 10)
    
    stream.set(8)
    XCTAssertEqual(minValues.count, 2)
    XCTAssertEqual(minComparable.count, 2)
    XCTAssertEqual(minValues.last, 8)
    XCTAssertEqual(minComparable.last, 8)
    
    stream.set(8)
    XCTAssertEqual(minValues.count, 2)
    XCTAssertEqual(minComparable.count, 2)
    XCTAssertEqual(minValues.last, 8)
    XCTAssertEqual(minComparable.last, 8)
    
    stream.set(10)
    XCTAssertEqual(minValues.count, 2)
    XCTAssertEqual(minComparable.count, 2)
    XCTAssertEqual(minValues.last, 8)
    XCTAssertEqual(minComparable.last, 8)
    
    stream.set(5)
    XCTAssertEqual(minValues.count, 3)
    XCTAssertEqual(minComparable.count, 3)
    XCTAssertEqual(minValues.last, 5)
    XCTAssertEqual(minComparable.last, 5)
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(minValues.count, 3)
    XCTAssertEqual(minComparable.count, 3)
    XCTAssertEqual(minValues.last, 5)
    XCTAssertEqual(minComparable.last, 5)
  }
  
  func testMax() {
    var maxValues = [Int]()
    var maxComparable = [Int]()
    let stream = ObservableInput<Int>(10)
    
    stream.max{ $0 > $1 }.on{ maxValues.append($0) }.replay()
    stream.max().on{ maxComparable.append($0) }.replay()
    
    XCTAssertEqual(maxValues.count, 1)
    XCTAssertEqual(maxComparable.count, 1)
    XCTAssertEqual(maxValues.last, 10)
    XCTAssertEqual(maxComparable.last, 10)
    
    stream.set(10)
    XCTAssertEqual(maxValues.count, 1)
    XCTAssertEqual(maxComparable.count, 1)
    XCTAssertEqual(maxValues.last, 10)
    XCTAssertEqual(maxComparable.last, 10)
    
    stream.set(12)
    XCTAssertEqual(maxValues.count, 2)
    XCTAssertEqual(maxComparable.count, 2)
    XCTAssertEqual(maxValues.last, 12)
    XCTAssertEqual(maxComparable.last, 12)
    
    stream.set(8)
    XCTAssertEqual(maxValues.count, 2)
    XCTAssertEqual(maxComparable.count, 2)
    XCTAssertEqual(maxValues.last, 12)
    XCTAssertEqual(maxComparable.last, 12)
    
    stream.set(20)
    XCTAssertEqual(maxValues.count, 3)
    XCTAssertEqual(maxComparable.count, 3)
    XCTAssertEqual(maxValues.last, 20)
    XCTAssertEqual(maxComparable.last, 20)
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(maxValues.count, 3)
    XCTAssertEqual(maxComparable.count, 3)
    XCTAssertEqual(maxValues.last, 20)
    XCTAssertEqual(maxComparable.last, 20)
  }
  
  func testDelay() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    
    stream.delay(0.5).on{ values.append($0) }
    
    stream.set(1)
    XCTAssertEqual(values.count, 0)
    
    wait(for: 0.25)
    
    stream.set(2)
    XCTAssertEqual(values.count, 0)
    
    wait(for: 0.3)
    
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 1)
    
    wait(for: 0.25)
    
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 2)
  }
  
  func testSkip() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    
    stream.set(1)
    stream.set(2)
    
    stream.skip(3).on{ values.append($0) }
    
    XCTAssertEqual(values.count, 0)
    
    stream.set(4)
    XCTAssertEqual(values.count, 0)
    
    stream.set(5)
    XCTAssertEqual(values.count, 0)
    
    stream.set(6)
    XCTAssertEqual(values.count, 0)
    
    stream.set(7)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 7)
    
    stream.set(8)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 8)
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 8)
  }
  
  func testStart() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    
    stream.start(with: [-1, -2, -3]).on{ values.append($0) }
    
    stream.set(0)
    XCTAssertEqual(values, [-1, -2, -3, 0])
    
    stream.set(1)
    XCTAssertEqual(values, [-1, -2, -3, 0, 1])
    
    stream.set(2)
    XCTAssertEqual(values, [-1, -2, -3, 0, 1, 2])
  }
  
  func testConcat() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    
    stream.concat([98, 99, 100]).on{ values.append($0) }
    
    stream.set(0)
    XCTAssertEqual(values, [0])
    
    stream.set(1)
    XCTAssertEqual(values, [0, 1])
    
    stream.set(2)
    XCTAssertEqual(values, [0, 1, 2])
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(values, [0, 1, 2, 98, 99, 100])
  }
  
  func testMerge() {
    var values = [Either<Int, String>]()
    let left = ObservableInput<Int>(0)
    let right = ObservableInput<String>("")
    var term: Termination? = nil
    var error: Error? = nil
    
    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .onError{ error = $0 }
    
    left.set(1)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    
    right.set("first")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.right, "first")
    
    right.set("second")
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last?.right, "second")
    
    left.set(2)
    XCTAssertEqual(values.count, 4)
    XCTAssertEqual(values.last?.left, 2)
    
    left.terminate(withReason: .cancelled)
    XCTAssertNil(term)
    XCTAssertNil(error)

    left.set(2)
    XCTAssertEqual(values.count, 4)
    
    right.set("third")
    XCTAssertEqual(values.count, 5)
    XCTAssertEqual(values.last?.right, "third")
    
    right.terminate(withReason: .completed)
    XCTAssertEqual(values.count, 5)
    
    right.set("fourth")
    XCTAssertEqual(values.count, 5)
    
    XCTAssertEqual(term, .completed)
  }
  
  func testMergeWithSameType() {
    var values = [Int]()
    let left = ObservableInput<Int>(0)
    let right = ObservableInput<Int>(0)
    var term: Termination? = nil
    var error: Error? = nil
    
    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .onError{ error = $0 }
    
    left.set(1)
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, 1)
    
    right.set(100)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last, 100)
    
    right.set(101)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last, 101)
    
    left.set(2)
    XCTAssertEqual(values.count, 4)
    XCTAssertEqual(values.last, 2)
    
    left.terminate(withReason: .cancelled)
    XCTAssertNil(term)
    XCTAssertNil(error)

    left.set(2)
    XCTAssertEqual(values.count, 4)
    
    right.set(102)
    XCTAssertEqual(values.count, 5)
    XCTAssertEqual(values.last, 102)
    
    right.terminate(withReason: .completed)
    XCTAssertEqual(values.count, 5)
    
    XCTAssertEqual(term, .completed)
  }

  func testHotZip() {
    var values = [(left: Int, right: String)]()
    let left = ObservableInput<Int>(0)
    let right = HotInput<String>()
    var term: Termination? = nil

    left
      .zip(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    left.set(1)
    XCTAssertEqual(values.count, 0)

    left.set(2)
    XCTAssertEqual(values.count, 0)

    right.push("one")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")

    right.push("two")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")

    right.push("three")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")

    right.push("four")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")

    right.push("five")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")

    left.set(3)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last?.left, 3)
    XCTAssertEqual(values.last?.right, "three")

    left.set(4)
    XCTAssertEqual(values.count, 4)
    XCTAssertEqual(values.last?.left, 4)
    XCTAssertEqual(values.last?.right, "four")

    left.terminate(withReason: .completed)
    XCTAssertEqual(values.count, 4)
    XCTAssertEqual(term, .completed)
  }
  
  func testZip() {
    var values = [(left: Int, right: String)]()
    let left = ObservableInput<Int>(0)
    let right = ObservableInput<String>("")
    var term: Termination? = nil
    
    left
      .zip(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    left.set(1)
    XCTAssertEqual(values.count, 0)
    
    left.set(2)
    XCTAssertEqual(values.count, 0)
    
    right.set("one")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    
    right.set("two")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")
    
    right.set("three")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")
    
    right.set("four")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")
    
    right.set("five")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")
    
    left.set(3)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last?.left, 3)
    XCTAssertEqual(values.last?.right, "three")
    
    left.set(4)
    XCTAssertEqual(values.count, 4)
    XCTAssertEqual(values.last?.left, 4)
    XCTAssertEqual(values.last?.right, "four")
    
    left.terminate(withReason: .completed)
    XCTAssertEqual(values.count, 4)
    XCTAssertEqual(term, .completed)
  }
  
  func testZipBuffer() {
    var values = [(left: Int, right: String)]()
    let left = ObservableInput<Int>(0)
    let right = ObservableInput<String>("")
    var term: Termination? = nil
    
    left
      .zip(right, buffer: 2)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    left.set(1)
    XCTAssertEqual(values.count, 0)
    
    left.set(2)
    XCTAssertEqual(values.count, 0)
    
    right.set("one")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    
    right.set("two")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")
    
    right.set("three")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")
    
    right.set("four")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")
    
    right.set("five") //Should be ignored, exceeds buffer
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")
    
    right.set("six") //Should be ignored, exceeds buffer
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")
    
    right.set("seven") //Should be ignored, exceeds buffer
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")
    
    left.set(3)
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last?.left, 3)
    XCTAssertEqual(values.last?.right, "three")
    
    left.set(4)
    XCTAssertEqual(values.count, 4)
    XCTAssertEqual(values.last?.left, 4)
    XCTAssertEqual(values.last?.right, "four")
    
    left.set(5)
    XCTAssertEqual(values.count, 4)
    XCTAssertEqual(values.last?.left, 4)
    XCTAssertEqual(values.last?.right, "four")
    
    left.set(6)
    XCTAssertEqual(values.count, 4)
    XCTAssertEqual(values.last?.left, 4)
    XCTAssertEqual(values.last?.right, "four")
    
    left.set(7) //Should be ignored, exceeds buffer
    XCTAssertEqual(values.count, 4)
    XCTAssertEqual(values.last?.left, 4)
    XCTAssertEqual(values.last?.right, "four")
    
    right.set("eight")
    XCTAssertEqual(values.count, 5)
    XCTAssertEqual(values.last?.left, 5)
    XCTAssertEqual(values.last?.right, "eight")
    
    right.set("nine")
    XCTAssertEqual(values.count, 6)
    XCTAssertEqual(values.last?.left, 6)
    XCTAssertEqual(values.last?.right, "nine")
    
    left.terminate(withReason: .completed)
    XCTAssertEqual(values.count, 6)
    XCTAssertEqual(term, .completed)
  }
  
  func testCombineLatest() {
    var values = [(left: Int, right: String)]()
    let left = ObservableInput<Int>(0)
    let right = ObservableInput<String>("")
    var term: Termination? = nil
    var error: Error? = nil
    
    left
      .combine(latest: true, stream: right)
      .on{ values.append($0) }
      .onError{ error = $0 }
      .onTerminate{ term = $0 }
    
    left.set(1)
    XCTAssertEqual(values.count, 0)
    
    left.set(2)
    XCTAssertEqual(values.count, 0)
    
    right.set("one")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "one")
    
    right.set("two")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "two")
    
    right.set("three")
    XCTAssertEqual(values.count, 3)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "three")
    
    left.set(3)
    XCTAssertEqual(values.count, 4)
    XCTAssertEqual(values.last?.left, 3)
    XCTAssertEqual(values.last?.right, "three")
    
    right.set("four")
    XCTAssertEqual(values.count, 5)
    XCTAssertEqual(values.last?.left, 3)
    XCTAssertEqual(values.last?.right, "four")
    
    right.terminate(withReason: .completed)
    XCTAssertNil(term)
    XCTAssertNil(error)

    left.set(4)
    XCTAssertEqual(values.count, 6)
    XCTAssertEqual(values.last?.left, 4)
    XCTAssertEqual(values.last?.right, "four")
    
    left.terminate(withReason: .completed)
    XCTAssertEqual(values.count, 6)
    XCTAssertEqual(term, .completed)
    XCTAssertNil(error)
  }

  func testCombineHot() {
    var values = [(left: Int, right: String)]()
    let left = ObservableInput<Int>(0)
    let right = HotInput<String>()
    var term: Termination? = nil
    var error: Error? = nil

    left
      .combine(latest: false, stream: right)
      .on{ values.append($0) }
      .onError{ error = $0 }
      .onTerminate{ term = $0 }

    left.set(1)
    XCTAssertEqual(values.count, 0)

    left.set(2)
    XCTAssertEqual(values.count, 0)

    right.push("one")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "one")

    right.push("two")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "one")

    right.push("three")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "one")

    left.set(3)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 3)
    XCTAssertEqual(values.last?.right, "three")

    right.push("four")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 3)
    XCTAssertEqual(values.last?.right, "three")

    right.terminate(withReason: .completed)
    XCTAssertEqual(term, .completed)
    XCTAssertNil(error)

    left.set(4)
    XCTAssertEqual(values.count, 2)

    left.terminate(withReason: .cancelled)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(term, .completed)
    XCTAssertNil(error)
  }
  
  func testCombine() {
    var values = [(left: Int, right: String)]()
    let left = ObservableInput<Int>(0)
    let right = ObservableInput<String>("")
    var term: Termination? = nil
    var error: Error? = nil
    
    left
      .combine(latest: false, stream: right)
      .on{ values.append($0) }
      .onError{ error = $0 }
      .onTerminate{ term = $0 }
    
    left.set(1)
    XCTAssertEqual(values.count, 0)
    
    left.set(2)
    XCTAssertEqual(values.count, 0)
    
    right.set("one")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "one")
    
    right.set("two")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "one")
    
    right.set("three")
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 2)
    XCTAssertEqual(values.last?.right, "one")
    
    left.set(3)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 3)
    XCTAssertEqual(values.last?.right, "three")
    
    right.set("four")
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(values.last?.left, 3)
    XCTAssertEqual(values.last?.right, "three")
    
    right.terminate(withReason: .completed)
    XCTAssertEqual(term, .completed)
    XCTAssertNil(error)
    
    left.set(4)
    XCTAssertEqual(values.count, 2)
    
    left.terminate(withReason: .cancelled)
    XCTAssertEqual(values.count, 2)
    XCTAssertEqual(term, .completed)
    XCTAssertNil(error)
  }

  func testCount() {
    var count: UInt = 0
    let stream = ObservableInput(0)
    stream.count().on{ count = $0 }

    stream.set(1)
    XCTAssertEqual(count, 1)

    stream.set(1)
    XCTAssertEqual(count, 2)

    stream.set(1)
    XCTAssertEqual(count, 3)
  }
  
  func testAverage() {
    var values = [Double]()
    let stream = ObservableInput<Double>(2.0)
    
    stream.average().on{ values.append($0) }.replay()
    
    stream.set(2.0) // 4 / 2
    XCTAssertEqual(values, [2.0, 2.0])
    
    stream.set(5.0) // 9 / 3
    XCTAssertEqual(values, [2.0, 2.0, 3.0])
    
    stream.set(7.0) // 16 / 4
    XCTAssertEqual(values, [2.0, 2.0, 3.0, 4.0])
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(values, [2.0, 2.0, 3.0, 4.0])
  }
  
  func testSum() {
    var values = [Double]()
    let stream = ObservableInput<Double>(2.0)
    
    stream.sum().on{ values.append($0) }.replay()
    
    XCTAssertEqual(values, [2.0])
    
    stream.set(3.0)
    XCTAssertEqual(values, [2.0, 5.0])
    
    stream.set(3.0)
    XCTAssertEqual(values, [2.0, 5.0, 8.0])
    
    stream.set(2.5)
    XCTAssertEqual(values, [2.0, 5.0, 8.0, 10.5])
    
    stream.set(-10.5)
    XCTAssertEqual(values, [2.0, 5.0, 8.0, 10.5, 0])
    
    stream.terminate(withReason: .completed)
    XCTAssertEqual(values, [2.0, 5.0, 8.0, 10.5, 0])
  }
  
  func testWhile() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    var term: Termination? = nil
    
    stream
      .doWhile{ $0 < 10 }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    stream.set(1)
    XCTAssertEqual(values, [1])
    
    stream.set(3)
    XCTAssertEqual(values, [1, 3])
    
    stream.set(7)
    XCTAssertEqual(values, [1, 3, 7])
    
    stream.set(10)
    XCTAssertEqual(values, [1, 3, 7])
    XCTAssertEqual(term, .cancelled)
  }
  
  func testWhileTransition() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    var term: Termination? = nil
    
    stream
      .doWhile{ (prior, next) -> Bool in
        guard let prior = prior else { return true }
        return prior < next
      }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    
    stream.set(1)
    XCTAssertEqual(values, [1])
    
    stream.set(3)
    XCTAssertEqual(values, [1, 3])
    
    stream.set(7)
    XCTAssertEqual(values, [1, 3, 7])
    
    stream.set(1)
    XCTAssertEqual(values, [1, 3, 7])
    XCTAssertEqual(term, .cancelled)
  }
  
  func testUntil() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    var term: Termination? = nil
    
    stream
      .until{ $0 == 10 }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    stream.set(1)
    XCTAssertEqual(values, [1])
    
    stream.set(3)
    XCTAssertEqual(values, [1, 3])
    
    stream.set(7)
    XCTAssertEqual(values, [1, 3, 7])
    
    stream.set(11)
    XCTAssertEqual(values, [1, 3, 7, 11])
    
    stream.set(10)
    XCTAssertEqual(values, [1, 3, 7, 11])
    XCTAssertEqual(term, .cancelled)
  }
  
  func testUntilTransition() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    var term: Termination? = nil
    
    stream
      .until{ (prior, next) -> Bool in
        guard let prior = prior else { return false }
        return prior == next
      }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    stream.set(1)
    XCTAssertEqual(values, [1])
    
    stream.set(3)
    XCTAssertEqual(values, [1, 3])
    
    stream.set(7)
    XCTAssertEqual(values, [1, 3, 7])
    
    stream.set(7)
    XCTAssertEqual(values, [1, 3, 7])
    XCTAssertEqual(term, .cancelled)
  }

  func testUntilTermination(){
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    var term: Termination? = nil

    stream
      .until{ value -> Termination? in
        return value == 10 ? .completed : nil
      }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    stream.set(1)
    XCTAssertEqual(values, [1])

    stream.set(3)
    XCTAssertEqual(values, [1, 3])

    stream.set(7)
    XCTAssertEqual(values, [1, 3, 7])

    stream.set(11)
    XCTAssertEqual(values, [1, 3, 7, 11])

    stream.set(10)
    XCTAssertEqual(values, [1, 3, 7, 11])
    XCTAssertEqual(term, .completed)
  }

  func testUntilTransitionTermination() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    var term: Termination? = nil

    stream
      .until{ (prior, next) -> Termination? in
        guard let prior = prior else { return nil }
        return prior == next ? .completed : nil
      }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    stream.set(1)
    XCTAssertEqual(values, [1])

    stream.set(3)
    XCTAssertEqual(values, [1, 3])

    stream.set(7)
    XCTAssertEqual(values, [1, 3, 7])

    stream.set(7)
    XCTAssertEqual(values, [1, 3, 7])
    XCTAssertEqual(term, .completed)
  }

  func testNext() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    var term: Termination? = nil
    
    stream.set(1)
    stream.set(2)
    
    stream
      .next(3, then: .completed)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    stream.set(3)
    XCTAssertEqual(values, [3])
    
    stream.set(4)
    XCTAssertEqual(values, [3, 4])
    
    stream.set(5)
    XCTAssertEqual(values, [3, 4, 5])
    XCTAssertEqual(term, .completed)
    
    stream.set(6)
    XCTAssertEqual(values, [3, 4, 5])
  }
  
  func testUsing() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    var term: Termination? = nil
    var object: TestClass? = TestClass()
    
    stream
      .using(object!)
      .on{ values.append($0.1) }
      .onTerminate{ term = $0 }
    
    stream.set(1)
    XCTAssertEqual(values, [1])
    
    stream.set(2)
    XCTAssertEqual(values, [1, 2])
    
    stream.set(3)
    XCTAssertEqual(values, [1, 2, 3])
    
    object = nil
   
    wait(for: 0.1) // Allow the object to deinit
    
    stream.set(4)
    XCTAssertEqual(values, [1, 2, 3])
    XCTAssertEqual(term, .cancelled)
  }
  
  func testLifeOf() {
    var values = [Int]()
    let stream = ObservableInput<Int>(0)
    var term: Termination? = nil
    var object: TestClass? = TestClass()
    
    stream
      .lifeOf(object!)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
    
    stream.set(1)
    XCTAssertEqual(values, [1])
    
    stream.set(2)
    XCTAssertEqual(values, [1, 2])
    
    stream.set(3)
    XCTAssertEqual(values, [1, 2, 3])
    
    object = nil
   
    wait(for: 0.1) // Allow the object to deinit
    
    stream.set(4)
    XCTAssertEqual(values, [1, 2, 3])
    XCTAssertEqual(term, .cancelled)
  }

  func testHot() {
    let stream = ObservableInput<Int>(0)
    var values = [Int]()

    stream.hot().on{ values.append($0) }

    XCTAssertEqual(values, [])

    stream.set(1)
    XCTAssertEqual(values, [1])

    stream.set(2)
    XCTAssertEqual(values, [1, 2])

    stream.set(3)
    XCTAssertEqual(values, [1, 2, 3])
  }

  func testObservable() {
    let stream = ObservableInput<Int>(0)
    var values = [Int]()

    stream.observable().on{ values.append($0) }

    XCTAssertEqual(values, [])

    stream.set(1)
    XCTAssertEqual(values, [1])

    stream.set(2)
    XCTAssertEqual(values, [1, 2])

    stream.set(3)
    XCTAssertEqual(values, [1, 2, 3])
  }

}
