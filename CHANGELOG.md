# Changelog

## Version 1.5.0 - Context-Aware AI Correction (February 2026)

### ✨ New Features

- **Context Awareness**: The AI correction model now understands which application and window you are working in. It adapts its tone, formatting, and technical terminology based on the active environment (e.g., formal for Outlook, informal for Slack, technical for VS Code).
- **Deep Text Extraction**: Using the macOS **TextMarker API**, Dictator can now reliably extract the selected text and surrounding context even from complex **Electron-based apps** like VS Code, Slack, and Safari.
- **Aggressives UI-Scanning**: Implemented a recursive UI-tree search (up to 10 levels deep) to find focused text fields that are nested within deep group structures.
- **Robustness Fallback**: For "Hard-Case" apps where Accessibility fails (VS Code, Discord, etc.), a safe clipboard-based context extraction is used as a last resort, preserving the user's original clipboard state.
- **Refined AI Correction**: Improved cleanup of AI preambles (e.g., "Output:", "Result:"), support for stop sequences to prevent model drift, and deep glossary integration.
- **Temporal & Environmental Context**: Sends current date, time, and weekday to the AI, allowing it to correctly resolve relative time mentions like "tomorrow" or "next Friday."
- **Verification**: 107 comprehensive unit tests verify the reliability of the entire pipeline, including edge cases for rate limiting, hallucination filtering, and context capture.

### 🔧 Configuration Changes

- **New Toggle**: Settings → Correction Settings → **Enable Context Awareness**.
- **Context-Ready System Prompt**: Updated the default correction prompt with specific instructions on how to utilize `<context>` blocks for smarter editing.

### 🧪 Technical Implementation

- **init.lua**: Immediate "Focus-Snap" at recording start to preserve the active text field's state. Uses async background capture to ensure zero delay in recording start.
- **utils.lua**: Complete overhaul of `M.getCurrentContext()` with cascading failover extraction logic. Renamed `<field_text>` to `<surrounding_text_readonly>` for better AI semantic parsing. Implemented **Recursive Child Concatenation** to handle fragmented web editors (LinkedIn) and a **Safe Clipboard Fallback** for "hard-case" apps (VS Code, Discord, Safari, Chrome). The fallback now preserves all clipboard data types (`readAllData`/`writeAllData`) and original cursor position, making it seamless for the user.
- **api.lua**: Payload expansion to include structured XML context (including user glossary) within the user message. Implemented deterministic correction with temperature 0.0, stop sequences, and robust output cleanup to eliminate AI preambles and code fences.

---

## Version 1.4.1 - XML-formatted Correction Prompts (February 2026)

### ✨ Enhancements

- **XML Transcript Tags**: Changed the correction user prompt to wrap transcripts in `<transcript>` tags instead of text markers. This improves recognition for models optimized for XML-structured data.

## Version 1.4.0 - Advanced API Routing & Dedicated Keys (February 2026)

### 🎯 Summary

Major update to the configuration system providing independent control over Transcription and Correction APIs. Introduced a hierarchical fallback system for API keys and endpoint routing.

### ✨ New Features

#### Dedicated API Keys

- **Transcription Key**: Set a specific API key for Whisper transcription independent of the global key.
- **Correction Key**: Set a specific API key for AI correction independent of the transcription key.
- **Hierarchical Fallback**:
  - Correction → Transcription → Global
  - This ensures maximum flexibility while maintaining "one-key setup" simplicity for most users.

#### Advanced Routing Logic

- **Inherited Endpoints**: If the Correction API Base URL is not explicitly set, it now automatically routes to the Transcription Base URL.
- **Provider Independence**: Seamlessly mix and match providers (e.g., Groq for lightning-fast Whisper + OpenAI for high-quality GPT-4o correction).

### 🔧 Configuration Changes

- **New Menu Items**:
  - Settings → Transcription API Settings → **Set Dedicated API Key**
  - Settings → Correction Settings → **Set Dedicated API Key**
- **Cleaner Overrides**: Setting a dedicated key or URL now "just works" without complex configuration.

### 📚 Documentation Updates

- **README Update**: Added section on Multi-Provider Routing and Fallbacks.
- **Model Recommendations**: Added recommendation to use **Instruct** models for better correction results.

### 🧪 Technical Implementation

- **config.lua**: Refactored `getCorrectionApiKey` and `getCorrectionApiBaseUrl` with multi-level fallback logic.
- **Unit Tests**: Added comprehensive test cases for routing logic and fallback chains (99 tests total).

---

## Version 1.3.1 - Provider Prioritization & Maintenance (January 2026)

### 🎯 Summary

Updated documentation to prioritize Groq as the recommended alternative to OpenAI due to its superior speed and performance. Fixed unit tests for flexible API key validation.

### 📚 Documentation Updates

- **Groq Prioritization**: Updated README to highlight Groq as the primary recommended alternative after OpenAI.
- **Improved Quick Start**: Optimized setup guide for Groq users.

### 🔧 Bug Fixes

- **Unit Tests**: Fixed `api_spec.lua` to match updated flexible API key validation logic.

## Version 1.3.0 - Cloudflare Workers AI Integration (January 2026)

### 🎯 Summary

Added full support for Cloudflare Workers AI, enabling users to leverage Cloudflare's global edge network for both transcription and AI correction with automatic provider detection and format adaptation.

### ✨ New Features

#### Cloudflare Workers AI Support

- **Automatic Provider Detection**: Detects Cloudflare URLs (`cloudflare.com`) and automatically adapts request format
- **Base64 Audio Encoding**: Implements Cloudflare's required base64 audio format (instead of multipart/form-data)
- **Transcription Models**: Support for `@cf/openai/whisper-large-v3-turbo` and `@cf/openai/whisper`
- **Correction Models**: Support for `@cf/meta/llama-3.1-8b-instruct`, `@cf/qwen/qwen2.5-7b-instruct`, and other Cloudflare LLMs
- **REST API Integration**: Full implementation of Cloudflare's `/ai/run/{model}` endpoint
- **Chat Completions**: Support for Cloudflare's `/v1/chat/completions` endpoint for AI correction

#### Technical Implementation

- **Provider-Agnostic Architecture**: Seamlessly switches between OpenAI, DeepInfra, and Cloudflare based on base URL
- **Base64 Encoding**: New `audioFileToBase64()` function using OpenSSL for reliable encoding
- **Extended Timeouts**: Increased timeout to 90s for Cloudflare requests
- **Enhanced Logging**: Provider type now displayed in console logs for debugging

#### Configuration

- **API Base URL Format**: `https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}`
- **Model Format**: Cloudflare models use `@cf/` prefix (e.g., `@cf/openai/whisper-large-v3-turbo`)
- **Authentication**: Standard Bearer token authentication with Cloudflare API tokens
- **Permissions Required**: "Workers AI Read" permission for API token

### 📚 Documentation Updates

- **Comprehensive Cloudflare Guide**: New section in README with setup instructions
- **Model List**: Complete list of available Cloudflare transcription and correction models
- **Troubleshooting**: Cloudflare-specific troubleshooting guide
- **Configuration Examples**: Step-by-step configuration with actual URLs and model names
- **Provider Comparison**: Updated performance comparison including Cloudflare metrics

### 🔧 Configuration Files

- **config.lua**: Added Cloudflare Workers AI default configuration comments
- **api.lua**: New provider detection and base64 encoding functions
- **README.md**: New Cloudflare Workers AI configuration section with prerequisites and examples

### 🎯 Benefits

- **Global Edge Deployment**: Low latency worldwide via Cloudflare's edge network
- **Free Tier**: 10,000 neurons/day included for personal use
- **Enterprise Infrastructure**: Reliable, scalable, and privacy-focused
- **No Cold Starts**: Always-ready AI models on edge network
- **Cost-Effective**: Competitive pricing with generous free tier

### 🔄 Compatibility

- **Backward Compatible**: All existing OpenAI and DeepInfra configurations continue to work
- **Automatic Detection**: No configuration changes needed for existing setups
- **Multi-Provider**: Can mix providers (e.g., Cloudflare transcription + OpenAI correction)

---

## Version 1.2.1 - Critical Bug Fixes & Stability Improvements (January 2026)

### 🐛 Critical Fixes

#### App Hanging Issues Resolved

- **Fixed undefined variable error**: Resolved `attempt to concatenate a nil value (global 'command')` error on line 450 that caused app to hang
- **Robust error handling**: All API callbacks now wrapped in `pcall` to prevent exceptions from freezing the app
- **Network error recovery**: Improved handling of curl exit code 6 (DNS resolution failure) and other network issues
- **State management**: Ensured processing flag is always reset on errors, preventing "already processing" lock

#### Stability Improvements

- **Error propagation**: Callback always invoked even on internal errors, preventing indefinite hangs
- **Variable scope fix**: Stored command string in proper scope for error logging
- **Graceful degradation**: App now recovers automatically from all callback exceptions

### 🧹 Repository Cleanup

- **Removed**: `SETUP_DEEPINFRA.md` - no longer needed (instructions integrated in main README)
- **Updated**: README troubleshooting section with comprehensive error recovery documentation

### 📝 Technical Details

- All `hs.task` callbacks protected with `pcall` error wrapping
- Fixed command variable reference in error handler
- Improved error messages with automatic API key redaction
- Better logging for debugging network and API issues

---

## Version 1.2.0 - Multi-Provider API Support

### 🎯 Summary

Added support for OpenAI-compatible API providers, enabling users to switch between OpenAI, DeepInfra, and other compatible services for both transcription and AI correction.

### ✨ New Features

#### Configuration Options

- **Transcription API Base URL**: Configurable base URL for speech-to-text API
  - Default: `https://api.openai.com/v1`
  - Menu: Settings → Transcription API Settings → Set API Base URL
- **Transcription Model**: Selectable model for transcription
  - Default: `whisper-1` (OpenAI)
  - Menu: Settings → Transcription API Settings → Set Model
- **Correction API Base URL**: Separate configurable base URL for AI correction
  - Default: `https://api.openai.com/v1`
  - Menu: Settings → Correction Settings → Set API Base URL

#### Supported Providers

##### OpenAI (Default)

- Transcription: `https://api.openai.com/v1` + `whisper-1`
- Correction: `https://api.openai.com/v1` + `gpt-4o-mini`

##### DeepInfra

- Transcription: `https://api.deepinfra.com/v1/openai` + `openai/whisper-large-v3-turbo`
- Benefits: 50-70% cheaper, 2-5x faster than OpenAI
- Correction: Compatible with various LLM models

### 🔧 Technical Changes

#### config.lua

- Added configuration keys:
  - `TRANSCRIPTION_API_BASE_URL_KEY`
  - `TRANSCRIPTION_MODEL_KEY`
  - `CORRECTION_API_BASE_URL_KEY`
- Added getter/setter functions:
  - `getTranscriptionApiBaseUrl()` / `setTranscriptionApiBaseUrl(url)`
  - `getTranscriptionModel()` / `setTranscriptionModel(model)`
  - `getCorrectionApiBaseUrl()` / `setCorrectionApiBaseUrl(url)`
- Added `sanitizeUrl()` function for URL validation:
  - Protocol validation (http/https)
  - Trailing slash removal
  - Length validation (<500 chars)
- Enhanced `sanitizeModel()` to support namespaced models (e.g., `openai/whisper-large-v3`)

#### api.lua

- Modified `transcribeWithRetry()`:
  - Replaced hardcoded OpenAI URL with `config.getTranscriptionApiBaseUrl() + "/audio/transcriptions"`
  - Replaced hardcoded `whisper-1` with `config.getTranscriptionModel()`
  - Enhanced debug logging to show API Base URL and Model
- Modified `correctTextWithRetry()`:
  - Replaced hardcoded OpenAI URL with `config.getCorrectionApiBaseUrl() + "/chat/completions"`
  - Enhanced debug logging for API endpoint visibility

#### init.lua

- Added menu structure for Transcription API Settings:
  - Set API Base URL dialog with examples
  - Set Model dialog with examples
- Enhanced Correction Settings menu:
  - Added Set API Base URL dialog
  - Reorganized for clarity
- Added local variables to `buildMenu()`:
  - `transcriptionApiBaseUrl`
  - `transcriptionModel`
  - `correctionApiBaseUrl`

#### README.md

- Added comprehensive "API Provider Configuration" section:
  - Supported providers table with URLs and models
  - Configuration examples for OpenAI and DeepInfra
  - Step-by-step provider switching guide
- Enhanced Features section with multi-provider support
- Added troubleshooting section for API provider issues:
  - API key format validation
  - Base URL format requirements
  - Model name verification
  - Manual curl testing examples

### 🔄 Backward Compatibility

- ✅ 100% backward compatible with existing installations
- ✅ All existing settings (API key, language, glossary, etc.) preserved
- ✅ OpenAI defaults maintained for new installations
- ✅ No breaking changes to existing functionality

### ✅ Testing

- Syntax validation passed (luac -p)
- Configuration getter/setter validation completed
- URL sanitization tested with edge cases
- Model name validation tested with various formats
- No errors in error checking

### 📚 Documentation

- Updated README.md with comprehensive provider configuration guide
- Added troubleshooting section for common provider issues
- Included example configurations for OpenAI and DeepInfra
- Documented URL and model name format requirements

### 🚀 Usage Example

#### Switching to DeepInfra:

1. Get API key from [DeepInfra Console](https://deepinfra.com/)
2. Dictator menu → Settings → API Key: `<your-deepinfra-key>`
3. Settings → Transcription API Settings → Set API Base URL: `https://api.deepinfra.com/v1/openai`
4. Settings → Transcription API Settings → Set Model: `openai/whisper-large-v3`
5. Test with a recording

#### Switching back to OpenAI:

1. Settings → API Key: `sk-...`
2. Settings → Transcription API Settings → Set API Base URL: `https://api.openai.com/v1`
3. Settings → Transcription API Settings → Set Model: `whisper-1`

### 📊 Performance Benefits (DeepInfra)

- Cost: 50-70% cheaper than OpenAI
- Speed: 2-5x faster inference
- Quality: Identical (uses same Whisper models)
- Compatibility: 100% OpenAI-compatible API

### 🔒 Security

- API keys validated before use
- URLs validated for proper format
- Model names sanitized to prevent injection
- All sensitive data handled securely

### 📝 Notes

- Each provider requires its own API key format
- URLs must NOT include endpoint paths (e.g., `/audio/transcriptions`)
- Model names must match provider's format exactly
- Test with a short recording after switching providers
- Console logs show exact API requests for debugging
