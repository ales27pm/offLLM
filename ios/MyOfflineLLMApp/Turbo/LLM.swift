import Foundation
import React
import AppSpec // exposes LLMSpec

@objc(LLM)
class LLM: NSObject, LLMSpec {
  private var isModelLoaded = false

  func loadModel(_ path: String, options: [AnyHashable: Any]?, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    let exists = FileManager.default.fileExists(atPath: path)
    isModelLoaded = exists
    resolve(exists)
  }
  func unloadModel(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) { isModelLoaded = false; resolve(true) }
  func generate(_ prompt: String, options: [AnyHashable : Any]?, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
    guard isModelLoaded else { resolve(""); return }
    resolve(prompt) // placeholder
  }
  func embed(_ text: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) { resolve([Double]()) }
  func getPerformanceMetrics(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) { resolve(["memoryUsage": 0.5, "cpuUsage": 0.5]) }
  func getKVCacheSize(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) { resolve(0) }
  func getKVCacheMaxSize(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) { resolve(0) }
  func clearKVCache(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) { resolve(nil) }
  func addMessageBoundary(_ resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) { resolve(nil) }
  func adjustPerformanceMode(_ mode: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) { resolve(true) }
}
