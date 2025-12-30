local M = {}

function M.file_exists(name)
   local f = io.open(name, "r")
   if f ~= nil then io.close(f) return true end
   return false
end

function M.get_temp_file_path(extension)
    local uuid = hs.host.uuid()
    return os.tmpname() .. "_" .. uuid .. "." .. (extension or "wav")
end

return M
