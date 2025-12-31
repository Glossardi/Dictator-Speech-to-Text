local M = {}
local config = require("config")
local audio = require("audio")
local api = require("api")
local ui = require("ui")
local utils = require("utils")
local rateLimiter = require("rate_limiter")

-- Initialize logger
local log = hs.logger.new("Dictator", "info")
M.log = log

-- State management
M.isProcessing = false  -- Global flag to prevent concurrent operations
M.lastActionTime = 0  -- Track last action for debouncing
M.DEBOUNCE_DELAY = 0.5  -- Minimum 500ms between actions
M.MIN_RECORDING_DURATION = 0.4  -- Minimum duration in seconds to trigger transcription
M.recordingStartTime = nil
M.lastTranscription = nil  -- Store last successful transcription text

-- Initialize rate limiter
rateLimiter.init()

-- Initialize UI
ui.init()

log.i("Dictator initialized")

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
        { title = "Copy Last Transcription", disabled = (M.lastTranscription == nil), fn = function()
            if M.lastTranscription then
                hs.pasteboard.setContents(M.lastTranscription)
                hs.alert.show("Last transcription copied to clipboard")
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

-- Check if enough time has passed since last action (debouncing)
function M.canPerformAction()
    local now = hs.timer.secondsSinceEpoch()
    local timeSinceLastAction = now - M.lastActionTime
    
    if timeSinceLastAction < M.DEBOUNCE_DELAY then
        log.d(string.format("Debounce: Action blocked (%.2fs since last, need %.2fs)", 
            timeSinceLastAction, M.DEBOUNCE_DELAY))
        return false
    end
    
    M.lastActionTime = now
    return true
end

function M.startRecording()
    -- Debouncing: prevent rapid double-taps
    if not M.canPerformAction() then
        log.i("Start recording blocked by debounce")
        return
    end
    
    -- State guard: prevent concurrent operations
    if M.isProcessing then
        log.w("Start recording blocked: already processing")
        hs.alert.show("Already processing, please wait...")
        return
    end
    
    -- Check if already recording
    if audio.isRecording then
        log.w("Already recording")
        return
    end
    
    if audio.startRecording() then
        log.i("Recording started")
        M.recordingStartTime = hs.timer.secondsSinceEpoch()
        ui.updateStatus("recording", "Recording...")
    else
        log.e("Could not start recording")
        ui.showError("Could not start recording")
    end
end

function M.stopAndTranscribe()
    -- Debouncing: prevent rapid double-taps
    if not M.canPerformAction() then
        log.i("Stop recording blocked by debounce")
        return
    end
    
    -- State guard: prevent concurrent operations
    if M.isProcessing then
        log.w("Stop recording blocked: already processing")
        return
    end
    
    -- Check if not recording
    if not audio.isRecording then
        log.w("Not recording, cannot stop")
        return
    end
    
    -- Determine recording duration to ignore very short taps
    local now = hs.timer.secondsSinceEpoch()
    local duration = 0
    if M.recordingStartTime then
        duration = now - M.recordingStartTime
    end
    local isShortTap = duration > 0 and duration < M.MIN_RECORDING_DURATION

    if isShortTap then
        log.i(string.format("Recording too short (%.2fs), ignoring.", duration))
        ui.updateStatus("idle", "Ready")
    else
        M.isProcessing = true
        log.i("Stopping recording and starting transcription")
        ui.updateStatus("processing", "Processing...")
    end
    
    audio.stopRecording(function(filePath, err)
        -- Reset start time on every stop
        M.recordingStartTime = nil

        -- Watchdog: falls innerhalb von 35s kein Ergebnis zurückkommt, brechen wir sauber ab
        local timeoutTimer
        if not isShortTap then
            timeoutTimer = hs.timer.doAfter(35, function()
                if M.isProcessing then
                    M.isProcessing = false
                    log.e("Transcription timeout after 35 seconds")
                    ui.updateStatus("idle", "Timeout")
                    ui.showError("Transcription timeout: no response from API")
                end
            end)
        end

        if err then
            if not isShortTap then
                M.isProcessing = false
                log.e("Recording error: " .. err)
                ui.showError("Recording Error: " .. err)
                if timeoutTimer then timeoutTimer:stop() end
            end
            return
        end
        
        if not filePath then
            if not isShortTap then
                M.isProcessing = false
                log.e("No audio file generated")
                ui.showError("No audio file generated")
                if timeoutTimer then timeoutTimer:stop() end
            end
            return
        end

        -- For short taps: just clean up the file and return without API call or rate limiting
        if isShortTap then
            log.d("Short tap: deleting temp audio file and skipping transcription")
            os.remove(filePath)
            return
        end

        -- Check rate limiter before making API call
        local allowed, waitTime = rateLimiter.consumeToken()
        if not allowed then
            M.isProcessing = false
            local msg = string.format("Rate limit reached. Please wait %d seconds.", waitTime)
            log.w(msg)
            ui.showError(msg)
            os.remove(filePath)  -- Cleanup
            return
        end

        log.i("Sending audio to Whisper API")
        api.transcribe(filePath, function(text, apiErr)
            if timeoutTimer then timeoutTimer:stop() end
            M.isProcessing = false  -- Reset processing flag
            
            -- Cleanup temp file
            os.remove(filePath)

            if apiErr then
                log.e("API error: " .. apiErr)
                ui.showError("API Error: " .. apiErr)
                return
            end

            if text then
                log.i("Transcription successful (" .. #text .. " characters)")
                ui.updateStatus("idle", "Ready")
                
                -- Copy to clipboard
                hs.pasteboard.setContents(text)
                log.d("Text copied to clipboard: " .. string.sub(text, 1, 50) .. "...")
                -- Store last transcription for later retrieval via menu
                M.lastTranscription = text
                ui.setMenu(buildMenu())
                
                if config.getAutoPaste() then
                    -- Paste text with a slight delay to ensure focus
                    hs.timer.doAfter(0.3, function()
                        log.d("Auto-pasting text")
                        hs.eventtap.keyStroke({"cmd"}, "v", 0)
                    end)
                    ui.showNotification("Transcribed and Pasted!")
                else
                    ui.showNotification("Transcribed (Copied to Clipboard)")
                end
            else
                log.e("No text returned from API")
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
        log.d("Previous hotkey binding cleared")
    end
    if fnWatcher then 
        fnWatcher:stop()
        fnWatcher = nil
        log.d("Previous Fn key watcher stopped")
    end
    fnPressed = false  -- Reset state

    if config.getUseFnKey() then
        log.i("Binding Fn key for recording")
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
                        log.d("Fn key pressed")
                        M.startRecording()
                    end
                else
                    -- Fn key was just released
                    if audio.isRecording then
                        log.d("Fn key released")
                        M.stopAndTranscribe()
                    end
                end
            end
            
            -- Do NOT block the event
            return false
        end)
        
        local success = fnWatcher:start()
        if not success then
            log.e("Failed to start Fn key watcher - check Accessibility permissions!")
            hs.alert.show("Failed to start Fn key watcher. Check Accessibility permissions!")
        else
            log.i("Fn key watcher started successfully")
        end
    else
        -- Standard Hotkey Fallback
        local mods, key = config.getHotkey()
        log.i("Binding hotkey: " .. table.concat(mods, "+") .. "+" .. key)
        hotkeyObject = hs.hotkey.bind(mods, key, 
            function() -- Pressed
                log.d("Hotkey pressed")
                M.startRecording()
            end,
            function() -- Released
                log.d("Hotkey released")
                M.stopAndTranscribe()
            end
        )
        
        if hotkeyObject then
            log.i("Hotkey bound successfully")
        else
            log.e("Failed to bind hotkey!")
            hs.alert.show("Failed to bind hotkey!")
        end
    end
end

M.bindHotkey()

return M
