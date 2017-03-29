//
//  Cache.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/28/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/// Base Cache that
open class Cache<Key: Hashable, Value> {
  open func set(value: Value, forKey key: Key) { }
  open func removeValue(forKey: Key) { }
  open func getValue(forKey: Key) -> Value? { return nil }
  
  public subscript(key: Key) -> Value? {
    get { return getValue(forKey: key) }
    set(value) {
      if let value = value {
        set(value: value, forKey: key)
      } else {
        removeValue(forKey: key)
      }
    }
  }
  
}
