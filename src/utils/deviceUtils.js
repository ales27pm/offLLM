import { Platform, NativeModules } from "react-native";
import {
  getRuntimeConfigValue,
  setRuntimeConfigValue,
} from "../config/runtime";

const DEVICE_PROFILE_KEY = "deviceProfile";

function toPositiveInteger(value) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return undefined;
  }
  return Math.max(1, Math.round(value));
}

function getNodeRequire() {
  if (typeof module !== "undefined" && typeof module.require === "function") {
    return module.require.bind(module);
  }
  try {
    // Using eval avoids bundlers (e.g. Metro) trying to resolve the module at build time.
    return eval("require");
  } catch {
    return null;
  }
}

function probeNodeHardware() {
  if (
    typeof process === "undefined" ||
    !process.release ||
    process.release.name !== "node"
  ) {
    return { totalMemory: undefined, processorCores: undefined };
  }

  const nodeRequire = getNodeRequire();
  if (!nodeRequire) {
    return { totalMemory: undefined, processorCores: undefined };
  }

  try {
    const os = nodeRequire("os");
    const totalMemoryBytes =
      typeof os.totalmem === "function" ? os.totalmem() : undefined;
    const cpuInfo = typeof os.cpus === "function" ? os.cpus() : undefined;

    const totalMemory = toPositiveInteger(
      typeof totalMemoryBytes === "number"
        ? totalMemoryBytes / (1024 * 1024)
        : undefined,
    );
    const processorCores = Array.isArray(cpuInfo)
      ? toPositiveInteger(cpuInfo.length)
      : undefined;

    return { totalMemory, processorCores };
  } catch {
    return { totalMemory: undefined, processorCores: undefined };
  }
}

function deriveTier(totalMemory, processorCores) {
  if (totalMemory >= 6000 && processorCores >= 6) {
    return "high";
  }
  if (totalMemory >= 3000 && processorCores >= 4) {
    return "mid";
  }
  return "low";
}

function buildDeviceProfile() {
  const sources = new Set();

  let totalMemory;
  let processorCores;

  if (Platform.OS === "ios") {
    const nativeMemory = toPositiveInteger(
      NativeModules.DeviceInfo?.getTotalMemory?.(),
    );
    if (nativeMemory) {
      totalMemory = nativeMemory;
      sources.add("native");
    }
    const nativeCores = toPositiveInteger(
      NativeModules.DeviceInfo?.getProcessorCount?.(),
    );
    if (nativeCores) {
      processorCores = nativeCores;
      sources.add("native");
    }
  } else {
    const nativeMemory = toPositiveInteger(
      NativeModules.DeviceInfo?.totalMemory?.(),
    );
    if (nativeMemory) {
      totalMemory = nativeMemory;
      sources.add("native");
    }
    const nativeCores = toPositiveInteger(
      NativeModules.DeviceInfo?.processorCores?.(),
    );
    if (nativeCores) {
      processorCores = nativeCores;
      sources.add("native");
    }
  }

  if (!totalMemory || !processorCores) {
    const nodeHardware = probeNodeHardware();
    if (!totalMemory && nodeHardware.totalMemory) {
      totalMemory = nodeHardware.totalMemory;
      sources.add("node");
    }
    if (!processorCores && nodeHardware.processorCores) {
      processorCores = nodeHardware.processorCores;
      sources.add("node");
    }
  }

  if (!totalMemory) {
    console.warn(
      "[DeviceProfile] hardware memory probe unavailable, using fallback value 4000MB",
    );
    totalMemory = 4000;
    sources.add("fallback");
  }
  if (!processorCores) {
    console.warn(
      "[DeviceProfile] hardware core probe unavailable, using fallback value 4 cores",
    );
    processorCores = 4;
    sources.add("fallback");
  }

  const tier = deriveTier(totalMemory, processorCores);
  const detectionMethod =
    sources.size > 0 ? Array.from(sources).sort().join("+") : "unknown";

  return {
    tier,
    totalMemory,
    processorCores,
    isLowEndDevice: tier === "low",
    platform: Platform.OS,
    isQuantized: totalMemory < 4000,
    detectionMethod,
  };
}

export function getDeviceProfile() {
  const cachedProfile = getRuntimeConfigValue(DEVICE_PROFILE_KEY);
  if (cachedProfile) {
    return cachedProfile;
  }

  try {
    const profile = buildDeviceProfile();
    setRuntimeConfigValue(DEVICE_PROFILE_KEY, profile);
    return profile;
  } catch (error) {
    console.error("Failed to get device profile:", error);
    const fallbackProfile = {
      tier: "low",
      totalMemory: 2000,
      processorCores: 2,
      isLowEndDevice: true,
      platform: Platform.OS,
      isQuantized: true,
      detectionMethod: "fallback",
    };
    setRuntimeConfigValue(DEVICE_PROFILE_KEY, fallbackProfile);
    return fallbackProfile;
  }
}

export function getPerformanceMode(
  deviceProfile,
  batteryLevel = 1.0,
  thermalState = "nominal",
) {
  const { tier, isLowEndDevice } = deviceProfile;

  // Base mode based on device tier
  let mode = "balanced";
  if (tier === "high") {
    mode = "performance";
  } else if (isLowEndDevice) {
    mode = "power-saving";
  }

  // Adjust based on battery level
  if (batteryLevel < 0.2) {
    mode = "power-saving";
  } else if (batteryLevel < 0.5 && mode === "performance") {
    mode = "balanced";
  }

  // Adjust based on thermal state
  if (thermalState === "serious" || thermalState === "critical") {
    mode = "power-saving";
  } else if (thermalState === "fair" && mode === "performance") {
    mode = "balanced";
  }

  return mode;
}

export function getRecommendedModelConfig(deviceProfile) {
  const { tier, isQuantized } = deviceProfile;

  if (tier === "high") {
    return {
      modelSize: "7B",
      quantization: isQuantized ? "Q4_K_M" : "none",
      contextSize: 8192,
      maxBatchSize: 8,
    };
  } else if (tier === "mid") {
    return {
      modelSize: "3B",
      quantization: "Q4_K_S",
      contextSize: 4096,
      maxBatchSize: 4,
    };
  } else {
    return {
      modelSize: "1B",
      quantization: "Q4_0",
      contextSize: 2048,
      maxBatchSize: 2,
    };
  }
}

export function formatBytes(bytes, decimals = 2) {
  if (bytes === 0) return "0 Bytes";

  const k = 1024;
  const dm = decimals < 0 ? 0 : decimals;
  const sizes = ["Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];

  const i = Math.floor(Math.log(bytes) / Math.log(k));
  const index = Math.min(i, sizes.length - 1);

  return (
    parseFloat((bytes / Math.pow(k, index)).toFixed(dm)) + " " + sizes[index]
  );
}

export function formatMilliseconds(ms, decimals = 1) {
  if (ms < 0) {
    return "Invalid duration";
  }
  if (ms < 1000) {
    return ms.toFixed(decimals) + "ms";
  } else if (ms < 60000) {
    return (ms / 1000).toFixed(decimals) + "s";
  } else {
    return (ms / 60000).toFixed(decimals) + "min";
  }
}

export function isDeviceCompatible(minRequirements = {}) {
  const {
    minMemory = 2000,
    minProcessorCores = 2,
    platforms = ["ios", "android"],
  } = minRequirements;

  const deviceProfile = getDeviceProfile();

  return (
    deviceProfile.totalMemory >= minMemory &&
    deviceProfile.processorCores >= minProcessorCores &&
    platforms.includes(deviceProfile.platform)
  );
}
