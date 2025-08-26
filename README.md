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
  assistant retrieves relevant past information from a local database and
  injects it into the prompt to improve answer quality.
- **Adaptive performance** – quantization levels are adjusted based on
  inference times and memory usage. Sparse attention is enabled
  automatically for long contexts.
- **Extensible tool system** – register your own tools in `toolSystem.js`
  or enable device APIs on iOS. Android gracefully reports unsupported
  tools.

## Getting started

1. Install dependencies and build the app:

   ```bash
   npm install
   npx react-native run-ios   # or run-android
   ```

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

## Development notes

This project is under active development. Some notable changes in this
release include:

- **Android module naming** has been unified. The native module is now
  exported as `LlamaTurboModule` to match JNI symbols.
- **Chat UI** added with voice input and TTS output.
- **Search service bug** fixed – ReadabilityService now uses
  `extractFromUrl()` instead of the non‑existent `extract()` method.
- **Adaptive quantization** implemented directly on `LLMService`.

See `CITATIONS.md` for references and inspiration. Contributions are
welcome!
