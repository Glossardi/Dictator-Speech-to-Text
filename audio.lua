-- audio.lua
-- Audio recording via SoX (FLAC format, 16kHz mono, lossless compression)

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
    
    -- Using 'rec' from SoX with MP3 output (VBR -V 4 for balanced encoding/upload)
    -- CRITICAL: Added '-q' (quiet) to prevent stdout/stderr pipe overflow in hs.task
    -- for long-running recordings (which would block the recording process).
    local soxPath = "/opt/homebrew/bin/rec" -- Standard brew path on Apple Silicon
    if not utils.file_exists(soxPath) then
        soxPath = "/usr/local/bin/rec" -- Intel Mac
    end
    if not utils.file_exists(soxPath) then
        -- Last resort: check PATH
        local pathCheck = hs.execute("which rec")
        if pathCheck and pathCheck ~= "" then
            soxPath = pathCheck:gsub("%s+", "")
        end
    end

    if not utils.file_exists(soxPath) then
        hs.alert.show("SoX (rec) not found! Please run 'brew install sox'")
        return false
    end

    -- Arguments: -q (quiet), -r 16000 (Whisper native rate), -c 1 (mono)
    -- FLAC is lossless and universally accepted by all Whisper API providers.
    -- 16kHz is Whisper's native input rate — no resampling on the server side.
    -- Effect: gain 3 (boost volume by 3dB to help Whisper detect speech in quiet environments)
    M.currentTask = hs.task.new(soxPath, function(exitCode, stdOut, stdErr)
        print("Recording process exited. Code: " .. exitCode)
        if exitCode ~= 0 and exitCode ~= -1 then
            print("SoX Error: " .. (stdErr or "unknown"))
        end
        -- If it exited unexpectedly without us stopping it, update state
        if exitCode ~= -1 and M.isRecording then
            print("WARNING: Recording process died unexpectedly!")
            M.isRecording = false
        end
    end, {"-q", "-r", "16000", "-c", "1", M.currentFilePath, "gain", "3"})
    
    if M.currentTask:start() then
        M.isRecording = true
        local pid = M.currentTask:pid()
        print("Recording process started (PID: " .. (pid or "unknown") .. ")")
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
    -- This ensures MP3 files are finalized correctly for long recordings
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
    
    -- Give file system a moment to flush and close the MP3 file
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
