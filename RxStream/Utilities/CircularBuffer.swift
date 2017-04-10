//
//  CircularBuffer.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/9/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
 A very simple Circular Buffer designed to hold and return a statically limited number of elements without allocating, shifting or moving memory after the buffer has been initialized.
 
 Data can be iterated, accessed and appended. The size of the buffer can't change and data cannot be deleted from the buffer.
 */
struct CircularBuffer<Element> : RandomAccessCollection {
  typealias Indices = DefaultRandomAccessIndices<CircularBuffer<Element>>

  /// Privately, we use a simple fixed array to store the collection and replace elements as needed, keeping track of the head index.
  private var buffer: [Element] = []
  
  /// The size of the buffer.
  let size: Int
  
  /// The current head index. -1 when the buffer is empty, otherwise it points to the start of the current buffer.
  private var head: Int = -1
  
  var count: Int { return buffer.count }
  var startIndex: Int { return 0 }
  var endIndex: Int { return buffer.endIndex }
  
  /**
   Initialize the buffer with a size and optionally an initial set of data.
   
   - parameters:
     - size: The size of the buffer.  Cannot be changed after initialization.
     - data: _(Optional)_.  Provide an initial set of data to fill the buffer with. If you provide data that is larger than the buffer, only the last `n == size` elements will be added to the buffer.
  
   - returns: A new CircularBuffer
  */
  init(size: Int, data: [Element]? = nil) {
    self.size = Swift.max(1, size)
    // Fill buffer if data is provided
    if let newData = data {
      switch newData.count {
      case 0: break
      case 1...size:
        buffer = newData
        head = 0
      default:
        buffer = newData[(newData.count - size)..<newData.count].map{ $0 }
        head = 0
      }
    }
    self.buffer.reserveCapacity(self.size)
  }
  
  /**
   Retrieve an element from the buffer by index.
   
   - parameter index: The index of the element you wish to retrieve.  If you provide an index outside of the buffer range, a fatal error will be thrown.
   
   - returns: The element at the specified index.
   */
  subscript(index: Int) -> Element {
    guard index < buffer.count else { fatalError("CircularBuffer: Index outside of buffer range.") }
    guard buffer.count >= size else { return buffer[index] }
    let offset = head + index
    if offset < size {
      return buffer[offset]
    } else {
      return buffer[offset % size]
    }
  }
  
  /**
   Append a new element to the buffer.
   If the buffer is full, the element will overwrite the oldest element in the buffer.  
   Otherwise, the element will be appended to the current buffer data.
   
   - parameter element: The element to add.
   */
  mutating func append(_ element: Element) {
    switch (head, buffer.count) {
    case (_, 0..<size):
      buffer.append(element)
      head = 0
    case (0..<size - 1, _):
      buffer[head] = element
      head += 1
    case (size - 1, _):
      buffer[head] = element
      head = 0
    default: fatalError("Internal Error: Either the buffer has overflown or the head is out of range.")
    }
  }
  
  func index(after i: Int) -> Int {
    return i + 1
  }

  func index(before i: Int) -> Int {
    return i - 1
  }

}
