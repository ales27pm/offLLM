import { useEffect, useState } from "react";
import {
  View,
  Text,
  ActivityIndicator,
  StyleSheet,
  Platform,
} from "react-native";
import LLMService from "./services/llmService";
import { ensureModelDownloaded } from "./utils/modelDownloader";
import { ToolRegistry, builtInTools } from "./architecture/toolSystem";
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
  openUrlTool,
} from "./tools/iosTools";
import { PluginManager } from "./architecture/pluginManager";
import { DependencyInjector } from "./architecture/dependencyInjector";
import ChatInterface from "./components/ChatInterface";
import { useSpeechRecognition } from "./hooks/useSpeechRecognition";
import { useChat } from "./hooks/useChat";
import useLLMStore from "./store/llmStore";

function App() {
  const [initialized, setInitialized] = useState(false);
  const [error, setError] = useState(null);
  const [input, setInput] = useState("");
  const { send } = useChat();
  const { messages } = useLLMStore();
  const { isRecording, start } = useSpeechRecognition(send, (err) =>
    console.warn("Speech recognition error", err)
  );

  useEffect(() => {
    initializeApp();
  }, []);

  const initializeApp = async () => {
    try {
      const dependencyInjector = new DependencyInjector();
      const toolRegistry = new ToolRegistry();
      Object.entries(builtInTools).forEach(([name, tool]) => {
        toolRegistry.registerTool(name, tool);
      });
      if (Platform.OS === "ios") {
        [
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
          openUrlTool,
        ].forEach((tool) => {
          toolRegistry.registerTool(tool.name, tool);
        });
      }
      const pluginManager = new PluginManager();
      const MODEL_URL = "https://example.com/model.bin"; // TODO: set actual model URL
      const modelPath = await ensureModelDownloaded(MODEL_URL);
      await LLMService.loadModel(modelPath);
      dependencyInjector.register("toolRegistry", toolRegistry);
      dependencyInjector.register("pluginManager", pluginManager);
      dependencyInjector.register("llmService", LLMService);
      setInitialized(true);
    } catch (err) {
      console.error("App initialization failed:", err);
      setError(err.message);
    }
  };

  const handleSend = (text) => {
    const message = text || input;
    send(message);
    setInput("");
  };

  if (error) {
    return (
      <View style={styles.centered}>
        <Text style={styles.errorText}>Error initializing app: {error}</Text>
      </View>
    );
  }

  if (!initialized) {
    return (
      <View style={styles.centered}>
        <ActivityIndicator size="large" />
        <Text style={styles.loading}>Initializing...</Text>
      </View>
    );
  }

  return (
    <ChatInterface
      messages={messages}
      input={input}
      onInputChange={setInput}
      onSend={() => handleSend()}
      isRecording={isRecording}
      onMicPress={start}
    />
  );
}

const styles = StyleSheet.create({
  centered: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
  },
  loading: { marginTop: 20 },
  errorText: { color: "red" },
});

export default App;
