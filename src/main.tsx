import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";
import { debugLog } from "./lib/debug";

debugLog('🚀 App starting...');
debugLog('Environment:', import.meta.env.MODE);
debugLog('API Key exists:', !!import.meta.env.VITE_OPENAI_API_KEY);

const rootElement = document.getElementById("root");
debugLog('Root element found:', !!rootElement);

if (rootElement) {
  try {
    createRoot(rootElement).render(<App />);
    debugLog('✅ App rendered successfully');
  } catch (error) {
    console.error('❌ Error rendering app:', error);
  }
} else {
  console.error('❌ Root element not found!');
}
