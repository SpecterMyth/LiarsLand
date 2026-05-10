from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHAPTER = ROOT / "data" / "chapter_01.json"
GENERATED = ROOT / "assets" / "generated"
SELECT_CARDS = ROOT / "assets" / "ui" / "characters" / "cards"


def main() -> int:
    data = json.loads(CHAPTER.read_text(encoding="utf-8"))
    npcs = data.get("npcs", [])
    errors: list[str] = []
    seen: set[str] = set()

    if len(npcs) != 20:
        errors.append(f"Expected 20 NPCs, found {len(npcs)}.")

    for npc in npcs:
        npc_id = str(npc.get("id", ""))
        if not npc_id:
            errors.append("NPC is missing id.")
            continue
        if npc_id in seen:
            errors.append(f"Duplicate NPC id: {npc_id}")
        seen.add(npc_id)

        portrait = str(npc.get("portrait", ""))
        background = str(npc.get("background", ""))
        required = [
            GENERATED / portrait,
            GENERATED / portrait.replace(".png", "_half.png"),
            GENERATED / portrait.replace("_portrait.png", "_head_avatar.png"),
            SELECT_CARDS / f"{npc_id}_select_card.png",
            GENERATED / background,
        ]
        for path in required:
            if not path.exists():
                errors.append(f"{npc_id}: missing {path.relative_to(ROOT)}")

    if errors:
        print("NPC asset check failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"NPC asset check passed for {len(npcs)} NPCs.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
