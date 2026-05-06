from __future__ import annotations

from pathlib import Path
from shutil import copyfile


ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = ROOT.parent
SOURCE = PROJECT_ROOT / "ui" / "final_references"
OUT = ROOT / "assets" / "generated" / "ui" / "card"

PAGES = {
    "round_start_opponent_select_final_effect_v4_card.png": "page_round_start_v4.png",
    "shop_page_final_effect_v5_card_unified.png": "page_shop_v5.png",
    "ascension_dominion_final_effect_v5_card_unified.png": "page_ascension_v5.png",
}


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for source_name, output_name in PAGES.items():
        copyfile(SOURCE / source_name, OUT / output_name)
    print(f"Synced final reference UI pages to {OUT}")


if __name__ == "__main__":
    main()
