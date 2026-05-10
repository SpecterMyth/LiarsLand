#!/usr/bin/env python3
"""Codex-driven UI page pipeline for LiarsLand.

This tool intentionally does not call any image generation API. It creates a
deterministic workflow around Codex's built-in Imagegen: asset planning,
prompt-task generation, candidate registration, approval, importing, Godot
resource mapping, and screenshot comparison.
"""

from __future__ import annotations

import argparse
import base64
import json
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
PROJECT_DIR = ROOT / "project"
SOURCE_ROOT = ROOT / "ui" / "source_pages"
GENERATED_ROOT = ROOT / "ui" / "generated_pages"
COMMON_ASSET_DIR = PROJECT_DIR / "assets" / "ui" / "common"
LEGACY_SHOP_DIR = PROJECT_DIR / "assets" / "generated" / "ui" / "shop_v2"
RUNTIME_CARD_DIR = ROOT / "ui" / "concepts" / "runtime_card_v2"

STATUS_ORDER = [
    "initialized",
    "planned",
    "prompt_ready",
    "generated",
    "approved",
    "imported",
    "wired",
    "verified",
]


@dataclass(frozen=True)
class PageConfig:
    page: str
    page_asset_dir: Path
    source_asset_dir: Path | None
    legacy_asset_dir: Path | None
    runtime_screenshot: Path
    compare_image: Path
    godot_test_script: str


PAGE_CONFIGS = {
    "shop": PageConfig(
        page="shop",
        page_asset_dir=PROJECT_DIR / "assets" / "ui" / "shop",
        source_asset_dir=ROOT / "ui" / "split" / "shop",
        legacy_asset_dir=LEGACY_SHOP_DIR,
        runtime_screenshot=RUNTIME_CARD_DIR / "shop_runtime_card_v2.png",
        compare_image=GENERATED_ROOT / "shop" / "verification" / "shop_compare.png",
        godot_test_script="res://tests/card_ui_screenshot_export.gd",
    ),
}


SHOP_ASSETS: list[dict[str, Any]] = [
    {
        "id": "shop_title_banner_red",
        "file_name": "shop_title_banner_red.png",
        "scope": "shop",
        "kind": "title_banner",
        "size_hint": [610, 150],
        "nine_patch_margin": 28,
        "seed_source": "shop_banner_title_red_large.png",
    },
    {
        "id": "shop_status_bar_dark",
        "file_name": "shop_status_bar_dark.png",
        "scope": "shop",
        "kind": "panel",
        "size_hint": [340, 78],
        "nine_patch_margin": 26,
        "seed_source": "shop_panel_mini_dark.png",
    },
    {
        "id": "shop_player_card_red",
        "file_name": "shop_player_card_red.png",
        "scope": "shop",
        "kind": "panel",
        "size_hint": [300, 560],
        "nine_patch_margin": 34,
        "seed_source": "shop_panel_character_red.png",
    },
    {
        "id": "shop_requirement_panel_red",
        "file_name": "shop_requirement_panel_red.png",
        "scope": "shop",
        "kind": "panel",
        "size_hint": [300, 140],
        "nine_patch_margin": 24,
        "seed_source": "shop_panel_requirement_bar_dark.png",
    },
    {
        "id": "shop_requirement_panel_teal",
        "file_name": "shop_requirement_panel_teal.png",
        "scope": "shop",
        "kind": "panel",
        "size_hint": [300, 140],
        "nine_patch_margin": 24,
        "seed_source": "shop_panel_requirement_bar_dark.png",
    },
    {
        "id": "shop_requirement_title_red",
        "file_name": "shop_requirement_title_red.png",
        "scope": "shop",
        "kind": "label_plate",
        "size_hint": [240, 48],
        "nine_patch_margin": 18,
        "seed_source": "shop_label_red.png",
    },
    {
        "id": "shop_requirement_title_teal",
        "file_name": "shop_requirement_title_teal.png",
        "scope": "shop",
        "kind": "label_plate",
        "size_hint": [240, 48],
        "nine_patch_margin": 18,
        "seed_source": "shop_label_teal.png",
    },
    {
        "id": "shop_section_title_teal",
        "file_name": "shop_section_title_teal.png",
        "scope": "shop",
        "kind": "label_plate",
        "size_hint": [370, 58],
        "nine_patch_margin": 18,
        "seed_source": "shop_title_bar_teal.png",
    },
    {
        "id": "shop_item_card_red",
        "file_name": "shop_item_card_red.png",
        "scope": "shop",
        "kind": "card",
        "size_hint": [210, 292],
        "nine_patch_margin": 20,
        "seed_source": "shop_card_item_red.png",
    },
    {
        "id": "shop_item_card_teal",
        "file_name": "shop_item_card_teal.png",
        "scope": "shop",
        "kind": "card",
        "size_hint": [210, 292],
        "nine_patch_margin": 20,
        "seed_source": "shop_card_item_teal.png",
    },
    {
        "id": "shop_item_card_purple",
        "file_name": "shop_item_card_purple.png",
        "scope": "shop",
        "kind": "card",
        "size_hint": [210, 292],
        "nine_patch_margin": 20,
        "seed_source": "shop_card_item_purple.png",
    },
    {
        "id": "shop_artifact_frame_red",
        "file_name": "shop_artifact_frame_red.png",
        "scope": "shop",
        "kind": "icon_frame",
        "size_hint": [148, 106],
        "nine_patch_margin": 18,
        "seed_source": "shop_corner_red.png",
    },
    {
        "id": "shop_artifact_frame_teal",
        "file_name": "shop_artifact_frame_teal.png",
        "scope": "shop",
        "kind": "icon_frame",
        "size_hint": [148, 106],
        "nine_patch_margin": 18,
        "seed_source": "shop_corner_teal.png",
    },
    {
        "id": "shop_artifact_frame_purple",
        "file_name": "shop_artifact_frame_purple.png",
        "scope": "shop",
        "kind": "icon_frame",
        "size_hint": [148, 106],
        "nine_patch_margin": 18,
        "seed_source": "shop_corner_purple.png",
    },
    {
        "id": "shop_price_plate_dark",
        "file_name": "shop_price_plate_dark.png",
        "scope": "shop",
        "kind": "label_plate",
        "size_hint": [160, 46],
        "nine_patch_margin": 18,
        "seed_source": "shop_label_dark.png",
    },
    {
        "id": "shop_button_gold_normal",
        "file_name": "shop_button_gold_normal.png",
        "scope": "shop",
        "kind": "button",
        "size_hint": [220, 56],
        "nine_patch_margin": 24,
        "states": {"normal": "shop_button_gold_normal.png"},
        "seed_source": "shop_button_gold_normal.png",
    },
    {
        "id": "shop_button_gold_hover",
        "file_name": "shop_button_gold_hover.png",
        "scope": "shop",
        "kind": "button",
        "size_hint": [220, 56],
        "nine_patch_margin": 24,
        "states": {"hover": "shop_button_gold_hover.png"},
        "seed_source": "shop_button_gold_hover.png",
    },
    {
        "id": "shop_button_gold_pressed",
        "file_name": "shop_button_gold_pressed.png",
        "scope": "shop",
        "kind": "button",
        "size_hint": [220, 56],
        "nine_patch_margin": 24,
        "states": {"pressed": "shop_button_gold_pressed.png"},
        "seed_source": "shop_button_gold_pressed.png",
    },
    {
        "id": "shop_button_disabled_dark",
        "file_name": "shop_button_disabled_dark.png",
        "scope": "shop",
        "kind": "button",
        "size_hint": [220, 56],
        "nine_patch_margin": 24,
        "states": {"disabled": "shop_button_disabled_dark.png"},
        "seed_source": "shop_button_disabled_dark.png",
    },
    {
        "id": "shop_backpack_panel_purple",
        "file_name": "shop_backpack_panel_purple.png",
        "scope": "shop",
        "kind": "panel",
        "size_hint": [230, 520],
        "nine_patch_margin": 24,
        "seed_source": "shop_panel_inventory_dark.png",
    },
    {
        "id": "shop_backpack_title_purple",
        "file_name": "shop_backpack_title_purple.png",
        "scope": "shop",
        "kind": "label_plate",
        "size_hint": [200, 48],
        "nine_patch_margin": 18,
        "seed_source": "shop_title_bar_purple.png",
    },
    {
        "id": "shop_slot_empty",
        "file_name": "shop_slot_empty.png",
        "scope": "shop",
        "kind": "slot",
        "size_hint": [78, 78],
        "nine_patch_margin": 16,
        "seed_source": "shop_slot_backpack_dark.png",
    },
    {
        "id": "shop_slot_filled_red",
        "file_name": "shop_slot_filled_red.png",
        "scope": "shop",
        "kind": "slot",
        "size_hint": [78, 78],
        "nine_patch_margin": 16,
        "seed_source": "shop_slot_backpack_red.png",
    },
    {
        "id": "shop_slot_missing_dark",
        "file_name": "shop_slot_missing_dark.png",
        "scope": "shop",
        "kind": "slot",
        "size_hint": [78, 78],
        "nine_patch_margin": 16,
        "seed_source": "shop_slot_requirement_locked_dark.png",
    },
    {
        "id": "shop_count_badge_dark",
        "file_name": "shop_count_badge_dark.png",
        "scope": "shop",
        "kind": "badge",
        "size_hint": [42, 42],
        "nine_patch_margin": 12,
        "seed_source": "shop_label_dark.png",
    },
    {
        "id": "shop_stat_row_dark",
        "file_name": "shop_stat_row_dark.png",
        "scope": "shop",
        "kind": "row",
        "size_hint": [210, 44],
        "nine_patch_margin": 16,
        "seed_source": "shop_panel_mini_dark.png",
    },
    {
        "id": "shop_nameplate_red",
        "file_name": "shop_nameplate_red.png",
        "scope": "shop",
        "kind": "label_plate",
        "size_hint": [280, 60],
        "nine_patch_margin": 18,
        "seed_source": "shop_label_red.png",
    },
]

SHOP_LAYOUT: dict[str, Any] = {
    "base_size": [1672, 941],
    "nodes": {
        "TitleBanner": [0, 52, 640, 160],
        "TitleLabel": [76, 82, 405, 86],
        "StatusBar": [1114, 68, 515, 72],
        "PlayerCard": [34, 206, 410, 700],
        "AscensionRequirement": [455, 222, 410, 176],
        "DominionRequirement": [910, 222, 410, 176],
        "ShopItemsTitle": [660, 424, 420, 64],
        "ShopItemSlots/ShopItem1": [465, 505, 250, 405],
        "ShopItemSlots/ShopItem2": [735, 505, 250, 405],
        "ShopItemSlots/ShopItem3": [1005, 505, 250, 405],
        "BackpackPanel": [1300, 224, 320, 686],
    },
    "fonts": {
        "TitleLabel": 54,
        "StatusBar/StatusRow/EnergyLabel": 24,
        "StatusBar/StatusRow/InventoryLabel": 24,
        "ShopItemsTitle": 32,
    },
}


def rel(path: Path) -> str:
    return path.resolve().relative_to(ROOT.resolve()).as_posix()


def now_stamp() -> str:
    return datetime.now().isoformat(timespec="seconds")


def page_config(page: str) -> PageConfig:
    if page not in PAGE_CONFIGS:
        supported = ", ".join(PAGE_CONFIGS)
        raise SystemExit(f"Unsupported page '{page}'. Supported pages: {supported}")
    return PAGE_CONFIGS[page]


def source_dir(page: str) -> Path:
    return SOURCE_ROOT / page


def generated_dir(page: str) -> Path:
    return GENERATED_ROOT / page


def manifest_path(page: str) -> Path:
    return source_dir(page) / "page_manifest.json"


def load_manifest(page: str) -> dict[str, Any]:
    path = manifest_path(page)
    if not path.exists():
        raise SystemExit(f"Missing manifest: {rel(path)}. Run init first.")
    return json.loads(path.read_text(encoding="utf-8"))


def save_manifest(manifest: dict[str, Any]) -> None:
    page = manifest["page"]
    path = manifest_path(page)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def set_status(manifest: dict[str, Any], stage: str) -> None:
    manifest["status"] = stage
    manifest.setdefault("history", []).append({"stage": stage, "at": now_stamp()})


def canvas_size(path: Path) -> list[int] | None:
    try:
        from PIL import Image

        with Image.open(path) as image:
            return [image.width, image.height]
    except Exception:
        pass
    if path.suffix.lower() == ".png":
        try:
            with path.open("rb") as handle:
                header = handle.read(24)
            if header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR":
                return [int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")]
        except Exception:
            return None
    return None


def expected_assets(page: str) -> list[dict[str, Any]]:
    if page == "shop":
        return [dict(asset) for asset in SHOP_ASSETS]
    return []


def make_manifest(page: str, reference: Path) -> dict[str, Any]:
    config = page_config(page)
    return {
        "schema_version": 1,
        "page": page,
        "status": "initialized",
        "created_at": now_stamp(),
        "updated_at": now_stamp(),
        "reference_image": rel(reference),
        "canvas_size": canvas_size(reference),
        "directories": {
            "source": rel(source_dir(page)),
            "generated": rel(generated_dir(page)),
            "candidates": rel(generated_dir(page) / "candidates"),
            "verification": rel(generated_dir(page) / "verification"),
            "common_assets": rel(COMMON_ASSET_DIR),
            "page_assets": rel(config.page_asset_dir),
            "source_assets": rel(config.source_asset_dir) if config.source_asset_dir else None,
            "legacy_assets": rel(config.legacy_asset_dir) if config.legacy_asset_dir else None,
        },
        "runtime": {
            "godot_test_script": config.godot_test_script,
            "runtime_screenshot": rel(config.runtime_screenshot),
            "comparison_image": rel(config.compare_image),
        },
        "asset_policy": {
            "common_threshold": "Use common only when the asset is expected to be reused by at least two pages.",
            "page_scope": f"Page-specific assets for {page} go under {rel(config.page_asset_dir)}.",
            "imagegen": "Codex built-in Imagegen only; this tool never calls external image APIs.",
        },
        "assets": expected_assets(page),
        "layout": SHOP_LAYOUT if page == "shop" else {},
        "candidates": {},
        "approvals": {},
        "imports": {},
        "verification": {},
        "history": [{"stage": "initialized", "at": now_stamp()}],
    }


def init(args: argparse.Namespace) -> None:
    page = args.page
    config = page_config(page)
    reference = (ROOT / args.reference).resolve()
    if not reference.exists():
        raise SystemExit(f"Reference image does not exist: {reference}")
    source_dir(page).mkdir(parents=True, exist_ok=True)
    (generated_dir(page) / "candidates").mkdir(parents=True, exist_ok=True)
    (generated_dir(page) / "verification").mkdir(parents=True, exist_ok=True)
    config.page_asset_dir.mkdir(parents=True, exist_ok=True)
    manifest = make_manifest(page, reference)
    save_manifest(manifest)
    print(f"Initialized {page} pipeline: {rel(manifest_path(page))}")


def asset_paths(config: PageConfig, file_name: str) -> list[tuple[str, Path]]:
    paths: list[tuple[str, Path]] = [
        ("page", config.page_asset_dir / file_name),
        ("common", COMMON_ASSET_DIR / file_name),
    ]
    if config.legacy_asset_dir:
        paths.append(("legacy", config.legacy_asset_dir / file_name))
    return paths


def resolve_asset(config: PageConfig, file_name: str, include_legacy: bool = True) -> tuple[str, Path] | None:
    for scope, path in asset_paths(config, file_name):
        if scope == "legacy" and not include_legacy:
            continue
        if path.exists():
            return scope, path
    return None


def plan_assets(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.page)
    config = page_config(args.page)
    planned: list[dict[str, Any]] = []
    missing: list[str] = []
    for asset in manifest["assets"]:
        item = dict(asset)
        resolved = resolve_asset(config, item["file_name"], include_legacy=args.accept_legacy)
        legacy_resolved = resolve_asset(config, item["file_name"], include_legacy=True)
        source_path = None
        if config.source_asset_dir and item.get("seed_source"):
            candidate = config.source_asset_dir / str(item["seed_source"])
            if candidate.exists():
                source_path = candidate
        item["resolved_scope"] = resolved[0] if resolved else None
        item["resolved_path"] = rel(resolved[1]) if resolved else None
        item["legacy_path"] = rel(legacy_resolved[1]) if legacy_resolved and legacy_resolved[0] == "legacy" else None
        item["seed_source_path"] = rel(source_path) if source_path else None
        item["needs_generation"] = resolved is None
        if resolved is None:
            missing.append(item["id"])
        planned.append(item)
    manifest["assets"] = planned
    manifest["updated_at"] = now_stamp()
    set_status(manifest, "planned")
    save_manifest(manifest)
    print(f"Planned {len(planned)} assets for {args.page}; missing: {len(missing)}")
    if missing:
        print("Missing assets: " + ", ".join(missing))


def seed_assets(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.page)
    config = page_config(args.page)
    if config.source_asset_dir is None or not config.source_asset_dir.exists():
        raise SystemExit(f"No source asset directory configured for {args.page}.")
    copied = 0
    skipped = 0
    for asset in manifest["assets"]:
        seed_name = asset.get("seed_source")
        if not seed_name:
            skipped += 1
            continue
        src = config.source_asset_dir / str(seed_name)
        if not src.exists():
            skipped += 1
            continue
        dest_dir = COMMON_ASSET_DIR if asset["scope"] == "common" else config.page_asset_dir
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / asset["file_name"]
        if dest.exists() and not args.force:
            skipped += 1
            continue
        if dest.exists() and args.force:
            dest = unique_dest(dest)
        shutil.copy2(src, dest)
        asset["resolved_scope"] = "common" if dest_dir == COMMON_ASSET_DIR else "page"
        asset["resolved_path"] = rel(dest)
        asset["needs_generation"] = False
        manifest.setdefault("imports", {})[asset["id"]] = {
            "source": rel(src),
            "dest": rel(dest),
            "imported_at": now_stamp(),
            "mode": "seed-from-source-assets",
        }
        copied += 1
    manifest["updated_at"] = now_stamp()
    if copied:
        set_status(manifest, "imported")
    save_manifest(manifest)
    print(f"Seeded {copied} assets for {args.page}; skipped {skipped}.")


def generate_special_assets(args: argparse.Namespace) -> None:
    if args.page != "shop":
        raise SystemExit("Special asset generation is currently implemented for shop only.")
    script = ROOT / "tools" / "generate_shop_special_assets.ps1"
    if not script.exists():
        raise SystemExit(f"Missing special asset generator: {rel(script)}")
    command = [
        "powershell",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(script),
    ]
    result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True)
    if result.stdout.strip():
        print(result.stdout.rstrip())
    if result.stderr.strip():
        print(result.stderr.rstrip(), file=sys.stderr)
    if result.returncode != 0:
        raise SystemExit(f"Special asset generation failed with exit code {result.returncode}")
    manifest = load_manifest(args.page)
    manifest["updated_at"] = now_stamp()
    manifest.setdefault("generation", {})["special_assets"] = {
        "generated_at": now_stamp(),
        "script": rel(script),
        "output": rel(page_config(args.page).page_asset_dir),
    }
    save_manifest(manifest)


def prompt_for_asset(manifest: dict[str, Any], asset: dict[str, Any]) -> str:
    size = asset.get("size_hint", ["target", "target"])
    transparent = "transparent PNG with alpha" if asset.get("transparent", False) else "flat #00ff00 chroma-key background for alpha removal if transparency is needed"
    states = asset.get("states")
    state_text = ""
    if states:
        state_text = f"\nButton states to preserve in manifest: {json.dumps(states, ensure_ascii=False)}"
    return (
        f"Use case: ui-mockup\n"
        f"Asset type: LiarsLand Godot UI sprite, {asset['kind']}\n"
        f"Primary request: Generate `{asset['file_name']}` for the `{manifest['page']}` page, matching the reference image `{manifest['reference_image']}`.\n"
        f"Target size: approximately {size[0]} x {size[1]} px.\n"
        f"Style/medium: dark fantasy moon-market contract UI, hard chamfered edges, thick ink shadow, gold/red/teal/purple accents, worn painted texture.\n"
        f"Materials/textures: layered dark panels, gold bevels, subtle scratches and noise, high-contrast readable surface.\n"
        f"Constraints: no text, no numbers, no watermark, no background scene, no rounded modern UI, no glassmorphism.\n"
        f"Background/alpha: {transparent}; keep generous padding and crisp edges.\n"
        f"Nine-patch intent: safe stretch margin around {asset.get('nine_patch_margin', 18)} px; keep corners and borders visually stable.{state_text}"
    )


def prepare_prompts(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.page)
    prompt_path = source_dir(args.page) / "codex_imagegen_tasks.md"
    tasks = []
    for asset in manifest["assets"]:
        if args.all_assets or asset.get("needs_generation", False):
            tasks.append(asset)
    lines = [
        f"# Codex Imagegen Tasks: {args.page}",
        "",
        "These prompts are meant for Codex built-in Imagegen. Do not use external API keys.",
        "After generating a candidate, save it under `ui/generated_pages/%s/candidates/` and run `mark-generated`." % args.page,
        "",
    ]
    for index, asset in enumerate(tasks, start=1):
        lines.extend(
            [
                f"## {index}. {asset['id']}",
                "",
                f"- Target file: `{asset['file_name']}`",
                f"- Scope: `{asset['scope']}`",
                f"- Kind: `{asset['kind']}`",
                "",
                "```text",
                prompt_for_asset(manifest, asset),
                "```",
                "",
            ]
        )
    prompt_path.write_text("\n".join(lines), encoding="utf-8")
    manifest["updated_at"] = now_stamp()
    set_status(manifest, "prompt_ready")
    save_manifest(manifest)
    print(f"Wrote {len(tasks)} Imagegen tasks: {rel(prompt_path)}")


def require_asset(manifest: dict[str, Any], asset_id: str) -> dict[str, Any]:
    for asset in manifest["assets"]:
        if asset["id"] == asset_id:
            return asset
    raise SystemExit(f"Unknown asset id: {asset_id}")


def mark_generated(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.page)
    asset = require_asset(manifest, args.asset)
    file_path = (ROOT / args.file).resolve()
    if not file_path.exists():
        raise SystemExit(f"Candidate file does not exist: {file_path}")
    entry = {
        "asset": asset["id"],
        "file": rel(file_path),
        "registered_at": now_stamp(),
        "approved": False,
    }
    manifest.setdefault("candidates", {}).setdefault(asset["id"], []).append(entry)
    manifest["updated_at"] = now_stamp()
    set_status(manifest, "generated")
    save_manifest(manifest)
    print(f"Registered candidate for {asset['id']}: {rel(file_path)}")


def approve_asset(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.page)
    asset = require_asset(manifest, args.asset)
    if args.file:
        file_path = (ROOT / args.file).resolve()
        if not file_path.exists():
            raise SystemExit(f"Approved file does not exist: {file_path}")
    else:
        candidates = manifest.get("candidates", {}).get(asset["id"], [])
        if not candidates:
            raise SystemExit(f"No candidates registered for {asset['id']}")
        file_path = ROOT / candidates[-1]["file"]
    manifest.setdefault("approvals", {})[asset["id"]] = {
        "file": rel(file_path),
        "approved_at": now_stamp(),
        "approved_by": "codex_or_user",
    }
    for candidate in manifest.get("candidates", {}).get(asset["id"], []):
        if candidate["file"] == rel(file_path):
            candidate["approved"] = True
    manifest["updated_at"] = now_stamp()
    set_status(manifest, "approved")
    save_manifest(manifest)
    print(f"Approved {asset['id']}: {rel(file_path)}")


def unique_dest(dest: Path) -> Path:
    if not dest.exists():
        return dest
    stem = dest.stem
    suffix = dest.suffix
    for index in range(2, 1000):
        candidate = dest.with_name(f"{stem}_v{index}{suffix}")
        if not candidate.exists():
            return candidate
    raise SystemExit(f"Could not find versioned destination for {dest}")


def import_assets(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.page)
    config = page_config(args.page)
    approvals = manifest.get("approvals", {})
    imported = 0
    for asset in manifest["assets"]:
        approval = approvals.get(asset["id"])
        if not approval:
            continue
        src = ROOT / approval["file"]
        if not src.exists():
            raise SystemExit(f"Approved file missing for {asset['id']}: {src}")
        dest_dir = COMMON_ASSET_DIR if asset["scope"] == "common" else config.page_asset_dir
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = unique_dest(dest_dir / asset["file_name"])
        shutil.copy2(src, dest)
        manifest.setdefault("imports", {})[asset["id"]] = {
            "source": rel(src),
            "dest": rel(dest),
            "imported_at": now_stamp(),
        }
        asset["resolved_scope"] = "common" if dest_dir == COMMON_ASSET_DIR else "page"
        asset["resolved_path"] = rel(dest)
        asset["needs_generation"] = False
        imported += 1
    manifest["updated_at"] = now_stamp()
    if imported:
        set_status(manifest, "imported")
    save_manifest(manifest)
    print(f"Imported {imported} approved assets for {args.page}.")


def wire_godot(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.page)
    config = page_config(args.page)
    resource_map: dict[str, Any] = {
        "page": args.page,
        "generated_at": now_stamp(),
        "resolution_order": [
            f"res://assets/ui/{args.page}/",
            "res://assets/ui/common/",
            "res://assets/generated/ui/shop_v2/" if args.page == "shop" else None,
        ],
        "assets": {},
    }
    missing: list[str] = []
    for asset in manifest["assets"]:
        resolved = resolve_asset(config, asset["file_name"])
        if resolved is None:
            missing.append(asset["id"])
            resource_map["assets"][asset["id"]] = {"file_name": asset["file_name"], "status": "missing"}
        else:
            scope, path = resolved
            resource_map["assets"][asset["id"]] = {
                "file_name": asset["file_name"],
                "scope": scope,
                "path": rel(path),
                "res_path": local_to_res(path),
                "nine_patch_margin": asset.get("nine_patch_margin"),
                "states": asset.get("states", {}),
            }
    map_path = source_dir(args.page) / "godot_resource_map.json"
    map_path.write_text(json.dumps(resource_map, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    manifest["godot_resource_map"] = rel(map_path)
    manifest["updated_at"] = now_stamp()
    set_status(manifest, "wired")
    save_manifest(manifest)
    print(f"Wrote Godot resource map: {rel(map_path)}")
    if missing:
        print("Still missing assets: " + ", ".join(missing))


def local_to_res(path: Path) -> str:
    try:
        return "res://" + path.resolve().relative_to(PROJECT_DIR.resolve()).as_posix()
    except ValueError:
        return rel(path)


def find_godot(explicit: str | None) -> str | None:
    if explicit:
        return explicit
    for candidate in [
        "godot",
        "Godot",
        r"D:\AIProjects\CodexProjects\Tools\godot\Godot_v4.6.2-stable_win64.exe",
        r"C:\AIProjects\CodexProjects\Tools\godot\Godot_v4.6.2-stable_win64.exe",
    ]:
        path = shutil.which(candidate) if not candidate.endswith(".exe") else candidate
        if path and (not path.endswith(".exe") or Path(path).exists()):
            return path
    return None


def run_godot_export(config: PageConfig, godot_bin: str | None) -> bool:
    exe = find_godot(godot_bin)
    if exe is None:
        print("Godot executable not found; skipping screenshot export.")
        return False
    command = [exe, "--path", str(PROJECT_DIR), "--script", config.godot_test_script]
    print("Running: " + " ".join(command))
    result = subprocess.run(command, cwd=PROJECT_DIR, text=True, capture_output=True)
    if result.stdout.strip():
        print(result.stdout.rstrip())
    if result.stderr.strip():
        print(result.stderr.rstrip(), file=sys.stderr)
    failed_text = "\n".join([result.stdout, result.stderr])
    if result.returncode != 0 or "SCRIPT ERROR" in failed_text or "Cannot call method" in failed_text:
        raise SystemExit(f"Godot verification failed with exit code {result.returncode}")
    return True


def make_comparison(reference: Path, runtime: Path, output: Path) -> bool:
    if not reference.exists() or not runtime.exists():
        return False
    try:
        from PIL import Image, ImageDraw
    except Exception:
        return make_comparison_with_powershell(reference, runtime, output)
    ref = Image.open(reference).convert("RGB")
    run = Image.open(runtime).convert("RGB")
    target_h = max(ref.height, run.height)
    ref_w = round(ref.width * target_h / ref.height)
    run_w = round(run.width * target_h / run.height)
    ref = ref.resize((ref_w, target_h))
    run = run.resize((run_w, target_h))
    gutter = 24
    label_h = 48
    canvas = Image.new("RGB", (ref_w + run_w + gutter, target_h + label_h), (18, 11, 13))
    canvas.paste(ref, (0, label_h))
    canvas.paste(run, (ref_w + gutter, label_h))
    draw = ImageDraw.Draw(canvas)
    draw.text((12, 14), "Reference", fill=(246, 233, 203))
    draw.text((ref_w + gutter + 12, 14), "Runtime", fill=(246, 233, 203))
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)
    return True


def make_comparison_with_powershell(reference: Path, runtime: Path, output: Path) -> bool:
    if sys.platform != "win32":
        print("Pillow is not available; skipping comparison image.")
        return False
    output.parent.mkdir(parents=True, exist_ok=True)
    script = f"""
Add-Type -AssemblyName System.Drawing
$refPath = [System.IO.Path]::GetFullPath('{str(reference).replace("'", "''")}')
$runPath = [System.IO.Path]::GetFullPath('{str(runtime).replace("'", "''")}')
$outPath = [System.IO.Path]::GetFullPath('{str(output).replace("'", "''")}')
$ref = [System.Drawing.Image]::FromFile($refPath)
$run = [System.Drawing.Image]::FromFile($runPath)
$targetH = [Math]::Max($ref.Height, $run.Height)
$refW = [int][Math]::Round($ref.Width * $targetH / $ref.Height)
$runW = [int][Math]::Round($run.Width * $targetH / $run.Height)
$gutter = 24
$labelH = 48
$canvas = New-Object System.Drawing.Bitmap ($refW + $runW + $gutter), ($targetH + $labelH)
$graphics = [System.Drawing.Graphics]::FromImage($canvas)
$graphics.Clear([System.Drawing.Color]::FromArgb(18, 11, 13))
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(246, 233, 203))
$font = New-Object System.Drawing.Font "Arial", 14
$graphics.DrawString("Reference", $font, $brush, 12, 14)
$graphics.DrawString("Runtime", $font, $brush, ($refW + $gutter + 12), 14)
$graphics.DrawImage($ref, 0, $labelH, $refW, $targetH)
$graphics.DrawImage($run, ($refW + $gutter), $labelH, $runW, $targetH)
$canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$canvas.Dispose()
$ref.Dispose()
$run.Dispose()
"""
    encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
    result = subprocess.run(
        ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-EncodedCommand", encoded],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    if result.returncode != 0:
        print("PowerShell comparison fallback failed:")
        print(result.stderr.strip())
        return False
    return True


def verify(args: argparse.Namespace) -> None:
    manifest = load_manifest(args.page)
    config = page_config(args.page)
    if not args.no_godot:
        if config.runtime_screenshot.exists():
            config.runtime_screenshot.unlink()
        run_godot_export(config, args.godot)
        if not config.runtime_screenshot.exists():
            raise SystemExit(f"Godot did not create runtime screenshot: {rel(config.runtime_screenshot)}")
    reference = ROOT / manifest["reference_image"]
    comparison_made = make_comparison(reference, config.runtime_screenshot, config.compare_image)
    manifest["verification"] = {
        "verified_at": now_stamp(),
        "runtime_screenshot": rel(config.runtime_screenshot),
        "comparison_image": rel(config.compare_image) if comparison_made else None,
        "comparison_made": comparison_made,
    }
    manifest["updated_at"] = now_stamp()
    set_status(manifest, "verified")
    save_manifest(manifest)
    if comparison_made:
        print(f"Wrote comparison image: {rel(config.compare_image)}")
    else:
        print("Verification metadata updated; comparison image was not created.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init")
    init_parser.add_argument("page")
    init_parser.add_argument("--reference", required=True)
    init_parser.set_defaults(func=init)

    plan_parser = subparsers.add_parser("plan-assets")
    plan_parser.add_argument("page")
    plan_parser.add_argument("--accept-legacy", action="store_true", help="Treat legacy generated assets as satisfying the page plan.")
    plan_parser.set_defaults(func=plan_assets)

    seed_parser = subparsers.add_parser("seed-assets")
    seed_parser.add_argument("page")
    seed_parser.add_argument("--force", action="store_true", help="Copy source assets even when destination names already exist, using versioned names.")
    seed_parser.set_defaults(func=seed_assets)

    special_parser = subparsers.add_parser("generate-special-assets")
    special_parser.add_argument("page")
    special_parser.set_defaults(func=generate_special_assets)

    prompt_parser = subparsers.add_parser("prepare-prompts")
    prompt_parser.add_argument("page")
    prompt_parser.add_argument("--all-assets", action="store_true", help="Write prompts for every known asset, not just missing ones.")
    prompt_parser.set_defaults(func=prepare_prompts)

    mark_parser = subparsers.add_parser("mark-generated")
    mark_parser.add_argument("page")
    mark_parser.add_argument("--asset", required=True)
    mark_parser.add_argument("--file", required=True)
    mark_parser.set_defaults(func=mark_generated)

    approve_parser = subparsers.add_parser("approve-asset")
    approve_parser.add_argument("page")
    approve_parser.add_argument("--asset", required=True)
    approve_parser.add_argument("--file")
    approve_parser.set_defaults(func=approve_asset)

    import_parser = subparsers.add_parser("import-assets")
    import_parser.add_argument("page")
    import_parser.set_defaults(func=import_assets)

    wire_parser = subparsers.add_parser("wire-godot")
    wire_parser.add_argument("page")
    wire_parser.set_defaults(func=wire_godot)

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("page")
    verify_parser.add_argument("--godot")
    verify_parser.add_argument("--no-godot", action="store_true", help="Only create comparison metadata/image from existing screenshots.")
    verify_parser.set_defaults(func=verify)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    args.func(args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
