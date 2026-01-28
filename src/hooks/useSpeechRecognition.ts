import { useState, useCallback, useEffect } from 'react';
import { SpeechRecognition } from '@capacitor-community/speech-recognition';
import { Capacitor } from '@capacitor/core';

export function useSpeechRecognition() {
  const [isListening, setIsListening] = useState(false);
  const [transcript, setTranscript] = useState('');
  const [partialTranscript, setPartialTranscript] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isAvailable, setIsAvailable] = useState(false);
  const [hasPermission, setHasPermission] = useState(false);

  useEffect(() => {
    const checkAvailability = async () => {
      if (!Capacitor.isNativePlatform()) {
        setError('Speech recognition requires a native device');
        return;
      }

      try {
        const { available } = await SpeechRecognition.available();
        setIsAvailable(available);

        if (available) {
          const { speechRecognition } = await SpeechRecognition.checkPermissions();
          setHasPermission(speechRecognition === 'granted');
        }
      } catch (err) {
        console.error('Error checking speech recognition:', err);
        setError('Failed to check speech recognition availability');
      }
    };

    checkAvailability();
  }, []);

  const requestPermission = useCallback(async () => {
    try {
      const { speechRecognition } = await SpeechRecognition.requestPermissions();
      const granted = speechRecognition === 'granted';
      setHasPermission(granted);
      if (!granted) {
        setError('Microphone permission denied');
      }
      return granted;
    } catch (err) {
      console.error('Error requesting permission:', err);
      setError('Failed to request permission');
      return false;
    }
  }, []);

  const startListening = useCallback(async () => {
    setError(null);

    if (!isAvailable) {
      setError('Speech recognition not available on this device');
      return;
    }

    if (!hasPermission) {
      const granted = await requestPermission();
      if (!granted) return;
    }

    try {
      setIsListening(true);
      setPartialTranscript('');

      await SpeechRecognition.start({
        language: 'en-US',
        maxResults: 5,
        prompt: 'Speak now...',
        partialResults: true,
        popup: false,
      });

      SpeechRecognition.addListener('partialResults', (data) => {
        if (data.matches && data.matches.length > 0) {
          setPartialTranscript(data.matches[0]);
        }
      });
    } catch (err) {
      console.error('Error starting speech recognition:', err);
      setError('Failed to start speech recognition');
      setIsListening(false);
    }
  }, [isAvailable, hasPermission, requestPermission]);

  const stopListening = useCallback(async () => {
    try {
      await SpeechRecognition.stop();
      setIsListening(false);
      
      // On iOS, the final result comes through partialResults listener
      // We'll commit the partial transcript to the main transcript
      if (partialTranscript) {
        setTranscript((prev) => {
          if (prev) {
            return prev + ' ' + partialTranscript;
          }
          return partialTranscript;
        });
        setPartialTranscript('');
      }

      await SpeechRecognition.removeAllListeners();
    } catch (err) {
      console.error('Error stopping speech recognition:', err);
      setIsListening(false);
    }
  }, []);

  const clearTranscript = useCallback(() => {
    setTranscript('');
    setPartialTranscript('');
  }, []);

  return {
    isListening,
    transcript,
    partialTranscript,
    error,
    isAvailable,
    hasPermission,
    startListening,
    stopListening,
    clearTranscript,
    requestPermission,
  };
}
