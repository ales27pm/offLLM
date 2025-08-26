import React, { useEffect, useState, useRef } from 'react';
import {
  View,
  Text,
  ActivityIndicator,
  StyleSheet,
  Platform,
  ScrollView,
  TextInput,
  TouchableOpacity
} from 'react-native';
import Voice from '@react-native-voice/voice';
import Tts from 'react-native-tts';
import LLMService from './services/llmService';
import { ToolRegistry, builtInTools } from './architecture/toolSystem';
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

// Optional: import vector store for contextual memory. You can comment this
// out if you do not need long‑term context.
import { HNSWVectorStore } from './utils/hnswVectorStore';

function App() {
  const [initialized, setInitialized] = useState(false);
  const [error, setError] = useState(null);
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [isRecording, setIsRecording] = useState(false);
  const vectorStoreRef = useRef(null);

  useEffect(() => {
    initializeApp();
    // Set up voice event listeners
    Voice.onSpeechResults = onSpeechResults;
    Voice.onSpeechError = onSpeechError;
    Tts.setDefaultRate(0.53);
    Tts.setDefaultPitch(1.0);
    return () => {
      Voice.destroy().then(() => Voice.removeAllListeners());
    };
  }, []);

  const initializeApp = async () => {
    try {
      const dependencyInjector = new DependencyInjector();
      const toolRegistry = new ToolRegistry();
      // Register built‑in tools
      Object.entries(builtInTools).forEach(([name, tool]) => {
        toolRegistry.registerTool(name, tool);
      });
      // Register iOS‑specific tools when on iOS
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
      const pluginManager = new PluginManager();
      // Load a default model. In a real app you would configure the path
      // via settings or download.
      await LLMService.loadModel('path/to/default/model');
      // Optionally initialize the vector store for context retrieval
      const vs = new HNSWVectorStore();
      await vs.initialize({ quantization: 'scalar' });
      vectorStoreRef.current = vs;
      dependencyInjector.register('toolRegistry', toolRegistry);
      dependencyInjector.register('pluginManager', pluginManager);
      dependencyInjector.register('llmService', LLMService);
      setInitialized(true);
    } catch (err) {
      console.error('App initialization failed:', err);
      setError(err.message);
    }
  };

  const detectEmotion = (text) => {
    const lower = text.toLowerCase();
    const checks = {
      happy: ['happy', 'glad', 'joy', 'excited', 'awesome'],
      sad: ['sad', 'unhappy', 'depressed', 'down'],
      angry: ['angry', 'mad', 'furious', 'annoyed', 'frustrated'],
      scared: ['scared', 'afraid', 'fear', 'nervous'],
      surprised: ['surprised', 'shocked']
    };
    for (const emotion of Object.keys(checks)) {
      if (checks[emotion].some(word => lower.includes(word))) {
        return emotion;
      }
    }
    return null;
  };

  const getContext = async (query) => {
    try {
      if (!vectorStoreRef.current) return '';
      const embedding = await LLMService.embed(query);
      const results = await vectorStoreRef.current.searchVectors(embedding, 3);
      return results.map(r => r.content).join('\n\n');
    } catch (e) {
      console.warn('Context retrieval failed:', e);
      return '';
    }
  };

  const handleSend = async (text) => {
    const query = (text || input).trim();
    if (!query) return;
    // Append user message
    setMessages(prev => [...prev, { id: prev.length + 1, sender: 'user', text: query }]);
    setInput('');
    try {
      const emotion = detectEmotion(query);
      const context = await getContext(query);
      let prompt = query;
      if (emotion) {
        prompt = `The user sounds ${emotion}. ${query}`;
      }
      if (context) {
        prompt = `Context:\n${context}\n\n${prompt}`;
      }
      const response = await LLMService.generate(prompt, 256, 0.7, { useSparseAttention: true });
      const reply = response?.text || '';
      setMessages(prev => [...prev, { id: prev.length + 2, sender: 'assistant', text: reply }]);
      // Speak the response with a slight pause after sentences
      Tts.stop();
      // Insert small breaks to make speech more natural
      const speechText = reply.replace(/([.?!])\s+/g, '$1 <break time="500ms"/> ');
      Tts.speak(speechText, {
        androidParams: {
          KEY_PARAM_PAN: 0,
          KEY_PARAM_VOLUME: 0.9,
          KEY_PARAM_STREAM: 'STREAM_MUSIC'
        }
      });
    } catch (e) {
      console.error('Error generating response:', e);
      setMessages(prev => [...prev, { id: prev.length + 2, sender: 'assistant', text: 'Error: ' + e.message }]);
    }
  };

  const onSpeechResults = (event) => {
    const values = event.value;
    if (values && values.length > 0) {
      const spoken = values[0];
      setInput(spoken);
      handleSend(spoken);
    }
    setIsRecording(false);
  };

  const onSpeechError = (event) => {
    console.warn('Speech recognition error', event.error);
    setIsRecording(false);
  };

  const startRecording = async () => {
    try {
      setIsRecording(true);
      await Voice.start('en-US');
    } catch (e) {
      console.warn('Voice start failed', e);
      setIsRecording(false);
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
      <Text style={styles.title}>Offline LLM Assistant</Text>
      <ScrollView
        style={styles.messages}
        contentContainerStyle={{ paddingVertical: 10 }}
        ref={ref => {
          if (ref) {
            // Scroll to bottom when messages change
            setTimeout(() => ref.scrollToEnd({ animated: true }), 100);
          }
        }}
      >
        {messages.map(msg => (
          <View
            key={msg.id}
            style={msg.sender === 'user' ? styles.userMessage : styles.assistantMessage}
          >
            <Text style={styles.messageText}>{msg.text}</Text>
          </View>
        ))}
      </ScrollView>
      <View style={styles.inputContainer}>
        <TextInput
          style={styles.textInput}
          value={input}
          onChangeText={setInput}
          placeholder="Ask me anything…"
          multiline
        />
        <TouchableOpacity onPress={() => handleSend()} style={styles.sendButton}>
          <Text style={styles.sendButtonText}>Send</Text>
        </TouchableOpacity>
        <TouchableOpacity
          onPress={isRecording ? null : startRecording}
          style={[styles.micButton, isRecording && styles.micButtonActive]}
        >
          <Text style={styles.micButtonText}>{isRecording ? '…' : '🎤'}</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    paddingTop: 50
  },
  title: {
    fontSize: 22,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 10
  },
  messages: {
    flex: 1,
    paddingHorizontal: 15
  },
  userMessage: {
    alignSelf: 'flex-end',
    backgroundColor: '#D1E8FF',
    padding: 10,
    borderRadius: 8,
    marginVertical: 4,
    maxWidth: '80%'
  },
  assistantMessage: {
    alignSelf: 'flex-start',
    backgroundColor: '#E8E8E8',
    padding: 10,
    borderRadius: 8,
    marginVertical: 4,
    maxWidth: '80%'
  },
  messageText: {
    fontSize: 16,
    color: '#333'
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderTopWidth: 1,
    borderTopColor: '#ccc'
  },
  textInput: {
    flex: 1,
    minHeight: 40,
    maxHeight: 100,
    backgroundColor: '#fff',
    borderRadius: 20,
    paddingHorizontal: 15,
    paddingVertical: 8,
    marginRight: 10
  },
  sendButton: {
    backgroundColor: '#007AFF',
    paddingVertical: 10,
    paddingHorizontal: 15,
    borderRadius: 20
  },
  sendButtonText: {
    color: '#fff',
    fontWeight: 'bold'
  },
  micButton: {
    marginLeft: 5,
    padding: 10
  },
  micButtonActive: {
    opacity: 0.5
  },
  micButtonText: {
    fontSize: 22
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

