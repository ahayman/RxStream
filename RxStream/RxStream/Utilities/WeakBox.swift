//
//  WeakBox.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/9/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
 A simple wrapper to encapsulate a weak object.  Largely used when capturing a weak object in a closure or function.
 */
class WeakBox<T: AnyObject> {
  
  weak var object: T?
  
  init(_ object: T) {
    self.object = object
  }
}
