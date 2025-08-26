import { Readability } from "@mozilla/readability";
import { JSDOM } from "jsdom";
import { Platform } from "react-native";

class ReadabilityService {
  constructor() {
    this.cache = new Map();
    this.cacheTimeout = 15 * 60 * 1000; // 15 minutes cache
  }

  async extractContent(html, url) {
    try {
      const cacheKey = this.generateCacheKey(html, url);
      const cached = this.cache.get(cacheKey);

      if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
        return cached.content;
      }

      const dom = new JSDOM(html, {
        url: url,
        pretendToBeVisual: true,
        resources: "usable",
        runScripts: "dangerously",
      });

      await new Promise((resolve) => {
        const { document } = dom.window;
        if (
          document.readyState === "complete" ||
          document.readyState === "interactive"
        ) {
          resolve();
        } else {
          const onContentLoaded = () => {
            document.removeEventListener("DOMContentLoaded", onContentLoaded);
            resolve();
          };
          document.addEventListener("DOMContentLoaded", onContentLoaded);
          setTimeout(resolve, 100);
        }
      });

      const reader = new Readability(dom.window.document);
      const article = reader.parse();

      if (!article) {
        throw new Error("Failed to extract content with Readability");
      }

      const cleanedContent = this.cleanContent(article, dom.window.document);

      this.cache.set(cacheKey, {
        content: cleanedContent,
        timestamp: Date.now(),
      });

      return cleanedContent;
    } catch (error) {
      console.error("Readability extraction failed:", error);
      throw new Error(`Content extraction failed: ${error.message}`);
    }
  }

  async extractFromUrl(url) {
    try {
      const response = await fetch(url, {
        headers: {
          "User-Agent": this.getUserAgent(),
          Accept:
            "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
          "Accept-Language": "en-US,en;q=0.5",
          "Accept-Encoding": "gzip, deflate",
          Connection: "keep-alive",
          "Upgrade-Insecure-Requests": "1",
        },
      });

      if (!response.ok) {
        throw new Error(
          `HTTP error ${response.status}: ${response.statusText}`,
        );
      }

      const html = await response.text();
      return await this.extractContent(html, url);
    } catch (error) {
      console.error("Failed to fetch URL:", error);
      throw new Error(`Failed to fetch URL: ${error.message}`);
    }
  }

  generateCacheKey(html, url) {
    let hash = 0;
    for (let i = 0; i < html.length; i++) {
      hash = (hash * 31 + html.charCodeAt(i)) >>> 0;
    }
    return `${url}_${hash}`;
  }

  cleanContent(article, document) {
    if (!article) return null;

    const content = {
      title: article.title || "",
      content: article.content || "",
      textContent: article.textContent || "",
      excerpt: article.excerpt || "",
      byline: article.byline || "",
      length: article.length || 0,
      siteName: this.extractSiteName(article, document) || "",
      publishedTime: this.extractPublishedTime(article, document) || "",
      language: this.detectLanguage(article.textContent) || "en",
      readingTime: this.calculateReadingTime(article.textContent),
    };

    content.content = this.optimizeForMobile(content.content);

    return content;
  }

  optimizeForMobile(html) {
    if (!html) return "";

    let optimized = html
      .replace(/<img[^>]+srcset="[^"]*"[^>]*>/gi, "")
      .replace(/<img[^>]+sizes="[^"]*"[^>]*>/gi, "")
      .replace(/<iframe[^>]*>[\s\S]*?<\/iframe>/gi, "")
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, "")
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, "");

    optimized = optimized
      .replace(/<div[^>]*>/gi, "")
      .replace(/<\/div>/gi, "")
      .replace(/<span[^>]*>/gi, "")
      .replace(/<\/span>/gi, "");

    return optimized;
  }

  extractSiteName(article, document) {
    if (article.siteName) return article.siteName;

    try {
      const urlString = article.url || (document && document.URL) || "";
      const url = new URL(urlString);
      return url.hostname.replace("www.", "");
    } catch (e) {
      return "";
    }
  }

  /**
   * Validates and normalizes a date string.
   * Returns the ISO string if valid, otherwise returns an empty string.
   */
  normalizePublishedTime(value) {
    if (!value || typeof value !== "string") return "";
    const date = new Date(value.trim());
    if (!isNaN(date.getTime()) && date.getFullYear() > 1970) {
      return date.toISOString();
    }
    return "";
  }

  extractPublishedTime(article, document) {
    if (article?.publishedTime) {
      const normalized = this.normalizePublishedTime(article.publishedTime);
      if (normalized) return normalized;
    }

    if (!document) return "";

    const selectors = [
      'meta[property="article:published_time"]',
      'meta[name="pubdate"]',
      'meta[name="publishdate"]',
      'meta[name="date"]',
      'meta[name="dcterms.date"]',
      'meta[itemprop="datePublished"]',
      "time[datetime]",
    ];

    for (const selector of selectors) {
      const element = document.querySelector(selector);
      if (element) {
        const rawValue =
          element.getAttribute("content") ||
          element.getAttribute("datetime") ||
          element.textContent ||
          "";
        const normalized = this.normalizePublishedTime(rawValue);
        if (normalized) return normalized;
      }
    }

    return "";
  }

  detectLanguage(text) {
    const englishWords = ["the", "and", "of", "to", "a", "in", "is", "it"];
    const wordCount = englishWords.filter((word) =>
      text.toLowerCase().includes(` ${word} `),
    ).length;

    return wordCount > 3 ? "en" : "unknown";
  }

  calculateReadingTime(text) {
    const wordsPerMinute = 200;
    const wordCount = text.split(/\s+/).length;
    return Math.ceil(wordCount / wordsPerMinute);
  }

  getUserAgent() {
    if (Platform.OS === "ios") {
      return "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1";
    } else {
      return "Mozilla/5.0 (Linux; Android 10; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.162 Mobile Safari/537.36";
    }
  }

  clearCache() {
    this.cache.clear();
  }

  getCacheStats() {
    return {
      size: this.cache.size,
      keys: Array.from(this.cache.keys()),
    };
  }
}

export default ReadabilityService;
