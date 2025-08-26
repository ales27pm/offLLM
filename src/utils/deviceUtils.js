import { Platform, NativeModules } from "react-native";

export function getDeviceProfile() {
  let totalMemory;
  let processorCores;
  let isLowEndDevice = false;

  try {
    if (Platform.OS === "ios") {
      totalMemory = NativeModules.DeviceInfo?.getTotalMemory?.();
      processorCores = NativeModules.DeviceInfo?.getProcessorCount?.();

      if (!totalMemory) {
        console.warn(
          "[DeviceProfile] getTotalMemory unavailable, using fallback value 4000MB"
        );
        totalMemory = 4000;
      }
      if (!processorCores) {
        console.warn(
          "[DeviceProfile] getProcessorCount unavailable, using fallback value 4 cores"
        );
        processorCores = 4;
      }
    } else {
      totalMemory = NativeModules.DeviceInfo?.totalMemory?.();
      processorCores = NativeModules.DeviceInfo?.processorCores?.();

      if (!totalMemory) {
        console.warn(
          "[DeviceProfile] totalMemory unavailable, using fallback value 4000MB"
        );
        totalMemory = 4000;
      }
      if (!processorCores) {
        console.warn(
          "[DeviceProfile] processorCores unavailable, using fallback value 4 cores"
        );
        processorCores = 4;
      }
    }

    // Determine device tier based on memory and processor
    let tier = "low";
    if (totalMemory >= 6000 && processorCores >= 6) {
      tier = "high";
    } else if (totalMemory >= 3000 && processorCores >= 4) {
      tier = "mid";
    } else {
      tier = "low";
      isLowEndDevice = true;
    }

    return {
      tier,
      totalMemory,
      processorCores,
      isLowEndDevice,
      platform: Platform.OS,
      isQuantized: totalMemory < 4000, // Use quantized models on lower memory devices
    };
  } catch (error) {
    console.error("Failed to get device profile:", error);

    // Return default profile
    return {
      tier: "low",
      totalMemory: 2000,
      processorCores: 2,
      isLowEndDevice: true,
      platform: Platform.OS,
      isQuantized: true,
    };
  }
}

export function getPerformanceMode(
  deviceProfile,
  batteryLevel = 1.0,
  thermalState = "nominal"
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
