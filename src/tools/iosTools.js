import { NativeModules } from 'react-native';

const { CalendarTurboModule, MessagesTurboModule } = NativeModules;

export const iosTools = {
  createCalendarEvent: {
    description: 'Create a new calendar event',
    parameters: {
      title: { type: 'string', required: true, description: 'Event title' },
      date: { type: 'string', required: true, description: 'Start date in ISO 8601 format' },
      notes: { type: 'string', required: false, description: 'Event notes' },
      location: { type: 'string', required: false, description: 'Event location' }
    },
    execute: async ({ title, date, notes, location }) => {
      return await CalendarTurboModule.createEvent(title, date, location || '', notes || '');
    }
  },
  sendMessage: {
    description: 'Send a text message to a phone number',
    parameters: {
      phoneNumber: { type: 'string', required: true, description: 'Recipient phone number' },
      body: { type: 'string', required: true, description: 'Message body' }
    },
    execute: async ({ phoneNumber, body }) => {
      return await MessagesTurboModule.sendMessage(phoneNumber, body);
    }
  }
};

export default iosTools;
