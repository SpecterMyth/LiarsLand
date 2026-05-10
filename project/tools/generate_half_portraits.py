from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "generated"
EXCLUDED_SUFFIXES = ("_portrait_half.png",)


def portrait_sources() -> list[Path]:
    return sorted(
        path
        for path in ASSETS.glob("*_portrait.png")
        if path.is_file() and not path.name.endswith(EXCLUDED_SUFFIXES)
    )


def alpha_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    if img.mode != "RGBA":
        img = img.convert("RGBA")
    alpha = img.getchannel("A")
    return alpha.getbbox() or (0, 0, img.width, img.height)


def make_half(src: Path) -> None:
    img = Image.open(src).convert("RGBA")
    left, top, right, bottom = alpha_bbox(img)
    height = bottom - top
    crop_bottom = top + int(height * 0.66)
    pad_x = int((right - left) * 0.10)
    pad_top = int(height * 0.02)
    box = (
        max(0, left - pad_x),
        max(0, top - pad_top),
        min(img.width, right + pad_x),
        min(img.height, crop_bottom),
    )
    cropped = img.crop(box)
    out = ASSETS / src.name.replace(".png", "_half.png")
    cropped.save(out)


def main() -> None:
    for src in portrait_sources():
        make_half(src)
    print("Generated half-body portraits.")


if __name__ == "__main__":
    main()
