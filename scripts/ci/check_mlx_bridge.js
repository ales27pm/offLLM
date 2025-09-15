#!/usr/bin/env node
/**
 * Quick sanity checks for the MLX RN bridge before we spend minutes archiving.
 * - Verifies presence of Swift + ObjC bridge files.
 * - Verifies RN JS bridge wrapper exists.
 * - Verifies Xcode project references (basic heuristics on pbxproj).
 * - Verifies Podfile / XcodeGen settings (platform iOS 18, Swift 6).
 * - Verifies project.yml contains MLX packages + signing disabled.
 *
 * Exit non-zero with actionable errors so CI can fail fast.
 */

const fs = require("fs");
const path = require("path");

const root = process.cwd();

function mustExist(relPath, label) {
  const p = path.join(root, relPath);
  if (!fs.existsSync(p)) {
    throw new Error(`Missing ${label || relPath} at ${relPath}`);
  }
  return p;
}

function mustContain(filePath, substrings, label) {
  const src = fs.readFileSync(filePath, "utf8");
  for (const s of substrings) {
    if (!src.includes(s)) {
      throw new Error(
        `Expected ${label || path.relative(root, filePath)} to contain: ${s}`,
      );
    }
  }
}

function softCheck(filePath, substrings, label) {
  try {
    mustContain(filePath, substrings, label);
    return true;
  } catch (e) {
    console.warn(`WARN: ${e.message}`);
    return false;
  }
}

function main() {
  const errors = [];

  // --- 1) Files existence checks
  const files = [
    [
      "ios/MyOfflineLLMApp/MLX/MLXModule.swift",
      "Swift bridge (MLXModule.swift)",
    ],
    [
      "ios/MyOfflineLLMApp/MLX/MLXModuleBridge.m",
      "ObjC shim (MLXModuleBridge.m)",
    ],
    ["src/native/MLXModule.ts", "JS wrapper (src/native/MLXModule.ts)"],
    ["src/services/chat/mlxChat.ts", "Chat service (mlxChat.ts)"],
  ];

  for (const [rel, label] of files) {
    try {
      mustExist(rel, label);
    } catch (e) {
      errors.push(e.message);
    }
  }

  // --- 2) Swift bridge API correctness
  try {
    const swiftPath = mustExist("ios/MyOfflineLLMApp/MLX/MLXModule.swift");
    mustContain(
      swiftPath,
      [
        "@objc(MLXModule)",
        "final class MLXModule: NSObject",
        "LLMModelFactory.shared.loadContainer",
        "ChatSession(",
      ],
      "MLXModule.swift",
    );
  } catch (e) {
    errors.push(e.message);
  }

  // --- 3) ObjC shim exports the methods React Native expects
  try {
    const mPath = mustExist("ios/MyOfflineLLMApp/MLX/MLXModuleBridge.m");
    mustContain(
      mPath,
      [
        "RCT_EXTERN_MODULE(MLXModule, NSObject)",
        "RCT_EXTERN_METHOD(load:(NSString *)modelID",
        "RCT_EXTERN_METHOD(isLoaded:(RCTPromiseResolveBlock)resolve",
        "RCT_EXTERN_METHOD(generate:(NSString *)prompt",
        "RCT_EXTERN_METHOD(reset)",
        "RCT_EXTERN_METHOD(unload)",
      ],
      "MLXModuleBridge.m",
    );
  } catch (e) {
    errors.push(e.message);
  }

  // --- 4) JS wrapper has expected shape
  try {
    const jsPath = mustExist("src/native/MLXModule.ts");
    mustContain(
      jsPath,
      [
        "NativeModules.MLXModule",
        "load(",
        "generate(",
        "isLoaded(",
        "reset(",
        "unload(",
      ],
      "src/native/MLXModule.ts",
    );
  } catch (e) {
    errors.push(e.message);
  }

  // --- 5) Basic Xcode project references (heuristic)
  // Ensure pbxproj mentions both files (not perfect, but catches common misses)
  const pbxprojCandidates = [
    "ios/monGARS.xcodeproj/project.pbxproj",
    "ios/MyOfflineLLMApp.xcodeproj/project.pbxproj",
  ];
  const pbx = pbxprojCandidates.find((p) => fs.existsSync(path.join(root, p)));
  if (pbx) {
    try {
      const p = path.join(root, pbx);
      softCheck(p, ["MLXModule.swift"], `${pbx} (MLXModule.swift ref)`);
      softCheck(p, ["MLXModuleBridge.m"], `${pbx} (MLXModuleBridge.m ref)`);
    } catch (e) {
      console.warn(`WARN: ${e.message}`);
    }
  } else {
    console.warn(
      "WARN: Could not find a project.pbxproj to verify file references.",
    );
  }

  // --- 6) Podfile sanity (iOS 18)
  if (fs.existsSync(path.join(root, "ios/Podfile"))) {
    try {
      const pod = path.join(root, "ios/Podfile");
      softCheck(pod, ["platform :ios, '18.0'"], "Podfile platform iOS 18");
    } catch (e) {
      console.warn(`WARN: ${e.message}`);
    }
  }

  // --- 7) XcodeGen project.yml sanity (Swift 6, signing disabled, MLX packages)
  if (fs.existsSync(path.join(root, "ios/project.yml"))) {
    try {
      const yml = path.join(root, "ios/project.yml");
      softCheck(yml, ['SWIFT_VERSION: "6.0"'], "Swift 6 in project.yml");
      softCheck(
        yml,
        ["CODE_SIGNING_ALLOWED: NO"],
        "Signing disabled in project.yml",
      );
      softCheck(
        yml,
        ["MLXLMCommon"],
        "MLXLMCommon added in project.yml packages",
      );
      softCheck(yml, ["MLXLLM"], "MLXLLM added in project.yml packages");
    } catch (e) {
      console.warn(`WARN: ${e.message}`);
    }
  }

  // --- 8) Surface any accumulated hard errors
  if (errors.length) {
    console.error(
      "❌ MLX bridge sanity check failed:\n- " + errors.join("\n- "),
    );
    process.exit(1);
  } else {
    console.log("✅ MLX bridge sanity check passed.");
  }
}

try {
  main();
} catch (err) {
  console.error(`❌ ${err.message}`);
  process.exit(1);
}
