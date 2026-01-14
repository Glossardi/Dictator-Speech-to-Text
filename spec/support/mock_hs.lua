-- spec/support/mock_hs.lua
-- Mock layer for Hammerspoon APIs used in Dictator
-- Allows testing Lua modules without running Hammerspoon

local M = {}

-- Track all mock calls for verification in tests
M.calls = {
    settings_set = {},
    settings_get = {},
    alert_show = {},
    task_new = {},
    dialog_textPrompt = {},
    fs_attributes = {},
    host_uuid = {},
}

-- Mock storage for hs.settings
M.settingsStore = {}

-- Reset all mocks (call this in before_each)
function M.reset()
    M.calls = {
        settings_set = {},
        settings_get = {},
        alert_show = {},
        task_new = {},
        dialog_textPrompt = {},
        fs_attributes = {},
        host_uuid = {},
    }
    M.settingsStore = {}
end

-- Create the mock hs global
function M.setup()
    _G.hs = {
        -- hs.settings mock
        settings = {
            set = function(key, value)
                table.insert(M.calls.settings_set, {key = key, value = value})
                M.settingsStore[key] = value
                return true
            end,
            
            get = function(key)
                table.insert(M.calls.settings_get, {key = key})
                return M.settingsStore[key]
            end,
            
            clear = function(key)
                M.settingsStore[key] = nil
            end,
        },
        
        -- hs.alert mock
        alert = {
            show = function(message, style, screen, duration)
                table.insert(M.calls.alert_show, {
                    message = message,
                    style = style,
                    screen = screen,
                    duration = duration
                })
            end,
        },
        
        -- hs.task mock
        task = {
            new = function(path, callback, args)
                local mockTask = {
                    _path = path,
                    _callback = callback,
                    _args = args,
                    _started = false,
                    
                    start = function(self)
                        self._started = true
                        return self
                    end,
                    
                    terminate = function(self)
                        return self
                    end,
                }
                
                table.insert(M.calls.task_new, {
                    path = path,
                    args = args,
                    task = mockTask
                })
                
                return mockTask
            end,
        },
        
        -- hs.dialog mock
        dialog = {
            textPrompt = function(title, message, defaultText, okButton, cancelButton)
                table.insert(M.calls.dialog_textPrompt, {
                    title = title,
                    message = message,
                    defaultText = defaultText,
                    okButton = okButton,
                    cancelButton = cancelButton
                })
                -- Default: return OK with the default text
                return "OK", defaultText or ""
            end,
        },
        
        -- hs.fs mock
        fs = {
            attributes = function(filepath)
                table.insert(M.calls.fs_attributes, {filepath = filepath})
                -- Return mock file attributes
                return {
                    size = 1024 * 100,  -- 100KB default
                    mode = "file",
                    modification = os.time(),
                }
            end,
        },
        
        -- hs.host mock
        host = {
            uuid = function()
                table.insert(M.calls.host_uuid, {})
                return "mock-uuid-12345"
            end,
        },
        
        -- hs.logger mock
        logger = {
            new = function(name, level)
                return {
                    i = function(...) end,
                    d = function(...) end,
                    w = function(...) end,
                    e = function(...) end,
                    f = function(...) end,
                    v = function(...) end,
                }
            end,
        },
        
        -- hs.timer mock
        timer = {
            secondsSinceEpoch = function()
                return os.time()
            end,
            
            doAfter = function(delay, fn)
                -- For testing, execute immediately or store for manual triggering
                return {
                    _delay = delay,
                    _fn = fn,
                    stop = function() end,
                }
            end,
            
            doEvery = function(interval, fn)
                return {
                    _interval = interval,
                    _fn = fn,
                    stop = function() end,
                }
            end,
        },
        
        -- hs.pasteboard mock
        pasteboard = {
            setContents = function(contents)
                M._clipboard = contents
            end,
            
            getContents = function()
                return M._clipboard or ""
            end,
        },
        
        -- hs.eventtap mock
        eventtap = {
            keyStroke = function(modifiers, character, delay, application)
                -- Mock keystroke - do nothing
            end,
        },
    }
    
    return _G.hs
end

-- Teardown mock
function M.teardown()
    _G.hs = nil
end

-- Helper: Get last call to a specific mock function
function M.getLastCall(funcName)
    local callList = M.calls[funcName]
    if callList and #callList > 0 then
        return callList[#callList]
    end
    return nil
end

-- Helper: Get call count for a specific mock function
function M.getCallCount(funcName)
    local callList = M.calls[funcName]
    return callList and #callList or 0
end

return M
