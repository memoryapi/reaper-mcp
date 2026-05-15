-- Diagnostic script to check TimeMap_GetTimeSigAtTime values
local retval, v1, v2, v3 = reaper.TimeMap_GetTimeSigAtTime(0, 0)
reaper.ShowConsoleMsg("Retval: " .. tostring(retval) .. "\n")
reaper.ShowConsoleMsg("V1: " .. tostring(v1) .. "\n")
reaper.ShowConsoleMsg("V2: " .. tostring(v2) .. "\n")
reaper.ShowConsoleMsg("V3: " .. tostring(v3) .. "\n")
