-- audio.lua
-- Audio recording via SoX (FLAC format, 16kHz mono for optimal Whisper performance)

local M = {}
local utils = require("utils")
local config = require("config")

M.isRecording = false
M.currentTask = nil
M.currentFilePath = nil
M.pendingCallback = nil  -- Retain timer to prevent GC

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
    local pid = M.currentTask:pid()
    
    -- Try to stop SoX gracefully with SIGINT (kill -2)
    -- This ensures FLAC headers are written correctly for long recordings
    if pid then
        os.execute("kill -2 " .. pid)
        -- Give it a tiny moment to exit through SIGINT before forced termination
        hs.timer.doAfter(0.2, function()
            if M.currentTask and M.currentTask:isRunning() then
                M.currentTask:terminate()
            end
        end)
    else
        M.currentTask:terminate()
    end
    
    M.isRecording = false
    M.currentTask = nil
    
    -- Give file system a moment to flush and close the FLAC file
    -- This ensures the file is fully written before we try to upload it
    M.pendingCallback = hs.timer.doAfter(0.5, function() -- Increased from 0.1 to 0.5 for stability
        M.pendingCallback = nil
        
        -- Validate file exists and log size for diagnosis
        if utils.file_exists(filePath) then
            local size = utils.get_file_size(filePath) or 0
            print(string.format("Recording saved: %s (%.2f KB)", filePath, size / 1024))
            if size == 0 then
                if callback then callback(nil, "Audio file is empty") end
                return
            end
        else
            print("ERROR: Recording file missing after stop: " .. tostring(filePath))
            if callback then callback(nil, "File not found after recording") end
            return
        end
        
        if callback then callback(filePath, nil) end
    end)
end

return M
