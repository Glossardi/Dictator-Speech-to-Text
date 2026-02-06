-- config.lua
-- Configuration management and persistent settings via hs.settings
-- Handles API keys, hotkeys, correction settings, and user preferences

local M = {}
local settings = hs.settings
local defaults = require("config_defaults")

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
M.CONTEXT_AWARENESS_ENABLED_KEY = M.BUNDLE_ID .. ".contextAwarenessEnabled"
M.CORRECTION_MODEL_KEY = M.BUNDLE_ID .. ".correctionModel"
M.CORRECTION_SYSTEM_PROMPT_KEY = M.BUNDLE_ID .. ".correctionSystemPrompt"
M.GLOSSARY_KEY = M.BUNDLE_ID .. ".userGlossary"
M.TRANSCRIPTION_API_BASE_URL_KEY = M.BUNDLE_ID .. ".transcriptionApiBaseUrl"
M.TRANSCRIPTION_MODEL_KEY = M.BUNDLE_ID .. ".transcriptionModel"
M.TRANSCRIPTION_API_KEY_KEY = M.BUNDLE_ID .. ".transcriptionApiKey"
M.CORRECTION_API_BASE_URL_KEY = M.BUNDLE_ID .. ".correctionApiBaseUrl"
M.CORRECTION_API_KEY_KEY = M.BUNDLE_ID .. ".correctionApiKey"
M.INSTALL_PATH_KEY = M.BUNDLE_ID .. ".installPath"

-- Defaults
M.defaultHotkeyMods = defaults.defaultHotkeyMods
M.defaultHotkeyKey = defaults.defaultHotkeyKey
M.defaultUseFnKey = defaults.defaultUseFnKey
M.defaultAutoPaste = defaults.defaultAutoPaste
M.defaultLanguage = defaults.defaultLanguage
M.defaultRateLimitMax = defaults.defaultRateLimitMax
M.defaultRateLimitWindow = defaults.defaultRateLimitWindow
M.defaultCorrectionEnabled = defaults.defaultCorrectionEnabled
M.defaultContextAwarenessEnabled = defaults.defaultContextAwarenessEnabled
M.defaultCorrectionModel = defaults.defaultCorrectionModel
M.defaultCorrectionSystemPrompt = defaults.defaultCorrectionSystemPrompt
M.defaultTranscriptionApiBaseUrl = defaults.defaultTranscriptionApiBaseUrl
M.defaultTranscriptionModel = defaults.defaultTranscriptionModel
M.defaultCorrectionApiBaseUrl = defaults.defaultCorrectionApiBaseUrl

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

function M.getTranscriptionApiKey()
    local key = settings.get(M.TRANSCRIPTION_API_KEY_KEY)
    if key and key ~= "" then return key end
    return M.getApiKey()
end

function M.setTranscriptionApiKey(key)
    if key == "" then key = nil end
    settings.set(M.TRANSCRIPTION_API_KEY_KEY, key)
end

function M.getCorrectionApiKey()
    local key = settings.get(M.CORRECTION_API_KEY_KEY)
    if key and key ~= "" then return key end
    -- Fallback to dedicated transcription key if available, which itself falls back to global
    return M.getTranscriptionApiKey()
end

function M.setCorrectionApiKey(key)
    if key == "" then key = nil end
    settings.set(M.CORRECTION_API_KEY_KEY, key)
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

function M.getContextAwarenessEnabled()
    local val = settings.get(M.CONTEXT_AWARENESS_ENABLED_KEY)
    if val == nil then return M.defaultContextAwarenessEnabled end
    return val and true or false
end

function M.setContextAwarenessEnabled(val)
    settings.set(M.CONTEXT_AWARENESS_ENABLED_KEY, val and true or false)
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
    url = sanitizeUrl(url)
    if url then return url end
    
    -- Fallback to transcription URL if no dedicated correction URL is set
    return M.getTranscriptionApiBaseUrl()
end

function M.setCorrectionApiBaseUrl(url)
    if url == "" then
        settings.set(M.CORRECTION_API_BASE_URL_KEY, nil)
        return true
    end
    local sanitized = sanitizeUrl(url)
    if not sanitized then return false end
    settings.set(M.CORRECTION_API_BASE_URL_KEY, sanitized)
    return true
end

function M.setInstallPath(path)
    settings.set(M.INSTALL_PATH_KEY, path)
end

function M.getInstallPath()
    return settings.get(M.INSTALL_PATH_KEY)
end

return M
