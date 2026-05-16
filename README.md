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
- `set_track_channels(track_index, num_channels)`: Set total audio channels (e.g., 4 or 6 for sidechaining).
- `list_vsts(filter)`: Search for installed VST plugins.
- `add_fx(track_index, fx_name)`: Add an FX/VST to a track.
- `delete_track_fx(track_index, fx_index)`: Remove an FX.
- `list_track_fx_params(track_index, fx_index)`: List all parameters for a specific FX, including current values.
- `set_track_fx_param(track_index, fx_index, param_index, value)`: Set a parameter value (normalized 0.0 to 1.0). For dropdowns, use steps (e.g., 0.0, 0.5, 1.0).

### Routing & Sends
- `list_track_sends(track_index)`: View outgoing sends.
- `create_track_send(source_index, dest_index, volume_db, src_chan, dst_chan)`: Create a new send. Use strings like `"3/4"` for sidechains.
- `set_track_send_info(track_index, send_index, ...)`: Update volume, pan, mute, or channel mapping.
- `delete_track_send(track_index, send_index)`: Remove a send.

### Media & Composition
- `list_media_items(track_index)`: List **all** timeline objects (Audio and MIDI) with their type and position.
- `list_midi_items(track_index)`: List only MIDI items with detailed note/CC counts.
- `move_media_item(track_index, item_index, new_pos_beats)`: Move any item (Audio or MIDI) to a new position.
- `delete_media_item(track_index, item_index)`: Remove any item from the timeline.
- `get_track_midi(track_index)`: Read MIDI data in RMID format (MIDI only).
- `insert_midi_item(track_index, rmid)`: Add new MIDI data.
- `set_midi_item(track_index, item_index, rmid)`: Replace MIDI content.
- `copy_media_item(...)`: Copy items (supports MIDI pooling for MIDI).
- `describe_track(track_index)`: Musical analysis of the track content.

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
