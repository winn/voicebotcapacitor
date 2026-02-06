#!/usr/bin/env node

/**
 * Build script that injects environment variables into index.html
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Read .env.local file
function loadEnvFile() {
  const envPath = path.join(__dirname, '.env.local');

  if (!fs.existsSync(envPath)) {
    console.log('⚠️  No .env.local file found, skipping env injection');
    return {};
  }

  const envContent = fs.readFileSync(envPath, 'utf-8');
  const env = {};

  envContent.split('\n').forEach(line => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#')) {
      const [key, ...valueParts] = trimmed.split('=');
      const value = valueParts.join('=');
      env[key] = value;
    }
  });

  return env;
}

// Main build
function build() {
  console.log('🔨 Building with environment variables...');

  // Load environment
  const env = loadEnvFile();
  const apiKey = env.VITE_OPENAI_API_KEY;
  const elevenLabsKey = env.VITE_ELEVENLABS_API_KEY || '';
  const botnoiKey = env.VITE_BOTNOI_API_KEY || '';

  if (!apiKey || apiKey === 'your-api-key-here') {
    console.log('⚠️  No valid OpenAI API key in .env.local');
    console.log('ℹ️  User will need to enter API key in the app');
  } else {
    console.log('✅ OpenAI API key found in .env.local');
  }

  if (elevenLabsKey && !elevenLabsKey.includes('your-')) {
    console.log('✅ ElevenLabs API key found in .env.local');
  }

  if (botnoiKey && !botnoiKey.includes('your-')) {
    console.log('✅ BOTNOI API key found in .env.local');
  }

  // Read index.html
  const htmlPath = path.join(__dirname, 'index.html');
  let html = fs.readFileSync(htmlPath, 'utf-8');

  // Inject API keys into localStorage initialization script
  const initScript = `
    <script>
      // Pre-populate API keys from build-time env if available
      (function() {
        const buildTimeApiKey = '${apiKey || ''}';
        if (buildTimeApiKey && buildTimeApiKey.startsWith('sk-')) {
          const existingKey = localStorage.getItem('openai_api_key');
          if (!existingKey) {
            console.log('🔑 Using OpenAI API key from .env.local');
            localStorage.setItem('openai_api_key', buildTimeApiKey);
          }
        }

        const elevenLabsKey = '${elevenLabsKey || ''}';
        if (elevenLabsKey && !elevenLabsKey.includes('your-')) {
          const existingKey = localStorage.getItem('elevenlabs_api_key');
          if (!existingKey) {
            console.log('🔑 Using ElevenLabs API key from .env.local');
            localStorage.setItem('elevenlabs_api_key', elevenLabsKey);
          }
        }

        const botnoiKey = '${botnoiKey || ''}';
        if (botnoiKey && !botnoiKey.includes('your-')) {
          const existingKey = localStorage.getItem('botnoi_api_key');
          if (!existingKey) {
            console.log('🔑 Using BOTNOI API key from .env.local');
            localStorage.setItem('botnoi_api_key', botnoiKey);
          }
        }
      })();
    </script>
  `;

  // Insert before the IMMEDIATE BRIDGE SETUP script
  html = html.replace(
    '<!-- IMMEDIATE BRIDGE SETUP',
    initScript + '\n    <!-- IMMEDIATE BRIDGE SETUP'
  );

  // Write to dist
  const distDir = path.join(__dirname, 'dist');
  if (!fs.existsSync(distDir)) {
    fs.mkdirSync(distDir, { recursive: true });
  }

  fs.writeFileSync(path.join(distDir, 'index.html'), html);
  console.log('✅ Built dist/index.html with environment variables');
}

build();
