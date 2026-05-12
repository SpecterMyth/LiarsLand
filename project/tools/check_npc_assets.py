from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CHAPTERS = [
    ROOT / "data" / "chapter_01.json",
    ROOT / "data" / "council_chapter_01.json",
    ROOT / "data" / "council_chapter_02.json",
    ROOT / "data" / "council_chapter_03.json",
]
GENERATED = ROOT / "assets" / "generated"
CHARACTERS = ROOT / "assets" / "ui" / "characters"
HEADICONS = CHARACTERS / "headicon"
PORTRAITS = CHARACTERS / "portrait"
PORTRAIT_HALVES = CHARACTERS / "portrait_half"
SELECT_CARDS = ROOT / "assets" / "ui" / "characters" / "cards"


def main() -> int:
    errors: list[str] = []
    total_npcs = 0

    for chapter_path in CHAPTERS:
        data = json.loads(chapter_path.read_text(encoding="utf-8"))
        chapter_name = chapter_path.name
        npcs = data.get("npcs", [])
        seen: set[str] = set()

        if chapter_name == "chapter_01.json" and len(npcs) != 20:
            errors.append(f"{chapter_name}: expected 20 NPCs, found {len(npcs)}.")

        for npc in npcs:
            npc_id = str(npc.get("id", ""))
            if not npc_id:
                errors.append(f"{chapter_name}: NPC is missing id.")
                continue
            if npc_id in seen:
                errors.append(f"{chapter_name}: duplicate NPC id: {npc_id}")
            seen.add(npc_id)
            total_npcs += 1

            portrait = str(npc.get("portrait", ""))
            background = str(npc.get("background", npc.get("scene", "")))
            select_card = portrait.replace("_portrait.png", "_select_card.png")
            required = [
                PORTRAITS / portrait,
                PORTRAIT_HALVES / str(npc.get("portrait_half", portrait.replace(".png", "_half.png"))),
                HEADICONS / portrait.replace("_portrait.png", "_head_avatar.png"),
                SELECT_CARDS / select_card,
                GENERATED / background,
            ]
            for path in required:
                if not path.exists():
                    errors.append(f"{chapter_name}:{npc_id}: missing {path.relative_to(ROOT)}")

    if errors:
        print("NPC asset check failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"NPC asset check passed for {total_npcs} NPC references across {len(CHAPTERS)} chapters.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
