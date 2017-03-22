//
//  WeakBox.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/9/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

class WeakBox<T: AnyObject> {
  weak var object: T?
  
  init(_ object: T) {
    self.object = object
  }
}
