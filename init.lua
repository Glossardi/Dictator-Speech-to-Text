local M = {}
local config = require("config")
local audio = require("audio")
local api = require("api")
local ui = require("ui")
local utils = require("utils")

-- Initialize UI
ui.init()

-- Menu Definition
local function buildMenu()
    local apiKey = config.getApiKey()
    local apiKeyDisplay = apiKey and (string.sub(apiKey, 1, 4) .. "..." .. string.sub(apiKey, -4)) or "Not Set"
    local mods, key = config.getHotkey()
    if type(mods) ~= "table" then mods = {"cmd", "alt"} end -- Safety fallback
    local hotkeyDisplay = table.concat(mods, "+") .. "+" .. key
    local lang = config.getLanguage()
    local autoPaste = config.getAutoPaste()
    local useFnKey = config.getUseFnKey()

    return {
        { title = "Status: " .. ui.currentStatus:upper(), disabled = true },
        { title = "-" },
        { title = "Start/Stop Recording", fn = function() M.toggleRecording() end },
        { title = "-" },
        { title = "Settings", disabled = true },
        { title = "  API Key: " .. apiKeyDisplay, fn = function() 
            local button, text = hs.dialog.textPrompt("OpenAI API Key", "Enter your OpenAI API Key:", apiKey or "", "OK", "Cancel")
            if button == "OK" then
                config.setApiKey(text)
                hs.alert.show("API Key Saved")
                ui.setMenu(buildMenu()) -- Refresh menu
            end
        end },
        { title = "  Language: " .. lang, fn = function()
             local button, text = hs.dialog.textPrompt("Language", "Enter language code (e.g. 'en', 'de', 'auto'):", lang, "OK", "Cancel")
             if button == "OK" then
                 config.setLanguage(text)
                 hs.alert.show("Language Saved")
                 ui.setMenu(buildMenu())
             end
        end },
        { title = "  Auto-Paste", checked = autoPaste, fn = function()
            config.setAutoPaste(not autoPaste)
            ui.setMenu(buildMenu())
        end },
        { title = "  Use Fn Key (Hold)", checked = useFnKey, fn = function()
            config.setUseFnKey(not useFnKey)
            M.bindHotkey() -- Rebind
            ui.setMenu(buildMenu())
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
                    M.bindHotkey()
                    hs.alert.show("Hotkey Saved: " .. table.concat(newMods, "+") .. "+" .. newKey)
                    ui.setMenu(buildMenu())
                else
                    hs.alert.show("Invalid format. Use 'mod1 mod2 key'")
                end
            end
        end },
        { title = "-" },
        { title = "Reload Config", fn = hs.reload },
        { title = "Quit", fn = function() M.menubarItem:delete() end } -- Actually just removes item, HS stays open
    }
end

ui.setMenu(buildMenu()) -- Pass table directly to avoid dynamic function issues

-- Recording Logic
function M.toggleRecording()
    if audio.isRecording then
        M.stopAndTranscribe()
    else
        M.startRecording()
    end
end

function M.startRecording()
    if audio.startRecording() then
        ui.updateStatus("recording", "Recording...")
    else
        ui.showError("Could not start recording")
    end
end

function M.stopAndTranscribe()
    ui.updateStatus("processing", "Processing...")
    audio.stopRecording(function(filePath, err)
        if err then
            ui.showError("Recording Error: " .. err)
            return
        end
        
        if not filePath then
            ui.showError("No audio file generated")
            return
        end

        api.transcribe(filePath, function(text, apiErr)
            -- Cleanup temp file
            os.remove(filePath)

            if apiErr then
                ui.showError("API Error: " .. apiErr)
                return
            end

            if text then
                ui.updateStatus("idle", "Ready")
                
                -- Copy to clipboard
                hs.pasteboard.setContents(text)
                print("Text copied to clipboard: " .. string.sub(text, 1, 50) .. "...")
                
                if config.getAutoPaste() then
                    -- Paste text with a slight delay to ensure focus
                    -- Using doAfter to give time for the application to regain focus
                    hs.timer.doAfter(0.3, function()
                        print("Auto-pasting text...")
                        -- Simulate Cmd+V keypress
                        hs.eventtap.keyStroke({"cmd"}, "v", 0)
                    end)
                    ui.showNotification("Transcribed and Pasted!")
                else
                    ui.showNotification("Transcribed (Copied to Clipboard)")
                end
            else
                ui.showError("No text returned")
            end
        end)
    end)
end

-- Hotkey Setup
local hotkeyObject = nil
local fnWatcher = nil
local fnPressed = false  -- Track Fn key state

function M.bindHotkey()
    -- Clear existing bindings
    if hotkeyObject then 
        hotkeyObject:delete()
        hotkeyObject = nil
    end
    if fnWatcher then 
        fnWatcher:stop()
        fnWatcher = nil
    end
    fnPressed = false  -- Reset state

    if config.getUseFnKey() then
        -- Fn Key Listener using Eventtap
        fnWatcher = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(event)
            local flags = event:getFlags()
            local currentFnState = flags.fn and true or false
            
            -- Only act if Fn state has changed
            if currentFnState ~= fnPressed then
                fnPressed = currentFnState
                
                if fnPressed then
                    -- Fn key was just pressed
                    if not audio.isRecording then
                        print("Fn key pressed - starting recording")
                        M.startRecording()
                    end
                else
                    -- Fn key was just released
                    if audio.isRecording then
                        print("Fn key released - stopping recording")
                        M.stopAndTranscribe()
                    end
                end
            end
            
            -- Do NOT block the event
            return false
        end)
        
        local success = fnWatcher:start()
        if not success then
            hs.alert.show("Failed to start Fn key watcher. Check Accessibility permissions!")
            print("ERROR: Failed to start Fn key eventtap. Accessibility permissions may not be enabled.")
        else
            print("Fn key watcher started successfully")
        end
    else
        -- Standard Hotkey Fallback
        local mods, key = config.getHotkey()
        print("Binding hotkey: " .. table.concat(mods, "+") .. "+" .. key)
        hotkeyObject = hs.hotkey.bind(mods, key, 
            function() -- Pressed
                print("Hotkey pressed - starting recording")
                M.startRecording()
            end,
            function() -- Released
                print("Hotkey released - stopping recording")
                M.stopAndTranscribe()
            end
        )
        
        if hotkeyObject then
            print("Hotkey bound successfully")
        else
            hs.alert.show("Failed to bind hotkey!")
            print("ERROR: Failed to bind hotkey")
        end
    end
end

M.bindHotkey()

return M
