import AsyncStorage from '@react-native-async-storage/async-storage';

const PREFIX = 'consent:';

export async function setConsent(tool: string, value: boolean) {
  const record = { value, timestamp: Date.now() };
  await AsyncStorage.setItem(PREFIX + tool, JSON.stringify(record));
}

export async function getConsent(tool: string) {
  const raw = await AsyncStorage.getItem(PREFIX + tool);
  return raw ? JSON.parse(raw) : null;
}

export async function revokeConsent(tool: string) {
  await AsyncStorage.removeItem(PREFIX + tool);
}

export async function listConsents() {
  const keys = await AsyncStorage.getAllKeys();
  const consents: Record<string, any> = {};
  for (const key of keys) {
    if (key.startsWith(PREFIX)) {
      const val = await AsyncStorage.getItem(key);
      if (val) consents[key.slice(PREFIX.length)] = JSON.parse(val);
    }
  }
  return consents;
}
