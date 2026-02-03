/**
 * Type definitions for chat functionality
 */

export type MessageRole = 'user' | 'assistant' | 'system';

export interface ChatMessage {
  id: string;
  role: MessageRole;
  content: string;
  timestamp: Date;
}

export interface OpenAIConfig {
  apiKey: string;
  model: string;
  maxTokens: number;
  temperature: number;
  systemPrompt: string;
}

export interface ConversationState {
  messages: ChatMessage[];
  isProcessing: boolean;
  error: string | null;
}
