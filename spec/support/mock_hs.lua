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
    eventtap_keystroke = {},
    pasteboard_write = {},
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
        eventtap_keystroke = {},
        pasteboard_write = {},
    }
    M.settingsStore = {}
    M._clipboard = nil
end

-- Create the mock hs global
function M.setup()
    _G.hs = {
        -- hs.accessibilityState mock
        accessibilityState = function() return true end,

        -- hs.window mock
        window = {
            focusedWindow = function()
                return {
                    title = function() return "Mock Window" end,
                    application = function()
                        return {
                            name = function() return "Mock App" end,
                            bundleID = function() return "com.mock.app" end
                        }
                    end
                }
            end
        },

        -- hs.axuielement mock
        axuielement = {
            systemWideElement = function()
                return {
                    attributeValue = function(self, attr)
                        if attr == "AXFocusedUIElement" then
                            return {
                                attributeValue = function(el, a)
                                    if a == "AXRole" then return "AXTextArea" end
                                    if a == "AXValue" then return "Mock AX Text Content" end
                                    return nil
                                end
                            }
                        end
                        return nil
                    end
                }
            end,
            applicationElement = function(app)
                return {
                    attributeValue = function(self, attr) return nil end
                }
            end,
            windowElement = function(win)
                return {
                    attributeValue = function(self, attr) return nil end
                }
            end,
            axtextmarker = {
                newRange = function() return {} end
            }
        },

        -- hs.pasteboard mock
        pasteboard = {
            readAllData = function() return nil end,
            writeAllData = function(data)
                table.insert(M.calls.pasteboard_write, {data = data})
            end,
            setContents = function(contents)
                M._clipboard = contents
            end,
            getContents = function()
                return M._clipboard or "Mock Clipboard Content"
            end,
        },

        -- hs.eventtap mock
        eventtap = {
            keyStroke = function(mods, key, delay)
                table.insert(M.calls.eventtap_keystroke, {mods = mods, key = key, delay = delay})
            end
        },

        -- hs.timer mock
        timer = {
            usleep = function(mu) end,
            doAfter = function(sec, cb) 
                if type(sec) == "function" then return end
                if cb then cb() end
                return { stop = function() end }
            end,
            doEvery = function(sec, cb) return { stop = function() end } end,
            secondsSinceEpoch = function() return os.time() end
        },

        -- hs.json mock
        json = {
            encode = function(val) 
                if type(val) ~= "table" then return tostring(val) end
                local s = "{"
                local parts = {}
                if val.messages then
                    local ms = '"messages":['
                    for i, m in ipairs(val.messages) do
                        ms = ms .. '{"role":"' .. m.role .. '","content":"' .. m.content:gsub('"', '\\"'):gsub('\n', '\\n') .. '"}'
                        if i < #val.messages then ms = ms .. "," end
                    end
                    ms = ms .. "]"
                    table.insert(parts, ms)
                end
                if val.stop then
                    local ss = '"stop":['
                    for i, st in ipairs(val.stop) do
                        ss = ss .. '"' .. st:gsub('"', '\\"') .. '"'
                        if i < #val.stop then ss = ss .. "," end
                    end
                    ss = ss .. "]"
                    table.insert(parts, ss)
                end
                s = s .. table.concat(parts, ",") .. "}"
                return s
            end,
            decode = function(str) 
                if not str then return nil end
                if str:find('"messages"') then
                    local content1 = str:match('{"role":"system","content":"(.-)"}')
                    local content2 = str:match('{"role":"user","content":"(.-)"}')
                    return {
                        messages = {
                            { role = "system", content = content1 or "" },
                            { role = "user", content = content2 or "" }
                        }
                    }
                end
                if str:find("choices") then
                    local content = str:match('"content":"(.-)"')
                    if content then
                        content = content:gsub('\\n', '\n'):gsub('\\"', '"')
                        return { choices = { { message = { content = content } } } }
                    end
                end
                return { text = "mock result" }
            end
        },

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
                })
                return "OK", defaultText or ""
            end,
        },
        
        -- hs.fs mock
        fs = {
            attributes = function(filepath)
                table.insert(M.calls.fs_attributes, {filepath = filepath})
                return {
                    size = 1024 * 100,
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
