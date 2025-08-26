import { useState, useEffect, useCallback } from 'react';
import Voice from '@react-native-voice/voice';

export function useSpeechRecognition(onResult, onError) {
  const [isRecording, setIsRecording] = useState(false);

  useEffect(() => {
    Voice.onSpeechResults = event => {
      setIsRecording(false);
      onResult(event.value?.[0] ?? '');
    };
    Voice.onSpeechError = event => {
      setIsRecording(false);
      if (onError) {
        onError(event.error);
      }
    };
    return () => {
      Voice.destroy().then(Voice.removeAllListeners);
    };
  }, [onResult, onError]);

  const start = useCallback(async () => {
    setIsRecording(true);
    try {
      await Voice.start('en-US');
    } catch (e) {
      setIsRecording(false);
      if (onError) {
        onError(e);
      }
    }
  }, [onError]);

  return { isRecording, start };
}
