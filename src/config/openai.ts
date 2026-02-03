/**
 * OpenAI configuration constants
 */

export const OPENAI_CONFIG = {
  DEFAULT_MODEL: 'gpt-4o-mini',
  DEFAULT_MAX_TOKENS: 500,
  DEFAULT_TEMPERATURE: 0.7,
  SYSTEM_PROMPT: 'You are a helpful voice assistant. Provide concise, clear, and friendly responses suitable for voice interaction.',
} as const;
