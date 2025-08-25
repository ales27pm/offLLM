import { NativeModules } from 'react-native';

const { CalendarTurboModule, MessagesTurboModule } = NativeModules;

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
  return CalendarTurboModule.createEvent(title, startDate, endDate, durationSeconds, location, notes);
}

/**
 * Send a text message to a phone number.
 * @param {string} phoneNumber Recipient phone number
 * @param {string} body Message body
 * @returns {Promise<object>} Result with success flag
 */
export async function sendMessage(phoneNumber, body) {
  return MessagesTurboModule.sendMessage(phoneNumber, body);
}

export default {
  createCalendarEvent,
  sendMessage,
};
