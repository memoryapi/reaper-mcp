import re
from typing import List, Dict, Optional, Any

class RMID:
    """RMID (Reaper MIDI Compact) Codec for Python"""
    
    PITCH_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    PITCH_MAP = {
        "C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, 
        "F#": 6, "Gb": 6, "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11
    }

    @classmethod
    def get_pitch_name(cls, n: int) -> str:
        octave = (n // 12) - 1
        name = cls.PITCH_NAMES[n % 12]
        return f"{name}{octave}"

    @classmethod
    def get_note_number(cls, pitch_str: str) -> int:
        match = re.match(r"([A-Ga-g][#sb]*)(-?\d+)", pitch_str)
        if not match:
            return 60
        
        name, octave = match.groups()
        base = name[0].upper() + name[1:].lower()
        
        # Normalize
        norm = {"Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#"}.get(base, base)
        note = cls.PITCH_MAP.get(norm, 0)
        return (int(octave) + 1) * 12 + note

    @classmethod
    def serialize(cls, data: Dict[str, Any]) -> str:
        lines = []
        
        # Header
        header_parts = []
        if "bpm" in data: header_parts.append(f"BPM:{data['bpm']}")
        if "sig" in data: header_parts.append(f"SIG:{data['sig']}")
        if header_parts:
            lines.append(" ".join(header_parts))
            lines.append("")
            
        # Tracks
        for track in data.get("tracks", []):
            track_line = f'TRACK "{track.get("name", "Untitled")}"'
            if "channel" in track:
                track_line += f" CH:{track['channel']}"
            lines.append(track_line)
            
            if "fx" in track and track["fx"]:
                lines.append(f"FX: {' | '.join(track['fx'])}")
            
            for item in track.get("items", []):
                if "pos" in item and "len" in item:
                    lines.append(f"ITEM {item['pos']:.3f} {item['len']:.3f}")
                
                for note in item.get("notes", []):
                    lines.append(f"{note['pitch']:<4} {note['start']:<7.3f} {note['dur']:<7.3f} {note['vel']}")
                
                # CCs
                cc_dict = item.get("cc", {})
                for num in sorted(cc_dict.keys()):
                    events = cc_dict[num]
                    ev_strs = [f"{ev['time']:.3f}={ev['value']}" for ev in events]
                    lines.append(f"CC{num}: {' '.join(ev_strs)}")
            
            lines.append("") # Spacer
            
        return "\n".join(lines).strip()

    @classmethod
    def parse(cls, text: str) -> Dict[str, Any]:
        data = {"tracks": []}
        current_track = None
        current_item = None
        
        for line in text.splitlines():
            # Strip comments and trim
            line = re.sub(r"#.*", "", line).strip()
            if not line:
                continue
                
            if line.startswith("BPM:") or line.startswith("SIG:"):
                bpm_match = re.search(r"BPM:(\d+)", line)
                sig_match = re.search(r"SIG:(\d+/\d+)", line)
                if bpm_match: data["bpm"] = int(bpm_match.group(1))
                if sig_match: data["sig"] = sig_match.group(1)
                
            elif line.startswith("TRACK"):
                name_match = re.search(r'TRACK "([^"]+)"', line) or re.search(r"TRACK ([\w\s]+)", line)
                ch_match = re.search(r"CH:(\d+)", line)
                current_track = {
                    "name": name_match.group(1) if name_match else "Untitled",
                    "items": []
                }
                if ch_match:
                    current_track["channel"] = int(ch_match.group(1))
                data["tracks"].append(current_track)
                current_item = None
                
            elif line.startswith("FX:"):
                if current_track is not None:
                    fx_str = line[3:].strip()
                    current_track["fx"] = [f.strip() for f in fx_str.split("|") if f.strip()]
                    
            elif line.startswith("ITEM"):
                if current_track is not None:
                    parts = line.split()
                    if len(parts) >= 3:
                        current_item = {
                            "pos": float(parts[1]),
                            "len": float(parts[2]),
                            "notes": [],
                            "cc": {}
                        }
                        current_track["items"].append(current_item)
                        
            elif line.startswith("CC"):
                if current_item is not None:
                    num_match = re.match(r"CC(\d+):", line)
                    if num_match:
                        num = int(num_match.group(1))
                        ev_str = line.split(":", 1)[1].strip()
                        current_item["cc"][num] = []
                        for pair in ev_str.split():
                            if "=" in pair:
                                time, val = pair.split("=")
                                current_item["cc"][num].append({
                                    "time": float(time),
                                    "value": int(float(val))
                                })
            else:
                # Note line: Pitch Start Dur Vel
                parts = line.split()
                if len(parts) >= 4 and current_track is not None:
                    if current_item is None:
                        current_item = {"pos": 0, "len": 0, "notes": [], "cc": {}}
                        current_track["items"].append(current_item)
                    
                    try:
                        current_item["notes"].append({
                            "pitch": parts[0],
                            "start": float(parts[1]),
                            "dur": float(parts[2]),
                            "vel": int(float(parts[3]))
                        })
                    except ValueError:
                        pass # Not a note line
                        
        return data
