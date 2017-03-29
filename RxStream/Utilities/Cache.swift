//
//  Cache.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/28/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/** 
 Base Abstract class for Caches. Does not work on it's own and should be sublcassed to provide specific implementations.
 A cache should take a values for a key and store them according to their own specific rules.
 All sublcasses should override:
 
  - `set(value: Value, forKey: Key)` : Used to add a new value to the cache with the specified key
  - `getValue(forKey: Key) -> Value?` : Used to retrieve a value from the cache for the provided key
  - `removeValue(forKey: Key)` : Used to remove values from the cache.
 
 */
open class Cache<Key, Value> {
  
  open func set(value: Value, forKey key: Key) { }
  open func getValue(forKey key: Key) -> Value? { return nil }
  open func removeValue(forKey key: Key) { }
  
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

/**
 A TimedCache will retain values added to it for only a specific amount of time, after which the values will be removed.
 */
public class TimedCache<Key: Hashable, Value> : Cache<Key, Value> {
  
  /// We need the lock queue separately to used a delayed Dispatch for removing expired values
  private let lockQueue = Queue.custom(CustomQueue(type: .serial, name: "TimedCacheSync"))
  
  /// Create
  private lazy var lockDispatch: Dispatch = Dispatch.sync(on: self.lockQueue)
  
  /// The expiry timeout for values.
  private let timeout: TimeInterval
  
  /// Cache holds a timer and the value.  Timer is needed so we can terminate it if the value is updated or removed.
  private var cache = [Key:(timer: Timer, value: Value)]()
  
  /**
   Initialize the Cache with a timeout.  Every time a value is added to the cache, the value will be automatically removed
   */
  public init(timeout: TimeInterval) {
    self.timeout = timeout
  }
  
  public override func set(value: Value, forKey key: Key) {
    lockDispatch.execute {
      self.cache[key]?.timer.terminate(withReason: .cancelled)
      let timer = Timer(interval: self.timeout)
      timer
        .first(then: .completed)
        .dispatch(.sync(on: self.lockQueue)).on{ [weak self] in
          self?.cache[key] = nil
        }
      self.cache[key] = (timer, value)
    }
  }
  
  
  public override func getValue(forKey key: Key) -> Value? {
    var value: Value? = nil
    lockDispatch.execute {
      value = self.cache[key]?.value
    }
    return value
  }
  
  public override func removeValue(forKey key: Key) {
    lockDispatch.execute {
      self.cache[key]?.timer.terminate(withReason: .cancelled)
      self.cache[key] = nil
    }
  }
  
}
