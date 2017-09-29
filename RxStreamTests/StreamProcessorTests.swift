//
//  StreamProcessorTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 4/21/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

class StreamProcessorTests: XCTestCase {

  func testProcessorDoNothing() {
    let processor = StreamProcessor<Int>(stream: HotInput<Int>())
    processor.process(next: .next(1), withKey: .share)
    XCTAssertTrue(true)
  }

  func testDownStreamProcessorStreamVariable() {
    let stream = HotInput<Int>()
    let processor = DownstreamProcessor<Int, Int>(stream: stream) { _, _ in }

    XCTAssertEqual(stream.id, (processor.stream as! Hot<Int>).id)
  }

  func testDownStreamProcessorWork() {
    var events = [Event<Int>]()
    let stream = HotInput<Int>()
    let processor = DownstreamProcessor<Int, Int>(stream: stream) { event, _ in
      events.append(event)
    }

    processor.process(next: .next(0), withKey: .share)
    XCTAssertEqual(events.count, 1)

    processor.process(next: .next(0), withKey: .share)
    XCTAssertEqual(events.count, 2)
  }


}
