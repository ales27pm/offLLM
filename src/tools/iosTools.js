import { NativeModules, Linking, Platform, Vibration, Clipboard } from 'react-native';

const {
  CalendarTurboModule,
  RemindersTurboModule,
  MessagesTurboModule,
  MailTurboModule,
  HealthTurboModule,
  WeatherTurboModule,
  NotesTurboModule,
  AlarmsTurboModule,
  MapsTurboModule,
  PhotosTurboModule,
  CameraTurboModule,
  FilesTurboModule,
  LocationTurboModule,
  ContactsTurboModule,
  CallTurboModule,
  MusicTurboModule,
  BatteryTurboModule,
  SensorsTurboModule,
  ClipboardTurboModule,
  VibrationTurboModule,
  FlashlightTurboModule,
  DeviceInfoTurboModule,
  BrightnessTurboModule
} = NativeModules;

// Calendar Tools
export const createCalendarEventTool = {
  name: 'create_calendar_event',
  description: 'Create a new calendar event with title, date, location, notes',
  parameters: {
    title: { type: 'string', required: true },
    startDate: { type: 'string', required: true, description: 'ISO 8601 format' },
    endDate: { type: 'string', required: false, description: 'ISO 8601 format' },
    location: { type: 'string', required: false },
    notes: { type: 'string', required: false }
  },
  execute: async (params) => {
    const endDate =
      params.endDate || new Date(new Date(params.startDate).getTime() + 3600000).toISOString();
    return await CalendarTurboModule.createEvent(
      params.title,
      params.startDate,
      endDate,
      params.location,
      params.notes
    );
  }
};

export const getCalendarEventsTool = {
  name: 'get_calendar_events',
  description: 'Fetch calendar events in a date range',
  parameters: {
    startDate: { type: 'string', required: true, description: 'ISO 8601' },
    endDate: { type: 'string', required: true, description: 'ISO 8601' }
  },
  execute: async (params) => await CalendarTurboModule.fetchEvents(params.startDate, params.endDate)
};

// Reminders Tools
export const createReminderTool = {
  name: 'create_reminder',
  description: 'Create a new reminder',
  parameters: {
    title: { type: 'string', required: true },
    dueDate: { type: 'string', required: false, description: 'ISO 8601' },
    notes: { type: 'string', required: false },
    priority: { type: 'number', required: false, description: '1-9' }
  },
  execute: async (params) =>
    await RemindersTurboModule.createReminder(
      params.title,
      params.dueDate,
      params.notes,
      params.priority || 0
    )
};

export const getRemindersTool = {
  name: 'get_reminders',
  description: 'Fetch reminders',
  parameters: {
    completed: { type: 'boolean', required: false }
  },
  execute: async (params) =>
    await RemindersTurboModule.fetchReminders(params.completed ?? false)
};

// Messages/SMS Tool
export const sendMessageTool = {
  name: 'send_message',
  description: 'Compose and send SMS/iMessage (user confirmation required)',
  parameters: {
    recipient: { type: 'string', required: true, description: 'Phone number or email' },
    body: { type: 'string', required: true }
  },
  execute: async (params) =>
    await MessagesTurboModule.sendMessage(params.recipient, params.body)
};

// Phone Call Tools
export const makePhoneCallTool = {
  name: 'make_phone_call',
  description: 'Initiate a phone call (user confirmation required)',
  parameters: {
    phoneNumber: { type: 'string', required: true }
  },
  execute: async (params) => {
    const url = `tel:${params.phoneNumber}`;
    if (await Linking.canOpenURL(url)) {
      await Linking.openURL(url);
      return { success: true };
    }
    throw new Error('Cannot make call');
  }
};

export const getCallHistoryTool = {
  name: 'get_call_history',
  description: 'Get recent call history (limited access)',
  parameters: {
    limit: { type: 'number', required: false, default: 10 }
  },
  execute: async (params) =>
    await CallTurboModule.getRecentCalls(params.limit || 10)
};

// Email Tool
export const sendEmailTool = {
  name: 'send_email',
  description: 'Compose and send email (user confirmation required)',
  parameters: {
    to: { type: 'string', required: true },
    subject: { type: 'string', required: true },
    body: { type: 'string', required: true }
  },
  execute: async (params) =>
    await MailTurboModule.sendEmail(params.to, params.subject, params.body)
};

// Notes Tool
export const createNoteTool = {
  name: 'create_note',
  description: 'Create a new note in Notes app (via sharing)',
  parameters: {
    title: { type: 'string', required: true },
    body: { type: 'string', required: true }
  },
  execute: async (params) =>
    await NotesTurboModule.createNote(params.title, params.body)
};

// Alarms Tool
export const createAlarmTool = {
  name: 'create_alarm',
  description: 'Create an alarm using local notification',
  parameters: {
    title: { type: 'string', required: true },
    date: { type: 'string', required: true, description: 'ISO 8601' },
    sound: { type: 'boolean', required: false, default: true }
  },
  execute: async (params) =>
    await AlarmsTurboModule.scheduleAlarm(
      params.title,
      params.date,
      params.sound ?? true
    )
};

// Weather Tool
export const getWeatherTool = {
  name: 'get_weather',
  description: 'Get current weather or forecast',
  parameters: {
    location: { type: 'string', required: true, description: 'City or lat,long' },
    type: {
      type: 'string',
      required: false,
      default: 'current',
      enum: ['current', 'forecast']
    }
  },
  execute: async (params) =>
    await WeatherTurboModule.getWeather(params.location, params.type || 'current')
};

// Health Tools
export const getHealthDataTool = {
  name: 'get_health_data',
  description: 'Read health data like steps, heart rate',
  parameters: {
    type: { type: 'string', required: true, enum: ['steps', 'heartRate', 'sleep'] },
    startDate: { type: 'string', required: true, description: 'ISO 8601' },
    endDate: { type: 'string', required: true, description: 'ISO 8601' }
  },
  execute: async (params) =>
    await HealthTurboModule.queryHealthData(
      params.type,
      params.startDate,
      params.endDate
    )
};

export const logHealthDataTool = {
  name: 'log_health_data',
  description: 'Write health data',
  parameters: {
    type: { type: 'string', required: true, enum: ['steps', 'heartRate'] },
    value: { type: 'number', required: true },
    date: { type: 'string', required: true, description: 'ISO 8601' }
  },
  execute: async (params) =>
    await HealthTurboModule.saveHealthData(
      params.type,
      params.value,
      params.date
    )
};

// Location/GPS Tools
export const getCurrentLocationTool = {
  name: 'get_current_location',
  description: 'Get current GPS location',
  parameters: {
    accuracy: {
      type: 'string',
      required: false,
      default: 'high',
      enum: ['low', 'medium', 'high']
    }
  },
  execute: async (params) =>
    await LocationTurboModule.getCurrentLocation(params.accuracy || 'high')
};

export const startLocationUpdatesTool = {
  name: 'start_location_updates',
  description: 'Start continuous location updates',
  parameters: {
    interval: { type: 'number', required: false, default: 10000 }
  },
  execute: async (params) =>
    await LocationTurboModule.startUpdates(params.interval || 10000)
};

export const stopLocationUpdatesTool = {
  name: 'stop_location_updates',
  description: 'Stop location updates',
  parameters: {},
  execute: async () => await LocationTurboModule.stopUpdates()
};

// Maps Tools
export const showMapTool = {
  name: 'show_map',
  description: 'Display map at location',
  parameters: {
    latitude: { type: 'number', required: true },
    longitude: { type: 'number', required: true },
    title: { type: 'string', required: false }
  },
  execute: async (params) =>
    await MapsTurboModule.showMap(params.latitude, params.longitude, params.title)
};

export const getDirectionsTool = {
  name: 'get_directions',
  description: 'Get directions between points',
  parameters: {
    from: { type: 'string', required: true, description: 'Address or lat,long' },
    to: { type: 'string', required: true, description: 'Address or lat,long' },
    mode: {
      type: 'string',
      required: false,
      default: 'driving',
      enum: ['driving', 'walking', 'transit']
    }
  },
  execute: async (params) =>
    await MapsTurboModule.getDirections(params.from, params.to, params.mode || 'driving')
};

export const searchPlacesTool = {
  name: 'search_places',
  description: 'Search for places on map',
  parameters: {
    query: { type: 'string', required: true },
    near: { type: 'string', required: false, description: 'lat,long or address' }
  },
  execute: async (params) =>
    await MapsTurboModule.searchPlaces(params.query, params.near)
};

// Contacts Tools
export const findContactTool = {
  name: 'find_contact',
  description: 'Find contact by name or number',
  parameters: {
    query: { type: 'string', required: true }
  },
  execute: async (params) =>
    await ContactsTurboModule.findContact(params.query)
};

export const addContactTool = {
  name: 'add_contact',
  description: 'Add new contact',
  parameters: {
    name: { type: 'string', required: true },
    phone: { type: 'string', required: false },
    email: { type: 'string', required: false }
  },
  execute: async (params) =>
    await ContactsTurboModule.addContact(params.name, params.phone, params.email)
};

// Music Tools
export const playMusicTool = {
  name: 'play_music',
  description: 'Play music from library',
  parameters: {
    query: { type: 'string', required: true, description: 'Song, artist, or playlist' }
  },
  execute: async (params) =>
    await MusicTurboModule.playMusic(params.query)
};

export const getMusicLibraryTool = {
  name: 'get_music_library',
  description: 'Search music library',
  parameters: {
    query: { type: 'string', required: true },
    type: {
      type: 'string',
      required: false,
      default: 'songs',
      enum: ['songs', 'artists', 'playlists']
    }
  },
  execute: async (params) =>
    await MusicTurboModule.searchLibrary(params.query, params.type || 'songs')
};

// Battery Tool
export const getBatteryInfoTool = {
  name: 'get_battery_info',
  description: 'Get battery level and state',
  parameters: {},
  execute: async () => await BatteryTurboModule.getBatteryInfo()
};

// Sensors Tool
export const getSensorDataTool = {
  name: 'get_sensor_data',
  description: 'Get accelerometer/gyro data',
  parameters: {
    type: {
      type: 'string',
      required: true,
      enum: ['accelerometer', 'gyroscope', 'magnetometer']
    },
    duration: { type: 'number', required: false, default: 1000 }
  },
  execute: async (params) =>
    await SensorsTurboModule.getSensorData(params.type, params.duration || 1000)
};

// Clipboard Tools
export const setClipboardTool = {
  name: 'set_clipboard',
  description: 'Set text to clipboard',
  parameters: {
    text: { type: 'string', required: true }
  },
  execute: async (params) => {
    Clipboard.setString(params.text);
    return { success: true };
  }
};

export const getClipboardTool = {
  name: 'get_clipboard',
  description: 'Get text from clipboard',
  parameters: {},
  execute: async () => ({ text: await Clipboard.getString() })
};

// Vibration Tool
export const vibrateTool = {
  name: 'vibrate',
  description: 'Vibrate device',
  parameters: {
    pattern: { type: 'array', required: false, default: [1000] }
  },
  execute: async (params) => {
    Vibration.vibrate(params.pattern || [1000]);
    return { success: true };
  }
};

// Flashlight Tool
export const toggleFlashlightTool = {
  name: 'toggle_flashlight',
  description: 'Toggle flashlight on/off',
  parameters: {
    on: { type: 'boolean', required: true }
  },
  execute: async (params) =>
    await FlashlightTurboModule.setTorchMode(params.on)
};

// Device Info Tool
export const getDeviceInfoTool = {
  name: 'get_device_info',
  description: 'Get device information',
  parameters: {},
  execute: async () => await DeviceInfoTurboModule.getDeviceInfo()
};

// Brightness Tool
export const setBrightnessTool = {
  name: 'set_brightness',
  description: 'Set screen brightness (0-1)',
  parameters: {
    level: { type: 'number', required: true }
  },
  execute: async (params) => {
    if (Platform.OS === 'ios' && BrightnessTurboModule?.setBrightness) {
      await BrightnessTurboModule.setBrightness(params.level);
      return { success: true };
    }
    throw new Error('Brightness control not implemented on this platform');
  }
};

// Photos Tools
export const pickPhotoTool = {
  name: 'pick_photo',
  description: 'Pick photo from library',
  parameters: {},
  execute: async () => await PhotosTurboModule.pickPhoto()
};

export const takePhotoTool = {
  name: 'take_photo',
  description: 'Take photo with camera',
  parameters: {
    quality: { type: 'number', required: false, default: 0.8 }
  },
  execute: async (params) =>
    await CameraTurboModule.takePhoto(params.quality || 0.8)
};

// Files Tool
export const pickFileTool = {
  name: 'pick_file',
  description: 'Pick file from device',
  parameters: {
    type: { type: 'string', required: false, default: 'any' }
  },
  execute: async (params) =>
    await FilesTurboModule.pickFile(params.type || 'any')
};

// URL Tool
export const openUrlTool = {
  name: 'open_url',
  description: 'Open URL in Safari',
  parameters: {
    url: { type: 'string', required: true }
  },
  execute: async (params) => {
    if (await Linking.canOpenURL(params.url)) {
      await Linking.openURL(params.url);
      return { success: true };
    }
    throw new Error('Cannot open URL');
  }
};

