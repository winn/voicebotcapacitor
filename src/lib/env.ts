/**
 * Environment variable and localStorage helpers for API key management
 */

const STORAGE_KEY = 'openai_api_key';

/**
 * Get OpenAI API key from localStorage or environment variable
 * Priority: localStorage > environment variable
 */
export function getOpenAIApiKey(): string | null {
  // Check localStorage first
  if (typeof window !== 'undefined') {
    const storedKey = localStorage.getItem(STORAGE_KEY);
    if (storedKey) {
      return storedKey;
    }
  }

  // Fallback to environment variable
  const envKey = import.meta.env.VITE_OPENAI_API_KEY;
  return envKey || null;
}

/**
 * Save OpenAI API key to localStorage
 */
export function setOpenAIApiKey(apiKey: string): void {
  if (typeof window !== 'undefined') {
    localStorage.setItem(STORAGE_KEY, apiKey);
  }
}

/**
 * Remove OpenAI API key from localStorage
 */
export function clearOpenAIApiKey(): void {
  if (typeof window !== 'undefined') {
    localStorage.removeItem(STORAGE_KEY);
  }
}
