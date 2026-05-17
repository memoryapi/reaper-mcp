import asyncio
from typing import Optional, Any
from mcp.server.fastmcp import FastMCP
from reaper_mcp.ipc import ReaperIPC

# Initialize Reaper IPC
ipc = ReaperIPC()

# Initialize FastMCP server
mcp = FastMCP("reaper-mcp")

RMID_DOCS = """
RMID (Reaper MIDI Compact) Format:
- Note line: [Pitch] [StartBeats] [DurBeats] [Velocity]
- Pitch: C4, C#4, Bb3, etc.
- Example: 
  TRACK "Piano"
  C4  0  1.0  90
  E4  0  1.0  85
  G4  0  1.0  92
  CC64: 0=127 3.9=0
"""

@mcp.tool()
async def get_project_info() -> str:
    """Get basic project information (BPM, Time Sig, Cursor, etc.)"""
    result = ipc.send_command("get_project_info", {})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_tempo(bpm: float) -> str:
    """Set the project BPM."""
    result = ipc.send_command("set_tempo", {"bpm": bpm})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_time_signature(numerator: int, denominator: int) -> str:
    """Set the project time signature."""
    result = ipc.send_command("set_time_signature", {"numerator": numerator, "denominator": denominator})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_cursor_position(position: float, is_beats: bool = False) -> str:
    """Move the edit cursor. Set is_beats=True to use quarter notes."""
    result = ipc.send_command("set_cursor_position", {"position": position, "is_beats": is_beats})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def create_track(name: str = "New Track") -> str:
    """Create a new track with an optional name."""
    result = ipc.send_command("create_track", {"name": name})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def delete_track(track_index: int) -> str:
    """Delete a track by its 1-based index."""
    result = ipc.send_command("delete_track", {"track_index": track_index})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
def set_track_midi(track_index: int, rmid: str) -> str:
    """
    [WARNING: DESTRUCTIVE] Replaces ALL MIDI on the track with new RMID data.
    Existing items on this track will be DELETED. 

    RMID SCHEMA:
    - TRACK "Name" (Required)
    - ITEM [StartBeats] [LengthBeats] (Recommended)
    - [Pitch] [StartBeats] [DurBeats] [Velocity] (One per line)
    - Comments: Start with ';' or '//' or '#'
    
    EXAMPLE:
    TRACK "Piano"
    ITEM 0 4
    C4 0 1.0 90
    E4 1 1.0 80
    """
    result = ipc.send_command("set_track_midi", {"track_index": track_index, "rmid": rmid})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
def insert_midi_item(track_index: int, rmid: str) -> str:
    """
    Add new MIDI items to a track WITHOUT deleting existing ones.
    Useful for building songs layer-by-layer.

    RMID SCHEMA:
    TRACK "Name"
    ITEM [StartBeats] [LengthBeats]
    [Pitch] [RelativeStart] [Duration] [Velocity]
    """
    result = ipc.send_command("insert_midi_item", {"track_index": track_index, "rmid": rmid})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
def list_midi_items(track_index: int, start_beats: Optional[float] = None, end_beats: Optional[float] = None) -> str:
    """List all MIDI items on a track with their positions and event counts, optionally filtered by range."""
    result = ipc.send_command("list_midi_items", {
        "track_index": track_index,
        "start_beats": start_beats,
        "end_beats": end_beats
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
def list_media_items(track_index: int, start_beats: Optional[float] = None, end_beats: Optional[float] = None) -> str:
    """List ALL media items (Audio and MIDI) on a track with their types and positions, optionally filtered by range."""
    result = ipc.send_command("list_media_items", {
        "track_index": track_index,
        "start_beats": start_beats,
        "end_beats": end_beats
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
def move_media_item(track_index: int, item_index: int, new_pos_beats: float) -> str:
    """Move a media item (Audio or MIDI) to a new position in beats."""
    result = ipc.send_command("move_media_item", {
        "track_index": track_index, 
        "item_index": item_index, 
        "new_pos_beats": new_pos_beats
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
def delete_media_item(track_index: int, item_index: int) -> str:
    """Delete a specific media item (Audio or MIDI) from a track."""
    result = ipc.send_command("delete_media_item", {"track_index": track_index, "item_index": item_index})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
def copy_media_item(track_index: int, item_index: int, new_pos_beats: float, dest_track_index: Optional[int] = None, pooled: bool = False) -> str:
    """Copy a media item (supports MIDI pooling for MIDI items)."""
    result = ipc.send_command("copy_media_item", {
        "track_index": track_index,
        "item_index": item_index,
        "new_pos_beats": new_pos_beats,
        "dest_track_index": dest_track_index,
        "pooled": pooled
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_track_volume(track_index: int, volume_db: float) -> str:
    """Set the volume of a track in dB (e.g., 0.0, -6.0)."""
    result = ipc.send_command("set_track_volume", {"track_index": track_index, "volume_db": volume_db})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def list_tracks() -> str:
    """List all tracks in the project with their basic status."""
    result = ipc.send_command("list_tracks", {})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def get_track_info(track_index: int) -> str:
    """Get detailed info for a specific track, including FX chain."""
    result = ipc.send_command("get_track_info", {"track_index": track_index})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def describe_track(track_index: int, start_beats: Optional[float] = None, end_beats: Optional[float] = None) -> str:
    """Get a musical summary of the track (type, range, density), optionally filtered by range."""
    result = ipc.send_command("describe_track", {
        "track_index": track_index,
        "start_beats": start_beats,
        "end_beats": end_beats
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def get_project_midi_overview() -> str:
    """Get a compact summary of all tracks and their MIDI item positions."""
    result = ipc.send_command("get_project_midi_overview", {})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def get_track_midi(track_index: int, start_beats: Optional[float] = None, end_beats: Optional[float] = None) -> str:
    """
    Read MIDI data from a track in RMID format, optionally filtered by range.
    
    RMID Format:
    - Note line: [Pitch] [StartBeats] [DurBeats] [Velocity]
    - Pitch: C4, C#4, Bb3, etc.
    - Example: 
      TRACK "Piano"
      C4  0  1.0  90
      E4  0  1.0  85
      G4  0  1.0  92
      CC64: 0=127 3.9=0
    """
    result = ipc.send_command("get_track_midi", {
        "track_index": track_index,
        "start_beats": start_beats,
        "end_beats": end_beats
    })
    import json
    if isinstance(result, dict): return json.dumps(result, indent=2)
    return result

@mcp.tool()
async def get_midi_item(track_index: int, item_index: int) -> str:
    """
    Read MIDI data from a single specific MIDI item/clip in RMID format.
    Provides targeted access without fetching all MIDI data on the track.
    """
    result = ipc.send_command("get_midi_item", {"track_index": track_index, "item_index": item_index})
    import json
    if isinstance(result, dict): return json.dumps(result, indent=2)
    return result

@mcp.tool()

def set_midi_item(track_index: int, item_index: int, rmid: str) -> str:
    """
    [WARNING: DESTRUCTIVE] Replaces the MIDI content INSIDE a specific existing item.
    This wipes the notes inside the item and replaces them with new RMID data.
    """
    result = ipc.send_command("set_midi_item", {"track_index": track_index, "item_index": item_index, "rmid": rmid})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
def delete_midi_item(track_index: int, item_index: int) -> str:
    """
    Delete a specific MIDI item from a track.
    Use 'list_midi_items' to find the correct item_index.
    """
    result = ipc.send_command("delete_midi_item", {"track_index": track_index, "item_index": item_index})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def list_vsts(filter: Optional[str] = None) -> str:
    """
    List all installed VST plugins.
    Filter by name or manufacturer if provided.
    
    RECOMMENDATION:
    If no filter is provided, listing all plugins can yield hundreds of results.
    To work efficiently:
    1. You are fully free to query the entire list if needed by calling `list_vsts()`.
    2. Alternatively, you can use `list_plugin_manufacturers()` first to get a quick, high-level view of who developed the plugins on this system.
    3. You can then search specific brands or names directly using a filter (e.g. `list_vsts(filter="BABY Audio")` or `list_vsts(filter="reacomp")`).
    """
    result = ipc.send_command("list_vsts", {"filter": filter})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def add_fx(track_index: int, fx_name: str, instantiate: bool = True) -> str:
    """
    Add an FX to a track by name.
    """
    result = ipc.send_command("add_fx", {"track_index": track_index, "fx_name": fx_name, "instantiate": instantiate})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def delete_track_fx(track_index: int, fx_index: int) -> str:
    """
    Delete an FX from a track by its 0-based index.
    """
    result = ipc.send_command("delete_track_fx", {"track_index": track_index, "fx_index": fx_index})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def move_track(track_index: int, target_index: int) -> str:
    """
    Move a track to a new index (1-based).
    """
    result = ipc.send_command("move_track", {"track_index": track_index, "target_index": target_index})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_track_folder_depth(track_index: int, depth: int) -> str:
    """
    Set track folder depth. 
    1 = Folder start, 0 = Normal, -1 = Last track in folder.
    """
    result = ipc.send_command("set_track_folder_depth", {"track_index": track_index, "depth": depth})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_track_color(track_index: int, r: int, g: int, b: int) -> str:
    """
    Set track color (0-255 for each channel).
    """
    result = ipc.send_command("set_track_color", {"track_index": track_index, "r": r, "g": g, "b": b})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_track_channels(track_index: int, num_channels: int) -> str:
    """
    Set the TOTAL number of audio channels for a track.
    - Default is 2 (Stereo).
    - Set to 4 to enable one sidechain input (channels 3/4).
    - Set to 6 to enable two sidechain inputs (channels 3/4 and 5/6).
    """
    result = ipc.send_command("set_track_channels", {"track_index": track_index, "num_channels": num_channels})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def list_track_sends(track_index: int) -> str:
    """
    List all sends for a specific track.
    """
    result = ipc.send_command("list_track_sends", {"track_index": track_index})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def create_track_send(source_track_index: int, dest_track_index: int, volume_db: float = 0.0, src_chan: Optional[Any] = None, dst_chan: Optional[Any] = None) -> str:
    """
    Create a send from source track to destination track.
    
    CHANNEL MAPPING (CRITICAL):
    - ALWAYS use STRINGS for stereo pairs: "1/2", "3/4", "5/6", etc.
    - "3/4" is the standard sidechain input for most plugins.
    - "5/6" can be used for secondary sidechains (requires manual pin mapping).
    - WARNING: Do NOT use integers. An integer '3' is a raw bitfield that maps to '4/5', NOT '3/4'.
    """
    result = ipc.send_command("create_track_send", {
        "source_track_index": source_track_index, 
        "dest_track_index": dest_track_index,
        "volume_db": volume_db,
        "src_chan": src_chan,
        "dst_chan": dst_chan
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_track_send_info(track_index: int, send_index: int, volume_db: Optional[float] = None, pan: Optional[float] = None, mute: Optional[bool] = None, src_chan: Optional[Any] = None, dst_chan: Optional[Any] = None) -> str:
    """
    Update an existing send's parameters.
    
    CHANNEL MAPPING (CRITICAL):
    - ALWAYS use STRINGS for stereo pairs: "1/2", "3/4", "5/6", etc.
    - WARNING: Do NOT use integers. An integer '3' is a raw bitfield that maps to '4/5', NOT '3/4'.
    """
    result = ipc.send_command("set_track_send_info", {
        "track_index": track_index,
        "send_index": send_index,
        "volume_db": volume_db,
        "pan": pan,
        "mute": mute,
        "src_chan": src_chan,
        "dst_chan": dst_chan
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def delete_track_send(track_index: int, send_index: int) -> str:
    """
    Delete a specific send from a track.
    """
    result = ipc.send_command("delete_track_send", {"track_index": track_index, "send_index": send_index})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def list_track_fx_params(track_index: int, fx_index: int) -> str:
    """
    List all parameters for a specific FX on a track.
    """
    result = ipc.send_command("list_track_fx_params", {"track_index": track_index, "fx_index": fx_index})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_track_fx_param(track_index: int, fx_index: int, param_index: int, value: float) -> str:
    """
    Set a parameter value for an FX (normalized 0.0 to 1.0).
    """
    result = ipc.send_command("set_track_fx_param", {
        "track_index": track_index,
        "fx_index": fx_index,
        "param_index": param_index,
        "value": value
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def get_track_fx_pins(track_index: int, fx_index: int) -> str:
    """
    List the input and output pin mappings for a specific FX.
    Shows which track channels are routed to each plugin pin.
    """
    result = ipc.send_command("get_track_fx_pins", {"track_index": track_index, "fx_index": fx_index})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_track_fx_pins(track_index: int, fx_index: int, is_output: bool, pin_index: int, channels: list[int]) -> str:
    """
    Configure the pin mapping for an FX.
    - is_output: True for output pins, False for input pins.
    - pin_index: 1-based index of the plugin pin.
    - channels: List of 1-based track channel indices to map to this pin.
    """
    result = ipc.send_command("set_track_fx_pins", {
        "track_index": track_index,
        "fx_index": fx_index,
        "is_output": is_output,
        "pin_index": pin_index,
        "channels": channels
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def get_time_selection() -> str:
    """
    Get the active timeline selection (loop / time range selection).
    Returns start/end bounds in both seconds and beats, and indicates if a selection exists.
    """
    result = ipc.send_command("get_time_selection", {})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def list_markers() -> str:
    """
    List all project markers and regions, including their ID, name, position in seconds and beats,
    and end position (if it is a region).
    """
    result = ipc.send_command("list_markers", {})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def create_marker(name: str, position: float, is_beats: bool = True, is_region: bool = False, end_position: float = 0.0) -> str:
    """
    Create a project marker or region.
    - name: The text label for the marker or region.
    - position: The start position in beats/quarter notes (if is_beats is True) or seconds.
    - is_beats: If True, position is measured in beats; otherwise in seconds. Default is True.
    - is_region: If True, creates a region spanning from position to end_position. Default is False.
    - end_position: The end position of the region (beats or seconds). Only used if is_region is True.
    """
    result = ipc.send_command("create_marker", {
        "name": name,
        "position": position,
        "is_beats": is_beats,
        "is_region": is_region,
        "end_position": end_position
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def get_selected_items() -> str:
    """
    Get metadata for all currently selected media items across all tracks in the project.
    Provides track and item indexes, type (MIDI/Audio), position, and length.
    """
    result = ipc.send_command("get_selected_items", {})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def split_media_item(track_index: int, item_index: int, position_beats: float) -> str:
    """Split a media item at a specific beat position, creating a new item."""
    result = ipc.send_command("split_media_item", {
        "track_index": track_index,
        "item_index": item_index,
        "position_beats": position_beats
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_media_item_length(track_index: int, item_index: int, length_beats: float) -> str:
    """Set the length of a specific media item in beats."""
    result = ipc.send_command("set_media_item_length", {
        "track_index": track_index,
        "item_index": item_index,
        "length_beats": length_beats
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_media_item_take_offset(track_index: int, item_index: int, offset_beats: float) -> str:
    """Set the playback start offset (take offset) of a media item in beats."""
    result = ipc.send_command("set_media_item_take_offset", {
        "track_index": track_index,
        "item_index": item_index,
        "offset_beats": offset_beats
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_media_item_playrate(track_index: int, item_index: int, playrate: float) -> str:
    """Set the playrate (playback speed) of a specific media item (e.g. 0.5 for half speed)."""
    result = ipc.send_command("set_media_item_playrate", {
        "track_index": track_index,
        "item_index": item_index,
        "playrate": playrate
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_media_item_pitch(track_index: int, item_index: int, pitch: float) -> str:
    """Set the pitch shift of a specific media item in semitones (e.g., -12.0 for octave down)."""
    result = ipc.send_command("set_media_item_pitch", {
        "track_index": track_index,
        "item_index": item_index,
        "pitch": pitch
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_media_item_fades(track_index: int, item_index: int, fade_in_beats: float, fade_out_beats: float) -> str:
    """Apply fade-in and fade-out times in beats to a specific media item."""
    result = ipc.send_command("set_media_item_fades", {
        "track_index": track_index,
        "item_index": item_index,
        "fade_in_beats": fade_in_beats,
        "fade_out_beats": fade_out_beats
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_track_mute(track_index: int, mute: bool) -> str:
    """Cleanly mute or unmute a track by its 1-based index."""
    result = ipc.send_command("set_track_mute", {
        "track_index": track_index,
        "mute": mute
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def set_track_solo(track_index: int, solo: bool) -> str:
    """Cleanly solo or unsolo a track by its 1-based index."""
    result = ipc.send_command("set_track_solo", {
        "track_index": track_index,
        "solo": solo
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def insert_automation_point(track_index: int, envelope_name: str, position_beats: float, value: float) -> str:
    """Insert an automation envelope point on a track (e.g. for Volume, Pan, or VST FX parameters)."""
    result = ipc.send_command("insert_automation_point", {
        "track_index": track_index,
        "envelope_name": envelope_name,
        "position_beats": position_beats,
        "value": value
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def list_plugin_manufacturers() -> str:
    """
    List unique plugin manufacturers installed on the system (e.g. Cockos, BABY Audio, FabFilter, Arturia, Waves).
    
    RECOMMENDATION:
    1. Run this tool if you need a quick, lightweight summary of which VST companies are installed on the user's computer.
    2. This returns a compact list of developers.
    3. Once you identify a developer (e.g. "BABY Audio"), you can call `list_vsts(filter="BABY Audio")` to list their specific plugins cheaply and quickly.
    """
    result = ipc.send_command("list_plugin_manufacturers", {})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def check_overlapping_items(tolerance_beats: float = 0.01) -> str:
    """Analyze the project track-by-track and check for overlapping audio or MIDI clips."""
    result = ipc.send_command("check_overlapping_items", {
        "tolerance_beats": tolerance_beats
    })
    import json
    return json.dumps(result, indent=2)

if __name__ == "__main__":
    mcp.run(transport="stdio")


