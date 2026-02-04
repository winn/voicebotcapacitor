/**
 * OpenAI API client service
 */

import OpenAI from 'openai';
import type { ChatMessage } from '../types/chat';
import { OPENAI_CONFIG } from '../config/openai';
import { debugLog } from '../lib/debug';

/**
 * Validate OpenAI API key format
 */
export function validateApiKey(apiKey: string): boolean {
  // OpenAI API keys start with 'sk-' and have a minimum length
  return apiKey.startsWith('sk-') && apiKey.length > 20;
}

/**
 * Convert ChatMessage array to OpenAI format
 */
function convertToOpenAIFormat(messages: ChatMessage[]): Array<{
  role: 'system' | 'user' | 'assistant';
  content: string;
}> {
  return messages.map((msg) => ({
    role: msg.role,
    content: msg.content,
  }));
}

/**
 * Send message to OpenAI and get response
 */
let cachedClient: OpenAI | null = null;
let cachedApiKey: string | null = null;

function getOpenAIClient(apiKey: string): OpenAI {
  if (!cachedClient || cachedApiKey !== apiKey) {
    cachedApiKey = apiKey;
    cachedClient = new OpenAI({
      apiKey,
      dangerouslyAllowBrowser: true, // Required for client-side usage
    });
  }

  return cachedClient;
}

export async function sendMessage(
  apiKey: string,
  messages: ChatMessage[]
): Promise<string> {
  debugLog('🔧 sendMessage called');
  debugLog('📋 Messages to send:', messages.length);

  if (!validateApiKey(apiKey)) {
    console.error('❌ Invalid API key format');
    throw new Error('Invalid API key. Please check your OpenAI API key.');
  }

  // Validate messages array is not empty
  if (!messages || messages.length === 0) {
    console.error('❌ Empty messages array');
    throw new Error('Cannot send empty conversation. Please start a new conversation.');
  }

  try {
    const openai = getOpenAIClient(apiKey);

    const formattedMessages = convertToOpenAIFormat(messages);
    debugLog('📤 Sending to OpenAI:', {
      model: OPENAI_CONFIG.DEFAULT_MODEL,
      messageCount: formattedMessages.length,
    });

    const response = await openai.chat.completions.create({
      model: OPENAI_CONFIG.DEFAULT_MODEL,
      messages: formattedMessages,
      max_completion_tokens: OPENAI_CONFIG.DEFAULT_MAX_TOKENS,
    });

    debugLog('📥 OpenAI response received:', response);

    const content = response.choices[0]?.message?.content;

    if (!content) {
      console.error('❌ No content in response');
      throw new Error('No response from OpenAI');
    }

    debugLog('✅ Response content:', content);
    return content;
  } catch (error) {
    // Handle specific OpenAI errors
    if (error instanceof OpenAI.APIError) {
      if (error.status === 401) {
        throw new Error('Invalid API key. Please check your OpenAI API key.');
      } else if (error.status === 429) {
        throw new Error('Rate limit exceeded. Please wait and try again.');
      } else if (error.status === 500) {
        throw new Error('OpenAI server error. Please try again later.');
      }
      throw new Error(`OpenAI API error: ${error.message}`);
    }

    // Handle network errors
    if (error instanceof Error) {
      if (error.message.includes('fetch')) {
        throw new Error('Network error. Please check your connection.');
      }
      throw error;
    }

    throw new Error('An unexpected error occurred.');
  }
}
