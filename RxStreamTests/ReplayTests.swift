//
//  ReplayTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 5/4/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
import Rx

class ReplayTests: XCTestCase {

  func testReplay() {
    let hot = HotInput<Int>()
    hot.push(0)
    hot.push(1)

    var results = [Int]()
    hot.on{ results.append($0) }.replay()

    XCTAssertEqual(results, [1])
  }

  func testReplayBranchIsolation() {
    let hot = HotInput<Int>()
    hot.push(0)
    hot.push(1)

    var aResults = [Int]()
    var bResults = [Int]()

    let aBranch = hot.on{ aResults.append($0) }
    let bBranch = hot.on{ bResults.append($0) }

    XCTAssertEqual(aResults, [])
    XCTAssertEqual(bResults, [])

    aBranch.replay()
    XCTAssertEqual(aResults, [1])
    XCTAssertEqual(bResults, [])

    bBranch.replay()
    XCTAssertEqual(aResults, [1])
    XCTAssertEqual(bResults, [1])
  }

  func testLongChainReplay() {
    let hot = HotInput<Int>()
    hot.push(0)
    hot.push(1)

    var results = [Int]()
    hot
      .map{ $0 + 1 }
      .map{ $0 - 1 }
      .map{ $0 + 1 }
      .map{ $0 - 1 }
      .on{ results.append($0) }
      .replay()

    XCTAssertEqual(results, [1])
  }

}
