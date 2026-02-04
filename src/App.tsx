import { VoiceChatApp } from "@/components/VoiceChatApp";
import { Component, ReactNode, useEffect } from "react";
import { Capacitor } from "@capacitor/core";
import { StatusBar } from "@capacitor/status-bar";
import { debugLog } from "./lib/debug";

// Error Boundary to catch rendering errors
class ErrorBoundary extends Component<
  { children: ReactNode },
  { hasError: boolean; error: Error | null }
> {
  constructor(props: { children: ReactNode }) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error) {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, errorInfo: any) {
    console.error('❌ Error caught by boundary:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div style={{ padding: '20px', background: 'red', color: 'white', minHeight: '100vh' }}>
          <h1>Error in VoiceChatApp</h1>
          <p>Error: {this.state.error?.message}</p>
          <pre style={{ whiteSpace: 'pre-wrap', fontSize: '12px' }}>
            {this.state.error?.stack}
          </pre>
        </div>
      );
    }

    return this.props.children;
  }
}

const App = () => {
  debugLog('✅ App component rendering');

  useEffect(() => {
    if (Capacitor.getPlatform() !== 'ios') return;

    (async () => {
      try {
        await StatusBar.setOverlaysWebView({ overlay: false });
        debugLog('✅ StatusBar configured: overlay disabled');
      } catch (e) {
        console.error('❌ StatusBar overlay config failed', e);
      }
    })();

    // Diagnostic logging after 1 second
    setTimeout(() => {
      const root = document.documentElement;
      const safeTop = getComputedStyle(root).getPropertyValue('--safe-top');
      const bodyPadding = getComputedStyle(document.body).paddingTop;
      const viewportOffset = window.visualViewport?.offsetTop;

      console.log('📊 Safe area diagnostics:', {
        safeTop,
        bodyPadding,
        viewportOffset,
        platform: Capacitor.getPlatform()
      });
    }, 1000);
  }, []);

  try {
    return (
      <ErrorBoundary>
        <VoiceChatApp />
      </ErrorBoundary>
    );
  } catch (error) {
    console.error('❌ Error rendering VoiceChatApp:', error);
    return (
      <div style={{ padding: '20px', background: 'orange', minHeight: '100vh' }}>
        <h1 style={{ color: 'black' }}>Caught Error</h1>
        <p style={{ color: 'black' }}>{String(error)}</p>
      </div>
    );
  }
};

export default App;
