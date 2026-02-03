/**
 * Orchestrator hook combining speech recognition and OpenAI LLM
 */

import { useEffect, useRef } from 'react';
import { useSpeechRecognition } from './useSpeechRecognition';
import { useOpenAI } from './useOpenAI';

// Common languages for speech recognition
const AVAILABLE_LANGUAGES = [
  { code: 'en-US', name: 'English (US)' },
  { code: 'en-GB', name: 'English (UK)' },
  { code: 'es-ES', name: 'Spanish' },
  { code: 'fr-FR', name: 'French' },
  { code: 'de-DE', name: 'German' },
  { code: 'it-IT', name: 'Italian' },
  { code: 'pt-BR', name: 'Portuguese' },
  { code: 'zh-CN', name: 'Chinese' },
  { code: 'ja-JP', name: 'Japanese' },
  { code: 'ko-KR', name: 'Korean' },
  { code: 'th-TH', name: 'Thai' },
];

export interface UseVoiceChatResult {
  // Speech recognition state
  isListening: boolean;
  partialTranscript: string;
  finalTranscript: string;
  selectedLanguage: string;
  availableLanguages: Array<{ code: string; name: string }>;

  // LLM state
  messages: ReturnType<typeof useOpenAI>['messages'];
  isProcessing: boolean;
  apiKey: string | null;
  lastPayload: string | null;

  // Combined error
  error: string | null;

  // Actions
  startVoiceInput: () => void;
  stopVoiceInput: () => void;
  setLanguage: (language: string) => void;
  clearConversation: () => void;
  setApiKey: (key: string) => void;
  sendTestMessage: (message: string) => Promise<void>;
}

export function useVoiceChat(): UseVoiceChatResult {
  const speechRecognition = useSpeechRecognition();
  const openai = useOpenAI();

  const previousFinalTranscript = useRef('');
  const isProcessingRef = useRef(false);
  const shouldRestartAfterResponse = useRef(false);

  // Auto-send transcript to LLM when user stops speaking
  useEffect(() => {
    const transcript = speechRecognition.transcript.trim();

    // Check if we have a new transcript and we're not already processing
    if (
      transcript &&
      transcript !== previousFinalTranscript.current &&
      !isProcessingRef.current &&
      !openai.isProcessing
    ) {
      console.log('🎤 Sending to LLM:', transcript);
      previousFinalTranscript.current = transcript;
      isProcessingRef.current = true;
      shouldRestartAfterResponse.current = true;

      // Send to OpenAI
      openai.sendMessage(transcript)
        .then(() => {
          console.log('✅ LLM response received');
          // Clear the transcript after successful send to prevent stacking
          speechRecognition.clearTranscript();
        })
        .catch((error) => {
          console.error('❌ LLM error:', error);
        })
        .finally(() => {
          isProcessingRef.current = false;
        });
    }
  }, [speechRecognition.transcript, openai]);

  // Auto-restart microphone after LLM response
  useEffect(() => {
    if (
      !openai.isProcessing &&
      shouldRestartAfterResponse.current &&
      !speechRecognition.isListening
    ) {
      console.log('🔄 Auto-restarting microphone');
      shouldRestartAfterResponse.current = false;

      // Small delay before restarting
      setTimeout(() => {
        speechRecognition.startListening();
      }, 500);
    }
  }, [openai.isProcessing, speechRecognition.isListening, speechRecognition.startListening]);

  const startVoiceInput = () => {
    if (!openai.isProcessing) {
      speechRecognition.startListening();
    }
  };

  const stopVoiceInput = () => {
    speechRecognition.stopListening();
  };

  const clearConversation = () => {
    openai.clearConversation();
    previousFinalTranscript.current = '';
  };

  const sendTestMessage = async (message: string) => {
    console.log('🧪 Test message:', message);
    await openai.sendMessage(message);
  };

  // Combine errors from both hooks
  const error = speechRecognition.error || openai.error;

  return {
    // Speech recognition state
    isListening: speechRecognition.isListening,
    partialTranscript: speechRecognition.partialTranscript,
    finalTranscript: speechRecognition.transcript,
    selectedLanguage: speechRecognition.language,
    availableLanguages: AVAILABLE_LANGUAGES,

    // LLM state
    messages: openai.messages,
    isProcessing: openai.isProcessing,
    apiKey: openai.apiKey,
    lastPayload: openai.lastPayload,

    // Combined error
    error,

    // Actions
    startVoiceInput,
    stopVoiceInput,
    setLanguage: speechRecognition.setLanguage,
    clearConversation,
    setApiKey: openai.setApiKey,
    sendTestMessage,
  };
}
