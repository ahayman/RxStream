//
//  StringExtensions.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/7/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

extension String {
  static func newUUID() -> String {
    return CFUUIDCreateString(nil, CFUUIDCreate(nil)) as String
  }
}
