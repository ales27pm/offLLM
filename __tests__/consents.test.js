jest.mock("@react-native-async-storage/async-storage", () => {
  let store = {};
  return {
    setItem: async (k, v) => {
      store[k] = v;
    },
    getItem: async (k) => store[k] || null,
    removeItem: async (k) => {
      delete store[k];
    },
    getAllKeys: async () => Object.keys(store),
    multiGet: async (keys) => keys.map((k) => [k, store[k] || null]),
    __clear: () => {
      store = {};
    },
  };
});

import {
  setConsent,
  getConsent,
  revokeConsent,
  listConsents,
} from "../src/privacy/consents";

const AsyncStorage = require("@react-native-async-storage/async-storage");

beforeEach(() => AsyncStorage.__clear());

describe("Consent Management", () => {
  test("set and get valid consent", async () => {
    await setConsent("camera", true);
    const consent = await getConsent("camera");
    expect(consent).toEqual({
      key: "camera",
      value: true,
      timestamp: expect.any(Number),
    });
  });

  test("reject invalid consent key", async () => {
    await expect(setConsent("invalid", true)).rejects.toThrow(
      "Invalid consent key",
    );
    expect(await getConsent("invalid")).toBeNull();
  });

  test("list consents", async () => {
    await setConsent("camera", true);
    await setConsent("location", false);
    const consents = await listConsents();
    expect(consents).toEqual({
      camera: { key: "camera", value: true, timestamp: expect.any(Number) },
      location: {
        key: "location",
        value: false,
        timestamp: expect.any(Number),
      },
    });
  });

  test("revoke consent", async () => {
    await setConsent("camera", true);
    await revokeConsent("camera");
    expect(await getConsent("camera")).toBeNull();
  });

  test("revoke invalid key does not throw", async () => {
    await expect(revokeConsent("invalid")).resolves.toBeUndefined();
  });

  test("handle AsyncStorage error gracefully", async () => {
    jest
      .spyOn(AsyncStorage, "setItem")
      .mockRejectedValueOnce(new Error("Storage error"));
    await expect(setConsent("camera", true)).rejects.toThrow("Storage error");
  });
});
