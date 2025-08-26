import React, { useEffect, useState } from 'react';
import { View, Text, ActivityIndicator, StyleSheet, Platform } from 'react-native';
import LLMService from './services/llmService';
import { ToolRegistry } from './architecture/toolSystem';
import { builtInTools } from './architecture/toolSystem';
import {
  createCalendarEventTool,
  sendMessageTool,
  makePhoneCallTool,
  getCallHistoryTool,
  getCurrentLocationTool,
  startLocationUpdatesTool,
  stopLocationUpdatesTool,
  showMapTool,
  getDirectionsTool,
  searchPlacesTool,
  findContactTool,
  addContactTool,
  playMusicTool,
  getMusicLibraryTool,
  getBatteryInfoTool,
  getSensorDataTool,
  setClipboardTool,
  getClipboardTool,
  vibrateTool,
  toggleFlashlightTool,
  getDeviceInfoTool,
  setBrightnessTool,
  pickPhotoTool,
  takePhotoTool,
  pickFileTool,
  openUrlTool
} from './tools/iosTools';
import { PluginManager } from './architecture/pluginManager';
import { DependencyInjector } from './architecture/dependencyInjector';

function App() {
  const [initialized, setInitialized] = useState(false);
  const [error, setError] = useState(null);

  useEffect(() => {
    initializeApp();
  }, []);

  const initializeApp = async () => {
    try {
      // Initialize dependency injection
      const dependencyInjector = new DependencyInjector();
      
      // Initialize tool registry
      const toolRegistry = new ToolRegistry();
      Object.entries(builtInTools).forEach(([name, tool]) => {
        toolRegistry.registerTool(name, tool);
      });
      if (Platform.OS === 'ios') {
        const iosToolList = [
          createCalendarEventTool,
          sendMessageTool,
          makePhoneCallTool,
          getCallHistoryTool,
          getCurrentLocationTool,
          startLocationUpdatesTool,
          stopLocationUpdatesTool,
          showMapTool,
          getDirectionsTool,
          searchPlacesTool,
          findContactTool,
          addContactTool,
          playMusicTool,
          getMusicLibraryTool,
          getBatteryInfoTool,
          getSensorDataTool,
          setClipboardTool,
          getClipboardTool,
          vibrateTool,
          toggleFlashlightTool,
          getDeviceInfoTool,
          setBrightnessTool,
          pickPhotoTool,
          takePhotoTool,
          pickFileTool,
          openUrlTool
        ];
        iosToolList.forEach(tool => {
          toolRegistry.registerTool(tool.name, tool);
        });
      }
      
      // Initialize plugin manager
      const pluginManager = new PluginManager();
      
      // Load default model
      await LLMService.loadModel('path/to/default/model');
      
      // Register dependencies
      dependencyInjector.register('toolRegistry', toolRegistry);
      dependencyInjector.register('pluginManager', pluginManager);
      dependencyInjector.register('llmService', LLMService);
      
      setInitialized(true);
    } catch (error) {
      console.error('App initialization failed:', error);
      setError(error.message);
    }
  };

  if (error) {
    return (
      <View style={styles.container}>
        <Text style={styles.error}>Initialization Error: {error}</Text>
      </View>
    );
  }

  if (!initialized) {
    return (
      <View style={styles.container}>
        <ActivityIndicator size="large" />
        <Text style={styles.loading}>Initializing LLM Application...</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Offline LLM Application</Text>
      <Text style={styles.subtitle}>Ready to use</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f5f5f5',
    padding: 20
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 10,
    color: '#333'
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    marginBottom: 20
  },
  loading: {
    marginTop: 20,
    fontSize: 16,
    color: '#666'
  },
  error: {
    fontSize: 16,
    color: 'red',
    textAlign: 'center'
  }
});

export default App;
