-- init.lua
-- Main entry point for Dictator - Voice-to-Text menubar app
-- Handles recording lifecycle, menubar UI, hotkey bindings, and orchestrates
-- the transcription + correction pipeline with fail-open behavior

-- Load IPC module for command line interface support
require("hs.ipc")

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
M.lastOriginalTranscription = nil  -- Store original transcription (before correction)
M.currentContext = nil  -- Store context (app, window title, etc.) for AI correction
M.processingStartTime = nil  -- Track when processing started
M.MAX_PROCESSING_TIME = 90  -- Maximum allowed processing time in seconds
M.previousAudioFilePath = nil  -- Track previous audio file for cleanup

-- Initialize rate limiter
rateLimiter.init()

-- Initialize UI
ui.init(M)

log.i("Dictator initialized")

-- Global watchdog to detect stuck processing state
-- Checks every 10 seconds if processing has been active for too long
M.watchdogTimer = hs.timer.doEvery(10, function()
    if M.isProcessing and M.processingStartTime then
        local elapsed = hs.timer.secondsSinceEpoch() - M.processingStartTime
        if elapsed > M.MAX_PROCESSING_TIME then
            log.e(string.format("WATCHDOG: Processing stuck for %.0fs, forcing reset", elapsed))
            M.isProcessing = false
            M.processingStartTime = nil
            ui.updateStatus("error", "Processing timeout - please try again")
            hs.alert.show("Processing timeout detected. You can record again now.")
        end
    end
end)

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

    -- Capture context at start of recording if enabled
    M.currentContext = nil
    if config.getContextAwarenessEnabled() then
        -- Immediately capture focused element to avoid losing it during hotkey processing
        local systemWide = hs.axuielement.systemWideElement()
        local focusedAtStart = systemWide:attributeValue("AXFocusedUIElement")
        
        -- Run context capture in a background timer to avoid delaying recording start
        hs.timer.doAfter(0.01, function()
            log.i("Capturing context awareness in background...")
            local ctx = utils.getCurrentContext(focusedAtStart)
            if ctx and ctx ~= "" then
                M.currentContext = ctx
                log.i("Context captured:\n" .. M.currentContext)
            else
                log.w("Context awareness enabled but no context captured")
            end
        end)
    end
    
    -- Check if already recording
    if audio.isRecording then
        log.w("Already recording")
        return
    end
    
    -- Cleanup previous audio file before starting new recording
    -- Ensures user always has the latest audio file in case of issues
    if M.previousAudioFilePath and utils.file_exists(M.previousAudioFilePath) then
        log.d("Cleaning up previous audio file: " .. M.previousAudioFilePath)
        os.remove(M.previousAudioFilePath)
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
        M.processingStartTime = hs.timer.secondsSinceEpoch()  -- Track when processing started
        log.i("Stopping recording and starting transcription")
        ui.updateStatus("processing", "Processing...")
    end
    
    audio.stopRecording(function(filePath, err)
        -- Reset start time on every stop
        M.recordingStartTime = nil

        -- Watchdog: falls innerhalb von 90s kein Ergebnis zurückkommt, brechen wir sauber ab
        -- Erhöht von 35s auf 90s, um längere Transkriptionen + KI-Korrekturen zu ermöglichen
        local timeoutTimer
        if not isShortTap then
            timeoutTimer = hs.timer.doAfter(90, function()
                if M.isProcessing then
                    M.isProcessing = false
                    log.e("Transcription timeout after 90 seconds")
                    ui.updateStatus("idle", "Timeout")
                    ui.showError("Transcription timeout: no response from API")
                end
            end)
        end

        -- Validate file exists and log size for diagnosis
        if not err and filePath and utils.file_exists(filePath) then
            local size = utils.get_file_size(filePath) or 0
            local duration = 0
            if M.recordingStartTime then
                duration = hs.timer.secondsSinceEpoch() - M.recordingStartTime
            end
            
            -- Theoretical minimum size for MP3 VBR -V 4 at 16k mono is ~10-12KB/s
            -- 30s recording should be at least 300KB.
            if duration > 10 and size < 1024 * 30 then
                log.w(string.format("WARNING: File size (%.1f KB) suspiciously small for duration (%.1f s)", size/1024, duration))
            end
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
            log.d("Short tap: skipping transcription")
            M.previousAudioFilePath = filePath
            return
        end

        -- Check rate limiter before making API call
        local allowed, waitTime = rateLimiter.consumeToken()
        if not allowed then
            M.isProcessing = false
            local msg = string.format("Rate limit reached. Please wait %d seconds.", waitTime)
            log.w(msg)
            ui.showError(msg)
            M.previousAudioFilePath = filePath -- Keep for next cleanup
            return
        end

        -- Store current file path for cleanup on next recording
        M.previousAudioFilePath = filePath
        
        log.i("Sending audio to Whisper API")
        log.d(string.format("Audio file stored for cleanup: %s", filePath))
        api.transcribe(filePath, function(text, apiErr)
            if timeoutTimer then timeoutTimer:stop() end
            
            -- Log text length for debugging the ~1400-1500 character issue
            if text then
                log.d(string.format("Transcription received: %d characters", #text))
                if #text > 1300 and #text < 1600 then
                    log.w(string.format("TRUNCATION CHECK: Received text is %d chars (between 1300-1600 range)", #text))
                end
            end
            
            -- DO NOT remove file here. It will be removed when the next recording starts.
            -- This allows the user to recover the file if the transcription fails.

            if apiErr then
                M.isProcessing = false  -- Reset processing flag
                log.e("API error: " .. apiErr)
                ui.showError("API Error: " .. apiErr)
                return
            end

            if not text or text == "" then
                M.isProcessing = false  -- Reset processing flag
                log.e("No text returned from API")
                ui.showError("No text returned")
                return
            end

            -- Validate transcription output to prevent garbage responses
            local isValid, validationError = utils.validateTranscriptionOutput(text)
            if not isValid then
                M.isProcessing = false
                log.e("Invalid transcription output: " .. (validationError or "unknown"))
                ui.showError("⚠️ " .. (validationError or "Ungültige Antwort") .. "\n\nBitte starte die Aufnahme erneut oder starte die App neu, falls das Problem weiterhin besteht.")
                return
            end

            -- Store original transcription immediately after Whisper API
            M.lastOriginalTranscription = text

            local function finalize(finalText)
                M.isProcessing = false
                M.processingStartTime = nil  -- Reset processing timer
                log.i("Transcription successful (" .. #finalText .. " characters)")
                ui.updateStatus("idle", "Ready")

                -- Copy to clipboard
                -- Using a newline followed by a Zero Width Space (U+200B)
                -- This often tricks apps into not sending because the line isn't "empty" or "just a newline"
                local textToPaste = finalText .. "\n" .. "\226\128\139"
                hs.pasteboard.setContents(textToPaste)
                log.d("Text copied to clipboard: " .. string.sub(textToPaste, 1, 50) .. "...")

                -- Store last transcription for later retrieval via menu
                M.lastTranscription = finalText
                ui.refresh()

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
            end

            if config.getCorrectionEnabled() then
                log.i(string.format("AI correction enabled - correcting text (%d chars)", #text))
                log.d("Correction Input: \"" .. text .. "\"")
                ui.updateStatus("processing_ai", "Processing AI...")
                api.correctText(text, function(correctedText, correctionErr)
                    if correctionErr or type(correctedText) ~= "string" or correctedText == "" then
                        log.w("AI correction failed, falling back to raw transcription: " .. tostring(correctionErr))
                        finalize(text)
                    else
                        -- Validate AI-corrected output as well
                        local isValidCorrected, validationErrorCorrected = utils.validateTranscriptionOutput(correctedText)
                        if not isValidCorrected then
                            log.w("AI correction produced invalid output, falling back to raw transcription: " .. (validationErrorCorrected or "unknown"))
                            finalize(text)
                        else
                            log.i(string.format("AI correction successful (diff: %d chars)", #correctedText - #text))
                            log.d("Correction Output: \"" .. correctedText .. "\"")
                            finalize(correctedText)
                        end
                    end
                end, M.currentContext)
            else
                finalize(text)
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
