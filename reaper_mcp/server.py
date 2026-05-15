import asyncio
from typing import Optional
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
def move_midi_item(track_index: int, item_index: int, new_pos_beats: float) -> str:
    """Move a MIDI item to a new position in beats."""
    result = ipc.send_command("move_midi_item", {
        "track_index": track_index, 
        "item_index": item_index, 
        "new_pos_beats": new_pos_beats
    })
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
def copy_midi_item(track_index: int, item_index: int, new_pos_beats: float, dest_track_index: Optional[int] = None, pooled: bool = False) -> str:
    """Copy a MIDI item (optionally pooled/ghost copy)."""
    result = ipc.send_command("copy_midi_item", {
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
async def describe_track(track_index: int) -> str:
    """Get a musical summary of the track (type, range, density)."""
    result = ipc.send_command("describe_track", {"track_index": track_index})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def list_midi_items(track_index: int) -> str:
    """List all MIDI items on a track with their positions and event counts."""
    result = ipc.send_command("list_midi_items", {"track_index": track_index})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def get_project_midi_overview() -> str:
    """Get a compact summary of all tracks and their MIDI item positions."""
    result = ipc.send_command("get_project_midi_overview", {})
    import json
    return json.dumps(result, indent=2)

@mcp.tool()
async def get_track_midi(track_index: int) -> str:
    """
    Read all MIDI data from a track in RMID format.
    
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
    result = ipc.send_command("get_track_midi", {"track_index": track_index})
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
    Filter by name if provided.
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

if __name__ == "__main__":
    mcp.run(transport="stdio")
