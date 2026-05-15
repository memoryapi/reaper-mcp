from reaper_mcp.rmid import RMID

def test_rmid():
    text = """BPM:120 SIG:4/4

TRACK "Piano RH" CH:1
FX: Pianoteq VSTi | Reverb VST
E4   0.000   0.500   90
G4   0.500   0.500   85
B4   1.000   1.000   92
CC64: 0.000=127 3.900=0
"""
    # Parse
    data = RMID.parse(text)
    print("Parsed Data:")
    print(data)
    
    # Serialize back
    new_text = RMID.serialize(data)
    print("\nSerialized Text:")
    print(new_text)
    
    assert "E4" in new_text
    assert "CC64" in new_text
    assert "127" in new_text
    print("\nRMID Codec Test Passed!")

if __name__ == "__main__":
    test_rmid()
