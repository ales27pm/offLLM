import Config from 'react-native-config';

export function getEnv(key) {
  if (Config && typeof Config[key] !== 'undefined') {
    return Config[key];
  }
  if (typeof process !== 'undefined' && process.env && typeof process.env[key] !== 'undefined') {
    return process.env[key];
  }
  return undefined;
}
