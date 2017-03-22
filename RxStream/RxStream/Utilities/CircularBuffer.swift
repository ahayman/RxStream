//
//  CircularBuffer.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/9/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

struct CircularBuffer<T> : Collection {
  private var buffer: [T] = []
  private let size: Int
  private var head: Int = -1
  
  var count: Int { return buffer.count }
  var startIndex: Int { return 0 }
  var endIndex: Int { return buffer.endIndex }
  
  init(size: Int, data: [T]? = nil) {
    self.size = Swift.max(1, size)
    self.buffer.reserveCapacity(self.size)
  }
  
  subscript(index: Int) -> T {
    guard index < size else { fatalError() }
    guard buffer.count >= size else { return buffer[index] }
    let offset = head + index
    if offset < size {
      return buffer[offset]
    } else {
      return buffer[offset % size]
    }
  }
  
  mutating func append(_ item: T) {
    switch (head, buffer.count) {
    case (_, 0..<size):
      buffer.append(item)
      head = 0
    case (0..<size - 1, _):
      buffer[head] = item
      head += 1
    case (size - 1, _):
      buffer[head] = item
      head = 0
    default: fatalError("Internal Error: Either the buffer has overflown or the head is out of range.")
    }
  }
  
  func index(after i: Int) -> Int {
    return i + 1
  }
  
}
