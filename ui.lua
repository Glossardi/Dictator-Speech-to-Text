-- ui.lua
-- Menubar UI management and status indicators

local M = {}
local config = require("config")

M.menubarItem = nil
M.currentStatus = "idle" -- idle, recording, processing, processing_ai, error
M.mainModule = nil

-- Simple ASCII icons or text for now. Can be replaced with images.
M.icons = {
    idle = "🎙️",
    recording = "🔴",
    processing = "⏳",
    processing_ai = "🤖",
    error = "⚠️"
}

function M.init(mainModule)
    M.mainModule = mainModule
    M.menubarItem = hs.menubar.new()
    M.updateStatus("idle")
    M.refresh()
end

function M.refresh()
    if M.menubarItem then
        M.menubarItem:setMenu(M.buildMenu())
    end
end

function M.updateStatus(status, tooltip)
    M.currentStatus = status
    if M.menubarItem then
        M.menubarItem:setTitle(M.icons[status] or M.icons.idle)
        M.menubarItem:setTooltip(tooltip or "Menubar Dictation")
    end
end

function M.setMenu(menuTable)
    if M.menubarItem then
        M.menubarItem:setMenu(menuTable)
    end
end

function M.buildMenu()
    if not M.mainModule then return {} end
    local main = M.mainModule
    
    local apiKey = config.getApiKey()
    local apiKeyDisplay = apiKey and (string.sub(apiKey, 1, 4) .. "..." .. string.sub(apiKey, -4)) or "Not Set"
    local mods, key = config.getHotkey()
    if type(mods) ~= "table" then mods = {"cmd", "alt"} end -- Safety fallback
    local hotkeyDisplay = table.concat(mods, "+") .. "+" .. key
    local lang = config.getLanguage()
    local autoPaste = config.getAutoPaste()
    local useFnKey = config.getUseFnKey()
    local correctionEnabled = config.getCorrectionEnabled()
    local correctionModel = config.getCorrectionModel()
    local transcriptionApiBaseUrl = config.getTranscriptionApiBaseUrl()
    local transcriptionModel = config.getTranscriptionModel()
    local correctionApiBaseUrl = config.getCorrectionApiBaseUrl()

    return {
        { title = "Status: " .. M.currentStatus:upper(), disabled = true },
        { title = "-" },
        { title = "Start/Stop Recording", fn = function() main.toggleRecording() end },
        { title = "Copy Last Transcription", disabled = (main.lastOriginalTranscription == nil), fn = function()
            if main.lastOriginalTranscription then
                hs.pasteboard.setContents(main.lastOriginalTranscription)
                hs.alert.show("Original transcription copied to clipboard")
            else
                hs.alert.show("No transcription available yet")
            end
        end },
        { title = "-" },
        { title = "Settings", disabled = true },
        { title = "  API Key: " .. apiKeyDisplay, fn = function() 
            local button, text = hs.dialog.textPrompt("OpenAI API Key", "Enter your OpenAI API Key:", apiKey or "", "OK", "Cancel")
            if button == "OK" then
                config.setApiKey(text)
                hs.alert.show("API Key Saved")
                M.refresh()
            end
        end },
        { title = "  Language: " .. lang, fn = function()
             local button, text = hs.dialog.textPrompt("Language", "Enter language code (e.g. 'en', 'de', 'auto'):", lang, "OK", "Cancel")
             if button == "OK" then
                 config.setLanguage(text)
                 hs.alert.show("Language Saved")
                 M.refresh()
             end
        end },
        { title = "  Transcription API Settings", menu = {
            { title = "Set API Base URL...", fn = function()
                local current = transcriptionApiBaseUrl
                local button, text = hs.dialog.textPrompt(
                    "Transcription API Base URL",
                    "Enter base URL (without /audio/transcriptions):\\n\\nExamples:\\n- OpenAI: https://api.openai.com/v1\\n- DeepInfra: https://api.deepinfra.com/v1/openai",
                    current,
                    "Save",
                    "Cancel"
                )
                if button == "Save" then
                    local ok = config.setTranscriptionApiBaseUrl(text)
                    if ok then
                        hs.alert.show("Transcription API URL saved")
                        M.refresh()
                    else
                        hs.alert.show("Invalid URL format")
                    end
                end
            end },
            { title = "Set Model... (" .. transcriptionModel .. ")", fn = function()
                local button, text = hs.dialog.textPrompt(
                    "Transcription Model",
                    "Enter model name:\\n\\nExamples:\\n- OpenAI: whisper-1\\n- DeepInfra: openai/whisper-large-v3-turbo",
                    transcriptionModel,
                    "Save",
                    "Cancel"
                )
                if button == "Save" then
                    local ok = config.setTranscriptionModel(text)
                    if ok then
                        hs.alert.show("Transcription model saved")
                        M.refresh()
                    else
                        hs.alert.show("Invalid model name")
                    end
                end
            end },
            { title = "Set Dedicated API Key...", fn = function()
                local current = config.getTranscriptionApiKey()
                -- If it's the same as global key, it might be inherited
                local isInherited = (current == config.getApiKey())
                local promptValue = isInherited and "" or current
                
                local button, text = hs.dialog.textPrompt(
                    "Transcription Dedicated API Key",
                    "Enter dedicated API key for Whisper (leave empty to use global key):",
                    promptValue,
                    "Save",
                    "Cancel"
                )
                if button == "Save" then
                    config.setTranscriptionApiKey(text)
                    hs.alert.show("Transcription API key saved")
                    M.refresh()
                end
            end }
        } },
        { title = "  Edit Glossary...", fn = function()
             local currentGlossary = config.getGlossary()
             local button, text = hs.dialog.textPrompt(
                 "Dictator Glossary", 
                 "Enter context words, comma-separated (max ~200 words):\\nUsed to improve recognition of technical terms, names, etc.", 
                 currentGlossary, 
                 "Save", 
                 "Cancel"
             )
             if button == "Save" then
                 config.setGlossary(text)
                 hs.alert.show("Glossary Saved")
                 M.refresh()
             end
        end },
        { title = "  Auto-Paste", checked = autoPaste, fn = function()
            config.setAutoPaste(not autoPaste)
            M.refresh()
        end },
        { title = "  Enable AI Correction", checked = correctionEnabled, fn = function()
            config.setCorrectionEnabled(not correctionEnabled)
            M.refresh()
        end },
        { title = "  Correction Settings", disabled = (not correctionEnabled), menu = {
            { title = "Set API Base URL...", fn = function()
                local current = correctionApiBaseUrl
                local button, text = hs.dialog.textPrompt(
                    "Correction API Base URL",
                    "Enter base URL (without /chat/completions):\\n\\nExamples:\\n- OpenAI: https://api.openai.com/v1\\n- DeepInfra: https://api.deepinfra.com/v1/openai",
                    current,
                    "Save",
                    "Cancel"
                )
                if button == "Save" then
                    local ok = config.setCorrectionApiBaseUrl(text)
                    if ok then
                        hs.alert.show("Correction API URL saved")
                        M.refresh()
                    else
                        hs.alert.show("Invalid URL format")
                    end
                end
            end },
            { title = "Set Model... (" .. correctionModel .. ")", fn = function()
                local button, text = hs.dialog.textPrompt("Correction Model", "Enter model id (e.g. 'gpt-4o-mini', 'gpt-4o'):", correctionModel, "OK", "Cancel")
                if button == "OK" then
                    local ok = config.setCorrectionModel(text)
                    if ok then
                        hs.alert.show("Correction model saved")
                        M.refresh()
                    else
                        hs.alert.show("Invalid model id")
                    end
                end
            end },
            { title = "Set System Prompt...", fn = function()
                local current = config.getCorrectionSystemPrompt()
                local button, text = hs.dialog.textPrompt("Correction System Prompt", "Enter system prompt for correction:", current, "OK", "Cancel")
                if button == "OK" then
                    local ok = config.setCorrectionSystemPrompt(text)
                    if ok then
                        hs.alert.show("System prompt saved")
                        M.refresh()
                    else
                        hs.alert.show("Invalid prompt")
                    end
                end
            end },
            { title = "Set Dedicated API Key...", fn = function()
                local current = config.getCorrectionApiKey()
                local isInherited = (current == config.getApiKey())
                local promptValue = isInherited and "" or current

                local button, text = hs.dialog.textPrompt(
                    "Correction Dedicated API Key",
                    "Enter dedicated API key for Correction (leave empty to use global key):",
                    promptValue,
                    "Save",
                    "Cancel"
                )
                if button == "Save" then
                    config.setCorrectionApiKey(text)
                    hs.alert.show("Correction API key saved")
                    M.refresh()
                end
            end }
        } },
        { title = "  Use Fn Key (Hold)", checked = useFnKey, fn = function()
            config.setUseFnKey(not useFnKey)
            main.bindHotkey() -- Rebind
            M.refresh()
        end },
        { title = "  Set Custom Hotkey (" .. hotkeyDisplay .. ")", disabled = useFnKey, fn = function()
            local button, text = hs.dialog.textPrompt("Set Hotkey", "Enter modifiers and key separated by space (e.g. 'cmd alt D'):", table.concat(mods, " ") .. " " .. key, "OK", "Cancel")
            if button == "OK" then
                local parts = {}
                for part in string.gmatch(text, "%S+") do
                    table.insert(parts, part)
                end
                if #parts >= 2 then
                    local newKey = table.remove(parts) -- Last part is the key
                    local newMods = parts -- Remaining are mods
                    config.setHotkey(newMods, newKey)
                    main.bindHotkey()
                    hs.alert.show("Hotkey Saved: " .. table.concat(newMods, "+") .. "+" .. newKey)
                    M.refresh()
                else
                    hs.alert.show("Invalid format. Use 'mod1 mod2 key'")
                end
            end
        end },
        { title = "-" },
        { title = "Update Dictator...", fn = function()
            local installPath = config.getInstallPath() or (os.getenv("HOME") .. "/Documents/Dictator")
            local scriptPath = installPath .. "/update.sh"
            
            -- Check if file exists
            if hs.fs.attributes(scriptPath) then
                hs.alert.show("Opening Terminal to update...")
                local appleScript = string.format([[
                    tell application "Terminal"
                        do script "cd '%s' && chmod +x update.sh && ./update.sh"
                        activate
                    end tell
                ]], installPath)
                hs.osascript.applescript(appleScript)
            else
                hs.alert.show("Update script not found at: " .. installPath)
                hs.logger.new("Dictator", "info").e("Update failed: Script not found at " .. scriptPath)
            end
        end },
        { title = "Reload Config", fn = hs.reload },
        { title = "Quit", fn = function() M.menubarItem:delete() end } -- Actually just removes item, HS stays open
    }
end

function M.showNotification(message)
    hs.notify.new({title="Dictator", informativeText=message}):send()
end

function M.showError(message)
    M.updateStatus("error", message)
    hs.alert.show(message)
end

return M
