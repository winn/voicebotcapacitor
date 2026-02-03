/**
 * Main Voice Chat Application Component
 * Combines speech recognition with OpenAI LLM for ChatGPT-like voice mode
 */

import { Mic, MicOff, Trash2 } from 'lucide-react';
import { Button } from './ui/button';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Alert, AlertDescription } from './ui/alert';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from './ui/select';
import { useVoiceChat } from '../hooks/useVoiceChat';
import { ApiKeySetup } from './ApiKeySetup';
import { MessageList } from './MessageList';

export function VoiceChatApp() {
  const {
    isListening,
    partialTranscript,
    finalTranscript,
    selectedLanguage,
    availableLanguages,
    messages,
    isProcessing,
    apiKey,
    lastPayload,
    error,
    startVoiceInput,
    stopVoiceInput,
    setLanguage,
    clearConversation,
    setApiKey,
    sendTestMessage,
  } = useVoiceChat();

  // Show API key setup if not configured
  if (!apiKey) {
    return (
      <div className="min-h-screen bg-background p-4">
        <div className="max-w-2xl mx-auto pt-8">
          <div className="mb-6 text-center">
            <h1 className="text-3xl font-bold">Voice Chat Assistant</h1>
            <p className="text-muted-foreground mt-2">
              ChatGPT voice mode powered by OpenAI
            </p>
          </div>
          <ApiKeySetup onSave={setApiKey} />
        </div>
      </div>
    );
  }

  const handleMicClick = () => {
    if (isListening) {
      stopVoiceInput();
    } else {
      startVoiceInput();
    }
  };

  const hasMessages = messages.filter((m) => m.role !== 'system').length > 0;
  const isMicDisabled = isProcessing;

  return (
    <div className="min-h-screen bg-background p-4">
      <div className="max-w-2xl mx-auto space-y-4">
        {/* Header */}
        <div className="text-center">
          <h1 className="text-3xl font-bold">Voice Chat Assistant</h1>
          <p className="text-muted-foreground mt-2">
            Speak naturally, get intelligent responses
          </p>
          <div className="mt-2 text-2xl font-bold text-red-600 bg-yellow-300 p-2 rounded">
            VERSION 7.2 - DEBUG MODE
          </div>
        </div>

        {/* Language Selector */}
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-medium">Language</CardTitle>
          </CardHeader>
          <CardContent>
            <Select value={selectedLanguage} onValueChange={setLanguage}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {availableLanguages.map((lang) => (
                  <SelectItem key={lang.code} value={lang.code}>
                    {lang.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          </CardContent>
        </Card>

        {/* Error Display */}
        {error && (
          <Alert variant="destructive">
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}

        {/* Conversation History */}
        <Card>
          <CardHeader>
            <CardTitle>Conversation</CardTitle>
          </CardHeader>
          <CardContent>
            <MessageList messages={messages} />
          </CardContent>
        </Card>

        {/* Current Input Status */}
        <Card>
          <CardHeader>
            <CardTitle className="text-sm font-medium">
              {isListening ? 'Listening...' : isProcessing ? 'Thinking...' : 'Ready'}
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="min-h-[60px] text-sm text-muted-foreground">
              {isListening && partialTranscript && (
                <p className="italic">{partialTranscript}</p>
              )}
              {!isListening && finalTranscript && !isProcessing && (
                <p>{finalTranscript}</p>
              )}
              {isProcessing && (
                <div className="flex items-center gap-2">
                  <div className="animate-spin h-4 w-4 border-2 border-primary border-t-transparent rounded-full" />
                  <span>Processing your message...</span>
                </div>
              )}
              {!isListening && !finalTranscript && !isProcessing && (
                <p>Tap the microphone to start speaking</p>
              )}
            </div>
            {/* Debug Info */}
            <div className="mt-2 p-2 bg-gray-100 rounded text-xs font-mono">
              <p>Partial: {partialTranscript || 'none'}</p>
              <p>Final: {finalTranscript || 'none'}</p>
              <p>Processing: {isProcessing ? 'yes' : 'no'}</p>
              <p className="font-bold text-red-600 mt-2">Messages in state: {messages.length}</p>
              <div className="mt-1 max-h-32 overflow-y-auto">
                {messages.map((msg, idx) => (
                  <p key={idx} className="text-[10px]">
                    {idx}: {msg.role} - {msg.content.substring(0, 30)}...
                  </p>
                ))}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* JSON Payload Debug Display */}
        {lastPayload && (
          <Card className="border-yellow-500">
            <CardHeader>
              <CardTitle className="text-sm font-medium text-yellow-600">
                🔍 Last API Request Payload
              </CardTitle>
            </CardHeader>
            <CardContent>
              <pre className="text-xs bg-gray-900 text-green-400 p-3 rounded overflow-x-auto">
                {lastPayload}
              </pre>
            </CardContent>
          </Card>
        )}

        {/* Microphone Button */}
        <div className="flex flex-col items-center gap-2">
          <Button
            size="lg"
            onClick={handleMicClick}
            disabled={isMicDisabled}
            className={`w-20 h-20 rounded-full ${
              isListening
                ? 'bg-red-500 hover:bg-red-600 animate-pulse'
                : 'bg-primary hover:bg-primary/90'
            }`}
          >
            {isListening ? (
              <MicOff className="h-8 w-8" />
            ) : (
              <Mic className="h-8 w-8" />
            )}
          </Button>

          {/* Status Text */}
          <div className="text-center">
            <div className="text-sm font-medium text-foreground">
              {isMicDisabled
                ? 'Please wait...'
                : isListening
                ? 'TAP TO STOP'
                : 'Tap to start'}
            </div>
            <div className="text-xs text-muted-foreground mt-1">
              {isListening
                ? 'Or wait 2s for auto-stop'
                : 'Speak naturally'}
            </div>
          </div>
        </div>

        {/* Test Button */}
        <div className="flex justify-center">
          <Button
            variant="outline"
            onClick={() => sendTestMessage('Hello, can you hear me?')}
            disabled={isProcessing}
          >
            Test LLM
          </Button>
        </div>

        {/* Clear Conversation Button */}
        {hasMessages && (
          <div className="flex justify-center">
            <Button
              variant="outline"
              onClick={clearConversation}
              disabled={isProcessing}
              className="gap-2"
            >
              <Trash2 className="h-4 w-4" />
              Clear Conversation
            </Button>
          </div>
        )}

        {/* API Key Info */}
        <div className="text-center text-xs text-muted-foreground">
          <button
            onClick={() => {
              if (confirm('Clear your API key? You will need to enter it again.')) {
                setApiKey('');
              }
            }}
            className="underline hover:text-foreground"
          >
            Change API Key
          </button>
        </div>
      </div>
    </div>
  );
}
