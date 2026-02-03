/**
 * Device storage service for conversation history using Capacitor Preferences
 */

import { Preferences } from '@capacitor/preferences';
import type { ChatMessage } from '../types/chat';

const CONVERSATION_KEY = 'conversation_history';
const MAX_MESSAGE_PAIRS = 10; // Keep last 10 user+assistant pairs

export interface ConversationHistory {
  messages: ChatMessage[];
}

/**
 * Load conversation history from device storage
 */
export async function loadConversationHistory(): Promise<ChatMessage[]> {
  try {
    const { value } = await Preferences.get({ key: CONVERSATION_KEY });

    if (value) {
      const history: ConversationHistory = JSON.parse(value);
      console.log('📚 Loaded conversation history:', history.messages.length, 'messages');
      return history.messages;
    }

    return [];
  } catch (error) {
    console.error('❌ Error loading conversation history:', error);
    return [];
  }
}

/**
 * Save conversation history to device storage with sliding window
 * Keeps system message + last N user+assistant pairs
 */
export async function saveConversationHistory(messages: ChatMessage[]): Promise<void> {
  try {
    // Separate system message from conversation
    const systemMessage = messages.find(msg => msg.role === 'system');
    const conversationMessages = messages.filter(msg => msg.role !== 'system');

    // Keep only the last N pairs (user + assistant = 2 messages per pair)
    const maxMessages = MAX_MESSAGE_PAIRS * 2;
    const recentMessages = conversationMessages.slice(-maxMessages);

    // Reconstruct with system message first
    const messagesToSave: ChatMessage[] = systemMessage
      ? [systemMessage, ...recentMessages]
      : recentMessages;

    const history: ConversationHistory = {
      messages: messagesToSave,
    };

    await Preferences.set({
      key: CONVERSATION_KEY,
      value: JSON.stringify(history),
    });

    console.log('💾 Saved conversation history:', messagesToSave.length, 'messages');
  } catch (error) {
    console.error('❌ Error saving conversation history:', error);
  }
}

/**
 * Clear conversation history from device storage
 */
export async function clearConversationHistory(): Promise<void> {
  try {
    await Preferences.remove({ key: CONVERSATION_KEY });
    console.log('🗑️ Cleared conversation history');
  } catch (error) {
    console.error('❌ Error clearing conversation history:', error);
  }
}
