-- config.lua
-- Configuration management and persistent settings via hs.settings
-- Handles API keys, hotkeys, correction settings, and user preferences

local M = {}
local settings = hs.settings

-- Constants
M.BUNDLE_ID = "com.simon.dictator"
M.API_KEY_KEY = M.BUNDLE_ID .. ".apiKey"
M.HOTKEY_MODS_KEY = M.BUNDLE_ID .. ".hotkeyMods"
M.HOTKEY_KEY_KEY = M.BUNDLE_ID .. ".hotkeyKey"
M.AUTO_PASTE_KEY = M.BUNDLE_ID .. ".autoPaste"
M.USE_FN_KEY_KEY = M.BUNDLE_ID .. ".useFnKey"
M.LANGUAGE_KEY = M.BUNDLE_ID .. ".language"
M.RATE_LIMIT_MAX_KEY = M.BUNDLE_ID .. ".rateLimitMax"
M.RATE_LIMIT_WINDOW_KEY = M.BUNDLE_ID .. ".rateLimitWindow"
M.CORRECTION_ENABLED_KEY = M.BUNDLE_ID .. ".correctionEnabled"
M.CORRECTION_MODEL_KEY = M.BUNDLE_ID .. ".correctionModel"
M.CORRECTION_SYSTEM_PROMPT_KEY = M.BUNDLE_ID .. ".correctionSystemPrompt"
M.GLOSSARY_KEY = M.BUNDLE_ID .. ".userGlossary"
M.TRANSCRIPTION_API_BASE_URL_KEY = M.BUNDLE_ID .. ".transcriptionApiBaseUrl"
M.TRANSCRIPTION_MODEL_KEY = M.BUNDLE_ID .. ".transcriptionModel"
M.CORRECTION_API_BASE_URL_KEY = M.BUNDLE_ID .. ".correctionApiBaseUrl"

-- Defaults
M.defaultHotkeyMods = {"cmd", "alt"}
M.defaultHotkeyKey = "D"
M.defaultUseFnKey = true
M.defaultAutoPaste = true
M.defaultLanguage = "auto"
M.defaultRateLimitMax = 3  -- 3 requests
M.defaultRateLimitWindow = 60  -- per 60 seconds (1 minute)
M.defaultCorrectionEnabled = false
M.defaultCorrectionModel = "openai/gpt-oss-20b"  -- Best for production: 100/100 quality, 399 TPS, $0.000163 (via Groq)
M.defaultCorrectionSystemPrompt = [[You are Flow, an intelligent voice-to-text correction assistant. Transform natural speech into polished text while preserving the speaker's exact intent and language.

## Core Principles
1. **Never translate** - Output language = Input language (100%)
2. **Mirror intent** - Clean and format, never add or interpret
3. **No hallucinations** - If uncertain, preserve original

## Corrections (Priority Order)

### 1. Backtracking (Highest Priority)
Keep ONLY the final intended version:
- "Monday... actually Tuesday" → "Tuesday"
- "2 PM no wait 3 PM" → "3 PM"
- "budget actually timeline" → "timeline"

**Markers**: no wait | actually | wait | I mean | scratch that | nein warte (DE) | attends (FR) | espera (ES)

### 2. Filler Removal (AGGRESSIVE - Remove ALL)
**English**: um | uh | like | you know | so (sentence start) | well (sentence start)
**German**: äh | ähm | also (as filler) | sozusagen  
**French**: euh | ben | alors (as filler)
**Spanish**: eh | pues | este
**Italian**: eh | cioè (as filler)
**Dutch**: eh | nou
**Portuguese**: eh | né

**Rule**: Delete the filler word completely, then normalize spacing.

### 3. List Formatting (Auto-Detect)

**Numbered Lists** - When user says numbers or sequence words:
```
"1 apples 2 bananas 3 oranges" OR "first apples second bananas" →
1. Apples
2. Bananas
3. Oranges
```

Sequence words: first/second/third (EN), erstens/zweitens/drittens (DE), primero/segundo/tercero (ES), premier/deuxième (FR)

**Bullet Lists** - When user says "bullet point":
```
"bullet point feature A bullet point feature B" →
- Feature A
- Feature B
```

### 4. Punctuation
- Add periods at sentence boundaries
- Add commas for clauses
- Capitalize sentence starts
- Preserve technical terms (camelCase, snake_case, /api/paths)

### 5. Formatting

**Emails**:
```
Greeting,

[Body paragraphs]

[Closing],
[Name]
```

**Code/Technical**:
- Preserve: camelCase, PascalCase, snake_case, SCREAMING_CASE
- Format paths: /api/v2/users (lowercase with slashes)
- Keep acronyms: JWT, API, SQL, HTML

**Paragraphs**: Break at topic shifts ("Next", "Also", "Additionally")

## Output
Return ONLY the cleaned text. No explanations.]]
M.defaultTranscriptionApiBaseUrl = "https://api.openai.com/v1"  -- OpenAI API base URL
M.defaultTranscriptionModel = "whisper-1"  -- Standard OpenAI Whisper model
M.defaultCorrectionApiBaseUrl = "https://api.openai.com/v1"  -- OpenAI API base URL for corrections

-- Cloudflare Workers AI defaults (alternative provider)
-- To use Cloudflare: Set transcription/correction API base URL to: https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}
-- Recommended Cloudflare transcription model: @cf/openai/whisper-large-v3-turbo or @cf/openai/whisper
-- Recommended Cloudflare correction model: @cf/meta/llama-3.1-8b-instruct or @cf/qwen/qwen2.5-7b-instruct

local function trim(str)
    return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function sanitizeModel(model)
    if type(model) ~= "string" then return nil end
    model = trim(model)
    if model == "" then return nil end
    if #model > 128 then return nil end
    -- Allow common model id characters including @ for Cloudflare models (@cf/...), slashes for namespaced models (e.g., openai/whisper-large-v3-turbo)
    if not model:match("^[%w%._:%-/@]+$") then return nil end
    return model
end

local function sanitizePrompt(prompt)
    if type(prompt) ~= "string" then return nil end
    prompt = trim(prompt)
    if prompt == "" then return nil end
    -- Keep prompts reasonably sized for hs.settings
    if #prompt > 8000 then return nil end
    return prompt
end

function M.getApiKey()
    return settings.get(M.API_KEY_KEY)
end

function M.setApiKey(key)
    settings.set(M.API_KEY_KEY, key)
end

function M.getHotkey()
    local mods = settings.get(M.HOTKEY_MODS_KEY) or M.defaultHotkeyMods
    local key = settings.get(M.HOTKEY_KEY_KEY) or M.defaultHotkeyKey
    return mods, key
end

function M.setHotkey(mods, key)
    settings.set(M.HOTKEY_MODS_KEY, mods)
    settings.set(M.HOTKEY_KEY_KEY, key)
end

function M.getUseFnKey()
    local val = settings.get(M.USE_FN_KEY_KEY)
    if val == nil then return M.defaultUseFnKey end
    return val
end

function M.setUseFnKey(val)
    settings.set(M.USE_FN_KEY_KEY, val)
end

function M.getAutoPaste()
    local val = settings.get(M.AUTO_PASTE_KEY)
    if val == nil then return M.defaultAutoPaste end
    return val
end

function M.setAutoPaste(val)
    settings.set(M.AUTO_PASTE_KEY, val)
end

function M.getLanguage()
    return settings.get(M.LANGUAGE_KEY) or M.defaultLanguage
end

function M.setLanguage(lang)
    settings.set(M.LANGUAGE_KEY, lang)
end

function M.getRateLimitMaxRequests()
    return settings.get(M.RATE_LIMIT_MAX_KEY) or M.defaultRateLimitMax
end

function M.setRateLimitMaxRequests(max)
    settings.set(M.RATE_LIMIT_MAX_KEY, max)
end

function M.getRateLimitWindow()
    return settings.get(M.RATE_LIMIT_WINDOW_KEY) or M.defaultRateLimitWindow
end

function M.setRateLimitWindow(window)
    settings.set(M.RATE_LIMIT_WINDOW_KEY, window)
end

function M.getCorrectionEnabled()
    local val = settings.get(M.CORRECTION_ENABLED_KEY)
    if val == nil then return M.defaultCorrectionEnabled end
    return val and true or false
end

function M.setCorrectionEnabled(val)
    settings.set(M.CORRECTION_ENABLED_KEY, val and true or false)
end

function M.getCorrectionModel()
    local model = settings.get(M.CORRECTION_MODEL_KEY)
    model = sanitizeModel(model) or M.defaultCorrectionModel
    return model
end

function M.setCorrectionModel(model)
    local sanitized = sanitizeModel(model)
    if not sanitized then return false end
    settings.set(M.CORRECTION_MODEL_KEY, sanitized)
    return true
end

function M.getCorrectionSystemPrompt()
    -- First, try to get the prompt from user settings
    local userPrompt = settings.get(M.CORRECTION_SYSTEM_PROMPT_KEY)
    
    -- If user has set a prompt, sanitize and use it
    if userPrompt and type(userPrompt) == "string" and userPrompt ~= "" then
        local sanitized = sanitizePrompt(userPrompt)
        if sanitized then
            return sanitized
        end
    end
    
    -- Fall back to default prompt if no valid user prompt exists
    return M.defaultCorrectionSystemPrompt
end

function M.setCorrectionSystemPrompt(prompt)
    -- Allow empty/nil prompt to reset to default
    if not prompt or prompt == "" or (type(prompt) == "string" and trim(prompt) == "") then
        -- Clear the setting so getCorrectionSystemPrompt() falls back to default
        settings.set(M.CORRECTION_SYSTEM_PROMPT_KEY, nil)
        return true
    end
    
    -- Otherwise validate and set the custom prompt
    local sanitized = sanitizePrompt(prompt)
    if not sanitized then return false end
    settings.set(M.CORRECTION_SYSTEM_PROMPT_KEY, sanitized)
    return true
end

-- Glossary management (Whisper API prompt parameter)
function M.getGlossary()
    local glossary = settings.get(M.GLOSSARY_KEY)
    if type(glossary) ~= "string" then return "" end
    return trim(glossary)
end

function M.setGlossary(glossary)
    if type(glossary) ~= "string" then
        glossary = ""
    end
    glossary = trim(glossary)
    -- Limit to reasonable length (Whisper only uses first 224 tokens anyway)
    if #glossary > 2000 then
        glossary = glossary:sub(1, 2000)
    end
    settings.set(M.GLOSSARY_KEY, glossary)
    return true
end

-- API Base URLs and Model Configuration
local function sanitizeUrl(url)
    if type(url) ~= "string" then return nil end
    url = trim(url)
    if url == "" then return nil end
    -- Remove trailing slash for consistency
    url = url:gsub("/+$", "")
    -- Basic URL validation: must start with http:// or https://
    if not url:match("^https?://") then return nil end
    -- Length check
    if #url > 500 then return nil end
    return url
end

function M.getTranscriptionApiBaseUrl()
    local url = settings.get(M.TRANSCRIPTION_API_BASE_URL_KEY)
    url = sanitizeUrl(url) or M.defaultTranscriptionApiBaseUrl
    return url
end

function M.setTranscriptionApiBaseUrl(url)
    local sanitized = sanitizeUrl(url)
    if not sanitized then return false end
    settings.set(M.TRANSCRIPTION_API_BASE_URL_KEY, sanitized)
    return true
end

function M.getTranscriptionModel()
    local model = settings.get(M.TRANSCRIPTION_MODEL_KEY)
    model = sanitizeModel(model) or M.defaultTranscriptionModel
    return model
end

function M.setTranscriptionModel(model)
    local sanitized = sanitizeModel(model)
    if not sanitized then return false end
    settings.set(M.TRANSCRIPTION_MODEL_KEY, sanitized)
    return true
end

function M.getCorrectionApiBaseUrl()
    local url = settings.get(M.CORRECTION_API_BASE_URL_KEY)
    url = sanitizeUrl(url) or M.defaultCorrectionApiBaseUrl
    return url
end

function M.setCorrectionApiBaseUrl(url)
    local sanitized = sanitizeUrl(url)
    if not sanitized then return false end
    settings.set(M.CORRECTION_API_BASE_URL_KEY, sanitized)
    return true
end

return M
