import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.winn.voicebotcapacitor',
  appName: 'Voice Bot',
  webDir: 'dist',
  plugins: {
    Keyboard: {
      resize: 'none',
      style: 'dark'
    }
  }
};

export default config;
