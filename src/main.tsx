import { createRoot } from "react-dom/client";
import App from "./App.tsx";
import "./index.css";

console.log('🚀 App starting...');
console.log('Environment:', import.meta.env.MODE);
console.log('API Key exists:', !!import.meta.env.VITE_OPENAI_API_KEY);

const rootElement = document.getElementById("root");
console.log('Root element found:', !!rootElement);

if (rootElement) {
  try {
    createRoot(rootElement).render(<App />);
    console.log('✅ App rendered successfully');
  } catch (error) {
    console.error('❌ Error rendering app:', error);
  }
} else {
  console.error('❌ Root element not found!');
}
