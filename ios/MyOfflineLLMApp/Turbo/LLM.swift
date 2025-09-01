import Foundation
import Darwin
// React types are exposed via the bridging header; no Swift module import
// is required here.

/// A lightweight protocol that describes the surface area of our LLM
/// TurboModule.  In the original project this protocol is generated
/// automatically by the React Native codegen and lives in a separate
/// file (`LLMSpec`).  When the generated file is missing or fails to
/// build the compiler will emit an error like
/// “cannot find type `LLMSpec` in scope”.  Defining the protocol
/// ourselves ensures the module still compiles and provides a clear
/// contract for the methods we expose to JavaScript.  If a generated
/// version exists it will override this one at compile time.
@objc public protocol LLMSpec {
  @objc(loadModel:options:resolve:reject:)
  func loadModel(_ path: String,
                 options: [AnyHashable : Any]?,
                 resolve: @escaping RCTPromiseResolveBlock,
                 reject: @escaping RCTPromiseRejectBlock)

  @objc(unloadModel:reject:)
  func unloadModel(_ resolve: @escaping RCTPromiseResolveBlock,
                   reject: @escaping RCTPromiseRejectBlock)

  @objc(generate:options:resolve:reject:)
  func generate(_ prompt: String,
                options: [AnyHashable : Any]?,
                resolve: @escaping RCTPromiseResolveBlock,
                reject: @escaping RCTPromiseRejectBlock)

  @objc(embed:resolve:reject:)
  func embed(_ text: String,
             resolve: @escaping RCTPromiseResolveBlock,
             reject: @escaping RCTPromiseRejectBlock)

  @objc(getPerformanceMetrics:reject:)
  func getPerformanceMetrics(_ resolve: @escaping RCTPromiseResolveBlock,
                             reject: @escaping RCTPromiseRejectBlock)

  @objc(getKVCacheSize:reject:)
  func getKVCacheSize(_ resolve: @escaping RCTPromiseResolveBlock,
                      reject: @escaping RCTPromiseRejectBlock)

  @objc(getKVCacheMaxSize:reject:)
  func getKVCacheMaxSize(_ resolve: @escaping RCTPromiseResolveBlock,
                         reject: @escaping RCTPromiseRejectBlock)

  @objc(clearKVCache:reject:)
  func clearKVCache(_ resolve: @escaping RCTPromiseResolveBlock,
                    reject: @escaping RCTPromiseRejectBlock)

  @objc(addMessageBoundary:reject:)
  func addMessageBoundary(_ resolve: @escaping RCTPromiseResolveBlock,
                          reject: @escaping RCTPromiseRejectBlock)

  @objc(adjustPerformanceMode:resolve:reject:)
  func adjustPerformanceMode(_ mode: String,
                             resolve: @escaping RCTPromiseResolveBlock,
                             reject: @escaping RCTPromiseRejectBlock)
}

/// The concrete implementation of our LLM TurboModule.  This class
/// conforms to the `LLMSpec` protocol defined above and exposes
/// asynchronous methods to JavaScript.  The methods here are
/// intentionally simple placeholders: `loadModel` checks that a
/// directory exists on disk, `generate` echoes its prompt back, and
/// various getter methods return stubbed metrics.  The real
/// functionality can be filled in later once the native ML model
/// integration is ready.
@objc(LLM)
public final class LLM: NSObject, LLMSpec {
  /// Path to the currently loaded model, if any.  Loading a model
  /// simply records the folder’s existence; no heavy parsing is
  /// performed.  When this property is `nil` the module behaves as
  /// though no model is loaded.
  private var modelPath: String? = nil

  /// Simple in-memory key/value cache used by the `generate` method to
  /// memoise prompts and their outputs.  This illustrates a robust
  /// implementation of caching without relying on external ML
  /// libraries.
  private var kvCache: [String: String] = [:]

  public func loadModel(_ path: String,
                        options: [AnyHashable : Any]?,
                        resolve: @escaping RCTPromiseResolveBlock,
                        reject: @escaping RCTPromiseRejectBlock) {
    // Check that the directory exists on disk.  If it does, record the
    // path as the current model.  You could extend this to read
    // configuration files or model metadata from within the folder.
    let exists = FileManager.default.fileExists(atPath: path)
    if exists {
      self.modelPath = path
      self.kvCache.removeAll()
      resolve(true)
    } else {
      self.modelPath = nil
      resolve(false)
    }
  }

  public func unloadModel(_ resolve: @escaping RCTPromiseResolveBlock,
                          reject: @escaping RCTPromiseRejectBlock) {
    // Clear the loaded model and any cached state.
    self.modelPath = nil
    self.kvCache.removeAll()
    resolve(true)
  }

  public func generate(_ prompt: String,
                       options: [AnyHashable : Any]?,
                       resolve: @escaping RCTPromiseResolveBlock,
                       reject: @escaping RCTPromiseRejectBlock) {
    guard let _ = self.modelPath else {
      // When no model is loaded return an empty string.  This avoids
      // undefined behaviour and aligns with the Android implementation.
      resolve("")
      return
    }
    // If we’ve already generated a response for this prompt return
    // the cached result immediately.  This prevents repeated
    // computation for identical inputs.
    if let cached = kvCache[prompt] {
      resolve(cached)
      return
    }
    // A very simple generation algorithm: reverse the prompt and
    // prefix it with a descriptive string.  In a real implementation
    // you would call into your ML model here.
    let reply = "Echo: " + String(prompt.reversed())
    // Cache the result for future calls and return it.
    kvCache[prompt] = reply
    resolve(reply)
  }

  public func embed(_ text: String,
                    resolve: @escaping RCTPromiseResolveBlock,
                    reject: @escaping RCTPromiseRejectBlock) {
    // Produce a simple embedding by converting the first 64 UTF‑8 code
    // points of the string into double values and normalising them.
    let scalars = text.unicodeScalars.prefix(64)
    let maxCode = Double(0x10FFFF)
    let vector = scalars.map { Double($0.value) / maxCode }
    resolve(vector)
  }

  public func getPerformanceMetrics(_ resolve: @escaping RCTPromiseResolveBlock,
                                    reject: @escaping RCTPromiseRejectBlock) {
    // Compute memory usage ratio using mach APIs.  This returns the
    // fraction of physical memory currently used by the process.
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let kerr = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    let memoryUsageRatio: Double
    if kerr == KERN_SUCCESS {
      let usedBytes = Double(info.resident_size)
      let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
      memoryUsageRatio = totalBytes > 0 ? usedBytes / totalBytes : 0.0
    } else {
      memoryUsageRatio = 0.0
    }
    // CPU usage is not trivial to compute precisely without private
    // APIs.  For robustness we return `0` here.  You could replace
    // this with a more sophisticated implementation if needed.
    let cpuUsageRatio: Double = 0.0
    resolve(["memoryUsage": memoryUsageRatio, "cpuUsage": cpuUsageRatio])
  }

  public func getKVCacheSize(_ resolve: @escaping RCTPromiseResolveBlock,
                             reject: @escaping RCTPromiseRejectBlock) {
    resolve(kvCache.count)
  }

  public func getKVCacheMaxSize(_ resolve: @escaping RCTPromiseResolveBlock,
                                reject: @escaping RCTPromiseRejectBlock) {
    // For this simple implementation we don’t enforce a maximum size.
    resolve(Int.max)
  }

  public func clearKVCache(_ resolve: @escaping RCTPromiseResolveBlock,
                           reject: @escaping RCTPromiseRejectBlock) {
    kvCache.removeAll()
    resolve(true)
  }

  public func addMessageBoundary(_ resolve: @escaping RCTPromiseResolveBlock,
                                 reject: @escaping RCTPromiseRejectBlock) {
    // In a real chat model you might use this to separate messages.
    // Here it does nothing but return true.
    resolve(true)
  }

  public func adjustPerformanceMode(_ mode: String,
                                    resolve: @escaping RCTPromiseResolveBlock,
                                    reject: @escaping RCTPromiseRejectBlock) {
    // Accept one of a handful of predefined strings and ignore the rest.
    let validModes: Set<String> = ["high_quality", "balanced", "low_power"]
    resolve(validModes.contains(mode))
  }
}