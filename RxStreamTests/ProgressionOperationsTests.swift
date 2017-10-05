//
//  ProgressionOperationsTests.swift
//  RxTests
//
//  Created by Aaron Hayman on 9/29/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

private class TestClass { }

class ProgressionOperationsTests: XCTestCase {

  func testOnProgress() {
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)? = nil
    var progressEvents = [Double]()
    let total = 100.0
    let title = "Test Progression"
    let unit = "%"

    func validateProgress(event: ProgressEvent<Double>) -> Bool {
      return event.total == total && event.title == title && event.unit == unit
    }

    let progress = Progression<Double, Int> { cancelled, onCompletion in
      completion = onCompletion
    }
      .onProgress {
        progressEvents.append($0.current)
        XCTAssertTrue(validateProgress(event: $0))
      }

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
  }

  func testMapProgress() {
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)? = nil
    var progressEvents = [String]()
    let total = 100.0
    let title = "Test Progression"
    let unit = "%"

    func validateProgress(event: ProgressEvent<Double>) -> Bool {
      return event.total == total && event.title == title && event.unit == unit
    }

    let progress = Progression<Double, Int> { cancelled, onCompletion in
      completion = onCompletion
    }
      .mapProgress{ ProgressEvent(title: $0.title, unit: $0.unit, current: String($0.current), total: String($0.total)) }
      .onProgress{
        progressEvents.append($0.current)
      }

    XCTAssertTrue(progress.isActive)
    guard let completionTask = completion else { return XCTFail("Expected the Future task to be called") }

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 0.1, total: total)))
    XCTAssertEqual(progressEvents, ["0.1"])

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 50.0, total: total)))
    XCTAssertEqual(progressEvents, ["0.1", "50.0"])

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 75.2, total: total)))
    XCTAssertEqual(progressEvents, ["0.1", "50.0", "75.2"])

    completionTask(.left(ProgressEvent(title: title, unit: unit, current: 100.0, total: total)))
    XCTAssertEqual(progressEvents, ["0.1", "50.0", "75.2", "100.0"])
  }

  func testProgressMerge() {
    var values = [(Int, String)]()
    var lProg = ProgressEvent(title: "Left", unit: "int", current: 0, total: 1000)
    var rProg = ProgressEvent(title: "Right", unit: "double", current: 0.0, total: 100.0)
    var leftComp: ((Either<ProgressEvent<Int>, Result<Int>>) -> Void)? = nil
    var rightComp: ((Either<ProgressEvent<Double>, Result<String>>) -> Void)? = nil
    var progressions = [ProgressEvent<Double>]()
    let left = Progression<Int, Int>{ (_, c) in leftComp = c }
    let right = Progression<Double, String>{ (_, c) in rightComp = c }
    var term: Termination? = nil

    left
      .combineProgress(stream: right) { (events: EitherAnd<ProgressEvent<Int>, ProgressEvent<Double>>) -> ProgressEvent<Double> in
        switch events {
        case let .right(e): return ProgressEvent(title: e.title, unit: e.unit, current: e.current / e.total * 100.0, total: 100.0)
        case let .left(e): return ProgressEvent(title: e.title, unit: e.unit, current: Double(e.current) / Double(e.total) * 100.0, total: 100.0)
        case let .both(l, r):
          return ProgressEvent(
            title: l.title + ", " + r.title,
            unit: "%",
            current: (Double(l.current) / Double(l.total)) * 50.0 + (r.current / r.total) * 50.0,
            total: 100.0)
        }
      }
      .onProgress { progressions.append($0) }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    lProg.current = 100
    leftComp?(.left(lProg))
    XCTAssertEqual(progressions.map({ $0.current }), [10.0])
    XCTAssertEqual(progressions.map({ $0.total }), [100.0])
    XCTAssertEqual(progressions.map({ $0.title }), ["Left"])
    XCTAssertEqual(progressions.map({ $0.unit }), ["int"])

    lProg.current = 500
    leftComp?(.left(lProg))
    XCTAssertEqual(progressions.map({ $0.current }), [10.0, 50.0])
    XCTAssertEqual(progressions.map({ $0.total }), [100.0, 100.0])
    XCTAssertEqual(progressions.map({ $0.title }), ["Left", "Left"])
    XCTAssertEqual(progressions.map({ $0.unit }), ["int", "int"])

    rProg.current = 30.0
    rightComp?(.left(rProg))
    XCTAssertEqual(progressions.map({ $0.current }), [10.0, 50.0, 40.0])
    XCTAssertEqual(progressions.map({ $0.total }), [100.0, 100.0, 100.0])
    XCTAssertEqual(progressions.map({ $0.title }), ["Left", "Left", "Left, Right"])
    XCTAssertEqual(progressions.map({ $0.unit }), ["int", "int", "%"])
    
    leftComp?(.right(.success(1)))
    rightComp?(.right(.success("1.0")))

    XCTAssertEqual(values.map({ $0.1 }), ["1.0"], "Both terms are emitted, but only the last term emitted is replayed.")
    XCTAssertEqual(values.map({ $0.0 }), [1], "Both terms are emitted, but only the last term emitted is replayed.")
    XCTAssertEqual(term, .completed)
  }

  func testOn() {
    var value: Int? = nil
    var onCount = 0
    let progress = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }

    progress
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
    let progress = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }

    progress
      .onTerminate{ terminations.append($0) }
      .replay()

    XCTAssertEqual(terminations.count, 1, "The progression should only terminate once.")
  }

  func testMap() {
    var mapped: String? = nil
    var mapCount = 0
    var onCount = 0
    let progress = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }

    progress
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
    let progress = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }

    progress
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
    let progress = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }

    progress
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
    let progress = Progression<Double, String> { (_, c) in c(.right(.success("Test a multitude of words in a sentence."))) }

    progress
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
    let progress = Progression<Double, [Int]> { (_, c) in c(.right(.success([0, 1, 2, 3, 4]))) }

    progress
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
    let progress = Progression<Double, String>{ (_, c) in c(.right(.success("hello"))) }

    progress
      .filter { !$0.contains("a") } //Filter out strings that contain a
      .on{ values.append($0) }
      .replay()

    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last, "hello")
  }

  func testFiltered() {
    var values = [String]()
    let progress = Progression<Double, String>{ (_, c) in c(.right(.success("apple"))) }

    progress
      .filter { !$0.contains("a") } //Filter out strings that contain a
      .on{ values.append($0) }
      .replay()

    XCTAssertEqual(values.count, 0)
  }

  func testStamp() {
    var values = [(Int, String)]()
    let progress = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }

    progress
      .stamp{ "\($0)" }
      .on{ values.append($0) }
      .replay()

    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.0, 0)
    XCTAssertEqual(values.last?.1, "0")
  }

  func testTimeStamp() {
    var values = [(Int, Date)]()
    let progress = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }

    progress
      .timeStamp()
      .on{ values.append($0) }
      .replay()

    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.0, 0)
    XCTAssertEqual(values.last?.1.timeIntervalSinceReferenceDate ?? 0, Date.timeIntervalSinceReferenceDate, accuracy: 0.5)
  }

  func testDelay() {
    var values = [Int]()
    let progress = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }

    progress
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
    let progress = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }

    progress
      .start(with: [-3, -2, -1])
      .on{ values.append($0) }
      .replay()

    XCTAssertEqual(values, [-3, -2, -1, 0])
  }

  func testFilledConcat() {
    var values = [Int]()
    let progress = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }

    progress
      .concat([98, 99, 100])
      .on{ values.append($0) }
      .replay()

    XCTAssertEqual(values, [0, 98, 99, 100])
  }

  func testConcat() {
    var values = [Int]()
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let progress = Progression<Double, Int>{ (_, c) in completion = c }

    progress
      .concat([98, 99, 100])
      .on{ values.append($0) }

    completion?(.right(.success(0)))

    XCTAssertEqual(values, [0, 98, 99, 100])
  }

  func testDefaultValue() {
    var values = [Int]()
    var progress = Progression<Double, Int>{ (_, c) in c(.right(.failure(TestError()))) }

    progress
      .defaultValue(0)
      .on{ values.append($0) }
      .replay()

    XCTAssertEqual(values, [0])

    progress = Progression<Double, Int>{ (_, c) in c(.right(.success(1))) }
    values = []

    progress
      .defaultValue(0)
      .on{ values.append($0) }
      .replay()

    XCTAssertEqual(values, [1])
  }

  func testProgressionIntoHotMerge() {
    var values = [Either<String, Int>]()
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let right = Progression<Double, Int>{ (_, c) in completion = c }
    let left = HotInput<String>()
    var term: Termination? = nil
    var error: Error? = nil

    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .onError{ error = $0 }

    completion?(.right(.success(1)))
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
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let left = Progression<Double, Int>{ (_, c) in completion = c }
    let right = HotInput<String>()
    var term: Termination? = nil
    var error: Error? = nil

    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .onError{ error = $0 }

    completion?(.right(.success(1)))
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
    let left = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }
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

  func testMergeWithTwoCompletedProgressions() {
    var values = [Int]()
    let left = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }
    let right = Progression<Double, Int>{ (_, c) in c(.right(.success(1))) }
    var term: Termination? = nil

    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()

    XCTAssertEqual(values, [0], "Both terms are emitted, but only the last term emitted is replayed.")
    XCTAssertEqual(term, .completed)
  }

  func testMergeWithLeftCompletedProgression() {
    var values = [Int]()
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let right = Progression<Double, Int>{ (_, c) in completion = c }
    let left = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }
    var term: Termination? = nil

    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()

    XCTAssertEqual(values, [0], "Left Completed should replay.")
    XCTAssertEqual(term, .completed)

    completion?(.right(.success(1)))

    XCTAssertEqual(values, [0])
    XCTAssertEqual(term, .completed)
  }

  func testMergeWithRightCompletedProgression() {
    var values = [Int]()
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let left = Progression<Double, Int>{ (_, c) in completion = c }
    let right = Progression<Double, Int>{ (_, c) in c(.right(.success(0))) }
    var term: Termination? = nil

    left
      .merge(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()

    XCTAssertEqual(values, [0], "Right Completed should replay.")
    XCTAssertEqual(term, .completed)

    completion?(.right(.success(1)))

    XCTAssertEqual(values, [0])
    XCTAssertEqual(term, .completed)
  }

  func testZipBothProgressionCompleted() {
    var values = [(left: Int, right: String)]()
    let left = Progression<Double, Int>{ (_, c) in c(.right(.success(1))) }
    let right = Progression<Double, String>{ (_, c) in c(.right(.success("one"))) }
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

  func testZipLeftProgressionCompleted() {
    var values = [(left: Int, right: String)]()
    var completion: ((Either<ProgressEvent<Double>, Result<String>>) -> Void)?
    let right = Progression<Double, String>{ (_, c) in completion = c }
    let left = Progression<Double, Int>{ (_, c) in c(.right(.success(1))) }
    var term: Termination? = nil

    left
      .zip(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()

    XCTAssertEqual(values.count, 0)

    completion?(.right(.success("one")))

    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    XCTAssertEqual(term, .completed)
  }

  func testZipRightProgressionCompleted() {
    var values = [(left: Int, right: String)]()
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let left = Progression<Double, Int>{ (_, c) in completion = c }
    let right = Progression<Double, String>{ (_, c) in c(.right(.success("one"))) }
    var term: Termination? = nil

    left
      .zip(right)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }
      .replay()

    XCTAssertEqual(values.count, 0)

    completion?(.right(.success(1)))

    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values.last?.left, 1)
    XCTAssertEqual(values.last?.right, "one")
    XCTAssertEqual(term, .completed)
  }

  func testCombine() {
    var values = [(left: Int, right: String)]()
    let left = Progression<Double, Int>{ (_, c) in c(.right(.success(1))) }
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
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let stream = Progression<Double, Int>{ (_, c) in completion = c }
    var term: Termination? = nil

    stream
      .doWhile{ $0 < 10 }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    completion?(.right(.success(10)))
    XCTAssertEqual(values, [])
    XCTAssertEqual(term, .cancelled)
  }

  func testWhileCompleted() {
    var values = [Int]()
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let stream = Progression<Double, Int>{ (_, c) in completion = c }
    var term: Termination? = nil

    stream
      .doWhile{ $0 < 10 }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    completion?(.right(.success(9)))
    XCTAssertEqual(values, [9])
    XCTAssertEqual(term, .completed)
  }

  func testUntil() {
    var values = [Int]()
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let stream = Progression<Double, Int>{ (_, c) in completion = c }
    var term: Termination? = nil

    stream
      .until{ $0 == 10 }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    completion?(.right(.success(10)))
    XCTAssertEqual(values, [])
    XCTAssertEqual(term, .cancelled)
  }

  func testUntilCompleted() {
    var values = [Int]()
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let stream = Progression<Double, Int>{ (_, c) in completion = c }
    var term: Termination? = nil

    stream
      .until{ $0 == 10 }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    completion?(.right(.success(9)))
    XCTAssertEqual(values, [9])
    XCTAssertEqual(term, .completed)
  }

  func testUntilTermination(){
    var values = [Int]()
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let stream = Progression<Double, Int>{ (_, c) in completion = c }
    var term: Termination? = nil

    stream
      .until{ value -> Termination? in
        return value == 10 ? .cancelled : nil
      }
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    completion?(.right(.success(10)))
    XCTAssertEqual(values, [])

    XCTAssertEqual(term, .cancelled)
  }

  func testUsing() {
    var values = [Int]()
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let stream = Progression<Double, Int>{ (_, c) in completion = c }
    var term: Termination? = nil
    var object: TestClass? = TestClass()

    stream
      .using(object!)
      .on{ values.append($0.1) }
      .onTerminate{ term = $0 }

    object = nil

    wait(for: 0.1) // Allow the object to deinit

    completion?(.right(.success(1)))
    XCTAssertEqual(values, [])
    XCTAssertEqual(term, .cancelled)
  }

  func testUsingComplete() {
    var values = [Int]()
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let stream = Progression<Double, Int>{ (_, c) in completion = c }
    var term: Termination? = nil
    var object: TestClass? = TestClass()

    stream
      .using(object!)
      .on{ values.append($0.1) }
      .onTerminate{ term = $0 }

    completion?(.right(.success(1)))
    object = nil

    wait(for: 0.1) // Allow the object to deinit

    XCTAssertEqual(values, [1])
    XCTAssertEqual(term, .completed)
  }

  func testLifeOf() {
    var values = [Int]()
    var completion: ((Either<ProgressEvent<Double>, Result<Int>>) -> Void)?
    let progress = Progression<Double, Int>{ (_, c) in completion = c }
    var term: Termination? = nil
    var object: TestClass? = TestClass()

    progress
      .lifeOf(object!)
      .on{ values.append($0) }
      .onTerminate{ term = $0 }

    XCTAssertNotNil(completion)
    object = nil

    wait(for: 0.1) // Allow the object to deinit

    completion?(.right(.success(1)))
    XCTAssertEqual(values, [])
    XCTAssertEqual(term, .cancelled)
  }

}
