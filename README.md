# Dictator – Voice-to-Text Menubar App for macOS

A lightweight macOS menubar application for voice dictation using OpenAI's Whisper API. Record audio with a hotkey, get instant transcription, and optionally auto-paste into any application.

Built with [Hammerspoon](https://www.hammerspoon.org/).

---

## ✨ Features

- **🎙️ Hold-to-Record**: Press and hold `Fn` key (or custom hotkey) to record audio
- **🤖 OpenAI Whisper**: Accurate transcription via OpenAI's Whisper API
- **📋 Auto-Paste**: Automatically paste transcribed text (toggle on/off)
- **⚙️ Configurable**: Set API key, custom hotkeys, language, and auto-paste behavior
- **🎯 Minimal UI**: Clean menubar icon showing current status (🎙️ Idle, 🔴 Recording, ⏳ Processing)
- **🌍 Multi-language**: Support for multiple languages via Whisper API

---

## 🔧 Prerequisites

### Required Software
- **macOS** (tested on macOS Sonoma+)
- **Hammerspoon** – Automation framework for macOS
  ```bash
  brew install hammerspoon
  ```
- **SoX** – Audio recording utility
  ```bash
  brew install sox
  ```

### API Key
- **OpenAI API Key** with Whisper API access
  - Get one at [OpenAI Platform](https://platform.openai.com/api-keys)

### System Permissions
- **Accessibility Permission** for Hammerspoon (required for Fn key detection)
  - Go to: **System Settings** → **Privacy & Security** → **Accessibility**
  - Enable **Hammerspoon**

---

## 📦 Installation

### Option 1: Direct Install
```bash
# Clone the repository
git clone <repository-url> Dictator
cd Dictator

# Copy files to Hammerspoon config directory
cp -r *.lua ~/.hammerspoon/

# Reload Hammerspoon
# (Click Hammerspoon menubar icon → Reload Config)
```

### Option 2: Symlink (Recommended for Development)
```bash
# Clone the repository
git clone <repository-url> ~/Documents/Dictator
cd ~/Documents/Dictator

# Symlink files to Hammerspoon config
ln -sf ~/Documents/Dictator/*.lua ~/.hammerspoon/

# Reload Hammerspoon
```

---

## 🚀 Quick Start

### 1. Configure API Key
1. Click the **Dictator menubar icon** (🎙️)
2. Navigate to **Settings** → **API Key**
3. Enter your OpenAI API Key
4. Click **OK**

### 2. Test Recording
1. Open any text editor (Notes, TextEdit, etc.)
2. Click in a text field
3. **Hold the `Fn` key** and speak
4. **Release `Fn`** when done
5. Wait for transcription to appear

---

## ⚙️ Configuration

Access all settings via the menubar icon:

### Settings Menu
- **API Key**: Set your OpenAI API key
- **Language**: Set transcription language (`auto`, `en`, `de`, etc.)
- **Auto-Paste**: Toggle automatic text pasting
- **Use Fn Key (Hold)**: Toggle Fn key as recording hotkey
- **Set Custom Hotkey**: Configure alternative hotkey (when Fn key is disabled)

### Hotkey Options

#### Option 1: Fn Key (Default)
- **Enable**: Check **Use Fn Key (Hold)** in settings
- **Usage**: Hold `Fn` to record, release to transcribe
- **Requires**: Accessibility permissions

#### Option 2: Custom Hotkey
- **Enable**: Uncheck **Use Fn Key (Hold)**
- **Configure**: Click **Set Custom Hotkey**
- **Format**: Enter modifiers and key (e.g., `cmd alt d`)
- **Valid modifiers**: `cmd`, `alt`, `ctrl`, `shift`

---

## 🎯 Usage

### With Auto-Paste Enabled (Default)
1. Click into any text field
2. Hold your configured hotkey (`Fn` or custom)
3. Speak your text
4. Release the hotkey
5. Text automatically appears in the active field

### With Auto-Paste Disabled
1. Hold your configured hotkey
2. Speak your text
3. Release the hotkey
4. Text is copied to clipboard (notification appears)
5. Press `Cmd+V` to paste manually

---

## 🏗️ Project Structure

```
Dictator/
├── init.lua       # Main entry point, menu logic, hotkey binding
├── config.lua     # Configuration management (settings persistence)
├── audio.lua      # Audio recording via SoX
├── api.lua        # OpenAI API integration (Whisper transcription)
├── ui.lua         # Menubar UI and status updates
├── utils.lua      # Utility functions (temp file handling)
└── README.md      # This file
```

---

## 🐛 Troubleshooting

### Fn Key Not Working
**Symptom**: Nothing happens when holding Fn key

**Solutions**:
1. Check Hammerspoon Console for errors:
   - Open Hammerspoon → **Console**
   - Look for: `ERROR: Failed to start Fn key eventtap`
2. Enable Accessibility permission:
   - **System Settings** → **Privacy & Security** → **Accessibility**
   - Add/Enable **Hammerspoon**
3. Reload Hammerspoon config
4. Check Console for: `Fn key watcher started successfully` ✅

### Custom Hotkey Not Working
**Symptom**: Hotkey doesn't trigger recording

**Solutions**:
1. Ensure **Use Fn Key (Hold)** is **unchecked**
2. Check Console for: `Hotkey bound successfully`
3. Try a different key combination
4. Valid format: `cmd alt s`, `ctrl shift d`, etc.

### Auto-Paste Not Working
**Symptom**: Text copied to clipboard but not pasted

**Solutions**:
1. Ensure **Auto-Paste** is **checked** in menu
2. Check Console for: `Auto-pasting text...`
3. Make sure text editor has **focus** after recording
4. Wait 1-2 seconds before switching windows
5. Try disabling auto-paste and using manual `Cmd+V`

### Transcription Fails
**Symptom**: No text appears, error notification shown

**Solutions**:
1. Check Hammerspoon Console for detailed error messages
2. Verify API key is correct
3. Check OpenAI API quota/billing
4. Test with shorter recordings first
5. Check internet connection

### Recording Issues
**Symptom**: No audio captured or poor quality

**Solutions**:
1. Verify SoX is installed: `which rec`
2. Check microphone permissions for Hammerspoon
3. Test recording manually: `rec test.wav`
4. Check Console for SoX errors

---

## 🔍 Debug Mode

Open Hammerspoon Console to see detailed logging:

**Console Shows**:
- Hotkey press/release events
- Recording start/stop
- API requests/responses
- Transcription results
- Error messages

**Useful Console Commands**:
```lua
-- Check Fn watcher status
print(fnWatcher and "Fn watcher exists" or "Fn watcher is nil")

-- Check auto-paste setting
print(config.getAutoPaste() and "Auto-Paste ON" or "Auto-Paste OFF")

-- Check use Fn key setting
print(config.getUseFnKey() and "Use Fn Key ON" or "Use Fn Key OFF")
```

---

## 🛠️ Development

### Code Structure
- **Modular design**: Separation of concerns (UI, config, audio, API)
- **State management**: Persistent settings via `hs.settings`
- **Error handling**: Comprehensive logging for debugging
- **Event-driven**: Hotkey bindings and UI callbacks

### Testing Locally
1. Make changes to `.lua` files
2. Reload Hammerspoon config
3. Test functionality
4. Check Console for errors
5. Copy to `~/.hammerspoon/` when ready

### Contributing
Contributions welcome! Please:
- Follow existing code style
- Add error handling and logging
- Test thoroughly before submitting
- Update README if adding features

---

## 📝 License

MIT License - See LICENSE file for details

---

## 🙏 Acknowledgments

- [Hammerspoon](https://www.hammerspoon.org/) – macOS automation framework
- [OpenAI Whisper](https://openai.com/research/whisper) – Speech recognition AI
- [SoX](http://sox.sourceforge.net/) – Audio processing utility

---

## 📧 Support

For issues, questions, or feature requests, please open an issue on GitHub.
