-- @description Reaper MCP Bridge V2
-- @author Antigravity
-- @version 0.4
-- @noindex

local script_path = debug.getinfo(1, 'S').source:match([[^@?(.*[\/])]])
package.path = script_path .. "?.lua;" .. package.path
local ok, RMID = pcall(require, "rmid_lib")

local temp_dir = os.getenv("TEMP") or "/tmp"
local ipc_dir = temp_dir .. "/reaper_mcp_v2"
local cmd_file = ipc_dir .. "/command.json"
local resp_file = ipc_dir .. "/response.json"

local function json_escape(s)
    local escape_map = {['"']='\\"', ['\\']='\\\\', ['/']='\\/', ['\b']='\\b', ['\f']='\\f', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t'}
    return '"' .. s:gsub('["\\/\b\f\n\r\t]', escape_map) .. '"'
end

local function json_encode(v)
    if type(v) == "string" then return json_escape(v)
    elseif type(v) == "number" or type(v) == "boolean" then return tostring(v)
    elseif type(v) == "table" then
        local parts = {}
        if #v > 0 or (next(v) == nil) then
            for i, val in ipairs(v) do table.insert(parts, json_encode(val)) end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            for k, val in pairs(v) do table.insert(parts, json_escape(tostring(k)) .. ":" .. json_encode(val)) end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else return "null" end
end

local function json_decode(s)
    local id = s:match('"id"%s*:%s*"([^"]+)"')
    local tool = s:match('"tool"%s*:%s*"([^"]+)"')
    local args_str = s:match('"args"%s*:%s*({.*})')
    local args = {}
    if args_str then
        for k in args_str:gmatch('"([^"]+)"%s*:') do
            local _, p_colon = args_str:find('"' .. k .. '"%s*:')
            if p_colon then
                local val_start = p_colon + 1
                while args_str:sub(val_start, val_start):match("%s") do val_start = val_start + 1 end
                local first_char = args_str:sub(val_start, val_start)
                
                if first_char == '"' then
                    local val_end = nil
                    local search_pos = val_start + 1
                    while not val_end do
                        local q = args_str:find('"', search_pos)
                        if not q then break end
                        local escapes = 0
                        local b = q - 1
                        while b >= val_start and args_str:sub(b, b) == "\\" do escapes = escapes + 1; b = b - 1 end
                        if escapes % 2 == 0 then val_end = q else search_pos = q + 1 end
                    end
                    if val_end then
                        local val = args_str:sub(val_start + 1, val_end - 1)
                        args[k] = val:gsub("\\\\", "\1"):gsub('\\"', '"'):gsub("\\n", "\n"):gsub("\\r", "\r"):gsub("\\t", "\t"):gsub("\1", "\\")
                    end
                elseif first_char == '[' then
                    local val_end = args_str:find(']', val_start)
                    if val_end then
                        local array_str = args_str:sub(val_start + 1, val_end - 1)
                        local list = {}
                        for item in array_str:gmatch('([^,]+)') do
                            item = item:match("^%s*(.-)%s*$")
                            if tonumber(item) then table.insert(list, tonumber(item))
                            elseif item:match('^"(.*)"$') then table.insert(list, item:match('^"(.*)"$'))
                            end
                        end
                        args[k] = list
                    end
                else
                    local val = args_str:match('^([^,}%s]+)', val_start)
                    if val == "true" then args[k] = true
                    elseif val == "false" then args[k] = false
                    elseif tonumber(val) then args[k] = tonumber(val) end
                end
            end
        end
    end
    return { id = id, tool = tool, args = args }
end

local Tools = {}

local function channels_to_mask(channels)
    local low = 0
    local high = 0
    for _, ch in ipairs(channels) do
        local idx = tonumber(ch) - 1 -- 1-based to 0-based
        if idx < 32 then
            low = low | (1 << idx)
        elseif idx < 64 then
            high = high | (1 << (idx - 32))
        end
    end
    return low, high
end

local function mask_to_channels(low, high)
    local channels = {}
    for i = 0, 31 do
        if (low & (1 << i)) ~= 0 then table.insert(channels, i + 1) end
    end
    for i = 0, 31 do
        if (high & (1 << i)) ~= 0 then table.insert(channels, i + 33) end
    end
    return channels
end

local function parse_channels(s)
    if not s or s == "" then return nil end
    if type(s) == "number" then return s end
    if type(s) ~= "string" then return nil end
    
    -- Stereo pair: "1/2", "3/4", etc.
    local start_ch, stop_ch = s:match("(%d+)/(%d+)")
    if start_ch and stop_ch then
        local start_idx = tonumber(start_ch) - 1
        local num = tonumber(stop_ch) - tonumber(start_ch) + 1
        -- Reaper bits: 0-4=start, 5-9=num(0=2, 1=1, 2=3...), 10=mono
        local num_val = num
        if num == 2 then num_val = 0 end
        return start_idx | (num_val << 5)
    end
    
    -- Mono: "1", "3", etc.
    local mono_ch = s:match("^(%d+)$")
    if mono_ch then
        local start_idx = tonumber(mono_ch) - 1
        return start_idx | (1 << 5) | (1 << 10)
    end
    
    -- Fallback to tonumber if it's just a raw index string
    return tonumber(s)
end

function Tools.ping(args) return { status = "pong", v = "V2" } end
function Tools.set_cursor_position(args)
    local pos = args.position
    if not pos then return { error = "Missing position" } end
    if args.is_beats then pos = reaper.TimeMap_QNToTime(pos) end
    reaper.SetEditCurPos(pos, true, false)
    return { status = "ok" }
end

function Tools.create_track(args)
    reaper.InsertTrackAtIndex(reaper.CountTracks(0), true)
    local tr = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
    reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", args.name or "New Track", true)
    return { status = "ok", index = reaper.CountTracks(0) }
end

function Tools.delete_track(args)
    local tr = reaper.GetTrack(0, (args.track_index or 0) - 1)
    if tr then reaper.DeleteTrack(tr) return { status = "ok" } end
    return { error = "Track not found" }
end

function Tools.set_track_volume(args)
    local tr = reaper.GetTrack(0, (args.track_index or 0) - 1)
    if tr then 
        reaper.SetMediaTrackInfo_Value(tr, "D_VOL", 10 ^ ((args.volume_db or 0) / 20))
        return { status = "ok" }
    end
    return { error = "Track not found" }
end

function Tools.get_project_info(args)
    local num, den, bpm = reaper.TimeMap_GetTimeSigAtTime(0, 0)
    return { bpm = bpm, time_sig = string.format("%d/%d", num, den), name = reaper.GetProjectName(0, ""), cursor = reaper.GetCursorPosition() }
end

function Tools.set_tempo(args)
    local bpm = args.bpm
    if bpm then
        local num, den, _ = reaper.TimeMap_GetTimeSigAtTime(0, 0)
        reaper.SetTempoTimeSigMarker(0, -1, 0, -1, -1, bpm, num, den, false)
        reaper.UpdateTimeline()
        return { status = "ok" }
    end
    return { error = "Missing bpm" }
end

function Tools.set_time_signature(args)
    local num = args.numerator
    local den = args.denominator
    if num and den then
        reaper.SetTempoTimeSigMarker(0, -1, 0, -1, -1, -1, num, den, false)
        return { status = "ok" }
    end
    return { error = "Missing numerator or denominator" }
end

function Tools.list_tracks(args)
    local tracks = {}
    for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        local _, name = reaper.GetTrackName(tr)
        table.insert(tracks, { index = i + 1, name = name, fx_count = reaper.TrackFX_GetCount(tr) })
    end
    return tracks
end

function Tools.get_project_midi_overview(args)
    local tracks = {}
    for i = 0, reaper.CountTracks(0) - 1 do
        local tr = reaper.GetTrack(0, i)
        local _, name = reaper.GetTrackName(tr)
        local items = {}
        for j = 0, reaper.CountTrackMediaItems(tr) - 1 do
            local item = reaper.GetTrackMediaItem(tr, j)
            local take = reaper.GetActiveTake(item)
            if take and reaper.TakeIsMIDI(take) then
                local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                local start_qn = reaper.TimeMap_timeToQN(pos)
                local end_qn = reaper.TimeMap_timeToQN(pos + len)
                table.insert(items, string.format("[%.1f-%.1f]", start_qn, end_qn))
            end
        end
        if #items > 0 then
            table.insert(tracks, { index = i + 1, name = name, items = table.concat(items, ", ") })
        end
    end
    return tracks
end

function Tools.describe_track(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local _, name = reaper.GetTrackName(tr)
    
    local min_pitch = 127
    local max_pitch = 0
    local note_count = 0
    local total_len = 0
    local durations = {}
    
    for i = 0, reaper.CountTrackMediaItems(tr) - 1 do
        local item = reaper.GetTrackMediaItem(tr, i)
        local take = reaper.GetActiveTake(item)
        if take and reaper.TakeIsMIDI(take) then
            local _, ncount = reaper.MIDI_CountEvts(take)
            note_count = note_count + ncount
            local item_len = reaper.TimeMap_timeToQN(reaper.GetMediaItemInfo_Value(item, "D_POSITION") + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")) - reaper.TimeMap_timeToQN(reaper.GetMediaItemInfo_Value(item, "D_POSITION"))
            total_len = total_len + item_len
            
            for n = 0, ncount - 1 do
                local _, _, _, startppq, endppq, _, pitch, _ = reaper.MIDI_GetNote(take, n)
                if pitch < min_pitch then min_pitch = pitch end
                if pitch > max_pitch then max_pitch = pitch end
                local dur = reaper.MIDI_GetProjQNFromPPQPos(take, endppq) - reaper.MIDI_GetProjQNFromPPQPos(take, startppq)
                dur = math.floor(dur * 1000 + 0.5) / 1000 -- Round
                durations[dur] = (durations[dur] or 0) + 1
            end
        end
    end
    
    if note_count == 0 then return { name = name, empty = true } end
    
    local density = note_count / (total_len > 0 and total_len or 1)
    local common_dur = 0
    local max_freq = 0
    for dur, freq in pairs(durations) do
        if freq > max_freq then max_freq = freq; common_dur = dur end
    end
    
    local type_guess = "Melodic"
    if (max_pitch - min_pitch) <= 12 and density > 1 then type_guess = "Percussive/Drums" end
    if (max_pitch - min_pitch) > 36 then type_guess = "Wide Range/Piano" end
    
    return {
        name = name,
        type = type_guess,
        pitch_range = RMID.get_pitch_name(min_pitch) .. " to " .. RMID.get_pitch_name(max_pitch),
        note_count = note_count,
        density = string.format("%.2f notes/beat", density),
        common_duration = common_dur
    }
end

function Tools.get_track_info(args)
    local tr = reaper.GetTrack(0, (args.track_index or 0) - 1)
    if not tr then return { error = "Track not found" } end
    local _, name = reaper.GetTrackName(tr)
    local fx = {}
    for i = 0, reaper.TrackFX_GetCount(tr) - 1 do
        local _, fx_name = reaper.TrackFX_GetFXName(tr, i, "")
        table.insert(fx, fx_name)
    end
    return { name = name, volume_db = 20 * math.log(reaper.GetMediaTrackInfo_Value(tr, "D_VOL"), 10), fx = fx }
end

function Tools.list_midi_items(args)
    local tr = reaper.GetTrack(0, (args.track_index or 0) - 1)
    if not tr then return { error = "Track not found" } end
    local items = {}
    for i = 0, reaper.CountTrackMediaItems(tr) - 1 do
        local item = reaper.GetTrackMediaItem(tr, i)
        local take = reaper.GetActiveTake(item)
        if take and reaper.TakeIsMIDI(take) then
            local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local start_qn = reaper.TimeMap_timeToQN(pos)
            local end_qn = reaper.TimeMap_timeToQN(pos + len)
            local _, notecount, cccount = reaper.MIDI_CountEvts(take)
            local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            table.insert(items, { index = i + 1, name = name, pos_beats = start_qn, len_beats = end_qn - start_qn, note_count = notecount, cc_count = cccount })
        end
    end
    return items
end

function Tools.list_media_items(args)
    local tr = reaper.GetTrack(0, (args.track_index or 0) - 1)
    if not tr then return { error = "Track not found" } end
    local items = {}
    for i = 0, reaper.CountTrackMediaItems(tr) - 1 do
        local item = reaper.GetTrackMediaItem(tr, i)
        local take = reaper.GetActiveTake(item)
        local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        local start_qn = reaper.TimeMap_timeToQN(pos)
        local end_qn = reaper.TimeMap_timeToQN(pos + len)
        local name = "[Unnamed]"
        local itype = "Audio"
        
        if take then
            local _, tname = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
            name = tname
            if reaper.TakeIsMIDI(take) then
                itype = "MIDI"
            end
        end
        
        table.insert(items, { 
            index = i + 1, 
            name = name, 
            type = itype,
            pos_beats = start_qn, 
            len_beats = end_qn - start_qn 
        })
    end
    return items
end

function Tools.get_track_midi(args)
    local tr = reaper.GetTrack(0, (args.track_index or 0) - 1)
    if not tr then return { error = "Track not found" } end
    local _, tr_name = reaper.GetTrackName(tr)
    local track_data = { name = tr_name, items = {} }
    for i = 0, reaper.CountTrackMediaItems(tr) - 1 do
        local item = reaper.GetTrackMediaItem(tr, i)
        local take = reaper.GetActiveTake(item)
        if take and reaper.TakeIsMIDI(take) then
            reaper.MIDI_Sort(take)
            local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local start_qn = reaper.TimeMap_timeToQN(pos)
            local r_item = { pos = start_qn, len = reaper.TimeMap_timeToQN(pos + len) - start_qn, notes = {}, cc = {} }
            local _, notecount, cccount = reaper.MIDI_CountEvts(take)
            for n = 0, notecount - 1 do
                local _, _, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, n)
                if not muted then
                    local n_s = reaper.MIDI_GetProjQNFromPPQPos(take, startppq)
                    local n_e = reaper.MIDI_GetProjQNFromPPQPos(take, endppq)
                    table.insert(r_item.notes, { pitch = RMID.get_pitch_name(pitch), start = n_s - start_qn, dur = n_e - n_s, vel = vel })
                end
            end
            table.insert(track_data.items, r_item)
        end
    end
    return RMID.serialize_rmid({ bpm = math.floor(reaper.Master_GetTempo()), tracks = { track_data } })
end

function Tools.get_midi_item(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local item = reaper.GetTrackMediaItem(tr, (args.item_index or 1) - 1)
    if not item then return { error = "Item not found" } end
    local take = reaper.GetActiveTake(item)
    if not take or not reaper.TakeIsMIDI(take) then return { error = "Item is not a MIDI item" } end
    
    reaper.MIDI_Sort(take)
    local _, tr_name = reaper.GetTrackName(tr)
    local track_data = { name = tr_name, items = {} }
    local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local start_qn = reaper.TimeMap_timeToQN(pos)
    local r_item = { pos = start_qn, len = reaper.TimeMap_timeToQN(pos + len) - start_qn, notes = {}, cc = {} }
    
    local _, notecount, cccount = reaper.MIDI_CountEvts(take)
    for n = 0, notecount - 1 do
        local _, _, muted, startppq, endppq, chan, pitch, vel = reaper.MIDI_GetNote(take, n)
        if not muted then
            local n_s = reaper.MIDI_GetProjQNFromPPQPos(take, startppq)
            local n_e = reaper.MIDI_GetProjQNFromPPQPos(take, endppq)
            table.insert(r_item.notes, { pitch = RMID.get_pitch_name(pitch), start = n_s - start_qn, dur = n_e - n_s, vel = vel })
        end
    end
    table.insert(track_data.items, r_item)
    return RMID.serialize_rmid({ bpm = math.floor(reaper.Master_GetTempo()), tracks = { track_data } })
end

function Tools.set_midi_item(args)

    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    local item = reaper.GetTrackMediaItem(tr, (args.item_index or 1) - 1)
    if not item then return { error = "Item not found" } end
    local take = reaper.GetActiveTake(item)
    local data = RMID.parse_rmid(args.rmid)
    if data.note_count == 0 then return { error = "No notes found in RMID" } end
    
    local r_item = data.tracks[1].items[1]
    local qn_pos = reaper.TimeMap_timeToQN(reaper.GetMediaItemInfo_Value(item, "D_POSITION"))
    local item_start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, reaper.GetMediaItemInfo_Value(item, "D_POSITION"))
    local _, notes, ccs = reaper.MIDI_CountEvts(take)
    for i = notes-1, 0, -1 do reaper.MIDI_DeleteNote(take, i) end
    for i = ccs-1, 0, -1 do reaper.MIDI_DeleteCC(take, i) end
    for _, note in ipairs(r_item.notes) do
        local s = reaper.MIDI_GetPPQPosFromProjQN(take, qn_pos + note.start) - item_start_ppq
        local e = reaper.MIDI_GetPPQPosFromProjQN(take, qn_pos + note.start + note.dur) - item_start_ppq
        reaper.MIDI_InsertNote(take, false, false, s, e, 0, RMID.get_note_number(note.pitch), note.vel, true)
    end
    reaper.MIDI_Sort(take)
    reaper.UpdateArrange()
    return { status = "ok" }
end

function Tools.insert_midi_item(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local data = RMID.parse_rmid(args.rmid)
    if not data.tracks or #data.tracks == 0 or data.note_count == 0 then 
        return { error = "No valid notes found in RMID. Check TRACK/ITEM tags and note syntax." } 
    end
    
    local trace = {}
    for _, track in ipairs(data.tracks) do
        for _, item in ipairs(track.items) do
            local start_t = reaper.TimeMap_QNToTime(item.pos)
            local end_t = reaper.TimeMap_QNToTime(item.pos + item.len)
            local m_item = reaper.CreateNewMIDIItemInProj(tr, start_t, end_t)
            local take = reaper.GetActiveTake(m_item)
            local item_start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, start_t)
            for _, note in ipairs(item.notes) do
                local s = reaper.MIDI_GetPPQPosFromProjQN(take, item.pos + note.start) - item_start_ppq
                local e = reaper.MIDI_GetPPQPosFromProjQN(take, item.pos + note.start + note.dur) - item_start_ppq
                reaper.MIDI_InsertNote(take, false, false, s, e, 0, RMID.get_note_number(note.pitch), note.vel, true)
            end
            reaper.MIDI_Sort(take)
            table.insert(trace, "Inserted item at " .. item.pos)
        end
    end
    reaper.UpdateArrange()
    return { status = "ok", trace = trace }
end

function Tools.move_media_item(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    local item = reaper.GetTrackMediaItem(tr, (args.item_index or 1) - 1)
    if not item then return { error = "Item not found" } end
    
    local new_pos = args.new_pos_beats
    if new_pos then
        local t = reaper.TimeMap_QNToTime(new_pos)
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", t)
    end
    reaper.UpdateArrange()
    return { status = "ok" }
end

function Tools.delete_media_item(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    local item = reaper.GetTrackMediaItem(tr, (args.item_index or 1) - 1)
    if tr and item then
        reaper.DeleteTrackMediaItem(tr, item)
        reaper.UpdateArrange()
        return { status = "ok" }
    end
    return { error = "Item or Track not found" }
end

function Tools.copy_media_item(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    local item = reaper.GetTrackMediaItem(tr, (args.item_index or 1) - 1)
    if not item then return { error = "Item not found" } end
    
    local dest_tr = args.dest_track_index and reaper.GetTrack(0, args.dest_track_index - 1) or tr
    local new_pos = args.new_pos_beats and reaper.TimeMap_QNToTime(args.new_pos_beats) or reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    
    -- Select ONLY this item for action
    reaper.SelectAllMediaItems(0, false)
    reaper.SetMediaItemSelected(item, true)
    
    reaper.SetEditCurPos(new_pos, false, false)
    
    if args.pooled then
        -- Nuclear Chunk Method: Direct injection of POOLEDEVTS
        local _, chunk = reaper.GetItemStateChunk(item, "", false)
        local start_t = new_pos
        local end_t = start_t + reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
        
        -- Generate a new Pool GUID if not present, or reuse existing
        local pool_guid = chunk:match("POOLEDEVTS ({%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x})")
        if not pool_guid then
            pool_guid = reaper.genGuid()
            -- Convert MIDI SOURCE to MIDIPOOL and add POOLEDEVTS
            chunk = chunk:gsub("<SOURCE MIDI", "<SOURCE MIDIPOOL\nPOOLEDEVTS " .. pool_guid)
            -- Update the original item to be pooled too
            reaper.SetItemStateChunk(item, chunk, false)
        end
        
        local new_item = reaper.CreateNewMIDIItemInProj(dest_tr, start_t, end_t)
        -- Set the new item to use the same pooled chunk (Reaper handles GUID/IGUID fixup)
        reaper.SetItemStateChunk(new_item, chunk, false)
        reaper.SetMediaItemInfo_Value(new_item, "D_POSITION", start_t)
    else
        -- Regular copy via clipboard
        reaper.SelectAllMediaItems(0, false)
        reaper.SetMediaItemSelected(item, true)
        reaper.SetEditCurPos(new_pos, false, false)
        reaper.Main_OnCommand(40698, 0) -- Edit: Copy
        reaper.SetOnlyTrackSelected(dest_tr)
        reaper.Main_OnCommand(40058, 0) -- Item: Paste items/tracks
    end
    
    reaper.UpdateArrange()
    return { status = "ok" }
end

function Tools.set_track_midi(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local data = RMID.parse_rmid(args.rmid)
    if not data.tracks or #data.tracks == 0 or data.note_count == 0 then
        return { status = "error", error = "No valid notes found in RMID. Check formatting (TRACK/ITEM tags and note syntax)." }
    end
    
    -- Clear and Insert
    for i = reaper.CountTrackMediaItems(tr)-1, 0, -1 do reaper.DeleteTrackMediaItem(tr, reaper.GetTrackMediaItem(tr, i)) end
    for _, track in ipairs(data.tracks) do
        for _, item in ipairs(track.items) do
            local start_t = reaper.TimeMap_QNToTime(item.pos)
            local end_t = reaper.TimeMap_QNToTime(item.pos + item.len)
            local m_item = reaper.CreateNewMIDIItemInProj(tr, start_t, end_t)
            local take = reaper.GetActiveTake(m_item)
            local item_start_ppq = reaper.MIDI_GetPPQPosFromProjTime(take, start_t)
            for _, note in ipairs(item.notes) do
                local s = reaper.MIDI_GetPPQPosFromProjQN(take, item.pos + note.start) - item_start_ppq
                local e = reaper.MIDI_GetPPQPosFromProjQN(take, item.pos + note.start + note.dur) - item_start_ppq
                reaper.MIDI_InsertNote(take, false, false, s, e, 0, RMID.get_note_number(note.pitch), note.vel, true)
            end
            reaper.MIDI_Sort(take)
        end
    end
    reaper.UpdateArrange()
    return { status = "ok" }
end

function Tools.list_vsts(args)
    local resource_path = reaper.GetResourcePath()
    local files = { resource_path .. "/reaper-vstplugins64.ini", resource_path .. "/reaper-vstplugins.ini" }
    local vsts = {}
    local filter = args.filter and args.filter:lower() or nil
    
    for _, path in ipairs(files) do
        local f = io.open(path, "r")
        if f then
            for line in f:lines() do
                -- Pattern: filename=id,name
                local name = line:match(".-=.-,([^,]+)$")
                if not name then
                    -- Try VST3 shell pattern: WaveShell...<id=...,name
                    name = line:match("{.-,([^,]+)$")
                end
                
                if name then
                    local is_instrument = name:match("!!!VSTi") ~= nil
                    name = name:gsub("!!!VSTi", "")
                    
                    if not filter or name:lower():find(filter, 1, true) then
                        table.insert(vsts, { name = name, is_instrument = is_instrument })
                    end
                end
            end
            f:close()
        end
    end
    return vsts
end

function Tools.add_fx(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local fx_name = args.fx_name
    if not fx_name then return { error = "Missing fx_name" } end
    
    local instantiate = args.instantiate ~= false
    local idx = reaper.TrackFX_AddByName(tr, fx_name, false, instantiate and -1 or 0)
    
    if idx == -1 then return { error = "Failed to add FX: " .. fx_name } end
    return { status = "ok", index = idx }
end

function Tools.delete_track_fx(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local fx_index = args.fx_index or 0
    reaper.TrackFX_Delete(tr, fx_index)
    return { status = "ok" }
end

function Tools.move_track(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    
    local target_idx = args.target_index or 1
    reaper.SetOnlyTrackSelected(tr)
    reaper.ReorderSelectedTracks(target_idx - 1, 0)
    
    return { status = "ok" }
end

function Tools.set_track_folder_depth(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local depth = args.depth or 0
    reaper.SetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH", depth)
    return { status = "ok" }
end

function Tools.set_track_color(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local r, g, b = args.r or 255, args.g or 255, args.b or 255
    reaper.SetTrackColor(tr, reaper.ColorToNative(r, g, b))
    return { status = "ok" }
end

function Tools.set_track_channels(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local n = args.num_channels or 2
    reaper.SetMediaTrackInfo_Value(tr, "I_NCHAN", n)
    return { status = "ok" }
end

function Tools.list_track_sends(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local sends = {}
    for i = 0, reaper.GetTrackNumSends(tr, 0) - 1 do
        local dest_tr = reaper.GetTrackSendInfo_Value(tr, 0, i, "P_DESTTRACK")
        local _, dest_name = reaper.GetTrackName(dest_tr)
        local vol = reaper.GetTrackSendInfo_Value(tr, 0, i, "D_VOL")
        local pan = reaper.GetTrackSendInfo_Value(tr, 0, i, "D_PAN")
        local mute = reaper.GetTrackSendInfo_Value(tr, 0, i, "B_MUTE") == 1
        local src_chan = reaper.GetTrackSendInfo_Value(tr, 0, i, "I_SRCCHAN")
        local dst_chan = reaper.GetTrackSendInfo_Value(tr, 0, i, "I_DSTCHAN")
        table.insert(sends, { 
            index = i + 1, 
            dest_track_index = math.floor(reaper.GetMediaTrackInfo_Value(dest_tr, "IP_TRACKNUMBER")), 
            dest_track_name = dest_name,
            volume_db = 20 * (vol > 0 and math.log(vol, 10) or -100),
            pan = pan,
            mute = mute,
            src_chan = src_chan,
            dst_chan = dst_chan
        })
    end
    return sends
end

function Tools.create_track_send(args)
    local src_tr = reaper.GetTrack(0, (args.source_track_index or 1) - 1)
    local dst_tr = reaper.GetTrack(0, (args.dest_track_index or 1) - 1)
    if not src_tr or not dst_tr then return { error = "Source or destination track not found" } end
    
    local idx = reaper.CreateTrackSend(src_tr, dst_tr)
    if args.volume_db then
        reaper.SetTrackSendInfo_Value(src_tr, 0, idx, "D_VOL", 10 ^ (args.volume_db / 20))
    end
    
    local s_ch = parse_channels(args.src_chan)
    if s_ch then reaper.SetTrackSendInfo_Value(src_tr, 0, idx, "I_SRCCHAN", s_ch) end
    
    local d_ch = parse_channels(args.dst_chan)
    if d_ch then reaper.SetTrackSendInfo_Value(src_tr, 0, idx, "I_DSTCHAN", d_ch) end
    
    return { status = "ok", index = idx + 1 }
end

function Tools.set_track_send_info(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local idx = (args.send_index or 1) - 1
    
    if args.volume_db then
        reaper.SetTrackSendInfo_Value(tr, 0, idx, "D_VOL", 10 ^ (args.volume_db / 20))
    end
    if args.pan then
        reaper.SetTrackSendInfo_Value(tr, 0, idx, "D_PAN", args.pan)
    end
    if args.mute ~= nil then
        reaper.SetTrackSendInfo_Value(tr, 0, idx, "B_MUTE", args.mute and 1 or 0)
    end
    
    local s_ch = parse_channels(args.src_chan)
    if s_ch then reaper.SetTrackSendInfo_Value(tr, 0, idx, "I_SRCCHAN", s_ch) end
    
    local d_ch = parse_channels(args.dst_chan)
    if d_ch then reaper.SetTrackSendInfo_Value(tr, 0, idx, "I_DSTCHAN", d_ch) end
    
    return { status = "ok" }
end

function Tools.delete_track_send(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local idx = (args.send_index or 1) - 1
    
    local ok = reaper.RemoveTrackSend(tr, 0, idx)
    return { status = ok and "ok" or "error" }
end

function Tools.list_track_fx_params(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local fx_idx = args.fx_index or 0
    local num_params = reaper.TrackFX_GetNumParams(tr, fx_idx)
    local params = {}
    for i = 0, num_params - 1 do
        local _, name = reaper.TrackFX_GetParamName(tr, fx_idx, i, "")
        local val = reaper.TrackFX_GetParam(tr, fx_idx, i)
        local _, formatted = reaper.TrackFX_GetFormattedParamValue(tr, fx_idx, i, "")
        table.insert(params, { index = i, name = name, value = val, formatted = formatted })
    end
    return params
end

function Tools.set_track_fx_param(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local fx_idx = args.fx_index or 0
    local param_idx = args.param_index or 0
    local val = args.value or 0
    reaper.TrackFX_SetParam(tr, fx_idx, param_idx, val)
    return { status = "ok" }
end

function Tools.get_track_fx_pins(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local fx_idx = args.fx_index or 0
    
    local _, num_ins, num_outs = reaper.TrackFX_GetIOSize(tr, fx_idx)
    
    local pins = { inputs = {}, outputs = {} }
    
    for i = 0, num_ins - 1 do
        local low, high = reaper.TrackFX_GetPinMappings(tr, fx_idx, 0, i)
        table.insert(pins.inputs, { pin = i + 1, channels = mask_to_channels(low, high) })
    end
    
    for i = 0, num_outs - 1 do
        local low, high = reaper.TrackFX_GetPinMappings(tr, fx_idx, 1, i)
        table.insert(pins.outputs, { pin = i + 1, channels = mask_to_channels(low, high) })
    end
    
    return pins
end

function Tools.set_track_fx_pins(args)
    local tr = reaper.GetTrack(0, (args.track_index or 1) - 1)
    if not tr then return { error = "Track not found" } end
    local fx_idx = args.fx_index or 0
    local is_output = args.is_output and 1 or 0
    local pin_idx = (args.pin_index or 1) - 1
    
    local low, high
    if args.channels then
        low, high = channels_to_mask(args.channels)
    else
        low, high = args.low32 or 0, args.high32 or 0
    end
    
    local ok = reaper.TrackFX_SetPinMappings(tr, fx_idx, is_output, pin_idx, low, high)
    return { status = ok and "ok" or "error" }
end

function Tools.get_time_selection(args)
    local start_t, end_t = reaper.GetSet_LoopTimeRange(false, false, 0, 0, false)
    local has_sel = (start_t ~= end_t)
    local start_b = reaper.TimeMap_timeToQN(start_t)
    local end_b = reaper.TimeMap_timeToQN(end_t)
    return {
        has_selection = has_sel,
        start_seconds = start_t,
        end_seconds = end_t,
        start_beats = start_b,
        end_beats = end_b
    }
end

function Tools.list_markers(args)
    local markers = {}
    local idx = 0
    while true do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers3(0, idx)
        if retval == 0 then break end
        
        local m = {
            id = markrgnindexnumber,
            name = name,
            pos_seconds = pos,
            pos_beats = reaper.TimeMap_timeToQN(pos),
            is_region = isrgn
        }
        if isrgn then
            m.end_seconds = rgnend
            m.end_beats = reaper.TimeMap_timeToQN(rgnend)
        end
        table.insert(markers, m)
        idx = idx + 1
    end
    return markers
end

function Tools.create_marker(args)
    local is_beats = args.is_beats ~= false
    local is_region = args.is_region == true
    local pos = args.position or 0
    local rgnend = args.end_position or 0
    
    if is_beats then
        pos = reaper.TimeMap_QNToTime(pos)
        rgnend = reaper.TimeMap_QNToTime(rgnend)
    end
    
    local name = args.name or ""
    local mark_id = reaper.AddProjectMarker2(0, is_region, pos, rgnend, name, -1, 0)
    
    return { status = "ok", id = mark_id }
end

function Tools.get_selected_items(args)
    local count = reaper.CountSelectedMediaItems(0)
    local items = {}
    for i = 0, count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        if item then
            local tr = reaper.GetMediaItem_Track(item)
            local track_idx = math.floor(reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER"))
            
            local item_idx = -1
            for j = 0, reaper.CountTrackMediaItems(tr) - 1 do
                if reaper.GetTrackMediaItem(tr, j) == item then
                    item_idx = j + 1
                    break
                end
            end
            
            local take = reaper.GetActiveTake(item)
            local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local start_qn = reaper.TimeMap_timeToQN(pos)
            local end_qn = reaper.TimeMap_timeToQN(pos + len)
            local name = "[Unnamed]"
            local itype = "Audio"
            
            if take then
                local _, tname = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
                name = tname
                if reaper.TakeIsMIDI(take) then
                    itype = "MIDI"
                end
            end
            
            table.insert(items, {
                track_index = track_idx,
                item_index = item_idx,
                name = name,
                type = itype,
                pos_beats = start_qn,
                len_beats = end_qn - start_qn,
                pos_seconds = pos,
                len_seconds = len
            })
        end
    end
    return items
end


local function main()
    local f = io.open(cmd_file, "r")
    if f then
        local content = f:read("*a")
        f:close()
        os.remove(cmd_file)
        local cmd = json_decode(content)
        if cmd and cmd.id and cmd.tool then
            local result = Tools[cmd.tool] and Tools[cmd.tool](cmd.args) or { error = "Unknown tool" }
            local out = io.open(resp_file .. ".tmp", "w")
            if out then
                out:write(json_encode({ id = cmd.id, ok = true, result = result }))
                out:close()
                os.remove(resp_file)
                os.rename(resp_file .. ".tmp", resp_file)
            end
        end
    end
    reaper.defer(main)
end

reaper.ShowConsoleMsg("Reaper MCP Bridge V2 Started (V0.4)\n")
main()
