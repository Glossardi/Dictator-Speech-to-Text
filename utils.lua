-- utils.lua
-- Utility functions for file operations and temp file handling

local M = {}

function M.file_exists(name)
   if not name then return false end
   local f = io.open(name, "r")
   if f ~= nil then io.close(f) return true end
   return false
end

function M.get_file_size(filePath)
    local attributes = hs.fs.attributes(filePath)
    if attributes then
        return attributes.size
    end
    return nil
end

function M.get_temp_file_path(extension)
    local uuid = hs.host.uuid()
    return os.tmpname() .. "_" .. uuid .. "." .. (extension or "mp3")
end

-- Get context about the currently active application and window
function M.getCurrentContext()
    local win = hs.window.focusedWindow()
    if not win then return "" end

    local app = win:application()
    local appName = app and app:name() or "Unknown"
    local bundleID = app and app:bundleID() or "Unknown"
    local winTitle = win:title() or "Untitled"
    
    local dateStr = os.date("%Y-%m-%d")
    local timeStr = os.date("%H:%M:%S")
    local dayName = os.date("%A")
    
    local contextParts = {
        "<context>",
        "  <current_date>" .. dateStr .. " (" .. dayName .. ")</current_date>",
        "  <current_time>" .. timeStr .. "</current_time>",
        "  <app_name>" .. appName .. "</app_name>",
        "  <bundle_id>" .. bundleID .. "</bundle_id>",
        "  <window_title>" .. winTitle .. "</window_title>"
    }
    
    -- Add Clipboard hint
    local clipboard = hs.pasteboard.getContents()
    if clipboard and type(clipboard) == "string" and #clipboard > 0 then
        -- Detect if it's a previous Dictator transcript (marked by Zero Width Space \226\128\139)
        local isDictator = clipboard:find("\226\128\139$")
        local tag = isDictator and "previous_transcription" or "clipboard_hint"
        
        -- Limit to first 350 chars
        local cbHint = #clipboard > 350 and (clipboard:sub(1, 350) .. "...") or clipboard
        -- Remove the marker from display in context if present
        if isDictator then cbHint = cbHint:gsub("\226\128\139$", "") end
        table.insert(contextParts, "  <" .. tag .. ">" .. cbHint .. "</" .. tag .. ">")
    end

    -- Check Accessibility permissions
    local hasAx = hs.accessibilityState()
    table.insert(contextParts, "  <accessibility_enabled>" .. tostring(hasAx) .. "</accessibility_enabled>")

    -- Deeper Accessibility extraction (Optimized for Electron/VS Code)
    local function extractFromElement(el)
        if not el then return nil end
        local data = {}
        
        -- Try AXSelectedText
        local okSel, sel = pcall(function() return el.AXSelectedText end)
        if okSel and type(sel) == "string" and #sel > 0 then data.selected = sel end
        
        -- Try AXValue
        local okVal, val = pcall(function() return el.AXValue end)
        if okVal and type(val) == "string" and #val > 0 then data.value = val end
        
        -- Try AXRole
        local okRole, role = pcall(function() return el.AXRole end)
        if okRole then data.role = role end

        return (data.selected or data.value) and data or nil
    end

    local ok, focusedElement = pcall(function() return hs.axuielement.focusedElement() end)
    local elementData = extractFromElement(focusedElement)
    
    -- Fallback 1: If focused element gave nothing, try its parent (Electron often nests text)
    if not elementData and focusedElement then
        local okP, parent = pcall(function() return focusedElement.AXParent end)
        if okP and parent then
            elementData = extractFromElement(parent)
        end
    end

    -- Fallback 2: Try identifying the main window's focused element directly (Fallback for focus shifts)
    if not elementData and win then
        local okW, winEl = pcall(function() return hs.axuielement.windowElement(win) end)
        if okW and winEl then
            local pW, focusedEl = pcall(function() return winEl:attributeValue("AXFocusedUIElement") end)
            if pW and focusedEl then
                elementData = extractFromElement(focusedEl)
            end
        end
    end

    if elementData then
        if elementData.selected then
            table.insert(contextParts, "  <selected_text>" .. elementData.selected .. "</selected_text>")
        end
        if elementData.value then
            local val = elementData.value
            local textContext = #val > 2000 and val:sub(-2000) or val
            table.insert(contextParts, "  <field_text>" .. textContext .. "</field_text>")
        end
        if elementData.role then
            table.insert(contextParts, "  <element_role>" .. elementData.role .. "</element_role>")
        end
    end
    
    table.insert(contextParts, "</context>")
    return table.concat(contextParts, "\n")
end
        if okRole and role then
            table.insert(contextParts, "  <element_role>" .. role .. "</element_role>")
        end
    end
    
    table.insert(contextParts, "</context>")
    return table.concat(contextParts, "\n")
end

-- Validate transcription output to prevent garbage/malicious content
-- Returns: isValid (boolean), errorMessage (string or nil)
function M.validateTranscriptionOutput(text)
    if not text or type(text) ~= "string" then
        return false, "Ungültige Antwort vom Server"
    end
    
    -- Check for empty or whitespace-only text
    local trimmed = text:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return false, "Leere Antwort vom Server"
    end
    
    -- Block if the ENTIRE response is just a problematic domain (case-insensitive)
    -- This allows domains within normal text, but blocks pure domain outputs
    local lowerText = trimmed:lower()
    local blockedDomains = {
        "www.feyyaz.tv",
        "feyyaz.tv",
    }
    
    for _, domain in ipairs(blockedDomains) do
        if lowerText == domain then
            return false, "Ungültige Antwort erkannt"
        end
    end
    
    -- Block if response is ONLY a URL with nothing else (suspiciously short)
    if trimmed:match("^https?://[%w%.%-]+/?$") and #trimmed < 50 then
        return false, "Ungültige Antwort erkannt"
    end
    
    -- Check if text is suspiciously short for transcription (less than 2 characters)
    if #trimmed < 2 then
        return false, "Antwort zu kurz"
    end
    
    -- Check for suspicious patterns that indicate API errors or garbage
    local errorPatterns = {
        "^error$",
        "^exception$",
        "^failed$",
        "^unauthorized$",
        "^forbidden$",
        "^rate limit$",
        "^quota exceeded$"
    }
    
    -- Only flag as error if the ENTIRE response matches an error pattern (case-insensitive)
    for _, errorPattern in ipairs(errorPatterns) do
        if lowerText:match(errorPattern) then
            return false, "API meldet einen Fehler"
        end
    end
    
    return true, nil
end

return M
