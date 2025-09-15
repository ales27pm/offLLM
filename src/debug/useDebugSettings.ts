import create from "zustand";
import Config from "react-native-config";
import logger, { LogLevel } from "../utils/logger";

const isDevelopment = process?.env?.NODE_ENV !== "production";
const DEBUG_LOGGING = Config.DEBUG_LOGGING === "1";

if (DEBUG_LOGGING) {
  logger.setFileLoggingEnabled(true);
}

export const useDebugSettings = create<{
  verbose: boolean;
  file: boolean;
  toggleVerbose: () => void;
  toggleFile: () => void;
}>((set) => ({
  verbose: isDevelopment,
  file: DEBUG_LOGGING,
  toggleVerbose: () =>
    set((state) => {
      const next = !state.verbose;
      logger.setLogLevel(next ? LogLevel.DEBUG : LogLevel.INFO);
      return { verbose: next };
    }),
  toggleFile: () =>
    set((state) => {
      const next = !state.file;
      logger.setFileLoggingEnabled(next);
      return { file: next };
    }),
}));
