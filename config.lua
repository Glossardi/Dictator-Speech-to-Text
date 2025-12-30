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

-- Defaults
M.defaultHotkeyMods = {"cmd", "alt"}
M.defaultHotkeyKey = "D"
M.defaultUseFnKey = true
M.defaultAutoPaste = true
M.defaultLanguage = "auto"

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

return M
