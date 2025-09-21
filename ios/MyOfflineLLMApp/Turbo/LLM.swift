import Foundation
import Darwin
import React

/// A lightweight protocol that mirrors the generated React Native TurboModule
/// spec for the LLM bridge. When codegen outputs its own interface it will
/// replace this declaration automatically, but providing a local version keeps
/// the Swift compilation stable when the generated header is absent.
@objc public protocol LLMSpec {
  @objc(loadModel:options:resolve:reject:)
  func loadModel(_ path: String,
                 options: [AnyHashable: Any]?,
                 resolve: @escaping RCTPromiseResolveBlock,
                 reject: @escaping RCTPromiseRejectBlock)

  @objc(generate:options:resolve:reject:)
  func generate(_ prompt: String,
                options: [AnyHashable: Any]?,
                resolve: @escaping RCTPromiseResolveBlock,
                reject: @escaping RCTPromiseRejectBlock)

  @objc(unloadModel:resolve:reject:)
  func unloadModel(_ resolve: @escaping RCTPromiseResolveBlock,
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
/// intentionally lightweight: `loadModel` validates that a
/// directory exists on disk, `generate` synthesises a structured
/// response with deterministic metadata, and the remaining methods
/// expose cache statistics and runtime metrics so the JavaScript side
/// can make informed decisions.
@MainActor
@objc(LLM)
public final class LLM: NSObject, LLMSpec {
  private struct GenerationOptions: Hashable, Sendable {
    enum CachePolicy: String, Sendable {
      case automatic
      case bypass
    }

    let maxTokens: Int
    let temperature: Double
    let topK: Int?
    let topP: Double?
    let stopSequences: [String]
    let cachePolicy: CachePolicy

    init(raw: [AnyHashable: Any]?) {
      var tokens = 256
      var temp = 0.7
      var topKValue: Int? = nil
      var topPValue: Double? = nil
      var stops: [String] = []
      var policy: CachePolicy = .automatic

      if let raw {
        if let value = GenerationOptions.doubleValue(from: raw["maxTokens"]) {
          tokens = max(1, min(Int(value.rounded()), 4096))
        }
        if let value = GenerationOptions.doubleValue(from: raw["temperature"]) {
          temp = max(0.0, min(value, 2.0))
        }
        if let value = GenerationOptions.doubleValue(from: raw["topK"]) {
          let candidate = Int(value.rounded())
          topKValue = candidate >= 0 ? candidate : nil
        }
        if let value = GenerationOptions.doubleValue(from: raw["topP"]) {
          topPValue = max(0.0, min(value, 1.0))
        }
        if let stopValue = raw["stop"] {
          stops = GenerationOptions.stopList(from: stopValue)
        }
        if let rawPolicy = raw["cachePolicy"] as? String {
          let normalised = rawPolicy
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
          if let parsed = CachePolicy(rawValue: normalised) {
            policy = parsed
          } else if ["no_cache", "skip", "none"].contains(normalised) {
            policy = .bypass
          }
        }
      }

      self.maxTokens = tokens
      self.temperature = temp
      self.topK = topKValue
      self.topP = topPValue
      self.stopSequences = stops
      self.cachePolicy = policy
    }

    private static func doubleValue(from value: Any?) -> Double? {
      switch value {
      case let number as NSNumber:
        return number.doubleValue
      case let string as NSString:
        return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
      case let string as String:
        return Double(string.trimmingCharacters(in: .whitespacesAndNewlines))
      default:
        return nil
      }
    }

    private static func stopList(from value: Any) -> [String] {
      if let strings = value as? [String] {
        return strings
          .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty }
      }
      if let rawArray = value as? [Any] {
        return rawArray.compactMap { element -> String? in
          guard let string = element as? String else { return nil }
          let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
          return trimmed.isEmpty ? nil : trimmed
        }
      }
      if let string = value as? String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(",") {
          return trimmed
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        }
        return trimmed.isEmpty ? [] : [trimmed]
      }
      return []
    }
  }

  private struct CacheKey: Hashable, Sendable {
    let prompt: String
    let options: GenerationOptions
  }

  private struct ToolCallSummary: Sendable, Hashable {
    let identifier: String
    let name: String
    let argumentsJSON: String
  }

  private struct GenerationSummary: Sendable {
    struct Usage: Sendable {
      let promptTokens: Int
      let completionTokens: Int
      var totalTokens: Int { promptTokens + completionTokens }
    }

    let text: String
    let finishReason: String
    let toolCalls: [ToolCallSummary]
    let usage: Usage
    let duration: TimeInterval
    let createdAt: Date
  }

  private var loadedModelURL: URL? = nil
  private var cache: [CacheKey: GenerationSummary] = [:]
  private let maxCacheEntries = 50
  private var messageBoundaries: [Date] = []

  @objc(loadModel:options:resolve:reject:)
  public func loadModel(_ path: String,
                        options: [AnyHashable: Any]?,
                        resolve: @escaping RCTPromiseResolveBlock,
                        reject: @escaping RCTPromiseRejectBlock) {
    guard let url = resolveModelURL(from: path) else {
      loadedModelURL = nil
      cache.removeAll()
      resolve(false)
      return
    }

    loadedModelURL = url
    cache.removeAll()
    resolve(true)
  }

  @objc(unloadModel:resolve:reject:)
  public func unloadModel(_ resolve: @escaping RCTPromiseResolveBlock,
                          reject: @escaping RCTPromiseRejectBlock) {
    loadedModelURL = nil
    cache.removeAll()
    resolve(true)
  }

  @objc(generate:options:resolve:reject:)
  public func generate(_ prompt: String,
                       options: [AnyHashable: Any]?,
                       resolve: @escaping RCTPromiseResolveBlock,
                       reject: @escaping RCTPromiseRejectBlock) {
    guard loadedModelURL != nil else {
      resolve("")
      return
    }

    let normalisedOptions = GenerationOptions(raw: options)
    let key = CacheKey(prompt: prompt, options: normalisedOptions)

    if normalisedOptions.cachePolicy != .bypass, let cached = cache[key] {
      resolve(cached.text)
      return
    }

    let start = Date()
    let summary = synthesiseSummary(
      prompt: prompt,
      options: normalisedOptions,
      startedAt: start
    )
    storeSummary(summary, for: key)
    resolve(summary.text)
  }

  @objc(embed:resolve:reject:)
  public func embed(_ text: String,
                    resolve: @escaping RCTPromiseResolveBlock,
                    reject: @escaping RCTPromiseRejectBlock) {
    let scalars = text.unicodeScalars.prefix(64)
    let maxCode = Double(0x10FFFF)
    let vector = scalars.map { Double($0.value) / maxCode }
    resolve(vector)
  }

  @objc(getPerformanceMetrics:reject:)
  public func getPerformanceMetrics(_ resolve: @escaping RCTPromiseResolveBlock,
                                    reject: @escaping RCTPromiseRejectBlock) {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
    let kern = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }

    let memoryUsageRatio: Double
    if kern == KERN_SUCCESS {
      let usedBytes = Double(info.resident_size)
      let totalBytes = Double(ProcessInfo.processInfo.physicalMemory)
      memoryUsageRatio = totalBytes > 0 ? usedBytes / totalBytes : 0.0
    } else {
      memoryUsageRatio = 0.0
    }

    let metrics: [String: Double] = [
      "memoryUsage": memoryUsageRatio,
      "cpuUsage": 0.0,
    ]
    resolve(metrics)
  }

  @objc(getKVCacheSize:reject:)
  public func getKVCacheSize(_ resolve: @escaping RCTPromiseResolveBlock,
                             reject: @escaping RCTPromiseRejectBlock) {
    resolve(cache.count)
  }

  @objc(getKVCacheMaxSize:reject:)
  public func getKVCacheMaxSize(_ resolve: @escaping RCTPromiseResolveBlock,
                                reject: @escaping RCTPromiseRejectBlock) {
    resolve(maxCacheEntries)
  }

  @objc(clearKVCache:reject:)
  public func clearKVCache(_ resolve: @escaping RCTPromiseResolveBlock,
                           reject: @escaping RCTPromiseRejectBlock) {
    cache.removeAll()
    resolve(NSNull())
  }

  @objc(addMessageBoundary:reject:)
  public func addMessageBoundary(_ resolve: @escaping RCTPromiseResolveBlock,
                                 reject: @escaping RCTPromiseRejectBlock) {
    messageBoundaries.append(Date())
    resolve(NSNull())
  }

  @objc(adjustPerformanceMode:resolve:reject:)
  public func adjustPerformanceMode(_ mode: String,
                                    resolve: @escaping RCTPromiseResolveBlock,
                                    reject: @escaping RCTPromiseRejectBlock) {
    let validModes: Set<String> = ["high_quality", "balanced", "low_power"]
    resolve(validModes.contains(mode))
  }

  private func resolveModelURL(from path: String) -> URL? {
    let url = URL(fileURLWithPath: path)
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      return nil
    }
    return url
  }

  private func synthesiseSummary(prompt: String,
                                 options: GenerationOptions,
                                 startedAt: Date) -> GenerationSummary {
    let reversed = String(prompt.reversed())
    var candidate = String(reversed.prefix(options.maxTokens))
    var finishReason = candidate.count < reversed.count ? "length" : "stop"

    let (truncated, didMatchStop) = applyStopSequences(
      to: candidate,
      stops: options.stopSequences
    )
    if didMatchStop {
      candidate = truncated
      finishReason = "stop"
    }

    let decorated = decorateResponse(with: candidate, temperature: options.temperature)
    let usage = GenerationSummary.Usage(
      promptTokens: max(1, estimateTokens(for: prompt)),
      completionTokens: max(1, estimateTokens(for: decorated))
    )
    let duration = max(Date().timeIntervalSince(startedAt), 0)

    return GenerationSummary(
      text: decorated,
      finishReason: finishReason,
      toolCalls: [],
      usage: usage,
      duration: duration,
      createdAt: Date()
    )
  }

  private func decorateResponse(with text: String, temperature: Double) -> String {
    let band: String
    switch temperature {
    case ..<0.3:
      band = "Precise"
    case ..<0.8:
      band = "Balanced"
    default:
      band = "Creative"
    }
    return "(\(band)) Echo: \(text)"
  }

  private func applyStopSequences(to text: String, stops: [String]) -> (String, Bool) {
    guard !stops.isEmpty else {
      return (text, false)
    }

    for stop in stops where !stop.isEmpty {
      if let range = text.range(of: stop) {
        let truncated = String(text[..<range.lowerBound])
        return (truncated, true)
      }
    }
    return (text, false)
  }

  private func estimateTokens(for text: String) -> Int {
    if text.isEmpty {
      return 0
    }
    let words = text.split { $0.isWhitespace || $0.isNewline }
    let approx = max(words.count, text.unicodeScalars.count / 4)
    return max(1, approx)
  }

  private func storeSummary(_ summary: GenerationSummary, for key: CacheKey) {
    cache[key] = summary
    trimCacheIfNeeded()
  }

  private func trimCacheIfNeeded() {
    guard cache.count > maxCacheEntries else { return }
    let sortedEntries = cache.sorted { lhs, rhs in
      lhs.value.createdAt < rhs.value.createdAt
    }
    for entry in sortedEntries.dropFirst(maxCacheEntries) {
      cache.removeValue(forKey: entry.key)
    }
  }
}
