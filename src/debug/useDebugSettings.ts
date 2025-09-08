import create from "zustand";
import Config from "react-native-config";
import { Logger } from "../utils/logger";

declare const __DEV__: boolean;

const DEBUG_LOGGING = Config.DEBUG_LOGGING === "1";

export const useDebugSettings = create<{
  verbose: boolean;
  file: boolean;
  toggleVerbose: () => void;
  toggleFile: () => void;
}>((set) => ({
  verbose: __DEV__,
  file: DEBUG_LOGGING,
  toggleVerbose: () =>
    set((state) => {
      const next = !state.verbose;
      Logger.setLevel(next ? "debug" : "info");
      return { verbose: next };
    }),
  toggleFile: () =>
    set((state) => {
      const next = !state.file;
      Logger.setFileSink(next);
      return { file: next };
    }),
}));
