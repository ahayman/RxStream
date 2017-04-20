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

}

extension Array where Element : Equatable {

  func removing(_ elements: [Element]) -> [Element] {
    return self.filter { !elements.contains($0) }
  }

}
