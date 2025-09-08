import RNFS from "react-native-fs";
import Config from "react-native-config";
import { logToNative } from "./NativeLogger";

declare const __DEV__: boolean;
/* eslint-disable no-unused-vars */
export enum LogLevel {
  debug = 10,
  info = 20,
  warn = 30,
  error = 40,
}
/* eslint-enable no-unused-vars */

const DEBUG_LOGGING = Config.DEBUG_LOGGING === "1";
const RING_SIZE = 500;
const MAX_SIZE = 1024 * 1024; // ~1MB
const logsDir = `${RNFS.DocumentDirectoryPath}/logs`;
const activeLog = `${logsDir}/app.log`;
const rotatedLog = `${logsDir}/app.log.1`;

export class Logger {
  private static level: LogLevel = __DEV__ ? LogLevel.debug : LogLevel.info;
  private static buffer: string[] = [];
  private static fileSinkEnabled = DEBUG_LOGGING;

  static setLevel(level: keyof typeof LogLevel): void {
    this.level = LogLevel[level];
  }

  static setFileSink(enabled: boolean): void {
    this.fileSinkEnabled = enabled;
  }

  static async log(
    level: keyof typeof LogLevel,
    tag: string,
    ...args: any[]
  ): Promise<void> {
    if (LogLevel[level] < this.level) return;
    const line = `[${tag}] ${args.map(String).join(" ")}`;
    const fn = console[level] || console.log;
    fn(line);
    this.buffer.push(line);
    if (this.buffer.length > RING_SIZE) this.buffer.shift();
    if (this.fileSinkEnabled) {
      await this.writeToFile(line);
    }
    if (level === "warn" || level === "error") {
      try {
        logToNative?.(level, tag, line);
      } catch {
        // no-op
      }
    }
  }

  static debug(tag: string, ...args: any[]): Promise<void> {
    return this.log("debug", tag, ...args);
  }
  static info(tag: string, ...args: any[]): Promise<void> {
    return this.log("info", tag, ...args);
  }
  static warn(tag: string, ...args: any[]): Promise<void> {
    return this.log("warn", tag, ...args);
  }
  static error(tag: string, ...args: any[]): Promise<void> {
    return this.log("error", tag, ...args);
  }

  private static async writeToFile(line: string): Promise<void> {
    try {
      await RNFS.mkdir(logsDir);
      const info = await RNFS.stat(activeLog).catch(() => null);
      if (info && info.size > MAX_SIZE) {
        await RNFS.unlink(rotatedLog).catch(() => {});
        await RNFS.moveFile(activeLog, rotatedLog).catch(() => {});
      }
      await RNFS.appendFile(activeLog, line + "\n", "utf8");
    } catch {
      // swallow file errors
    }
  }

  static async tail(n = 200): Promise<string> {
    if (this.fileSinkEnabled) {
      try {
        const content = await RNFS.readFile(activeLog, "utf8");
        const lines = content.split("\n");
        return lines.slice(-n).join("\n");
      } catch {
        // fall back to buffer
      }
    }
    return this.buffer.slice(-n).join("\n");
  }

  static async clear(): Promise<void> {
    this.buffer = [];
    if (this.fileSinkEnabled) {
      await RNFS.unlink(activeLog).catch(() => {});
      await RNFS.unlink(rotatedLog).catch(() => {});
    }
  }
}
