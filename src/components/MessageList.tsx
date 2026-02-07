/**
 * Component for displaying conversation history
 */

import { useEffect, useRef, useState } from 'react';
import { Volume2 } from 'lucide-react';
import type { ChatMessage } from '../types/chat';
import { Capacitor } from '@capacitor/core';

interface MessageListProps {
  messages: ChatMessage[];
}

export function MessageList({ messages }: MessageListProps) {
  const bottomRef = useRef<HTMLDivElement>(null);
  const [playingMessageId, setPlayingMessageId] = useState<string | null>(null);

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Listen for playback state changes from native
  useEffect(() => {
    console.log('🔍 [WEB] MessageList useEffect running');
    console.log('🔍 [WEB] Capacitor.isNativePlatform():', Capacitor.isNativePlatform());

    if (Capacitor.isNativePlatform()) {
      console.log('📝 [WEB] Registering playback state listeners...');

      (window as any).onAudioPlaybackStarted = (messageId: string) => {
        console.log('📥 [NATIVE->WEB] Audio playback started:', messageId);
        console.log('📥 [NATIVE->WEB] Current playingMessageId:', playingMessageId);
        setPlayingMessageId(messageId);
        console.log('📥 [NATIVE->WEB] Updated playingMessageId to:', messageId);
      };

      (window as any).onAudioPlaybackStopped = () => {
        console.log('📥 [NATIVE->WEB] Audio playback stopped');
        console.log('📥 [NATIVE->WEB] Current playingMessageId:', playingMessageId);
        setPlayingMessageId(null);
        console.log('📥 [NATIVE->WEB] Cleared playingMessageId');
      };

      console.log('✅ [WEB] Registered playback state listeners');
      console.log('✅ [WEB] window.onAudioPlaybackStarted type:', typeof (window as any).onAudioPlaybackStarted);
      console.log('✅ [WEB] window.onAudioPlaybackStopped type:', typeof (window as any).onAudioPlaybackStopped);
    } else {
      console.log('⚠️ [WEB] Not on native platform, skipping listener registration');
    }

    return () => {
      console.log('🧹 [WEB] Cleaning up playback state listeners');
      delete (window as any).onAudioPlaybackStarted;
      delete (window as any).onAudioPlaybackStopped;
    };
  }, []);

  // Generate message ID from text (same algorithm as native)
  const getMessageId = (text: string): string => {
    let hash = 0;
    for (let i = 0; i < text.length; i++) {
      const char = text.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32bit integer
    }
    return String(Math.abs(hash));
  };

  // Handle audio playback/stop
  const handleAudioClick = async (text: string) => {
    if (!Capacitor.isNativePlatform()) return;

    const messageId = getMessageId(text);

    try {
      // If this message is currently playing, stop it
      if (playingMessageId === messageId) {
        if ((window as any).stopAudio) {
          (window as any).stopAudio();
        }
        return;
      }

      // If another message is playing, use switchAudio for atomic stop+play
      if (playingMessageId !== null) {
        if ((window as any).switchAudio) {
          (window as any).switchAudio(text);
        }
        return;
      }

      // No audio playing, start playback normally (always use replayAudioText for cached audio)
      if ((window as any).replayAudioText) {
        (window as any).replayAudioText(text);
      }
    } catch (error) {
      console.error('Failed to handle audio:', error);
    }
  };

  // Filter out system messages from display
  const displayMessages = messages.filter((msg) => msg.role !== 'system');

  if (displayMessages.length === 0) {
    return (
      <div className="rounded-2xl border border-dashed border-border p-8 text-center text-sm text-muted-foreground">
        Start a conversation by typing below or entering voice mode.
      </div>
    );
  }

  return (
    <div className="space-y-4 pb-6">
      {displayMessages.map((message) => {
        const isUser = message.role === 'user';
        const timestamp = message.timestamp instanceof Date
          ? message.timestamp
          : new Date(message.timestamp);
        const time = isNaN(timestamp.getTime())
          ? ''
          : timestamp.toLocaleTimeString([], {
            hour: '2-digit',
            minute: '2-digit',
          });

        const messageId = getMessageId(message.content);
        const isPlaying = playingMessageId === messageId;
        const hasAudio = !isUser && message.hasAudio;

        return (
          <div
            key={message.id}
            className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}
          >
            <div className={`max-w-[85%] ${isUser ? 'text-right' : 'text-left'}`}>
              <div
                className={`chat-bubble text-[15px] leading-relaxed ${
                  isUser ? 'chat-bubble-user' : ''
                } ${hasAudio ? 'cursor-pointer hover:opacity-80 transition-opacity' : ''} ${isPlaying ? 'ring-2 ring-blue-400 ring-opacity-50' : ''}`}
                onClick={() => hasAudio && handleAudioClick(message.content)}
              >
                <div className="flex items-start gap-2">
                  <div className="flex-1 whitespace-pre-wrap break-words">
                    {message.content}
                  </div>
                  {!isUser && message.hasAudio && (
                    <Volume2 className={`h-4 w-4 flex-shrink-0 mt-0.5 ${isPlaying ? 'opacity-100 animate-pulse' : 'opacity-60'}`} />
                  )}
                </div>
              </div>
              {time && (
                <div className="mt-1 text-[11px] text-muted-foreground">
                  {isUser ? 'You' : 'AI'} · {time}
                  {!isUser && message.hasAudio && (
                    <span className="ml-1 opacity-60">
                      • {isPlaying ? 'Tap to stop' : 'Tap to replay'}
                    </span>
                  )}
                </div>
              )}
            </div>
          </div>
        );
      })}
      <div ref={bottomRef} />
    </div>
  );
}
