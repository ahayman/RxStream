//
//  ThrottleTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/27/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
@testable import Rx

class ThrottleTests: XCTestCase {
  
  func testTimedThrottleLastWork() {
    var completions = [String:() -> Void]()
    var keys = [String]()
    var drops = [String]()
    let throttle = TimedThrottle(interval: 0.1, delayFirst: true)
    
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[0])
        return
      }
      completions[keys[0]] = completion
    }
    
    XCTAssertEqual(completions.count, 0, "Work should be delayed")
    
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[1])
        return
      }
      completions[keys[1]] = completion
    }
    
    XCTAssertEqual(completions.count, 0, "Work should be delayed")
    XCTAssertEqual(drops, [keys[0]], "First work should be dropped")
    
    wait(for: 0.1)
    
    XCTAssertEqual(completions.count, 1, "Only 1 work should pass through the throttle.")
    XCTAssertNotNil(completions[keys[1]], "The last work should execute.  The prior work should have been discarded.")
    completions[keys[1]]?()
    
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[2])
        return
      }
      completions[keys[2]] = completion
    }
    
    XCTAssertEqual(completions.count, 1, "Next work should buffer.")
    
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[3])
        return
      }
      completions[keys[3]] = completion
    }
    
    XCTAssertEqual(completions.count, 1, "Next work should buffer.")
    XCTAssertEqual(drops, [keys[0], keys[2]], "Pending work should drop.")
    
    wait(for: 0.1)
    
    XCTAssertEqual(completions.count, 2, "Next work should pass through the throttle.")
    XCTAssertNotNil(completions[keys[3]], "The last work should execute.")
  }
  
  func testTimeThrottleFirstFire() {
    var completions = [String:() -> Void]()
    var keys = [String]()
    let throttle = TimedThrottle(interval: 0.1, delayFirst: false)
    
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else { return }
      completions[keys[0]] = completion
    }
    
    XCTAssertEqual(completions.count, 1, "First Work should not be delayed")
    completions[keys[0]]?()
    
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else { return }
      completions[keys[1]] = completion
    }
    
    XCTAssertEqual(completions.count, 1, "Next Work should be delayed.")
    
    wait(for: 0.1)
    
    XCTAssertEqual(completions.count, 2, "Second work should pass through the throttle.")
    XCTAssertNotNil(completions[keys[1]], "The next work should execute.")
  }
  
  func testPressureThrottleLimit() {
    var completions = [String:() -> Void]()
    var keys = [String]()
    var drops = [String]()
    let throttle = PressureThrottle(buffer: 0, limit: 2)
    
    // Pressure: 1
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[0])
        return
      }
      completions[keys[0]] = completion
    }
    
    XCTAssertEqual(completions.count, 1, "First Work within limit should execute.")
    XCTAssertNotNil(completions[keys[0]], "Verify correct work executed.")
    XCTAssertEqual(drops, [])
    
    // Pressure: 2
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[1])
        return
      }
      completions[keys[1]] = completion
    }
    
    XCTAssertEqual(completions.count, 2, "Second Work within limit should execute.")
    XCTAssertNotNil(completions[keys[1]], "Verify correct work executed.")
    XCTAssertEqual(drops, [])
    
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[2])
        return
      }
      completions[keys[2]] = completion
    }
    
    XCTAssertEqual(completions.count, 2, "Third Work within exceeds limit shouldn't execute.")
    XCTAssertNil(completions[keys[2]], "Verify correct work executed.")
    XCTAssertEqual(drops, [keys[2]])
    
    // Pressure: 1
    completions[keys[0]]?()
    
    XCTAssertEqual(completions.count, 2, "Third Work shouldn't be buffered. Shouldn't execute.")
    XCTAssertNil(completions[keys[2]], "Verify correct work executed.")
    XCTAssertEqual(drops, [keys[2]])
    
    // Pressure: 2
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[3])
        return
      }
      completions[keys[3]] = completion
    }
    
    XCTAssertEqual(completions.count, 3, "Fourth Work within limit, should execute.")
    XCTAssertNotNil(completions[keys[3]], "Verify correct work executed.")
    XCTAssertEqual(drops, [keys[2]])
    
    // Pressure: 1
    completions[keys[1]]?()
    // Pressure: 0
    completions[keys[3]]?()
    
    // Pressure: 1
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[4])
        return
      }
      completions[keys[4]] = completion
    }
    
    XCTAssertEqual(completions.count, 4, "Fourth Work within limit, should execute.")
    XCTAssertNotNil(completions[keys[4]], "Verify correct work executed.")
    XCTAssertEqual(drops, [keys[2]])
    
    // Pressure: 2
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[5])
        return
      }
      completions[keys[5]] = completion
    }
    
    XCTAssertEqual(completions.count, 5, "Fourth Work within limit, should execute.")
    XCTAssertNotNil(completions[keys[5]], "Verify correct work executed.")
    XCTAssertEqual(drops, [keys[2]])
  }
  
  func testPressureThrottleBuffer() {
    var completions = [String:() -> Void]()
    var drops = [String]()
    var keys = [String]()
    let throttle = PressureThrottle(buffer: 2, limit: 1)
    
    // Pressure: 1, Buffer: 0
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[0])
        return
      }
      completions[keys[0]] = completion
    }
    
    XCTAssertEqual(completions.count, 1, "First Work within limit should execute.")
    XCTAssertNotNil(completions[keys[0]], "Verify correct work executed.")
    XCTAssertEqual(drops, [])
    
    // Pressure: 1, Buffer: 1
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[1])
        return
      }
      completions[keys[1]] = completion
    }
    
    XCTAssertEqual(completions.count, 1, "Second Work should be buffered.")
    XCTAssertEqual(drops, [])
    
    // Pressure: 1, Buffer: 2
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[2])
        return
      }
      completions[keys[2]] = completion
    }
    
    XCTAssertEqual(completions.count, 1, "Third Work should be buffered.")
    XCTAssertEqual(drops, [])
    
    // Pressure: 1, Buffer: 2
    keys.append(String.newUUID())
    throttle.process { signal in
      guard case .perform(let completion) = signal else {
        drops.append(keys[3])
        return
      }
      completions[keys[3]] = completion
    }
    XCTAssertEqual(completions.count, 1, "Fourth work should be dropped, exceeds buffer.")
    XCTAssertEqual(drops, [keys[3]])
    
    // Pressure: 1, Buffer: 1
    completions[keys[0]]?()
    
    XCTAssertEqual(completions.count, 2, "Second work should be pulled from buffer and executed.")
    XCTAssertNotNil(completions[keys[1]], "Verify correct work executed.")
    XCTAssertEqual(drops, [keys[3]])
    
    // Pressure: 1, Buffer: 0
    completions[keys[1]]?()
    
    XCTAssertEqual(completions.count, 3, "Third work should be pulled from buffer and executed.")
    XCTAssertNotNil(completions[keys[2]], "Verify correct work executed.")
    XCTAssertEqual(drops, [keys[3]])
    
    // Pressure: 0, Buffer: 0
    completions[keys[2]]?()
    
    XCTAssertEqual(completions.count, 3, "Buffer empty, nothing else should execute. Fourth work should have been dropped.")
    XCTAssertEqual(drops, [keys[3]])
  }
  
}
