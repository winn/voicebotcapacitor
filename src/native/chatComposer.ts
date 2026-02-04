import { registerPlugin, type PluginListenerHandle } from '@capacitor/core';

export interface ChatComposerPlugin {
  show(): Promise<void>;
  hide(): Promise<void>;
  addListener(
    eventName: 'messageSend',
    listener: (data: { text: string }) => void
  ): Promise<PluginListenerHandle>;
  addListener(
    eventName: 'voiceToggle',
    listener: () => void
  ): Promise<PluginListenerHandle>;
}

export const ChatComposer = registerPlugin<ChatComposerPlugin>('ChatComposer');
