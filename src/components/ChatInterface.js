import { useMemo, useState } from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  FlatList,
  Switch,
  ScrollView,
  ActivityIndicator,
  useWindowDimensions,
} from "react-native";

const formatTimestamp = (timestamp) => {
  if (!timestamp) {
    return "";
  }
  try {
    const date = new Date(timestamp);
    return date.toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return "";
  }
};

const toPercentage = (value) => {
  if (typeof value !== "number" || Number.isNaN(value)) {
    return 0;
  }
  return Math.max(0, Math.min(100, Math.round(value * 100)));
};

export default function ChatInterface({
  messages,
  input,
  onInputChange,
  onSend,
  isRecording,
  onMicPress,
  onMicStop,
  conversations,
  onSelectConversation,
  onNewConversation,
  currentConversationId,
  voiceModeEnabled,
  onVoiceModeToggle,
  modelOptions,
  onModelSelect,
  selectedModel,
  onDownloadModel,
  modelStatus,
  modelError,
  downloadProgress,
  currentModelPath,
  isGenerating,
}) {
  const { width } = useWindowDimensions();
  const isLargeScreen = width >= 900;
  const [showSidebar, setShowSidebar] = useState(isLargeScreen);
  const canSend = modelStatus === "ready";

  const orderedConversations = useMemo(
    () =>
      conversations.map((conversation) => {
        const lastMessage = conversation.messages.slice(-1)[0];
        return {
          ...conversation,
          lastMessage,
        };
      }),
    [conversations],
  );

  const handleSelectConversation = (conversationId) => {
    onSelectConversation(conversationId);
    if (!isLargeScreen) {
      setShowSidebar(false);
    }
  };

  const renderMessage = ({ item }) => {
    const isUser = item.role === "user";
    return (
      <View style={isUser ? styles.userMessage : styles.assistantMessage}>
        <View style={styles.messageHeader}>
          <Text style={styles.messageRole}>{isUser ? "You" : "Assistant"}</Text>
          <Text style={styles.messageTimestamp}>
            {formatTimestamp(item.timestamp)}
          </Text>
        </View>
        <Text style={styles.messageText}>{item.content}</Text>
      </View>
    );
  };

  const renderConversation = ({ item }) => {
    const isActive = item.id === currentConversationId;
    return (
      <TouchableOpacity
        onPress={() => handleSelectConversation(item.id)}
        style={[styles.conversationItem, isActive && styles.activeConversation]}
      >
        <Text style={styles.conversationTitle}>{item.title}</Text>
        <Text style={styles.conversationTimestamp}>
          {formatTimestamp(item.lastUpdated)}
        </Text>
        <Text style={styles.conversationPreview} numberOfLines={2}>
          {item.lastMessage?.content ?? "No messages yet"}
        </Text>
      </TouchableOpacity>
    );
  };

  const sidebarContent = (
    <View style={styles.sidebarContent}>
      <View style={styles.sidebarSectionHeader}>
        <Text style={styles.sidebarTitle}>Conversations</Text>
        <TouchableOpacity
          onPress={onNewConversation}
          style={styles.newConversationButton}
        >
          <Text style={styles.newConversationText}>New</Text>
        </TouchableOpacity>
      </View>
      <FlatList
        data={orderedConversations}
        keyExtractor={(item) => item.id}
        renderItem={renderConversation}
        ListEmptyComponent={
          <Text style={styles.emptyStateText}>
            Start a conversation to see it here.
          </Text>
        }
        contentContainerStyle={
          orderedConversations.length === 0 && styles.emptyListContainer
        }
      />
      <View style={styles.divider} />
      <View style={styles.toggleRow}>
        <View style={styles.toggleLabelGroup}>
          <Text style={styles.toggleLabel}>Vocal mode</Text>
          <Text style={styles.toggleDescription}>
            Automatically listen for speech and send transcriptions.
          </Text>
          {!canSend && (
            <Text style={styles.toggleDisabledHint}>
              Available once the model is ready.
            </Text>
          )}
        </View>
        <Switch
          value={voiceModeEnabled}
          onValueChange={onVoiceModeToggle}
          disabled={!canSend}
        />
      </View>
      <View style={styles.divider} />
      <ScrollView
        style={styles.settingsScroll}
        contentContainerStyle={styles.settingsContainer}
      >
        <Text style={styles.sidebarTitle}>Model settings</Text>
        <Text style={styles.modelHint}>
          Choose a model, download it for offline use, and load it into the
          assistant.
        </Text>
        {modelOptions.map((option) => {
          const selected = option.id === selectedModel?.id;
          return (
            <TouchableOpacity
              key={option.id}
              style={[
                styles.modelOption,
                selected && styles.modelOptionSelected,
              ]}
              onPress={() => onModelSelect(option)}
            >
              <View style={styles.modelOptionHeader}>
                <Text style={styles.modelOptionTitle}>{option.name}</Text>
                {selected && <Text style={styles.selectedBadge}>Selected</Text>}
              </View>
              {option.description ? (
                <Text style={styles.modelOptionDescription}>
                  {option.description}
                </Text>
              ) : null}
              {option.size ? (
                <Text style={styles.modelOptionMeta}>Size · {option.size}</Text>
              ) : null}
            </TouchableOpacity>
          );
        })}
        <TouchableOpacity
          onPress={onDownloadModel}
          style={[
            styles.downloadButton,
            (modelStatus === "downloading" || modelStatus === "loading") &&
              styles.downloadButtonDisabled,
          ]}
          disabled={
            !selectedModel ||
            modelStatus === "downloading" ||
            modelStatus === "loading"
          }
        >
          <Text style={styles.downloadButtonText}>
            {modelStatus === "downloading" ? "Downloading…" : "Download & Load"}
          </Text>
        </TouchableOpacity>
        <View style={styles.statusRow}>
          <Text style={styles.statusLabel}>Status:</Text>
          <Text style={styles.statusValue}>{modelStatus}</Text>
        </View>
        <View style={styles.progressBarTrack}>
          <View
            style={[
              styles.progressBarFill,
              { width: `${toPercentage(downloadProgress)}%` },
            ]}
          />
        </View>
        {currentModelPath ? (
          <Text style={styles.modelPath} numberOfLines={2}>
            Loaded from: {currentModelPath}
          </Text>
        ) : null}
        {modelError ? (
          <Text style={styles.modelErrorText}>{modelError}</Text>
        ) : null}
      </ScrollView>
    </View>
  );

  return (
    <View style={styles.root}>
      {(isLargeScreen || showSidebar) && (
        <View
          style={[styles.sidebar, !isLargeScreen && styles.sidebarFloating]}
        >
          {!isLargeScreen && (
            <TouchableOpacity
              onPress={() => setShowSidebar(false)}
              style={styles.closeSidebarButton}
            >
              <Text style={styles.closeSidebarText}>Close</Text>
            </TouchableOpacity>
          )}
          {sidebarContent}
        </View>
      )}
      <View style={styles.chatArea}>
        {!isLargeScreen && (
          <View style={styles.mobileHeader}>
            <TouchableOpacity
              onPress={() => setShowSidebar(true)}
              style={styles.openSidebarButton}
            >
              <Text style={styles.openSidebarText}>
                ☰ Conversations & Settings
              </Text>
            </TouchableOpacity>
          </View>
        )}
        <View style={styles.chatHeader}>
          <Text style={styles.chatHeaderTitle}>Chat</Text>
          <View style={styles.chatHeaderStatus}>
            <Text style={styles.headerStatusLabel}>Model:</Text>
            <Text style={styles.headerStatusValue} numberOfLines={1}>
              {selectedModel?.name ?? "Not selected"}
            </Text>
          </View>
          <View style={styles.chatHeaderStatus}>
            <Text style={styles.headerStatusLabel}>Mode:</Text>
            <Text style={styles.headerStatusValue}>
              {voiceModeEnabled ? "Vocal" : "Text"}
            </Text>
          </View>
        </View>
        <FlatList
          style={styles.messages}
          contentContainerStyle={styles.messageListContent}
          data={messages}
          renderItem={renderMessage}
          keyExtractor={(item) => item.id}
          inverted
          keyboardShouldPersistTaps="handled"
          ListEmptyComponent={
            <View style={styles.emptyStateContainer}>
              <Text style={styles.emptyStateTitle}>No messages yet</Text>
              <Text style={styles.emptyStateSubtitle}>
                Ask a question, record your voice, or select a conversation from
                the left panel.
              </Text>
            </View>
          }
          ListFooterComponent={
            isGenerating ? (
              <View style={styles.generatingContainer}>
                <ActivityIndicator size="small" color="#007AFF" />
                <Text style={styles.generatingText}>Thinking…</Text>
              </View>
            ) : null
          }
        />
        <View style={styles.inputContainer}>
          <TextInput
            style={styles.textInput}
            value={input}
            onChangeText={onInputChange}
            placeholder={
              voiceModeEnabled
                ? "Listening… tap send to confirm or type to edit"
                : "Ask me anything…"
            }
            multiline
            onSubmitEditing={onSend}
            blurOnSubmit={false}
          />
          <TouchableOpacity
            onPress={onSend}
            style={[
              styles.sendButton,
              (!input.trim() || !canSend) && styles.disabledButton,
            ]}
            disabled={!input.trim() || !canSend}
          >
            <Text style={styles.sendButtonText}>Send</Text>
          </TouchableOpacity>
          <TouchableOpacity
            onPress={isRecording ? onMicStop : onMicPress}
            style={[
              styles.micButton,
              isRecording && styles.micButtonActive,
              !isRecording && !canSend && styles.disabledButton,
            ]}
            disabled={!isRecording && !canSend}
          >
            <Text style={styles.micButtonText}>
              {isRecording ? "⏹" : "🎤"}
            </Text>
          </TouchableOpacity>
        </View>
        {!canSend && (
          <Text style={styles.sendHint}>
            Model status: {modelStatus}. Sending is disabled until it is ready.
          </Text>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
    backgroundColor: "#f5f7fa",
    flexDirection: "row",
  },
  sidebar: {
    width: 320,
    backgroundColor: "#ffffff",
    borderRightWidth: 1,
    borderRightColor: "#e0e6ef",
  },
  sidebarFloating: {
    position: "absolute",
    top: 0,
    bottom: 0,
    left: 0,
    zIndex: 10,
    shadowColor: "#000",
    shadowOpacity: 0.1,
    shadowRadius: 12,
    elevation: 8,
  },
  sidebarContent: {
    flex: 1,
    paddingTop: 48,
    paddingHorizontal: 16,
  },
  sidebarTitle: {
    fontSize: 18,
    fontWeight: "600",
    color: "#132149",
    marginBottom: 8,
  },
  sidebarSectionHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 12,
  },
  newConversationButton: {
    backgroundColor: "#007AFF",
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
  },
  newConversationText: {
    color: "#fff",
    fontWeight: "600",
  },
  conversationItem: {
    padding: 12,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: "#e0e6ef",
    marginBottom: 10,
    backgroundColor: "#fff",
  },
  activeConversation: {
    borderColor: "#007AFF",
    backgroundColor: "#f0f6ff",
  },
  conversationTitle: {
    fontSize: 16,
    fontWeight: "600",
    color: "#0f1a34",
  },
  conversationTimestamp: {
    fontSize: 12,
    color: "#6b7a99",
    marginTop: 4,
  },
  conversationPreview: {
    fontSize: 14,
    color: "#3b4b6b",
    marginTop: 6,
  },
  emptyStateText: {
    textAlign: "center",
    color: "#6b7a99",
    marginTop: 32,
  },
  emptyListContainer: {
    flexGrow: 1,
    justifyContent: "center",
  },
  divider: {
    height: 1,
    backgroundColor: "#e0e6ef",
    marginVertical: 16,
  },
  toggleRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 16,
  },
  toggleLabelGroup: { flex: 1, paddingRight: 12 },
  toggleLabel: {
    fontSize: 16,
    fontWeight: "600",
    color: "#0f1a34",
  },
  toggleDescription: {
    fontSize: 13,
    color: "#6b7a99",
    marginTop: 4,
  },
  toggleDisabledHint: {
    fontSize: 12,
    color: "#9aa6c3",
    marginTop: 2,
  },
  settingsScroll: { flex: 1 },
  settingsContainer: {
    paddingBottom: 64,
  },
  modelHint: {
    fontSize: 13,
    color: "#6b7a99",
    marginBottom: 12,
  },
  modelOption: {
    borderWidth: 1,
    borderColor: "#d5dceb",
    borderRadius: 14,
    padding: 12,
    marginBottom: 12,
  },
  modelOptionSelected: {
    borderColor: "#007AFF",
    backgroundColor: "#f0f6ff",
  },
  modelOptionHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 6,
  },
  modelOptionTitle: {
    fontSize: 16,
    fontWeight: "600",
    color: "#0f1a34",
  },
  selectedBadge: {
    fontSize: 12,
    fontWeight: "600",
    color: "#007AFF",
  },
  modelOptionDescription: {
    fontSize: 13,
    color: "#3b4b6b",
    marginBottom: 4,
  },
  modelOptionMeta: {
    fontSize: 12,
    color: "#6b7a99",
  },
  downloadButton: {
    marginTop: 4,
    marginBottom: 8,
    backgroundColor: "#007AFF",
    paddingVertical: 12,
    borderRadius: 20,
    alignItems: "center",
  },
  downloadButtonDisabled: {
    opacity: 0.6,
  },
  downloadButtonText: {
    color: "#fff",
    fontWeight: "700",
    fontSize: 16,
  },
  statusRow: {
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 8,
  },
  statusLabel: {
    fontSize: 14,
    fontWeight: "500",
    color: "#3b4b6b",
    marginRight: 8,
  },
  statusValue: {
    fontSize: 14,
    color: "#0f1a34",
    textTransform: "capitalize",
  },
  progressBarTrack: {
    height: 6,
    borderRadius: 3,
    backgroundColor: "#e0e6ef",
    overflow: "hidden",
    marginBottom: 8,
  },
  progressBarFill: {
    height: "100%",
    backgroundColor: "#007AFF",
    borderRadius: 3,
  },
  modelPath: {
    fontSize: 12,
    color: "#3b4b6b",
  },
  modelErrorText: {
    marginTop: 8,
    color: "#c81e1e",
    fontSize: 13,
  },
  chatArea: {
    flex: 1,
    paddingTop: 48,
    paddingHorizontal: 24,
  },
  mobileHeader: {
    marginBottom: 12,
  },
  openSidebarButton: {
    backgroundColor: "#ffffff",
    borderRadius: 24,
    paddingVertical: 10,
    paddingHorizontal: 18,
    borderWidth: 1,
    borderColor: "#e0e6ef",
    alignSelf: "flex-start",
  },
  openSidebarText: {
    fontSize: 15,
    fontWeight: "600",
    color: "#132149",
  },
  closeSidebarButton: {
    alignSelf: "flex-end",
    marginTop: 18,
    marginRight: 16,
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 14,
    backgroundColor: "#f0f3fa",
  },
  closeSidebarText: {
    color: "#132149",
    fontWeight: "600",
  },
  chatHeader: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between",
    marginBottom: 16,
  },
  chatHeaderTitle: {
    fontSize: 24,
    fontWeight: "700",
    color: "#0f1a34",
  },
  chatHeaderStatus: {
    flexDirection: "row",
    alignItems: "center",
    maxWidth: 200,
  },
  headerStatusLabel: {
    fontSize: 13,
    color: "#6b7a99",
    marginRight: 6,
  },
  headerStatusValue: {
    fontSize: 14,
    color: "#132149",
    fontWeight: "600",
  },
  messages: {
    flex: 1,
  },
  messageListContent: {
    paddingBottom: 24,
    paddingHorizontal: 4,
  },
  messageHeader: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
    marginBottom: 4,
  },
  messageRole: {
    fontSize: 12,
    fontWeight: "700",
    color: "#132149",
    textTransform: "uppercase",
  },
  messageTimestamp: {
    fontSize: 11,
    color: "#6b7a99",
  },
  userMessage: {
    alignSelf: "flex-end",
    backgroundColor: "#dceeff",
    padding: 12,
    borderRadius: 16,
    marginVertical: 6,
    maxWidth: "80%",
  },
  assistantMessage: {
    alignSelf: "flex-start",
    backgroundColor: "#ffffff",
    padding: 12,
    borderRadius: 16,
    marginVertical: 6,
    borderWidth: 1,
    borderColor: "#e0e6ef",
    maxWidth: "80%",
  },
  messageText: {
    fontSize: 16,
    color: "#111827",
    lineHeight: 22,
  },
  emptyStateContainer: {
    paddingVertical: 48,
    alignItems: "center",
  },
  emptyStateTitle: {
    fontSize: 18,
    fontWeight: "600",
    color: "#132149",
    marginBottom: 8,
  },
  emptyStateSubtitle: {
    fontSize: 14,
    color: "#6b7a99",
    textAlign: "center",
    paddingHorizontal: 24,
  },
  generatingContainer: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    paddingVertical: 12,
  },
  generatingText: {
    marginLeft: 8,
    color: "#6b7a99",
    fontSize: 14,
  },
  inputContainer: {
    flexDirection: "row",
    alignItems: "flex-end",
    paddingVertical: 12,
    borderTopWidth: 1,
    borderTopColor: "#d5dceb",
  },
  textInput: {
    flex: 1,
    minHeight: 44,
    maxHeight: 120,
    backgroundColor: "#ffffff",
    borderRadius: 22,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 16,
    borderWidth: 1,
    borderColor: "#e0e6ef",
  },
  sendButton: {
    backgroundColor: "#007AFF",
    paddingHorizontal: 18,
    paddingVertical: 12,
    borderRadius: 22,
    marginLeft: 8,
  },
  disabledButton: {
    opacity: 0.5,
  },
  sendButtonText: {
    color: "#fff",
    fontWeight: "700",
    fontSize: 16,
  },
  micButton: {
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 22,
    backgroundColor: "#ffffff",
    borderWidth: 1,
    borderColor: "#e0e6ef",
    marginLeft: 8,
  },
  micButtonActive: {
    backgroundColor: "#ffece5",
    borderColor: "#ff9472",
  },
  micButtonText: {
    fontSize: 20,
  },
  sendHint: {
    fontSize: 12,
    color: "#6b7a99",
    marginTop: 4,
  },
});
