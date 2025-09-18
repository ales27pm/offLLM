//
//  MLXEvents.swift
//  monGARS
//
//  React Native event emitter for token streaming.
//

import Foundation
import React

@objc(MLXEvents)
final class MLXEvents: RCTEventEmitter {

  // RN requires this for Swift modules
  @objc override static func requiresMainQueueSetup() -> Bool { false }

  // Single shared instance for convenience
  @MainActor static var shared: MLXEvents?

  override init() {
    super.init()
    MLXEvents.shared = self
  }

  deinit {
    if MLXEvents.shared === self { MLXEvents.shared = nil }
  }

  override func supportedEvents() -> [String]! {
    return ["mlxToken", "mlxCompleted", "mlxError", "mlxStopped"]
  }

  // Convenience senders
  @MainActor func emitToken(_ text: String) {
    sendEvent(withName: "mlxToken", body: ["text": text])
  }

  @MainActor func emitCompleted() {
    sendEvent(withName: "mlxCompleted", body: nil)
  }

  @MainActor func emitError(_ code: String, message: String) {
    sendEvent(withName: "mlxError", body: ["code": code, "message": message])
  }

  @MainActor func emitStopped() {
    sendEvent(withName: "mlxStopped", body: nil)
  }
}
