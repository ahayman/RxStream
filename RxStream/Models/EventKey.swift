//
//  EventKey.swift
//  RxStream
//
//  Created by Aaron Hayman on 4/20/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/// Determines how events travel down their branches.
enum EventKey {
  case keyed(String) /// The event is keyed and should only travel down branches with that key
  case shared(String) /// The event is keyed, but should travel down all branches.
  case none /// The event is not keyed and should travel down all branches.
  
  var key: String? {
    switch self {
    case let .keyed(key): return key
    case let .shared(key): return key
    default: return nil
    }
  }
}
