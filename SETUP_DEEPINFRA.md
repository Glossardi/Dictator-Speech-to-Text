# DeepInfra Setup Guide - Quick Reference

This is the **recommended configuration** for Dictator - faster and cheaper than OpenAI!

## ⚡ Quick Setup (5 minutes)

### 1. Get DeepInfra API Key
- Visit [DeepInfra Console](https://deepinfra.com/)
- Sign up (free credits available!)
- Copy your API key

### 2. Configure Dictator

Open **Dictator menubar icon** → **Settings**:

#### API Key
```
Paste your DeepInfra API key
```

#### Transcription API Settings
**Base URL:**
```
https://api.deepinfra.com/v1/openai
```

**Model:**
```
openai/whisper-large-v3-turbo
```
*(This is the fastest Whisper model on DeepInfra!)*

#### AI Correction (Optional but Recommended)

Enable **AI Correction** in Settings, then configure:

**Base URL:**
```
https://api.deepinfra.com/v1/openai
```

**Model (choose one):**
- **Fast & Good**: `Qwen/Qwen2.5-7B-Instruct`
- **Best Quality**: `meta-llama/Llama-3.3-70B-Instruct`
- **Ultra Fast**: `Qwen/Qwen2.5-3B-Instruct`

### 3. Test It!
- Hold Fn key
- Speak a few words
- Release
- Enjoy the speed! ⚡

## 💰 Cost Comparison

| Provider | Cost per Hour | Speed |
|----------|--------------|-------|
| **DeepInfra** | $0.08 - $0.17 | ⚡⚡⚡⚡⚡ 2-5x faster |
| OpenAI | $0.36 | ⚡⚡ baseline |

**Savings**: 50-70% cheaper with identical quality!

## 🎯 Recommended Models Tested

These combinations work perfectly together:

### Configuration 1: Maximum Speed ⚡
- Transcription: `openai/whisper-large-v3-turbo`
- Correction: `Qwen/Qwen2.5-7B-Instruct`
- **Use case**: Daily dictation, fast turnaround

### Configuration 2: Best Quality 🎯
- Transcription: `openai/whisper-large-v3`
- Correction: `meta-llama/Llama-3.3-70B-Instruct`
- **Use case**: Professional documents, high accuracy needed

### Configuration 3: Ultra Fast (Testing) 🚀
- Transcription: `openai/whisper-large-v3-turbo`
- Correction: `Qwen/Qwen2.5-3B-Instruct`
- **Use case**: Quick notes, prototyping

## 🔧 Troubleshooting

### "Invalid model name" error
- Make sure to include the full namespace: `openai/whisper-large-v3-turbo`
- Note the forward slash `/` - it's required!

### "API Error" or 404
- Double-check the Base URL ends with `/openai` (not `/inference/openai`)
- Correct: `https://api.deepinfra.com/v1/openai`

### Still getting errors?
- Verify your API key is valid at [DeepInfra Console](https://deepinfra.com/)
- Check you have credits remaining
- Try OpenAI temporarily to rule out configuration issues

## 🔄 Switch Back to OpenAI

If you need to switch back:

1. **API Key**: Your OpenAI key (starts with `sk-`)
2. **Transcription Base URL**: `https://api.openai.com/v1`
3. **Transcription Model**: `whisper-1`
4. **Correction Base URL**: `https://api.openai.com/v1`
5. **Correction Model**: `gpt-4o-mini` or `gpt-4o`

## 📚 More Information

- [DeepInfra Documentation](https://deepinfra.com/docs)
- [DeepInfra Model Catalog](https://deepinfra.com/models)
- [Main README](README.md)

---

**Enjoy dictating at lightning speed! ⚡**
