# offLLM

An experimental offline AI assistant for mobile devices. offLLM runs a
quantized large language model directly on your phone and exposes a suite of
device tools (calendar, messaging, phone, GPS, etc.) to the model. The
assistant can answer questions, perform calculations, search the web, and
interact with native APIs all without sending your data to the cloud. A new
chat interface allows you to talk to the assistant via text or voice.

## Features

- **On‑device inference** using a quantized Llama model via llama.cpp on
  Android and MLX on iOS. Models can be swapped by placing the file on
  your device and updating the path in `App.js`.
- **Chat interface** with support for multi‑turn conversations. Messages are
  displayed in a scrollable list and you can speak queries using the built-in
  microphone button. Responses are read aloud using `react‑native‑tts`.
- **Emotion awareness** – the assistant detects basic emotions in your
  requests (happy, sad, angry, etc.) and can tailor its responses
  accordingly. Emotion cues are passed to the LLM in the prompt.
- **Contextual memory** via an HNSW vector store. When enabled, the
  assistant retrieves relevant past information from a local, encrypted
  database and injects it into the prompt to improve answer quality.
- **Adaptive performance** – quantization levels are adjusted based on
  inference times and memory usage. Sparse attention is enabled
  automatically for long contexts.
- **Extensible tool system** – register your own tools in `toolSystem.js`
  or enable device APIs on iOS. Android gracefully reports unsupported
  tools.

### Contextual memory (HNSW)

The assistant can optionally store vector embeddings of conversation snippets in an encrypted HNSW index. Retrieval happens on‑device and is bounded by the `MEMORY_MAX_MB` limit. Memory can be exported, imported or wiped entirely. Enable this feature by setting `MEMORY_ENABLED=true` and provide a 32‑byte `MEMORY_ENCRYPTION_KEY`.

## Getting started

1. Install dependencies and build the app:

   ```bash
   npm install
   npx react-native run-ios   # or run-android
   ```

   > A stub `android/gradlew` script is included so CI environments can invoke `npm run build:android` without the Android SDK. Replace this stub with a full Gradle wrapper for real builds.

2. Place a compatible Llama model file on your device (e.g. in the app's
   documents directory) and update the path in `App.js` where
   `LLMService.loadModel` is called. Quantized models (Q4 or Q5) are
   recommended for mobile. The app will automatically configure context
   lengths and enable sparse attention for quantized models.

3. On the first launch the assistant will load the model, initialize the
   vector store and register tools. Once initialization completes you can
   begin chatting. Tap the microphone to speak your query; otherwise type
   and press Send.

4. To enable web search you must provide API keys for your preferred
   providers in `.env` and set them in `src/services/utils/apiKeys.js`.

## Configuration

- `MEMORY_ENABLED` – set to `true` to enable encrypted local memory.
- `MEMORY_MAX_MB` – maximum size of memory database in megabytes (default `10`).
- `MEMORY_ENCRYPTION_KEY` – 32 byte key used for AES‑GCM encryption.
- `EMOTION_AUDIO_ENABLED` – enable on‑device audio prosody detection.

## Development notes

This project is under active development. Some notable changes in this
release include:

- **Android module naming** has been unified. The native module is now
  exported as `LlamaTurboModule` to match JNI symbols.
- **Chat UI** added with voice input and TTS output.
- **Search service bug** fixed – ReadabilityService now uses
  `extractFromUrl()` instead of the non‑existent `extract()` method.
- **Adaptive quantization** implemented directly on `LLMService`.

## Testing

Run the Jest suite with:

```bash
npm test
```

For coverage in CI environments, use:

```bash
npm run test:ci
```

The repository also includes a GitHub Actions workflow that builds iOS TurboModules on macOS runners. The workflow emits clear
messages when Podfiles or Xcode projects are missing, so CI logs explicitly note skipped steps.

See `CITATIONS.md` for references and inspiration. Contributions are
welcome!
