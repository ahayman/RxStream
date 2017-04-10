//
//  ArrayExtensions.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/23/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

extension Array where Element: EventValue {
  
  /// Convenience to extract the value from the last event in the array that has a valid `.next(value)`
  var lastEventValue: Element.Value? {
    return self.reversed().first(where: { $0.eventValue != nil })?.eventValue
  }
  
  /// Convenience to extract the value from the first event in the array that has a valid `.next(value)`
  var firstEventValue: Element.Value? {
    return self.first(where: { $0.eventValue != nil })?.eventValue
  }
  
  var termination: Termination? {
    return self.first(where: { $0.termination != nil })?.termination
  }
  
}

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
