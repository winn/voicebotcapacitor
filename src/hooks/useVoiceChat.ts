/**
 * Orchestrator hook combining speech recognition and OpenAI LLM
 */

import { useEffect, useRef } from 'react';
import { useSpeechRecognition } from './useSpeechRecognition';
import { useOpenAI } from './useOpenAI';
import { debugLog } from '../lib/debug';

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
  sendMessage: (message: string) => Promise<void>;
}

export function useVoiceChat(): UseVoiceChatResult {
  const speechRecognition = useSpeechRecognition();
  const openai = useOpenAI();

  const {
    transcript,
    error: speechError,
    isListening,
    partialTranscript,
    language,
    setLanguage,
    clearTranscript,
    startListening,
    stopListening,
  } = speechRecognition;

  const {
    messages,
    isProcessing,
    error: openaiError,
    apiKey,
    lastPayload,
    sendMessage,
    clearConversation: clearOpenAIConversation,
    setApiKey,
  } = openai;

  const previousFinalTranscript = useRef('');
  const isProcessingRef = useRef(false);
  const shouldRestartAfterResponse = useRef(false);

  // Auto-send transcript to LLM when user stops speaking
  useEffect(() => {
    const trimmedTranscript = transcript.trim();

    // Check if we have a new transcript and we're not already processing
    if (
      trimmedTranscript &&
      trimmedTranscript !== previousFinalTranscript.current &&
      !isProcessingRef.current &&
      !isProcessing
    ) {
      debugLog('🎤 Sending to LLM:', trimmedTranscript);
      previousFinalTranscript.current = trimmedTranscript;
      isProcessingRef.current = true;
      shouldRestartAfterResponse.current = true;

      // Send to OpenAI
      sendMessage(trimmedTranscript)
        .then(() => {
          debugLog('✅ LLM response received');
          // Clear the transcript after successful send to prevent stacking
          clearTranscript();
        })
        .catch((error) => {
          console.error('❌ LLM error:', error);
        })
        .finally(() => {
          isProcessingRef.current = false;
        });
    }
  }, [clearTranscript, isProcessing, sendMessage, transcript]);

  // Auto-restart microphone after LLM response
  useEffect(() => {
    if (
      !isProcessing &&
      shouldRestartAfterResponse.current &&
      !isListening
    ) {
      debugLog('🔄 Auto-restarting microphone');
      shouldRestartAfterResponse.current = false;

      // Small delay before restarting
      setTimeout(() => {
        startListening();
      }, 500);
    }
  }, [isListening, isProcessing, startListening]);

  const startVoiceInput = () => {
    if (!isProcessing) {
      startListening();
    }
  };

  const stopVoiceInput = () => {
    stopListening();
  };

  const clearConversation = () => {
    clearOpenAIConversation();
    previousFinalTranscript.current = '';
  };

  const sendChatMessage = async (message: string) => {
    debugLog('🧪 Chat message:', message);
    await sendMessage(message);
  };

  // Combine errors from both hooks
  const error = speechError || openaiError;

  return {
    // Speech recognition state
    isListening,
    partialTranscript,
    finalTranscript: transcript,
    selectedLanguage: language,
    availableLanguages: AVAILABLE_LANGUAGES,

    // LLM state
    messages,
    isProcessing,
    apiKey,
    lastPayload,

    // Combined error
    error,

    // Actions
    startVoiceInput,
    stopVoiceInput,
    setLanguage,
    clearConversation,
    setApiKey,
    sendMessage: sendChatMessage,
  };
}
