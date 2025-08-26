let RNFS: any = null;
let nodeFs: any = null;
const isReactNative =
  typeof navigator !== "undefined" && navigator.product === "ReactNative";
if (isReactNative) {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    RNFS = require("react-native-fs");
  } catch (e) {
    RNFS = null;
  }
} else {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  nodeFs = require("fs").promises;
}

export default class FileStorage {
  filePath: string;
  constructor(filePath: string) {
    this.filePath = filePath;
  }

  async loadRaw(): Promise<Buffer | null> {
    try {
      if (RNFS) {
        const exists = await RNFS.exists(this.filePath);
        if (!exists) return null;
        const data = await RNFS.readFile(this.filePath, "base64");
        return Buffer.from(data, "base64");
      }
      const data = await nodeFs.readFile(this.filePath);
      return Buffer.from(data);
    } catch (e) {
      return null;
    }
  }

  async saveRaw(buf: Buffer) {
    if (RNFS) {
      await RNFS.writeFile(this.filePath, buf.toString("base64"), "base64");
    } else {
      await nodeFs.writeFile(this.filePath, buf);
    }
  }

  async exportBase64(): Promise<string> {
    const raw = await this.loadRaw();
    return raw ? raw.toString("base64") : "";
  }

  async importBase64(data: string) {
    const buf = Buffer.from(data, "base64");
    await this.saveRaw(buf);
  }
}
