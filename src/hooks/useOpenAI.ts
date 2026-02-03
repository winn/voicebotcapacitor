/**
 * React hook for OpenAI LLM integration
 */

import { useState, useCallback, useEffect } from 'react';
import { v4 as uuidv4 } from 'uuid';
import type { ChatMessage } from '../types/chat';
import { sendMessage as sendMessageToOpenAI } from '../services/openai';
import { OPENAI_CONFIG } from '../config/openai';
import { getOpenAIApiKey, setOpenAIApiKey as saveApiKey } from '../lib/env';
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
  const [messages, setMessages] = useState<ChatMessage[]>([
    {
      id: uuidv4(),
      role: 'system',
      content: OPENAI_CONFIG.SYSTEM_PROMPT,
      timestamp: new Date(),
    },
  ]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [apiKey, setApiKeyState] = useState<string | null>(getOpenAIApiKey());
  const [isLoadingHistory, setIsLoadingHistory] = useState(true);
  const [lastPayload, setLastPayload] = useState<string | null>(null);

  // Load conversation history from device storage on mount
  useEffect(() => {
    const loadHistory = async () => {
      try {
        const storedMessages = await loadConversationHistory();

        if (storedMessages.length > 0) {
          console.log('📚 Restoring conversation history');
          setMessages(storedMessages);
        }
      } catch (error) {
        console.error('❌ Failed to load conversation history:', error);
      } finally {
        setIsLoadingHistory(false);
      }
    };

    loadHistory();
  }, []);

  const setApiKey = useCallback((key: string) => {
    saveApiKey(key);
    setApiKeyState(key);
    setError(null);
  }, []);

  const sendMessage = useCallback(
    async (userMessage: string) => {
      console.log('🤖 useOpenAI.sendMessage called with:', userMessage);
      console.log('🔑 API Key exists:', !!apiKey);
      console.log('📊 Current messages state length:', messages.length);

      if (!apiKey) {
        console.error('❌ No API key configured');
        setError('API key not configured. Please set your OpenAI API key.');
        return;
      }

      if (!userMessage.trim()) {
        console.warn('⚠️ Empty message, skipping');
        return;
      }

      setIsProcessing(true);
      setError(null);

      // Build the messages array directly from current state
      const currentMessagesState = messages.length === 0
        ? [{
            id: uuidv4(),
            role: 'system' as const,
            content: OPENAI_CONFIG.SYSTEM_PROMPT,
            timestamp: new Date(),
          }]
        : messages;

      const userChatMessage: ChatMessage = {
        id: uuidv4(),
        role: 'user',
        content: userMessage.trim(),
        timestamp: new Date(),
      };

      // Build the array to send to OpenAI
      const messagesToSend = [...currentMessagesState, userChatMessage];

      console.log('📊 Messages to send:', messagesToSend.length);
      console.log('📋 Messages:', JSON.stringify(messagesToSend.map(m => ({ role: m.role, content: m.content.substring(0, 50) })), null, 2));

      // Create payload for debugging
      const payloadForDisplay = JSON.stringify(messagesToSend.map(m => ({
        role: m.role,
        content: m.content
      })), null, 2);

      console.log('🔍 Payload:');
      console.log(payloadForDisplay);

      // Store payload for UI display
      setLastPayload(payloadForDisplay);

      // Update UI state with user message
      setMessages([...currentMessagesState, userChatMessage]);

      try {
        console.log('📤 Calling OpenAI API...');

        const responseContent = await sendMessageToOpenAI(apiKey, messagesToSend);
        console.log('📥 OpenAI response:', responseContent);

        const assistantMessage: ChatMessage = {
          id: uuidv4(),
          role: 'assistant',
          content: responseContent,
          timestamp: new Date(),
        };

        // Add assistant message to conversation
        const newMessages = [...messagesToSend, assistantMessage];
        setMessages(newMessages);
        console.log('✅ Assistant message added to conversation');

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
        console.log('🏁 Processing complete');
      }
    },
    [apiKey, messages]
  );

  const clearConversation = useCallback(() => {
    setMessages([
      {
        id: uuidv4(),
        role: 'system',
        content: OPENAI_CONFIG.SYSTEM_PROMPT,
        timestamp: new Date(),
      },
    ]);
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
