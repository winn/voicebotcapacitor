/**
 * Main Voice Chat Application Component
 * Combines speech recognition with OpenAI LLM for ChatGPT-like voice mode
 */

import { Mic, MicOff, Square, Info } from 'lucide-react';
import { useCallback, useEffect, useState } from 'react';
import { Capacitor } from '@capacitor/core';
import { Button } from './ui/button';
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
import { DEBUG_ENABLED } from '../lib/debug';
import { ChatComposer } from '../native/chatComposer';

const APP_VERSION = '1.0.3';

export function VoiceChatApp() {
  const {
    isListening,
    partialTranscript,
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
    sendMessage,
  } = useVoiceChat();

  const [isVoiceMode, setIsVoiceMode] = useState(false);
  const [showDebug, setShowDebug] = useState(false);
  const isNative = Capacitor.isNativePlatform();
  const [composerStatus, setComposerStatus] = useState<'idle' | 'ready' | 'error'>('idle');
  const [composerError, setComposerError] = useState<string | null>(null);
  const [composerAvailable, setComposerAvailable] = useState<string>('unknown');

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

  const showComposer = useCallback(async () => {
    if (Capacitor.isNativePlatform()) {
      await ChatComposer.show();
    }
  }, []);

  const hideComposer = useCallback(async () => {
    if (Capacitor.isNativePlatform()) {
      await ChatComposer.hide();
    }
  }, []);

  const enterVoiceMode = useCallback(async () => {
    setIsVoiceMode(true);
    startVoiceInput();
    await hideComposer();
  }, [hideComposer, startVoiceInput]);

  const exitVoiceMode = useCallback(async () => {
    stopVoiceInput();
    setIsVoiceMode(false);
    await showComposer();
  }, [showComposer, stopVoiceInput]);

  useEffect(() => {
    if (!isNative) {
      return;
    }

    const hasChatComposer = Capacitor.isPluginAvailable('ChatComposer');
    setComposerAvailable(hasChatComposer ? 'ChatComposer' : 'missing');

    showComposer()
      .then(() => {
        setComposerStatus('ready');
        setComposerError(null);
      })
      .catch((err) => {
        console.error('ChatComposer.show failed', err);
        setComposerStatus('error');
        setComposerError(err instanceof Error ? err.message : String(err));
      });

    let messageSub: { remove: () => void } | undefined;
    let voiceSub: { remove: () => void } | undefined;

    ChatComposer.addListener('messageSend', async (data) => {
      if (!data?.text || isProcessing) return;
      await sendMessage(data.text);
    }).then((handle) => {
      messageSub = handle;
    });

    ChatComposer.addListener('voiceToggle', async () => {
      await enterVoiceMode();
    }).then((handle) => {
      voiceSub = handle;
    });

    return () => {
      messageSub?.remove();
      voiceSub?.remove();
    };
  }, [enterVoiceMode, isProcessing, sendMessage, showComposer]);

  const isMicDisabled = isProcessing;

  return (
    <div className="min-h-screen bg-background overflow-x-hidden">
      <div className="app-shell mx-auto w-full sm:max-w-2xl">
        <header className="app-header flex items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold">Voice Chat</h1>
            <p className="text-xs text-muted-foreground">
              {isVoiceMode ? 'Voice mode' : 'Text mode'}
            </p>
          </div>
          <div className="flex items-center gap-2">
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setShowDebug((value) => !value)}
              aria-label="Toggle app info"
            >
              <Info className="h-5 w-5" />
            </Button>
          </div>
        </header>

        {error && (
          <div className="px-4">
            <Alert variant="destructive">
              <AlertDescription>{error}</AlertDescription>
            </Alert>
          </div>
        )}

        <div className="app-content">
          <MessageList messages={messages} />
        </div>

        {showDebug && (
          <div className="border-t border-border bg-muted/40 px-4 py-3 text-xs">
            <div className="flex items-center justify-between">
              <div className="text-muted-foreground">App version</div>
              <div className="font-medium">{APP_VERSION}</div>
            </div>
            <div className="mt-2 flex items-center justify-between text-[11px] text-muted-foreground">
              <span>Composer</span>
              <span>{isNative ? composerStatus : 'web'}</span>
            </div>
            <div className="mt-1 flex items-center justify-between text-[11px] text-muted-foreground">
              <span>Composer plugin</span>
              <span>{isNative ? composerAvailable : 'web'}</span>
            </div>
            {composerError && (
              <div className="mt-1 text-[11px] text-red-600">
                {composerError}
              </div>
            )}
            {DEBUG_ENABLED && lastPayload && (
              <div className="mt-3">
                <div className="mb-2 text-muted-foreground">Last API payload</div>
                <pre className="max-h-40 overflow-x-auto rounded-md bg-black/90 p-2 text-[10px] text-green-300">
                  {lastPayload}
                </pre>
              </div>
            )}
            <div className="mt-3 flex items-center justify-between text-[11px] text-muted-foreground">
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
              <button
                onClick={clearConversation}
                disabled={isProcessing}
                className="underline hover:text-foreground disabled:opacity-50"
              >
                Clear Chat
              </button>
            </div>
          </div>
        )}

        {isVoiceMode && (
          <div className="border-t border-border bg-background px-4 py-4">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-sm font-medium">
                  {isListening ? 'Listening…' : isProcessing ? 'Thinking…' : 'Ready'}
                </div>
                <div className="text-xs text-muted-foreground">
                  {isListening ? 'Tap mic to pause' : 'Tap mic to speak'}
                </div>
              </div>
              <div className="flex items-center gap-2">
                <Button
                  size="icon"
                  onClick={handleMicClick}
                  disabled={isMicDisabled}
                  className={isListening ? 'bg-red-500 hover:bg-red-600' : ''}
                >
                  {isListening ? <MicOff className="h-5 w-5" /> : <Mic className="h-5 w-5" />}
                </Button>
                <Button variant="outline" onClick={exitVoiceMode} className="gap-2">
                  <Square className="h-4 w-4" />
                  Stop
                </Button>
              </div>
            </div>
            <div className="mt-3 flex items-center gap-2 text-xs">
              <span className="text-muted-foreground">Language</span>
              <Select value={selectedLanguage} onValueChange={setLanguage}>
                <SelectTrigger className="h-8 w-[170px] text-xs">
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
            </div>
            {partialTranscript && (
              <div className="mt-3 rounded-lg bg-muted px-3 py-2 text-sm text-muted-foreground">
                {partialTranscript}
              </div>
            )}
          </div>
        )}

        {!isVoiceMode && !isNative && (
          <div className="app-composer border-t border-border">
            <div className="text-xs text-muted-foreground">
              Text input is handled by the native composer.
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
