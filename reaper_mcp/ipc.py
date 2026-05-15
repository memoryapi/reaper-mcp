import os
import json
import time
import uuid
import tempfile
from typing import Dict, Any, Optional

class ReaperIPC:
    def __init__(self, ipc_dir: Optional[str] = None):
        if ipc_dir is None:
            ipc_dir = os.path.join(tempfile.gettempdir(), "reaper_mcp_v2")
        
        self.ipc_dir = ipc_dir
        self.cmd_file = os.path.join(ipc_dir, "command.json")
        self.resp_file = os.path.join(ipc_dir, "response.json")
        
        if not os.path.exists(self.ipc_dir):
            os.makedirs(self.ipc_dir)
            
        # Clear any stale files
        self._cleanup()

    def _cleanup(self):
        for f in [self.cmd_file, self.resp_file]:
            if os.path.exists(f):
                try:
                    os.remove(f)
                except OSError:
                    pass

    def send_command(self, tool: str, args: Dict[str, Any], timeout: float = 10.0) -> Dict[str, Any]:
        cmd_id = str(uuid.uuid4())
        cmd_data = {
            "id": cmd_id,
            "tool": tool,
            "args": args
        }
        
        # Write to temp file first then rename to ensure atomicity
        tmp_cmd = self.cmd_file + ".tmp"
        with open(tmp_cmd, "w") as f:
            json.dump(cmd_data, f)
        
        if os.path.exists(self.cmd_file):
            os.remove(self.cmd_file)
        os.rename(tmp_cmd, self.cmd_file)
        
        # Wait for response
        start_time = time.time()
        while time.time() - start_time < timeout:
            if os.path.exists(self.resp_file):
                try:
                    with open(self.resp_file, "r") as f:
                        resp = json.load(f)
                    
                    if resp.get("id") == cmd_id:
                        os.remove(self.resp_file)
                        if not resp.get("ok"):
                            raise Exception(f"Reaper Error: {resp.get('error')}")
                        return resp.get("result")
                except (json.JSONDecodeError, PermissionError):
                    # File might be mid-write
                    time.sleep(0.01)
                    continue
            
            time.sleep(0.05)
            
        raise TimeoutError(f"Reaper bridge timed out after {timeout}s")

# Simple test if run directly
if __name__ == "__main__":
    ipc = ReaperIPC()
    print(f"IPC initialized at {ipc.ipc_dir}")
    try:
        res = ipc.send_command("ping", {}, timeout=2.0)
        print(f"Result: {res}")
    except Exception as e:
        print(f"Expected failure (bridge not running): {e}")
        print("Run the Lua bridge in Reaper to test fully.")
