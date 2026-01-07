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

-- Defaults
M.defaultHotkeyMods = {"cmd", "alt"}
M.defaultHotkeyKey = "D"
M.defaultUseFnKey = true
M.defaultAutoPaste = true
M.defaultLanguage = "auto"
M.defaultRateLimitMax = 3  -- 3 requests
M.defaultRateLimitWindow = 60  -- per 60 seconds (1 minute)
M.defaultCorrectionEnabled = false
M.defaultCorrectionModel = "gpt-4o-mini"  -- Fast, stable, <2s typical latency
M.defaultCorrectionSystemPrompt = [[Correct spelling, punctuation, and grammar. Remove filler words, stutters, and resolve self-corrections (keep the final intended meaning). Strictly maintain the original language(s). Apply logical formatting and paragraphs based on the text's semantic structure (e.g., email layout, lists, code blocks, or standard prose). Do not add content or summarize. Output ONLY the cleaned text.]]

local function trim(str)
    return (str:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function sanitizeModel(model)
    if type(model) ~= "string" then return nil end
    model = trim(model)
    if model == "" then return nil end
    if #model > 128 then return nil end
    -- Allow common OpenAI model id characters
    if not model:match("^[%w%._:%-]+$") then return nil end
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
    local prompt = settings.get(M.CORRECTION_SYSTEM_PROMPT_KEY)
    prompt = sanitizePrompt(prompt) or M.defaultCorrectionSystemPrompt
    return prompt
end

function M.setCorrectionSystemPrompt(prompt)
    local sanitized = sanitizePrompt(prompt)
    if not sanitized then return false end
    settings.set(M.CORRECTION_SYSTEM_PROMPT_KEY, sanitized)
    return true
end

return M
