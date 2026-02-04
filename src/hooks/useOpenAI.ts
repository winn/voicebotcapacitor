/**
 * React hook for OpenAI LLM integration
 */

import { useState, useCallback, useEffect, useRef } from 'react';
import { v4 as uuidv4 } from 'uuid';
import type { ChatMessage } from '../types/chat';
import { sendMessage as sendMessageToOpenAI } from '../services/openai';
import { OPENAI_CONFIG } from '../config/openai';
import { getOpenAIApiKey, setOpenAIApiKey as saveApiKey } from '../lib/env';
import { DEBUG_ENABLED, debugLog, debugWarn } from '../lib/debug';
import {
  loadConversationHistory,
  saveConversationHistory,
  clearConversationHistory as clearStoredHistory,
} from '../services/storage';

export interface UseOpenAIResult {
  messages: ChatMessage[];
  isProcessing: boolean;
  error: string | null;
  apiKey: string | null;
  lastPayload: string | null;
  sendMessage: (userMessage: string) => Promise<void>;
  clearConversation: () => void;
  setApiKey: (key: string) => void;
}

export function useOpenAI(): UseOpenAIResult {
  const createSystemMessage = useCallback((): ChatMessage => ({
    id: uuidv4(),
    role: 'system',
    content: OPENAI_CONFIG.SYSTEM_PROMPT,
    timestamp: new Date(),
  }), []);

  const [messages, setMessages] = useState<ChatMessage[]>([createSystemMessage()]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [apiKey, setApiKeyState] = useState<string | null>(getOpenAIApiKey());
  const [lastPayload, setLastPayload] = useState<string | null>(null);
  const messagesRef = useRef<ChatMessage[]>(messages);

  // Load conversation history from device storage on mount
  useEffect(() => {
    const loadHistory = async () => {
      try {
        const storedMessages = await loadConversationHistory();

        if (storedMessages.length > 0) {
          debugLog('📚 Restoring conversation history');
          setMessages(storedMessages);
        }
      } catch (error) {
        console.error('❌ Failed to load conversation history:', error);
      }
    };

    loadHistory();
  }, []);

  useEffect(() => {
    messagesRef.current = messages;
  }, [messages]);

  const setApiKey = useCallback((key: string) => {
    saveApiKey(key);
    setApiKeyState(key);
    setError(null);
  }, []);

  const sendMessage = useCallback(
    async (userMessage: string) => {
      debugLog('🤖 useOpenAI.sendMessage called with:', userMessage);
      debugLog('🔑 API Key exists:', !!apiKey);
      debugLog('📊 Current messages state length:', messagesRef.current.length);

      if (!apiKey) {
        console.error('❌ No API key configured');
        setError('API key not configured. Please set your OpenAI API key.');
        return;
      }

      if (!userMessage.trim()) {
        debugWarn('⚠️ Empty message, skipping');
        return;
      }

      setIsProcessing(true);
      setError(null);

      // Build the messages array directly from current state
      const currentMessagesState = messagesRef.current.length === 0
        ? [createSystemMessage()]
        : messagesRef.current;

      const userChatMessage: ChatMessage = {
        id: uuidv4(),
        role: 'user',
        content: userMessage.trim(),
        timestamp: new Date(),
      };

      // Build the array to send to OpenAI
      const messagesToSend = [...currentMessagesState, userChatMessage];

      debugLog('📊 Messages to send:', messagesToSend.length);

      if (DEBUG_ENABLED) {
        const payloadForDisplay = JSON.stringify(
          messagesToSend.map(m => ({
            role: m.role,
            content: m.content
          })),
          null,
          2
        );

        debugLog('🔍 Payload:');
        debugLog(payloadForDisplay);

        // Store payload for UI display
        setLastPayload(payloadForDisplay);
      } else if (lastPayload) {
        setLastPayload(null);
      }

      // Update UI state with user message
      setMessages([...currentMessagesState, userChatMessage]);

      try {
      debugLog('📤 Calling OpenAI API...');

        const responseContent = await sendMessageToOpenAI(apiKey, messagesToSend);
        debugLog('📥 OpenAI response:', responseContent);

        const assistantMessage: ChatMessage = {
          id: uuidv4(),
          role: 'assistant',
          content: responseContent,
          timestamp: new Date(),
        };

        // Add assistant message to conversation
        const newMessages = [...messagesToSend, assistantMessage];
        setMessages(newMessages);
        debugLog('✅ Assistant message added to conversation');

        // Save conversation history to device storage (with sliding window)
        saveConversationHistory(newMessages).catch(err =>
          console.error('Failed to save conversation history:', err)
        );
      } catch (err) {
        console.error('❌ OpenAI error:', err);
        const errorMessage = err instanceof Error ? err.message : 'An unexpected error occurred.';
        setError(errorMessage);
        // Remove the user message if the request failed
        setMessages(currentMessagesState);
      } finally {
        setIsProcessing(false);
        debugLog('🏁 Processing complete');
      }
    },
    [apiKey, createSystemMessage, lastPayload]
  );

  const clearConversation = useCallback(() => {
    setMessages([createSystemMessage()]);
    setError(null);

    // Clear stored conversation history
    clearStoredHistory().catch(err =>
      console.error('Failed to clear stored conversation history:', err)
    );
  }, []);

  return {
    messages,
    isProcessing,
    error,
    apiKey,
    lastPayload,
    sendMessage,
    clearConversation,
    setApiKey,
  };
}
