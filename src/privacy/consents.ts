import AsyncStorage from '@react-native-async-storage/async-storage';
import { Logger } from '../utils/logger';

const VALID_CONSENTS = ['camera', 'location', 'contacts', 'photos', 'microphone'] as const;
type ConsentKey = (typeof VALID_CONSENTS)[number];

interface ConsentRecord {
  key: ConsentKey;
  value: boolean;
  timestamp: number;
}

const CONSENT_PREFIX = 'consent_';

class ConsentError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConsentError';
  }
}

export async function setConsent(key: string, value: boolean): Promise<void> {
  if (!VALID_CONSENTS.includes(key as ConsentKey)) {
    Logger.error(`Invalid consent key: ${key}`);
    throw new ConsentError(
      `Invalid consent key: ${key}. Allowed: ${VALID_CONSENTS.join(', ')}`,
    );
  }
  const record: ConsentRecord = { key: key as ConsentKey, value, timestamp: Date.now() };
  try {
    await AsyncStorage.setItem(`${CONSENT_PREFIX}${key}`, JSON.stringify(record));
    Logger.info(`Consent set: ${key} = ${value}`);
  } catch (error: any) {
    Logger.error(`Failed to set consent for ${key}: ${error.message}`);
    throw error;
  }
}

export async function getConsent(key: string): Promise<ConsentRecord | null> {
  if (!VALID_CONSENTS.includes(key as ConsentKey)) {
    Logger.warn(`Attempted to get invalid consent key: ${key}`);
    return null;
  }
  try {
    const value = await AsyncStorage.getItem(`${CONSENT_PREFIX}${key}`);
    return value ? (JSON.parse(value) as ConsentRecord) : null;
  } catch (error: any) {
    Logger.error(`Failed to get consent for ${key}: ${error.message}`);
    return null;
  }
}

export async function revokeConsent(key: string): Promise<void> {
  if (!VALID_CONSENTS.includes(key as ConsentKey)) {
    Logger.warn(`Attempted to revoke invalid consent key: ${key}`);
    return;
  }
  try {
    await AsyncStorage.removeItem(`${CONSENT_PREFIX}${key}`);
    Logger.info(`Consent revoked: ${key}`);
  } catch (error: any) {
    Logger.error(`Failed to revoke consent for ${key}: ${error.message}`);
    throw error;
  }
}

export async function listConsents(): Promise<Record<ConsentKey, ConsentRecord>> {
  try {
    const keys = await AsyncStorage.getAllKeys();
    const consentKeys = keys.filter((k) => k.startsWith(CONSENT_PREFIX));
    const entries = await AsyncStorage.multiGet(consentKeys);
    const result: Partial<Record<ConsentKey, ConsentRecord>> = {};
    for (const [key, value] of entries) {
      if (value) {
        const consentKey = key.replace(CONSENT_PREFIX, '') as ConsentKey;
        if (VALID_CONSENTS.includes(consentKey)) {
          result[consentKey] = JSON.parse(value) as ConsentRecord;
        }
      }
    }
    return result as Record<ConsentKey, ConsentRecord>;
  } catch (error: any) {
    Logger.error(`Failed to list consents: ${error.message}`);
    return {} as Record<ConsentKey, ConsentRecord>;
  }
}
