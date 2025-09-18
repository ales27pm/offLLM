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
  @MainActor private static weak var sharedStorage: MLXEvents?

  @MainActor static var shared: MLXEvents? {
    get { sharedStorage }
    set { sharedStorage = newValue }
  }

  override init() {
    super.init()
    Task { [weak self] @MainActor in
      guard let self else { return }
      MLXEvents.shared = self
    }
  }

  deinit {
    Task { [weak self] @MainActor in
      guard let self else { return }
      if MLXEvents.shared === self { MLXEvents.shared = nil }
    }
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
