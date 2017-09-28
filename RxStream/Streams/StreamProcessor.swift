//
//  StreamProcessor.swift
//  RxStream
//
//  Created by Aaron Hayman on 3/17/17.
//  Copyright © 2017 Aaron Hayman. All rights reserved.
//

import Foundation

/**
 Stream processor is a base class used to encapsulate the processing that needs to occur on an event before it is passed downstream. 
 This class also allows a stream to query down stream processors whether the processor should be pruned.
 */
class StreamProcessor<T> {
  var stream: CoreStream
  func process(next: Event<T>, withKey key: EventPath) { }
  init(stream: CoreStream) {
    self.stream = stream
  }
}

/**
 A concrete down stream processor that takes an event, processes it with the provided processor and passes that onto the stream.
 Subclasses should override to implement custom processing logic.
 */
class DownstreamProcessor<T, U> : StreamProcessor<T> {
  var downStream: Stream<U>
  var processor: StreamOp<T, U>

  override func process(next: Event<T>, withKey key: EventPath) {
    downStream.process(key: key, next: next, withOp: processor)
  }
  
  init(stream: Stream<U>, processor: @escaping StreamOp<T, U>) {
    self.downStream = stream
    self.processor = processor
    super.init(stream: stream)
    stream.onTerminate = { processor(.terminate(reason: $0), { _ in }) }
  }
  
}
