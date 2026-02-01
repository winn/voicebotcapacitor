import { Mic, MicOff, Trash2, AlertCircle, Languages } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { useSpeechRecognition } from '@/hooks/useSpeechRecognition';
import { SUPPORTED_LANGUAGES } from '@/config/languages';
import { Capacitor } from '@capacitor/core';

export function SpeechRecognitionApp() {
  const {
    isListening,
    transcript,
    partialTranscript,
    error,
    isAvailable,
    hasPermission,
    startListening,
    stopListening,
    clearTranscript,
    requestPermission,
    language,
    setLanguage,
  } = useSpeechRecognition();

  const isNative = Capacitor.isNativePlatform();

  return (
    <div className="min-h-screen bg-background p-6 flex flex-col">
      <header className="text-center mb-8">
        <h1 className="text-3xl font-bold text-foreground mb-2">
          Voice Transcription
        </h1>
        <p className="text-muted-foreground">
          Tap the microphone to start speaking
        </p>
      </header>

      <Card className="mb-6">
        <CardContent className="pt-6">
          <div className="flex items-center gap-3">
            <Languages className="h-5 w-5 text-muted-foreground shrink-0" />
            <div className="flex-1">
              <label className="text-sm font-medium mb-2 block">
                Language
              </label>
              <Select value={language} onValueChange={setLanguage} disabled={isListening}>
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Select language" />
                </SelectTrigger>
                <SelectContent>
                  {SUPPORTED_LANGUAGES.map((lang) => (
                    <SelectItem key={lang.code} value={lang.code}>
                      {lang.name}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </div>
          </div>
        </CardContent>
      </Card>

      {!isNative && (
        <Card className="mb-6 border-amber-500/50 bg-amber-500/10">
          <CardContent className="pt-6">
            <div className="flex items-start gap-3">
              <AlertCircle className="h-5 w-5 text-amber-500 mt-0.5 shrink-0" />
              <div>
                <p className="font-medium text-amber-500">Web Preview Mode</p>
                <p className="text-sm text-muted-foreground mt-1">
                  Speech recognition requires running on a native iOS device. 
                  Build and deploy this app using Capacitor to use the device microphone.
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      )}

      {error && (
        <Card className="mb-6 border-destructive/50 bg-destructive/10">
          <CardContent className="pt-6">
            <div className="flex items-start gap-3">
              <AlertCircle className="h-5 w-5 text-destructive mt-0.5 shrink-0" />
              <p className="text-sm text-destructive">{error}</p>
            </div>
          </CardContent>
        </Card>
      )}

      {isNative && !hasPermission && (
        <Card className="mb-6">
          <CardContent className="pt-6 text-center">
            <p className="text-muted-foreground mb-4">
              Microphone permission is required for speech recognition
            </p>
            <Button onClick={requestPermission}>
              Grant Permission
            </Button>
          </CardContent>
        </Card>
      )}

      <Card className="flex-1 mb-6">
        <CardHeader>
          <CardTitle className="text-lg flex items-center justify-between">
            <span>Transcript</span>
            {transcript && (
              <Button
                variant="ghost"
                size="sm"
                onClick={clearTranscript}
                className="text-muted-foreground hover:text-foreground"
              >
                <Trash2 className="h-4 w-4 mr-1" />
                Clear
              </Button>
            )}
          </CardTitle>
        </CardHeader>
        <CardContent>
          <div className="min-h-[200px] p-4 rounded-lg bg-muted/50">
            {transcript || partialTranscript ? (
              <p className="text-foreground leading-relaxed">
                {transcript}
                {partialTranscript && (
                  <span className="text-muted-foreground italic">
                    {transcript ? ' ' : ''}{partialTranscript}
                  </span>
                )}
              </p>
            ) : (
              <p className="text-muted-foreground text-center italic">
                {isListening 
                  ? 'Listening... speak now' 
                  : 'Your transcribed text will appear here'}
              </p>
            )}
          </div>
        </CardContent>
      </Card>

      <div className="flex justify-center pb-8">
        <Button
          size="lg"
          className={`w-20 h-20 rounded-full transition-all duration-300 ${
            isListening 
              ? 'bg-destructive hover:bg-destructive/90 animate-pulse' 
              : 'bg-primary hover:bg-primary/90'
          }`}
          onClick={isListening ? stopListening : startListening}
          disabled={!isNative || (isNative && !isAvailable)}
        >
          {isListening ? (
            <MicOff className="h-8 w-8" />
          ) : (
            <Mic className="h-8 w-8" />
          )}
        </Button>
      </div>

      {isListening && (
        <p className="text-center text-sm text-muted-foreground animate-pulse">
          Tap the button to stop recording
        </p>
      )}
    </div>
  );
}
