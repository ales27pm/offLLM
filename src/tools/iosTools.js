import { NativeModules, Platform } from 'react-native';

const isIOS = Platform.OS === 'ios';

function getCalendarModule() {
  if (isIOS && NativeModules.CalendarTurboModule) {
    return NativeModules.CalendarTurboModule;
  }
  throw new Error('CalendarTurboModule is unavailable on non-iOS platforms');
}

function getMessagesModule() {
  if (isIOS && NativeModules.MessagesTurboModule) {
    return NativeModules.MessagesTurboModule;
  }
  throw new Error('MessagesTurboModule is unavailable on non-iOS platforms');
}

/**
 * Create a new calendar event.
 * @param {string} title Event title
 * @param {string} startDate Start date in ISO 8601 format
 * @param {string|null} [endDate=null] Optional end date in ISO 8601 format
 * @param {number|null} [durationSeconds=null] Optional duration in seconds if endDate not provided
 * @param {string} [location=''] Event location
 * @param {string} [notes=''] Event notes
 * @returns {Promise<object>} Result with success flag and event identifier
 */
export async function createCalendarEvent(title, startDate, endDate = null, durationSeconds = null, location = '', notes = '') {
  const module = getCalendarModule();
  return module.createEvent(title, startDate, endDate, durationSeconds, location, notes);
}

/**
 * Send a text message to a phone number.
 * @param {string} phoneNumber Recipient phone number
 * @param {string} body Message body
 * @returns {Promise<object>} Result with success flag
 */
export async function sendMessage(phoneNumber, body) {
  const module = getMessagesModule();
  return module.sendMessage(phoneNumber, body);
}

export default {
  createCalendarEvent,
  sendMessage,
};
