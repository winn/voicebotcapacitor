import { VoiceChatApp } from "@/components/VoiceChatApp";
import { Component, ReactNode } from "react";

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
  console.log('✅ App component rendering');
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
