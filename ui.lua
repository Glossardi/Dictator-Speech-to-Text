-- ui.lua
-- Menubar UI management and status indicators

local M = {}
local config = require("config")

M.menubarItem = nil
M.currentStatus = "idle" -- idle, recording, processing, processing_ai, error

-- Simple ASCII icons or text for now. Can be replaced with images.
M.icons = {
    idle = "🎙️",
    recording = "🔴",
    processing = "⏳",
    processing_ai = "🤖",
    error = "⚠️"
}

function M.init()
    M.menubarItem = hs.menubar.new()
    M.updateStatus("idle")
end

function M.updateStatus(status, tooltip)
    M.currentStatus = status
    if M.menubarItem then
        M.menubarItem:setTitle(M.icons[status] or M.icons.idle)
        M.menubarItem:setTooltip(tooltip or "Menubar Dictation")
    end
end

function M.setMenu(menuTable)
    if M.menubarItem then
        M.menubarItem:setMenu(menuTable)
    end
end

function M.showNotification(message)
    hs.notify.new({title="Dictator", informativeText=message}):send()
end

function M.showError(message)
    M.updateStatus("error", message)
    hs.alert.show(message)
end

return M
