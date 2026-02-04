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
 * Retry configuration
 */
const MAX_RETRIES = 3;
const INITIAL_RETRY_DELAY = 1000; // 1 second
const REQUEST_TIMEOUT = 30000; // 30 seconds

/**
 * Sleep utility for retry delays
 */
function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
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
      timeout: REQUEST_TIMEOUT,
    });
  }

  return cachedClient;
}

/**
 * Send message with retry logic and timeout
 */
async function sendMessageWithRetry(
  openai: OpenAI,
  formattedMessages: Array<{ role: 'system' | 'user' | 'assistant'; content: string }>,
  retryCount = 0,
  onRetry?: (count: number) => void
): Promise<string> {
  try {
    debugLog('📤 Sending to OpenAI (attempt', retryCount + 1, ')');

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
      // Don't retry on auth errors or client errors
      if (error.status === 401) {
        throw new Error('Invalid API key. Please check your OpenAI API key.');
      } else if (error.status === 400) {
        throw new Error(`Bad request: ${error.message}`);
      }

      // Retry on rate limits and server errors
      if ((error.status === 429 || error.status === 500 || error.status === 503) && retryCount < MAX_RETRIES) {
        const delay = INITIAL_RETRY_DELAY * Math.pow(2, retryCount);
        debugLog(`⏳ Retrying after ${delay}ms (attempt ${retryCount + 1}/${MAX_RETRIES})`);
        if (onRetry) {
          onRetry(retryCount + 1);
        }
        await sleep(delay);
        return sendMessageWithRetry(openai, formattedMessages, retryCount + 1, onRetry);
      }

      // Final error messages
      if (error.status === 429) {
        throw new Error('Rate limit exceeded. Please wait a few minutes and try again.');
      } else if (error.status === 500 || error.status === 503) {
        throw new Error('OpenAI server error. Please try again later.');
      }

      throw new Error(`OpenAI API error: ${error.message}`);
    }

    // Handle network errors with retry
    if (error instanceof Error) {
      const isNetworkError = error.message.includes('fetch') ||
                            error.message.includes('network') ||
                            error.message.includes('timeout');

      if (isNetworkError && retryCount < MAX_RETRIES) {
        const delay = INITIAL_RETRY_DELAY * Math.pow(2, retryCount);
        debugLog(`⏳ Retrying after network error (attempt ${retryCount + 1}/${MAX_RETRIES})`);
        if (onRetry) {
          onRetry(retryCount + 1);
        }
        await sleep(delay);
        return sendMessageWithRetry(openai, formattedMessages, retryCount + 1, onRetry);
      }

      if (isNetworkError) {
        throw new Error('Network error. Please check your connection and try again.');
      }

      throw error;
    }

    throw new Error('An unexpected error occurred.');
  }
}

export async function sendMessage(
  apiKey: string,
  messages: ChatMessage[],
  onRetry?: (count: number) => void
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

  // Validate that user messages are not empty
  const lastUserMessage = messages.filter(m => m.role === 'user').pop();
  if (lastUserMessage && !lastUserMessage.content.trim()) {
    throw new Error('Cannot send empty message.');
  }

  const openai = getOpenAIClient(apiKey);
  const formattedMessages = convertToOpenAIFormat(messages);

  debugLog('📤 Request details:', {
    model: OPENAI_CONFIG.DEFAULT_MODEL,
    messageCount: formattedMessages.length,
    timeout: REQUEST_TIMEOUT,
  });

  return sendMessageWithRetry(openai, formattedMessages, 0, onRetry);
}
