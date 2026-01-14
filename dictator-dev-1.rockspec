-- dictator-dev-1.rockspec
-- Development rockspec for Dictator project dependencies

package = "dictator"
version = "dev-1"

source = {
    url = "git://github.com/Glossardi/Dictator.git"
}

description = {
    summary = "Voice-to-Text Menubar App for macOS with Hammerspoon",
    detailed = [[
        A lightweight, high-performance macOS menubar application for voice 
        dictation using OpenAI's Whisper API. Built with Hammerspoon.
    ]],
    homepage = "https://github.com/Glossardi/Dictator",
    license = "MIT"
}

dependencies = {
    "lua >= 5.1",
    "busted >= 2.0.0",  -- Testing framework
}

build = {
    type = "builtin",
    modules = {
        ["dictator.config"] = "config.lua",
        ["dictator.utils"] = "utils.lua",
        ["dictator.rate_limiter"] = "rate_limiter.lua",
        ["dictator.api"] = "api.lua",
        ["dictator.audio"] = "audio.lua",
        ["dictator.ui"] = "ui.lua",
    }
}
