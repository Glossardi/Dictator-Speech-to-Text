-- api_filters.lua
-- Detection and filtering of AI hallucinations and silent segments

local M = {}

-- Detect "Prompt Reflection" Hallucinations:
-- If the output is just a subset or exact match of the glossary, and audio was near-silent/short,
-- it is almost certainly a hallucination.
function M.isGlossaryHallucination(text, glossary)
    if not glossary or #glossary <= 5 or not text or #text <= 3 then
        return false
    end
    
    local cleanText = text:lower():gsub("[%s%p]", "")
    local cleanGlossary = glossary:lower():gsub("[%s%p]", "")
    
    if #cleanText > 5 and cleanGlossary:find(cleanText, 1, true) then
        return true
    end
    
    return false
end

-- Filter segments based on confidence thresholds
-- Thresholds tuned for Whisper models:
-- 1. no_speech_prob > 0.6: Very likely just background noise/silence
-- 2. avg_logprob < -1.0: Model is very uncertain about the text
function M.filterSegments(segments)
    if not segments then return nil, 0 end
    
    local filteredText = ""
    local filteredCount = 0
    
    for _, segment in ipairs(segments) do
        local noSpeechProb = segment.no_speech_prob or 0
        local avgLogProb = segment.avg_logprob or 0
        
        if noSpeechProb < 0.6 and avgLogProb > -1.0 then
            filteredText = filteredText .. segment.text
        else
            filteredCount = filteredCount + 1
            print(string.format("  → Filtering hallucination: '%s' (p_no_speech: %.2f, logprob: %.2f)", 
                segment.text:gsub("[\n\r]", " "):sub(1, 40), noSpeechProb, avgLogProb))
        end
    end
    
    return filteredText, filteredCount
end

return M
