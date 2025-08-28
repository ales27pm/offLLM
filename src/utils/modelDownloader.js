import RNFS from "react-native-fs";

/**
 * Downloads a model file from a remote URL to the device's documents directory.
 * If the file already exists, the download is skipped.
 * @param {string} url Remote URL of the model file.
 * @returns {Promise<string>} Local file path to the downloaded model.
 */
export async function ensureModelDownloaded(url) {
  try {
    if (!url) {
      throw new Error("Model URL is required");
    }

    const filename = url.split("/").pop()?.split("?")[0];
    const localPath = `${RNFS.DocumentDirectoryPath}/${filename}`;

    const exists = await RNFS.exists(localPath);
    if (!exists) {
      const download = RNFS.downloadFile({ fromUrl: url, toFile: localPath });
      const result = await download.promise;
      if (result.statusCode !== 200) {
        throw new Error(`Download failed with status ${result.statusCode}`);
      }
    }

    return localPath;
  } catch (error) {
    console.error("Model download failed:", error);
    throw error;
  }
}
