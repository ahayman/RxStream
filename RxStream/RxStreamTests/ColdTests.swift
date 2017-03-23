//
//  ColdTests.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/22/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import XCTest
import Rx

class ColdTests: XCTestCase {
  
  func testRequestSuccess() {
    var responses = [String]()
    var errors = [Error]()
    var terms = [Termination]()
    let coldTask = Cold { (_, request: Int, response: (Result<Int>) -> Void) in
      response(.success(request + 1))
    }
    
    let cold = coldTask
      .map{ "\($0)" }
      .on{ responses.append($0) }
      .onError{ errors.append($0); return nil }
      .onTerminate{ terms.append($0) }
    
    cold.request(1)
    XCTAssertEqual(responses, ["2"])
    XCTAssertEqual(errors.count, 0)
    XCTAssertEqual(terms, [])
    
    cold.request(2)
    XCTAssertEqual(responses, ["2", "3"])
    XCTAssertEqual(errors.count, 0)
    XCTAssertEqual(terms, [])
    
    cold.request(4)
    XCTAssertEqual(responses, ["2", "3", "5"])
    XCTAssertEqual(errors.count, 0)
    XCTAssertEqual(terms, [])
    
    coldTask.terminate(withReason: .completed)
    XCTAssertEqual(responses, ["2", "3", "5"])
    XCTAssertEqual(errors.count, 0)
    XCTAssertEqual(terms, [.completed])
    XCTAssertEqual(cold.state, .terminated(reason: .completed))
    
    cold.request(5)
    XCTAssertEqual(responses, ["2", "3", "5"])
    XCTAssertEqual(errors.count, 0)
    XCTAssertEqual(terms, [.completed])
    XCTAssertEqual(cold.state, .terminated(reason: .completed))
  }
  
  func testRequestErrors() {
    var responses = [String]()
    var errors = [Error]()
    var terms = [Termination]()
    let coldTask = Cold { (_, request: Int, response: (Result<Int>) -> Void) in
      if request % 2 == 0 {
        response(.success(request + 1))
      } else {
        response(.failure(NSError()))
      }
    }
    
    let cold = coldTask
      .map{ "\($0)" }
      .on{ responses.append($0) }
      .onError{ errors.append($0); return nil }
      .onTerminate{ terms.append($0) }
    
    cold.request(1)
    XCTAssertEqual(responses, [])
    XCTAssertEqual(errors.count, 1)
    XCTAssertEqual(terms, [])
    
    cold.request(2)
    XCTAssertEqual(responses, ["3"])
    XCTAssertEqual(errors.count, 1)
    XCTAssertEqual(terms, [])
    
    cold.request(4)
    XCTAssertEqual(responses, ["3", "5"])
    XCTAssertEqual(errors.count, 1)
    XCTAssertEqual(terms, [])
    
    cold.request(7)
    XCTAssertEqual(responses, ["3", "5"])
    XCTAssertEqual(errors.count, 2)
    XCTAssertEqual(terms, [])
    
    coldTask.terminate(withReason: .completed)
    XCTAssertEqual(responses, ["3", "5"])
    XCTAssertEqual(errors.count, 2)
    XCTAssertEqual(terms, [.completed])
    XCTAssertEqual(cold.state, .terminated(reason: .completed))
    
    cold.request(5)
    XCTAssertEqual(responses, ["3", "5"])
    XCTAssertEqual(errors.count, 2)
    XCTAssertEqual(terms, [.completed])
    XCTAssertEqual(cold.state, .terminated(reason: .completed))
  }
  
  func testBranchIsolation() {
    let coldTask = Cold { (_, request: Int, response: (Result<Int>) -> Void) in
      if request % 2 == 0 {
        response(.success(request + 1))
      } else {
        response(.failure(NSError()))
      }
    }
    
    var branchAResponses = [String]()
    var branchAErrors = [Error]()
    var branchATerms = [Termination]()
    let branchA = coldTask
      .map{ "\($0)" }
      .on{ branchAResponses.append($0) }
      .onError{ branchAErrors.append($0); return nil }
      .onTerminate{ branchATerms.append($0) }
    
    var branchBResponses = [String]()
    var branchBErrors = [Error]()
    var branchBTerms = [Termination]()
    let branchB = coldTask
      .map{ "\($0)" }
      .on{ branchBResponses.append($0) }
      .onError{ branchBErrors.append($0); return nil }
      .onTerminate{ branchBTerms.append($0) }
    
    branchA.request(2)
    XCTAssertEqual(branchAResponses, ["3"])
    XCTAssertEqual(branchAErrors.count, 0)
    XCTAssertEqual(branchATerms, [])
    XCTAssertEqual(branchBResponses, [])
    XCTAssertEqual(branchBErrors.count, 0)
    XCTAssertEqual(branchBTerms, [])
    
    branchA.request(3)
    XCTAssertEqual(branchAResponses, ["3"])
    XCTAssertEqual(branchAErrors.count, 1)
    XCTAssertEqual(branchATerms, [])
    XCTAssertEqual(branchBResponses, [])
    XCTAssertEqual(branchBErrors.count, 0)
    XCTAssertEqual(branchBTerms, [])
    
    branchB.request(2)
    XCTAssertEqual(branchAResponses, ["3"])
    XCTAssertEqual(branchAErrors.count, 1)
    XCTAssertEqual(branchATerms, [])
    XCTAssertEqual(branchBResponses, ["3"])
    XCTAssertEqual(branchBErrors.count, 0)
    XCTAssertEqual(branchBTerms, [])
    
    branchB.request(3)
    XCTAssertEqual(branchAResponses, ["3"])
    XCTAssertEqual(branchAErrors.count, 1)
    XCTAssertEqual(branchATerms, [])
    XCTAssertEqual(branchBResponses, ["3"])
    XCTAssertEqual(branchBErrors.count, 1)
    XCTAssertEqual(branchBTerms, [])
    
    coldTask.terminate(withReason: .completed)
    XCTAssertEqual(branchAResponses, ["3"])
    XCTAssertEqual(branchAErrors.count, 1)
    XCTAssertEqual(branchATerms, [.completed])
    XCTAssertEqual(branchBResponses, ["3"])
    XCTAssertEqual(branchBErrors.count, 1)
    XCTAssertEqual(branchBTerms, [.completed])
  }
  
  func testBranchSharing() {
    let coldTask = Cold { (_, request: Int, response: (Result<Int>) -> Void) in
      if request % 2 == 0 {
        response(.success(request + 1))
      } else {
        response(.failure(NSError()))
      }
    }.share(true)
    
    var branchAResponses = [String]()
    var branchAErrors = [Error]()
    var branchATerms = [Termination]()
    let branchA = coldTask
      .map{ "\($0)" }
      .on{ branchAResponses.append($0) }
      .onError{ branchAErrors.append($0); return nil }
      .onTerminate{ branchATerms.append($0) }
    
    var branchBResponses = [String]()
    var branchBErrors = [Error]()
    var branchBTerms = [Termination]()
    let branchB = coldTask
      .map{ "\($0)" }
      .on{ branchBResponses.append($0) }
      .onError{ branchBErrors.append($0); return nil }
      .onTerminate{ branchBTerms.append($0) }
    
    branchA.request(2)
    XCTAssertEqual(branchAResponses, ["3"])
    XCTAssertEqual(branchAErrors.count, 0)
    XCTAssertEqual(branchATerms, [])
    XCTAssertEqual(branchBResponses, ["3"])
    XCTAssertEqual(branchBErrors.count, 0)
    XCTAssertEqual(branchBTerms, [])
    
    branchA.request(3)
    XCTAssertEqual(branchAResponses, ["3"])
    XCTAssertEqual(branchAErrors.count, 1)
    XCTAssertEqual(branchATerms, [])
    XCTAssertEqual(branchBResponses, ["3"])
    XCTAssertEqual(branchBErrors.count, 1)
    XCTAssertEqual(branchBTerms, [])
    
    branchB.request(2)
    XCTAssertEqual(branchAResponses, ["3", "3"])
    XCTAssertEqual(branchAErrors.count, 1)
    XCTAssertEqual(branchATerms, [])
    XCTAssertEqual(branchBResponses, ["3", "3"])
    XCTAssertEqual(branchBErrors.count, 1)
    XCTAssertEqual(branchBTerms, [])
    
    branchB.request(3)
    XCTAssertEqual(branchAResponses, ["3", "3"])
    XCTAssertEqual(branchAErrors.count, 2)
    XCTAssertEqual(branchATerms, [])
    XCTAssertEqual(branchBResponses, ["3", "3"])
    XCTAssertEqual(branchBErrors.count, 2)
    XCTAssertEqual(branchBTerms, [])
    
    coldTask.terminate(withReason: .completed)
    XCTAssertEqual(branchAResponses, ["3", "3"])
    XCTAssertEqual(branchAErrors.count, 2)
    XCTAssertEqual(branchATerms, [.completed])
    XCTAssertEqual(branchBResponses, ["3", "3"])
    XCTAssertEqual(branchBErrors.count, 2)
    XCTAssertEqual(branchBTerms, [.completed])
  }
}
