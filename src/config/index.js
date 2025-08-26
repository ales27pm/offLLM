let Config = {};
const isReactNative =
  typeof navigator !== "undefined" && navigator.product === "ReactNative";
if (isReactNative) {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    Config = require("react-native-config");
  } catch (e) {
    Config = {};
    // eslint-disable-next-line no-console
    console.warn(
      "[Config] Failed to load react-native-config. Falling back to empty config. This may indicate a misconfiguration.",
      e
    );
  }
}

export function getEnv(key) {
  if (Config && typeof Config[key] !== "undefined") {
    return Config[key];
  }
  if (
    typeof process !== "undefined" &&
    process.env &&
    typeof process.env[key] !== "undefined"
  ) {
    return process.env[key];
  }
  return undefined;
}
