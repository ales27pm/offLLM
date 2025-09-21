import {
  isReactNative,
  resolveNodeRequire,
  getGlobalProcess,
} from "./envUtils";
import { dirname, joinPath, normalizePath, getNodePath } from "./pathUtils";

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
    RNFS = null;
  }
}

let nodeFs = null;
let nodeFsLoaded = false;
let nodeFsWarningLogged = false;

const logNodeFsUnavailable = (error) => {
  if (nodeFsWarningLogged) {
    return;
  }

  console.warn(
    "[fsUtils] Node fs.promises is unavailable; file system tool cannot access the local disk.",
    error,
  );
  nodeFsWarningLogged = true;
};

const loadNodeFsIfNeeded = () => {
  if (nodeFsLoaded) {
    return;
  }
  nodeFsLoaded = true;

  if (isReactNative) {
    nodeFs = null;
    return;
  }

  const requireFn = resolveNodeRequire();
  if (!requireFn) {
    nodeFs = null;
    logNodeFsUnavailable();
    return;
  }

  try {
    const fsModule = requireFn("fs");
    nodeFs = fsModule && fsModule.promises ? fsModule.promises : null;
    if (!nodeFs) {
      logNodeFsUnavailable();
    }
  } catch (error) {
    nodeFs = null;
    logNodeFsUnavailable(error);
  }
};

export const getReactNativeFs = () => RNFS;

export const getNodeFs = () => {
  loadNodeFsIfNeeded();
  return nodeFs;
};

const processRef = getGlobalProcess();

export const DEFAULT_SAFE_ROOT = (() => {
  if (processRef && typeof processRef.cwd === "function") {
    try {
      return processRef.cwd();
    } catch {
      return null;
    }
  }
  return null;
})();

const toIsoDateString = (value) => {
  if (!value) {
    return null;
  }
  const date =
    value instanceof Date
      ? value
      : typeof value === "number" || typeof value === "string"
        ? new Date(value)
        : null;
  if (date && !Number.isNaN(date.getTime())) {
    return date.toISOString();
  }
  return null;
};

const isDirectoryAlreadyExistsError = (error) =>
  Boolean(
    error &&
      (error.code === "EEXIST" ||
        error.code === "ERR_FS_EISDIR" ||
        (typeof error.message === "string" &&
          error.message.toLowerCase().includes("exist"))),
  );

export const ensureDirectoryExists = async (filePath) => {
  const directory = dirname(filePath);
  if (
    !directory ||
    directory === "." ||
    directory === filePath ||
    directory === "/"
  ) {
    return;
  }

  if (RNFS) {
    const exists = await RNFS.exists(directory);
    if (!exists) {
      try {
        await RNFS.mkdir(directory);
      } catch (error) {
        if (!isDirectoryAlreadyExistsError(error)) {
          throw error;
        }
      }
    }
    return;
  }

  const nodeFsModule = getNodeFs();
  if (nodeFsModule) {
    try {
      await nodeFsModule.mkdir(directory, { recursive: true });
    } catch (error) {
      if (!isDirectoryAlreadyExistsError(error)) {
        throw error;
      }
    }
  }
};

export const getPathStats = async (targetPath) => {
  if (RNFS) {
    try {
      return await RNFS.stat(targetPath);
    } catch {
      return null;
    }
  }

  const nodeFsModule = getNodeFs();
  if (nodeFsModule) {
    try {
      return await nodeFsModule.stat(targetPath);
    } catch {
      return null;
    }
  }

  return null;
};

export const pathExists = async (targetPath) =>
  Boolean(await getPathStats(targetPath));

export const isDirectoryStat = (stats) => {
  if (!stats) {
    return false;
  }
  if (typeof stats.isDirectory === "function") {
    return stats.isDirectory();
  }
  if (typeof stats.isDirectory === "boolean") {
    return stats.isDirectory;
  }
  return false;
};

export const normalizeDirectoryEntriesFromRN = (entries) =>
  entries.map((entry) => ({
    name: entry.name,
    path: entry.path,
    isFile:
      typeof entry.isFile === "function"
        ? entry.isFile()
        : Boolean(entry.isFile),
    isDirectory:
      typeof entry.isDirectory === "function"
        ? entry.isDirectory()
        : Boolean(entry.isDirectory),
    size:
      typeof entry.size === "number" && Number.isFinite(entry.size)
        ? entry.size
        : null,
    modifiedAt: toIsoDateString(entry.mtime),
  }));

export const listNodeDirectory = async (directoryPath) => {
  const nodeFsModule = getNodeFs();
  if (!nodeFsModule) {
    throw new Error("Node file system is not available");
  }

  const dirents = await nodeFsModule.readdir(directoryPath, {
    withFileTypes: true,
  });

  return Promise.all(
    dirents.map(async (dirent) => {
      const entryPath = joinPath(directoryPath, dirent.name);
      let stats = null;
      try {
        stats = await nodeFsModule.stat(entryPath);
      } catch {
        stats = null;
      }
      return {
        name: dirent.name,
        path: entryPath,
        isFile: dirent.isFile(),
        isDirectory: dirent.isDirectory(),
        size: stats ? stats.size : null,
        modifiedAt: stats ? toIsoDateString(stats.mtime) : null,
      };
    }),
  );
};

const traversalErrorMessage =
  "Invalid path: Directory traversal detected or path is outside the allowed root.";

export const resolveSafePath = (
  targetPath,
  { root = DEFAULT_SAFE_ROOT } = {},
) => {
  if (typeof targetPath !== "string") {
    throw new Error("A valid path is required for file system operations");
  }

  const trimmed = targetPath.trim();
  if (!trimmed) {
    throw new Error("A valid path is required for file system operations");
  }

  const pathModule = getNodePath();

  if (pathModule && root) {
    const normalizedRoot = pathModule.resolve(root);
    const normalizedTarget = pathModule.normalize(trimmed);
    const absolutePath = pathModule.resolve(normalizedRoot, normalizedTarget);
    const relative = pathModule.relative(normalizedRoot, absolutePath);

    if (relative.startsWith("..") || pathModule.isAbsolute(relative)) {
      throw new Error(traversalErrorMessage);
    }

    return {
      absolutePath,
      normalizedPath: pathModule.normalize(absolutePath),
    };
  }

  const normalised = normalizePath(trimmed);
  const segments = normalised.split("/");
  const resolved = [];
  const isAbsolute = normalised.startsWith("/");

  for (const segment of segments) {
    if (!segment || segment === ".") {
      continue;
    }
    if (segment === "..") {
      if (resolved.length === 0) {
        throw new Error(traversalErrorMessage);
      }
      resolved.pop();
      continue;
    }
    resolved.push(segment);
  }

  const resolvedPath = `${isAbsolute ? "/" : ""}${resolved.join("/")}`;
  const finalPath = resolvedPath || (isAbsolute ? "/" : ".");
  return {
    absolutePath: finalPath,
    normalizedPath: finalPath,
  };
};
