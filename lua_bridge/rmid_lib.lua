-- @noindex
-- RMID (Reaper MIDI Compact) Library for Reaper
-- Purpose-built compact MIDI text format for LLMs

local Lib = {}

-------------------------------------------------------------------------------
-- Pitch Conversion
-------------------------------------------------------------------------------

local pitch_names = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local pitch_map = {
    C=0, ["C#"]=1, Db=1, D=2, ["D#"]=3, Eb=3, E=4, F=5, ["F#"]=6, Gb=6, G=7, ["G#"]=8, Ab=8, A=9, ["A#"]=10, Bb=10, B=11
}

function Lib.get_pitch_name(n)
    local octave = math.floor(n / 12) - 1
    local name = pitch_names[(n % 12) + 1]
    return name .. octave
end

function Lib.get_note_number(pitch_str)
    local name, octave = pitch_str:match("([A-Ga-g][#sb]*)(%-?%d+)")
    if not name or not octave then return 60 end
    
    local base = name:sub(1,1):upper() .. name:sub(2):lower()
    -- Normalize common sharp/flat naming
    if base == "Db" then base = "C#" end
    if base == "Eb" then base = "D#" end
    if base == "Gb" then base = "F#" end
    if base == "Ab" then base = "G#" end
    if base == "Bb" then base = "A#" end
    
    local note = pitch_map[base] or 0
    return (tonumber(octave) + 1) * 12 + note
end

-------------------------------------------------------------------------------
-- Serialization (Reaper -> RMID)
-------------------------------------------------------------------------------

function Lib.serialize_rmid(data)
    local lines = {}
    
    -- Header
    if data.bpm or data.sig then
        local header = {}
        if data.bpm then table.insert(header, "BPM:" .. data.bpm) end
        if data.sig then table.insert(header, "SIG:" .. data.sig) end
        table.insert(lines, table.concat(header, " "))
        table.insert(lines, "")
    end
    
    -- Tracks
    for _, track in ipairs(data.tracks) do
        local track_line = string.format("TRACK %q", track.name or "Untitled")
        if track.channel then track_line = track_line .. " CH:" .. track.channel end
        table.insert(lines, track_line)
        
        if track.fx and #track.fx > 0 then
            table.insert(lines, "FX: " .. table.concat(track.fx, " | "))
        end
        
        for _, item in ipairs(track.items or {}) do
            if item.pos and item.len then
                table.insert(lines, string.format("ITEM %.3f %.3f", item.pos, item.len))
            end
            
            for _, note in ipairs(item.notes or {}) do
                table.insert(lines, string.format("%-4s %-7.3f %-7.3f %d", 
                    note.pitch, note.start, note.dur, note.vel))
            end
            
            -- CCs
            local cc_nums = {}
            for n in pairs(item.cc or {}) do table.insert(cc_nums, n) end
            table.sort(cc_nums)
            
            for _, n in ipairs(cc_nums) do
                local events = item.cc[n]
                local ev_strs = {}
                for _, ev in ipairs(events) do
                    table.insert(ev_strs, string.format("%.3f=%d", ev.time, ev.value))
                end
                table.insert(lines, string.format("CC%d: %s", n, table.concat(ev_strs, " ")))
            end
        end
        table.insert(lines, "") -- Spacer between tracks
    end
    
    return table.concat(lines, "\n")
end

-------------------------------------------------------------------------------
-- Parsing (RMID -> Table)
-------------------------------------------------------------------------------

function Lib.parse_rmid(text)
    -- Strip backslashes from JSON
    text = text:gsub("\\", "")
    
    local data = { tracks = {} }
    local current_track = nil
    local current_item = nil
    
    for line in text:gmatch("[^\r\n]+") do
        -- Strip comments (Multiple styles supported: ;, //, #)
        -- Special case: Only strip # if it's NOT following a note letter
        line = line:gsub(";.*", ""):gsub("//.*", "")
        if not line:match("[A-G]#") then
            line = line:gsub("#.*", "")
        end
        
        -- Trim
        line = line:match("^%s*(.-)%s*$")
        
        if line ~= "" then
            if line:match("^BPM:") or line:match("^SIG:") then
                data.bpm = line:match("BPM:(%d+)")
                data.sig = line:match("SIG:(%d+/%d+)")
                
            elseif line:match("^TRACK") then
                local name = line:match('TRACK%s+["\\]*(.-)["\\]*$')
                if not name then name = line:match('TRACK%s+(.*)') end
                local ch = line:match("CH:(%d+)")
                current_track = { name = (name or "Untitled"):gsub('^"', ''):gsub('"$', ''), channel = tonumber(ch), items = {} }
                table.insert(data.tracks, current_track)
                current_item = nil
                
            elseif line:match("^ITEM") then
                if current_track then
                    local pos, len = line:match("ITEM ([%d%.]+) ([%d%.]+)")
                    current_item = { pos = tonumber(pos), len = tonumber(len), notes = {}, cc = {} }
                    table.insert(current_track.items, current_item)
                end
                
            elseif line:match("^CC%d+:") then
                if current_item then
                    local num = line:match("^CC(%d+):")
                    local ev_str = line:match(":%s*(.*)")
                    current_item.cc[tonumber(num)] = {}
                    for time, val in ev_str:gmatch("([%d%.]+)=([%d%.]+)") do
                        table.insert(current_item.cc[tonumber(num)], { time = tonumber(time), value = tonumber(val) })
                    end
                end
                
            else
                -- Note line: Pitch Start Dur Vel
                local pitch, start, dur, vel = line:match("^(%S+)%s+([%d%.]+)%s+([%d%.]+)%s+([%d%.]+)")
                if pitch and start and dur and vel and current_track then
                    if not current_item then
                        current_item = { pos = 0, len = 0, notes = {}, cc = {} }
                        table.insert(current_track.items, current_item)
                    end
                    table.insert(current_item.notes, {
                        pitch = pitch,
                        start = tonumber(start),
                        dur = tonumber(dur),
                        vel = tonumber(vel)
                    })
                end
            end
        end
    end
    
    -- Strict Validation
    local note_count = 0
    for _, t in ipairs(data.tracks) do
        for _, it in ipairs(t.items) do note_count = note_count + #it.notes end
    end
    data.note_count = note_count
    
    return data
end

return Lib
