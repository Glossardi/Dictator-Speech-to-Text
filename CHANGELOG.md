# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-12-31

### Added
- Voice-to-text transcription using OpenAI Whisper API
- Hold-to-record with Fn key or custom hotkey
- Automatic text pasting to active application
- Menubar UI with status indicators (🎙️ Idle, 🔴 Recording, ⏳ Processing)
- Multi-language support via Whisper API
- Rate limiting with token bucket algorithm (3 requests/min default)
- Exponential backoff retry logic for API errors
- Hotkey debouncing (500ms) to prevent double-triggers
- Input validation (API key format, file size <25MB)
- Structured logging with hs.logger
- Configurable settings (API key, language, auto-paste, hotkeys)

### Security
- API key validation (must start with 'sk-')
- File size validation (<25MB OpenAI limit)
- Secure settings storage via Hammerspoon preferences
- No hardcoded credentials

### Performance
- Token bucket rate limiter prevents API abuse
- Automatic retry with exponential backoff (1s → 2s → 4s)
- State management prevents concurrent operations
- Efficient audio recording with SoX (16kHz, mono)

## [0.1.0] - 2025-12-30

### Added
- Initial prototype version
- Basic recording and transcription functionality
