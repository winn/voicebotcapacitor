/**
 * Component for displaying conversation history
 */

import { useEffect, useRef } from 'react';
import type { ChatMessage } from '../types/chat';

interface MessageListProps {
  messages: ChatMessage[];
}

export function MessageList({ messages }: MessageListProps) {
  const bottomRef = useRef<HTMLDivElement>(null);

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

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

        return (
          <div
            key={message.id}
            className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}
          >
            <div className={`max-w-[85%] ${isUser ? 'text-right' : 'text-left'}`}>
              <div
                className={`chat-bubble text-[15px] leading-relaxed ${
                  isUser ? 'chat-bubble-user' : ''
                }`}
              >
                <div className="whitespace-pre-wrap break-words">
                  {message.content}
                </div>
              </div>
              {time && (
                <div className="mt-1 text-[11px] text-muted-foreground">
                  {isUser ? 'You' : 'AI'} · {time}
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
