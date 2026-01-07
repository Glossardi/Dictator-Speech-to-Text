-- utils.lua
-- Utility functions for file operations and temp file handling

local M = {}

function M.file_exists(name)
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
    return os.tmpname() .. "_" .. uuid .. "." .. (extension or "flac")
end

return M
