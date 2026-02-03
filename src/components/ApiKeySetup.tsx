/**
 * Component for OpenAI API key configuration
 */

import { useState } from 'react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
import { Alert, AlertDescription } from './ui/alert';
import { validateApiKey } from '../services/openai';

interface ApiKeySetupProps {
  onSave: (key: string) => void;
}

export function ApiKeySetup({ onSave }: ApiKeySetupProps) {
  const [apiKey, setApiKey] = useState('');
  const [validationError, setValidationError] = useState<string | null>(null);

  const handleSave = () => {
    setValidationError(null);

    if (!apiKey.trim()) {
      setValidationError('Please enter an API key');
      return;
    }

    if (!validateApiKey(apiKey.trim())) {
      setValidationError('Invalid API key format. OpenAI API keys start with "sk-"');
      return;
    }

    onSave(apiKey.trim());
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSave();
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>OpenAI API Key Setup</CardTitle>
        <CardDescription>
          Enter your OpenAI API key to enable voice chat functionality
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <Alert>
          <AlertDescription>
            <strong>Security Warning:</strong> Your API key will be stored in browser localStorage
            and sent directly to OpenAI from your device. For production use, consider using a
            proxy server.
          </AlertDescription>
        </Alert>

        <div className="space-y-2">
          <Input
            type="password"
            placeholder="sk-..."
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
            onKeyPress={handleKeyPress}
          />
          {validationError && (
            <p className="text-sm text-red-500">{validationError}</p>
          )}
        </div>

        <div className="flex flex-col gap-2">
          <Button onClick={handleSave}>
            Save API Key
          </Button>
          <p className="text-xs text-muted-foreground">
            Don't have an API key?{' '}
            <a
              href="https://platform.openai.com/api-keys"
              target="_blank"
              rel="noopener noreferrer"
              className="underline"
            >
              Get one from OpenAI Platform
            </a>
          </p>
        </div>
      </CardContent>
    </Card>
  );
}
