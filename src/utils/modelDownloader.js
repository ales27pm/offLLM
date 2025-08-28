import RNFS from "react-native-fs";

/**
 * Download a model file to the device's documents directory, retrying on failures.
 * If the file already exists, the download is skipped.
 *
 * @param {string} url Remote URL of the model file.
 * @param {{retries?: number, baseDelay?: number}} options Retry options.
 * @returns {Promise<string>} Local file path to the downloaded model.
 */
export async function ensureModelDownloaded(url, options = {}) {
  if (!url) {
    throw new Error("Model URL is required");
  }

  let filename;
  try {
    const parsedUrl = new URL(url);
    filename = decodeURIComponent(parsedUrl.pathname.split("/").pop() || "");
    if (!filename) {
      throw new Error("Could not extract filename from URL");
    }
  } catch (err) {
    throw new Error(
      `Invalid URL or unable to extract filename: ${err.message}`
    );
  }

  const localPath = `${RNFS.DocumentDirectoryPath}/${filename}`;

  if (await RNFS.exists(localPath)) {
    return localPath;
  }

  const { retries = 3, baseDelay = 1000 } = options;
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const { statusCode } = await RNFS.downloadFile({
        fromUrl: url,
        toFile: localPath,
      }).promise;
      if (statusCode === 200) {
        return localPath;
      }
      throw new Error(`Download failed with status ${statusCode}`);
    } catch (err) {
      if (attempt === retries) {
        throw err;
      }
      const delay = baseDelay * Math.pow(2, attempt - 1);
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }

  return localPath;
}
