local M = {}
local utils = require("utils")
local config = require("config")

M.isRecording = false
M.currentTask = nil
M.currentFilePath = nil

function M.startRecording()
    if M.isRecording then return end
    
    M.currentFilePath = utils.get_temp_file_path("wav")
    print("Starting recording to: " .. M.currentFilePath)
    
    -- Using 'rec' from SoX
    -- -r 16000: sample rate
    -- -c 1: mono
    -- -b 16: 16-bit
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

    M.currentTask:terminate()
    M.isRecording = false
    M.currentTask = nil
    
    -- Give file system a moment to close the file? Usually terminate is enough.
    -- Return the file path to the callback
    if callback then callback(M.currentFilePath, nil) end
end

return M
