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
