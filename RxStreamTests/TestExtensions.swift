//
//  TextExtensions.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/21/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
import Rx

struct TestError : Error { }

extension XCTestCase {
  
  /**
   Use to wait for the provided time interval. Primarily used to flatten out Unit Tests and make the more readable and easier to write.
   
   - parameter for: The time interval to wait
   */
  func wait(for wait: TimeInterval) {
    let waitExpectation = expectation(description: "Wait for \(wait) seconds.  If this times out, then consider increasing the tolerance. ")
    Dispatch.after(delay: wait, on: .main).execute {
      waitExpectation.fulfill()
    }
    waitForExpectations(timeout: wait + 10.0, handler: nil)
  }
    
}
