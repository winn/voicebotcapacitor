/**
 * Component for displaying conversation history
 */

import { useEffect, useRef } from 'react';
import type { ChatMessage } from '../types/chat';
import { Card } from './ui/card';

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
      <Card className="p-8 text-center text-muted-foreground">
        No messages yet. Tap the microphone to start a conversation.
      </Card>
    );
  }

  return (
    <div className="space-y-3 max-h-[400px] overflow-y-auto">
      {displayMessages.map((message) => {
        const isUser = message.role === 'user';
        const time = message.timestamp.toLocaleTimeString([], {
          hour: '2-digit',
          minute: '2-digit',
        });

        return (
          <div
            key={message.id}
            className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}
          >
            <div className={`max-w-[80%] ${isUser ? 'text-right' : 'text-left'}`}>
              <Card
                className={`p-3 ${
                  isUser
                    ? 'bg-blue-500 text-white'
                    : 'bg-muted'
                }`}
              >
                <div className="text-sm whitespace-pre-wrap break-words">
                  {message.content}
                </div>
              </Card>
              <div className="text-xs text-muted-foreground mt-1 px-1">
                {isUser ? 'You' : 'AI'} · {time}
              </div>
            </div>
          </div>
        );
      })}
      <div ref={bottomRef} />
    </div>
  );
}
