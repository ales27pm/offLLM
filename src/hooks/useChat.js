import { useState, useRef, useEffect } from 'react';
import Tts from 'react-native-tts';
import LLMService from '../services/llmService';
import { HNSWVectorStore } from '../utils/hnswVectorStore';

function generateId() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2);
}

export function useChat() {
  const [messages, setMessages] = useState([]);
  const vectorStoreRef = useRef(null);

  useEffect(() => {
    Tts.setDefaultRate(0.53);
    Tts.setDefaultPitch(1.0);
  }, []);

  const initVectorStore = async () => {
    const vs = new HNSWVectorStore();
    await vs.initialize({ quantization: 'scalar' });
    vectorStoreRef.current = vs;
  };

  const detectEmotion = text => {
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

  const getContext = async query => {
    if (!vectorStoreRef.current) {
      console.warn('Context retrieval failed: vector store is not initialized.');
      return '';
    }
    try {
      const embedding = await LLMService.embed(query);
      const results = await vectorStoreRef.current.searchVectors(embedding, 3);
      return results.map(r => r.content).join('\n\n');
    } catch (e) {
      console.warn('Context retrieval failed:', e);
      return '';
    }
  };

  const send = async text => {
    const query = text.trim();
    if (!query) return;
    setMessages(prev => [...prev, { id: generateId(), sender: 'user', text: query }]);
    try {
      const emotion = detectEmotion(query);
      const context = await getContext(query);
      let prompt = query;
      if (emotion) {
        prompt = `The user sounds ${emotion}. ${prompt}`;
      }
      if (context) {
        prompt = `Context:\n${context}\n\n${prompt}`;
      }
      const response = await LLMService.generate(prompt, 256, 0.7, { useSparseAttention: true });
      const reply = response?.text || '';
      setMessages(prev => [...prev, { id: generateId(), sender: 'assistant', text: reply }]);
      Tts.stop();
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
      setMessages(prev => [...prev, { id: generateId(), sender: 'assistant', text: 'Error: ' + e.message }]);
    }
  };

  return { messages, send, initVectorStore };
}
