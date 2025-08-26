import React from "react";
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  FlatList,
} from "react-native";

export default function ChatInterface({
  messages,
  input,
  onInputChange,
  onSend,
  isRecording,
  onMicPress,
}) {
  const renderItem = ({ item }) => (
    <View
      style={
        item.role === "user" ? styles.userMessage : styles.assistantMessage
      }
    >
      <Text style={styles.messageText}>{item.content}</Text>
    </View>
  );

  return (
    <View style={styles.container}>
      <FlatList
        style={styles.messages}
        data={messages}
        renderItem={renderItem}
        keyExtractor={(item) => item.id}
        inverted
      />
      <View style={styles.inputContainer}>
        <TextInput
          style={styles.textInput}
          value={input}
          onChangeText={onInputChange}
          placeholder="Ask me anything…"
          multiline
        />
        <TouchableOpacity onPress={onSend} style={styles.sendButton}>
          <Text style={styles.sendButtonText}>Send</Text>
        </TouchableOpacity>
        <TouchableOpacity
          onPress={isRecording ? undefined : onMicPress}
          style={[styles.micButton, isRecording && styles.micButtonActive]}
        >
          <Text style={styles.micButtonText}>{isRecording ? "…" : "🎤"}</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, paddingTop: 50, backgroundColor: "#f5f5f5" },
  messages: { flex: 1, paddingHorizontal: 15 },
  userMessage: {
    alignSelf: "flex-end",
    backgroundColor: "#D1E8FF",
    padding: 10,
    borderRadius: 8,
    marginVertical: 4,
    maxWidth: "80%",
  },
  assistantMessage: {
    alignSelf: "flex-start",
    backgroundColor: "#E8E8E8",
    padding: 10,
    borderRadius: 8,
    marginVertical: 4,
    maxWidth: "80%",
  },
  messageText: { fontSize: 16, color: "#333" },
  inputContainer: {
    flexDirection: "row",
    alignItems: "center",
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderTopWidth: 1,
    borderTopColor: "#ccc",
  },
  textInput: {
    flex: 1,
    minHeight: 40,
    maxHeight: 100,
    backgroundColor: "#fff",
    borderRadius: 20,
    paddingHorizontal: 15,
    paddingVertical: 8,
    marginRight: 10,
  },
  sendButton: {
    backgroundColor: "#007AFF",
    paddingVertical: 10,
    paddingHorizontal: 15,
    borderRadius: 20,
  },
  sendButtonText: { color: "#fff", fontWeight: "bold" },
  micButton: { marginLeft: 5, padding: 10 },
  micButtonActive: { opacity: 0.5 },
  micButtonText: { fontSize: 22 },
});
