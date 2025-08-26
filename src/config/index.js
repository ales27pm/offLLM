let Config = {};
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  Config = require('react-native-config');
} catch (e) {
  Config = {};
}

export function getEnv(key) {
  if (Config && typeof Config[key] !== 'undefined') {
    return Config[key];
  }
  if (typeof process !== 'undefined' && process.env && typeof process.env[key] !== 'undefined') {
    return process.env[key];
  }
  return undefined;
}
