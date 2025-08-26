jest.mock('@react-native-async-storage/async-storage', () => {
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
    __clear: () => {
      store = {};
    },
  };
});

import { setConsent, getConsent, revokeConsent, listConsents } from '../src/privacy/consents';

const AsyncStorage = require('@react-native-async-storage/async-storage');

beforeEach(() => AsyncStorage.__clear());

test('consent set/get/list', async () => {
  await setConsent('camera', true);
  expect((await getConsent('camera')).value).toBe(true);
  const list = await listConsents();
  expect(list.camera.value).toBe(true);
  await revokeConsent('camera');
  expect(await getConsent('camera')).toBeNull();
});
