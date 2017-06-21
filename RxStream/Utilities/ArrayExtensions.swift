//
//  ArrayExtensions.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/23/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

extension Array {
  
  /// Iterate through the array searching for an element that returns true from the handler and return the index of that item.
  func indexOf(_ handler: (Element) -> Bool) -> Index? {
    for (index, element) in self.enumerated() where handler(element) {
      return index
    }
    return nil
  }

  /// This will take elements from the array until the handler returns `true`, at which point it will return a new array with the taken elements.
  func takeUntil(_ handler: (Element) -> Bool) -> [Element] {
    var elements = [Element]()
    for element in self {
      if !handler(element) {
        elements.append(element)
      } else {
        break
      }
    }
    return elements
  }

  /**
  Convenience variable that only returns the array if the array has an item in it (is filled).  Otherwise, it returns nil.
  It's mostly used as a convenience for Optional Binding.  Very useful when you need to only bind an array if it has items in it.
  */
  var filled: Array? {
    return self.count > 0 ? self : nil
  }

}

extension Array where Element : Equatable {

  func removing(_ elements: [Element]) -> [Element] {
    return self.filter { !elements.contains($0) }
  }

}
