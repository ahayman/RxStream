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
  indirect case key(String, next: EventKey) /// The event is keyed and should only travel down branches with that key
  case share /// The event should travel down all branches.
  case end /// The event should end here
}
