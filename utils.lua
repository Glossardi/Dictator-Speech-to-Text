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
function M.getCurrentContext(focusedElement)
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
    
    -- Check Accessibility permissions
    local hasAx = hs.accessibilityState()
    table.insert(contextParts, "  <accessibility_enabled>" .. tostring(hasAx) .. "</accessibility_enabled>")

    -- Deeper Accessibility extraction (Optimized for Electron/VS Code/Safari)
    local function extractFromElement(el)
        if not el then return nil end
        local data = {}
        
        -- Attributes to check for value and selection
        local valAttrs = {"AXValue", "AXSharedText", "AXDescription"}
        local selAttrs = {"AXSelectedText"}

        -- 1. Try directly supported text attributes
        for _, attr in ipairs(selAttrs) do
            local ok, val = pcall(function() return el:attributeValue(attr) end)
            if ok and type(val) == "string" and #val > 0 then
                data.selected = val
                break
            end
        end

        for _, attr in ipairs(valAttrs) do
            local ok, val = pcall(function() return el:attributeValue(attr) end)
            if ok and type(val) == "string" and #val > 0 then
                data.value = val
                break
            end
        end

        -- 2. Try TextMarker API for Electron/Safari if selection is missing
        if not data.selected then
            local okM, mRange = pcall(function() return el:attributeValue("AXSelectedTextMarkerRange") end)
            if okM and mRange then
                local okS, mStr = pcall(function() return el:attributeValue("AXStringForTextMarkerRange", mRange) end)
                if okS and type(mStr) == "string" and #mStr > 0 then
                    data.selected = mStr
                end
            end
        end
        
        -- 3. Try TextMarker API for Full Text if value is missing
        if not data.value then
            local pStart, startM = pcall(function() return el:attributeValue("AXStartTextMarker") end)
            local pEnd, endM = pcall(function() return el:attributeValue("AXEndTextMarker") end)
            if pStart and pEnd and startM and endM then
                pcall(function()
                    local fullRange = hs.axuielement.axtextmarker.newRange(startM, endM)
                    local fullStr = el:attributeValue("AXStringForTextMarkerRange", fullRange)
                    if type(fullStr) == "string" and #fullStr > 0 then
                        data.value = fullStr
                    end
                end)
            end
        end

        local okRole, role = pcall(function() return el:attributeValue("AXRole") end)
        if okRole then data.role = role end

        return (data.selected or data.value) and data or nil
    end

    -- Find the true focused element
    local focused = focusedElement
    if not focused then
        -- Strategy A: System Wide
        focused = hs.axuielement.systemWideElement():attributeValue("AXFocusedUIElement")
        -- Strategy B: App Specific (often more reliable for Electron)
        if not focused and app then
            local appEl = hs.axuielement.applicationElement(app)
            if appEl then focused = appEl:attributeValue("AXFocusedUIElement") end
        end
    end

    local elementData = extractFromElement(focused)
    
    -- Recursive Fallback: Search Parent and Children if direct focus yields nothing
    if not elementData and focused then
        -- Try Parent
        elementData = extractFromElement(focused:attributeValue("AXParent"))
        
        -- Try Children (Shallow search)
        if not elementData then
            local children = focused:attributeValue("AXChildren")
            if type(children) == "table" then
                for _, child in ipairs(children) do
                    elementData = extractFromElement(child)
                    if elementData then break end
                end
            end
        end
    end

    -- Last Resort: If we still have nothing, search the entire window for ANY focused text element
    if not elementData and win then
        local okW, winEl = pcall(function() return hs.axuielement.windowElement(win) end)
        if okW and winEl then
            -- This is a more horizontal search
            local function findText(el, depth)
                if depth > 10 then return nil end -- Deep enough for Electron/VS Code
                local d = extractFromElement(el)
                if d then return d end
                
                local okC, children = pcall(function() return el:attributeValue("AXChildren") end)
                if okC and type(children) == "table" then
                    for _, child in ipairs(children) do
                        local res = findText(child, depth + 1)
                        if res then return res end
                    end
                end
                return nil
            end
            elementData = findText(winEl, 0)
        end
    end

    if elementData then
        if elementData.selected then
            table.insert(contextParts, "  <selected_text>" .. elementData.selected .. "</selected_text>")
        end
        if elementData.value then
            local val = elementData.value
            -- Limit context to the last 1500 characters
            local textContext = #val > 1500 and val:sub(-1500) or val
            table.insert(contextParts, "  <surrounding_text_readonly>" .. textContext .. "</surrounding_text_readonly>")
        end
        if elementData.role then
            table.insert(contextParts, "  <element_role>" .. elementData.role .. "</element_role>")
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
