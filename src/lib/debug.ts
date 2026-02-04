export const DEBUG_ENABLED =
  import.meta.env.VITE_DEBUG === 'true' || import.meta.env.DEV;

export function debugLog(...args: unknown[]): void {
  if (DEBUG_ENABLED) {
    console.log(...args);
  }
}

export function debugWarn(...args: unknown[]): void {
  if (DEBUG_ENABLED) {
    console.warn(...args);
  }
}
