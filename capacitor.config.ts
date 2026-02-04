import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.winn.voicebotcapacitor',
  appName: 'Voice Bot',
  webDir: 'dist',
  ios: {
    contentInset: 'always'
  },
  plugins: {
    Keyboard: {
      resize: 'none',
      style: 'dark'
    },
    StatusBar: {
      overlaysWebView: false
    }
  }
};

export default config;
