# .luacheckrc
-- Configuration for luacheck linter

-- Don't report unused self arguments
self = false

-- Allow global hs (Hammerspoon)
globals = {
    "hs",
}

-- Allow standard Lua globals
std = "max"

-- Exclude directories
exclude_files = {
    "tmp-npm-cache/**",
    ".luarocks/**",
}

-- Max line length
max_line_length = 120

-- Ignore specific warnings
ignore = {
    "212",  -- Unused argument
    "213",  -- Unused loop variable
}
