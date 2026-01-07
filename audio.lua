-- audio.lua
-- Audio recording via SoX (FLAC format, 16kHz mono for optimal Whisper performance)

local M = {}
local utils = require("utils")
local config = require("config")

M.isRecording = false
M.currentTask = nil
M.currentFilePath = nil

function M.startRecording()
    if M.isRecording then return end
    
    M.currentFilePath = utils.get_temp_file_path("flac")
    print("Starting recording to: " .. M.currentFilePath)
    
    -- Using 'rec' from SoX with FLAC output (lossless, 50% smaller than WAV)
    -- FLAC is natively supported by SoX and perfect for Whisper API
    -- Arguments: output_file, then effects (rate, channels, compression)
    local soxPath = "/opt/homebrew/bin/rec" -- Standard brew path on Apple Silicon
    if not utils.file_exists(soxPath) then
        soxPath = "/usr/local/bin/rec" -- Intel Mac
    end
    if not utils.file_exists(soxPath) then
        -- Fallback or error
        hs.alert.show("SoX (rec) not found! Please run 'brew install sox'")
        return false
    end

    M.currentTask = hs.task.new(soxPath, function(exitCode, stdOut, stdErr)
        print("Recording finished. Exit code: " .. exitCode)
        if exitCode ~= 0 and exitCode ~= -1 then -- -1 is terminated
             print("SoX Error: " .. stdErr)
        end
    end, {M.currentFilePath, "rate", "16k", "channels", "1"})
    
    if M.currentTask:start() then
        M.isRecording = true
        return true
    else
        hs.alert.show("Failed to start recording")
        return false
    end
end

function M.stopRecording(callback)
    if not M.isRecording or not M.currentTask then
        if callback then callback(nil, "Not recording") end
        return
    end

    local filePath = M.currentFilePath
    M.currentTask:terminate()
    M.isRecording = false
    M.currentTask = nil
    
    -- Give file system a brief moment to flush and close the FLAC file
    -- This ensures the file is fully written before we try to upload it
    hs.timer.doAfter(0.1, function()
        if callback then callback(filePath, nil) end
    end)
end

return M
