# Reaper MCP Server

A bidirectional Model Context Protocol (MCP) server for REAPER, enabling AI-assisted music composition, track management, and project organization.

## Architecture

The project consists of two main components:
1. **Python MCP Server**: Exposes a set of high-level tools via the FastMCP framework.
2. **Lua Bridge**: A background script running inside REAPER that monitors a file-based IPC channel to execute commands and return project state.

## Setup

### 1. REAPER Side
- Copy `lua_bridge/reaper_mcp_bridge_v2.lua` and `lua_bridge/rmid_lib.lua` to your REAPER Scripts folder.
- Run `reaper_mcp_bridge_v2.lua` via the Actions list. It will start a deferred loop monitoring for commands.

### 2. Python Side
- Install dependencies: `pip install mcp`
- Run the server: `python -m reaper_mcp.server` (or via your MCP client).

## Available Tools

### Project Management
- `get_project_info()`: Get current BPM, time signature, and cursor position.
- `set_tempo(bpm)`: Update the project BPM.
- `set_time_signature(numerator, denominator)`: Update the time signature.
- `set_cursor_position(position, is_beats)`: Move the edit cursor.

### Track & FX Management
- `list_tracks()`: List all tracks with indices and FX counts.
- `create_track(name)`: Create a new track.
- `delete_track(track_index)`: Remove a track.
- `move_track(track_index, target_index)`: Reorder tracks.
- `set_track_volume(track_index, volume_db)`: Set track gain.
- `set_track_color(track_index, r, g, b)`: Set track visual color.
- `set_track_folder_depth(track_index, depth)`: Manage folder hierarchies (1=start, 0=normal, -1=end).
- `list_vsts(filter)`: Search for installed VST plugins.
- `add_fx(track_index, fx_name)`: Add an FX/VST to a track.
- `delete_track_fx(track_index, fx_index)`: Remove an FX.

### Routing & Sends
- `list_track_sends(track_index)`: View outgoing sends.
- `create_track_send(source_index, dest_index, volume_db)`: Create a new send.
- `set_track_send_info(track_index, send_index, ...)`: Update volume, pan, or mute status.
- `delete_track_send(track_index, send_index)`: Remove a send.

### MIDI & Composition
- `get_project_midi_overview()`: High-level summary of MIDI items across all tracks.
- `get_track_midi(track_index)`: Read all MIDI data from a track in RMID format.
- `describe_track(track_index)`: Get a musical analysis (pitch range, density, common durations).
- `list_midi_items(track_index)`: List all MIDI items on a specific track.
- `insert_midi_item(track_index, rmid)`: Add new MIDI data without deleting existing items.
- `set_midi_item(track_index, item_index, rmid)`: Replace the content of a specific item.
- `move_midi_item(track_index, item_index, new_pos_beats)`: Move an item.
- `delete_midi_item(track_index, item_index)`: Remove an item.

## RMID Format

The server uses **RMID** (Reaper Minimalistic Interchange Data) for MIDI exchange. It is a human-readable/LLM-friendly format:

```text
TRACK "Lead"
ITEM 0 4
C4 0 1.0 100
E4 1 1.0 100
G4 2 2.0 100
```

## Requirements
- REAPER 6.x+
- SWS Extensions (Highly recommended)
- Python 3.10+
