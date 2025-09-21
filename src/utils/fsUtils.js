import {
  isReactNative,
  resolveNodeRequire,
  getGlobalProcess as _getGlobalProcess,
} from "./envUtils";
import {
  dirname,
  joinPath,
  normalizePath,
  getNodePath as _getNodePath,
} from "./pathUtils";

let RNFS = null;

if (isReactNative) {
  try {
    // react-native-fs is only available in React Native environments
    RNFS = require("react-native-fs");
  } catch (error) {
    console.warn(
      "[fsUtils] Failed to load react-native-fs; file system operations will be limited.",
      error,
    );
  }
}

export const getReactNativeFs = () => RNFS;

export const getNodeFs = () => {
  if (!isReactNative) {
    const requireFn = resolveNodeRequire();
    if (requireFn) {
      try {
        return requireFn("fs");
      } catch (error) {
        console.warn(
          "[fsUtils] Failed to load Node fs module; file system operations will be limited.",
          error,
        );
      }
    }
  }
  return null;
};

export const resolveSafePath = (path) => {
  const normalized = normalizePath(path);
  return {
    absolutePath: normalized,
    isSafe: isPathSafe(normalized),
  };
};

export const isPathSafe = (_path) => {
  // Implement path safety checks here
  return true;
};

export const pathExists = async (path) => {
  const fs = getNodeFs();
  if (fs) {
    try {
      await fs.promises.access(path);
      return true;
    } catch {
      return false;
    }
  }

  if (RNFS) {
    try {
      await RNFS.exists(path);
      return true;
    } catch {
      return false;
    }
  }

  return false;
};

export const getPathStats = async (path) => {
  const fs = getNodeFs();
  if (fs) {
    try {
      return await fs.promises.stat(path);
    } catch {
      return null;
    }
  }

  if (RNFS) {
    try {
      return await RNFS.stat(path);
    } catch {
      return null;
    }
  }

  return null;
};

export const isDirectoryStat = (stats) => {
  if (!stats) return false;
  if (stats.isDirectory && typeof stats.isDirectory === "function") {
    return stats.isDirectory();
  }
  return false;
};

export const ensureDirectoryExists = async (path) => {
  const dir = dirname(path);
  const fs = getNodeFs();
  if (fs) {
    try {
      await fs.promises.mkdir(dir, { recursive: true });
    } catch (error) {
      console.warn("[fsUtils] Failed to create directory", dir, error);
    }
    return;
  }

  if (RNFS) {
    try {
      await RNFS.mkdir(dir);
    } catch (error) {
      console.warn("[fsUtils] Failed to create directory", dir, error);
    }
  }
};

export const listNodeDirectory = async (path) => {
  const fs = getNodeFs();
  if (fs) {
    try {
      const entries = await fs.promises.readdir(path, { withFileTypes: true });
      return entries.map((entry) => ({
        name: entry.name,
        path: joinPath(path, entry.name),
        isDirectory: entry.isDirectory(),
        isFile: entry.isFile(),
        size: entry.size,
        mtime: entry.mtime,
      }));
    } catch (error) {
      console.warn("[fsUtils] Failed to read directory", path, error);
      return [];
    }
  }
  return [];
};

export const normalizeDirectoryEntriesFromRN = (entries) => {
  return entries.map((entry) => ({
    name: entry.name,
    path: entry.path,
    isDirectory: entry.isDirectory(),
    isFile: entry.isFile(),
    size: entry.size,
    mtime: entry.mtime,
  }));
};
