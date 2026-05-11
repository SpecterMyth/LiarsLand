from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "assets" / "generated"
SOURCE_OUT = GENERATED / "source"
REFERENCE_OUT = ROOT.parents[0] / "arts" / "final_references"
CONTACT_OUT = ROOT.parents[0] / "tmp" / "circle_avatar_contact_sheet.png"

AVATAR_SIZE = 256
INNER_PADDING = 18
RING_WIDTH = 9


def _source_for_portrait(portrait_path: Path) -> Path:
    if portrait_path.name == "player_portrait.png":
        player_cutout = SOURCE_OUT / "player_circle_avatar_cutout.png"
        if player_cutout.exists():
            return player_cutout
    head_path = portrait_path.with_name(portrait_path.name.replace("_portrait.png", "_head_avatar.png"))
    if head_path.exists():
        return head_path
    return portrait_path


def _fit_source(image: Image.Image, source_path: Path) -> Image.Image:
    image = image.convert("RGBA")
    is_head_avatar = source_path.name.endswith("_head_avatar.png")
    is_circle_cutout = source_path.name.endswith("_circle_avatar_cutout.png")
    if is_head_avatar or is_circle_cutout:
        bbox = image.getbbox() or (0, 0, image.width, image.height)
    else:
        alpha_bbox = image.getbbox() or (0, 0, image.width, image.height)
        left, top, right, bottom = alpha_bbox
        subject_width = right - left
        subject_height = bottom - top
        size = int(max(subject_width * 0.72, subject_height * 0.42))
        center_x = (left + right) // 2
        center_y = top + int(subject_height * 0.24)
        bbox = (
            max(0, center_x - size // 2),
            max(0, center_y - size // 2),
            min(image.width, center_x + size // 2),
            min(image.height, center_y + size // 2),
        )
    crop = image.crop(bbox)
    crop.thumbnail((AVATAR_SIZE - INNER_PADDING * 2, AVATAR_SIZE - INNER_PADDING * 2), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (AVATAR_SIZE, AVATAR_SIZE), (0, 0, 0, 0))
    x = (AVATAR_SIZE - crop.width) // 2
    y = (AVATAR_SIZE - crop.height) // 2
    canvas.alpha_composite(crop, (x, y))
    return canvas


def _circle_mask(size: int, inset: int = 0) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((inset, inset, size - 1 - inset, size - 1 - inset), fill=255)
    return mask


def make_circle_avatar(portrait_path: Path, out_path: Path) -> None:
    source_path = _source_for_portrait(portrait_path)
    fitted = _fit_source(Image.open(source_path), source_path)

    background = Image.new("RGBA", (AVATAR_SIZE, AVATAR_SIZE), (18, 15, 22, 255))
    bg_draw = ImageDraw.Draw(background)
    bg_draw.ellipse((10, 10, AVATAR_SIZE - 11, AVATAR_SIZE - 11), fill=(32, 24, 33, 255))
    bg_draw.ellipse((28, 24, AVATAR_SIZE - 29, AVATAR_SIZE - 52), fill=(53, 40, 44, 255))

    soft_shadow = _circle_mask(AVATAR_SIZE, 8).filter(ImageFilter.GaussianBlur(4))
    shadow = Image.new("RGBA", (AVATAR_SIZE, AVATAR_SIZE), (0, 0, 0, 95))
    composed = Image.new("RGBA", (AVATAR_SIZE, AVATAR_SIZE), (0, 0, 0, 0))
    composed.alpha_composite(shadow, (0, 3))
    composed.putalpha(soft_shadow)

    circle_alpha = _circle_mask(AVATAR_SIZE, 5)
    background.putalpha(circle_alpha)
    composed.alpha_composite(background)
    composed.alpha_composite(fitted)

    outer_mask = _circle_mask(AVATAR_SIZE, 1)
    composed.putalpha(Image.composite(composed.getchannel("A"), Image.new("L", (AVATAR_SIZE, AVATAR_SIZE), 0), outer_mask))

    ring = Image.new("RGBA", (AVATAR_SIZE, AVATAR_SIZE), (0, 0, 0, 0))
    ring_draw = ImageDraw.Draw(ring)
    ring_draw.ellipse(
        (RING_WIDTH // 2, RING_WIDTH // 2, AVATAR_SIZE - 1 - RING_WIDTH // 2, AVATAR_SIZE - 1 - RING_WIDTH // 2),
        outline=(232, 178, 83, 245),
        width=RING_WIDTH,
    )
    ring_draw.ellipse(
        (RING_WIDTH + 6, RING_WIDTH + 6, AVATAR_SIZE - 7 - RING_WIDTH, AVATAR_SIZE - 7 - RING_WIDTH),
        outline=(55, 195, 176, 150),
        width=3,
    )
    composed.alpha_composite(ring)
    final_mask = _circle_mask(AVATAR_SIZE, 0)
    composed.putalpha(Image.composite(composed.getchannel("A"), Image.new("L", (AVATAR_SIZE, AVATAR_SIZE), 0), final_mask))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    composed.save(out_path)


def make_contact_sheet(paths: list[Path]) -> None:
    if not paths:
        return
    columns = 6
    cell = 176
    rows = (len(paths) + columns - 1) // columns
    sheet = Image.new("RGBA", (columns * cell, rows * cell), (19, 15, 22, 255))
    for index, path in enumerate(paths):
        img = Image.open(path).convert("RGBA")
        img.thumbnail((128, 128), Image.Resampling.LANCZOS)
        x = (index % columns) * cell + (cell - img.width) // 2
        y = (index // columns) * cell + 14
        sheet.alpha_composite(img, (x, y))
    CONTACT_OUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(CONTACT_OUT)


def main() -> None:
    portraits = sorted(GENERATED.glob("*_portrait.png"))
    outputs: list[Path] = []
    for portrait_path in portraits:
        out_path = portrait_path.with_name(portrait_path.name.replace("_portrait.png", "_circle_avatar.png"))
        make_circle_avatar(portrait_path, out_path)
        outputs.append(out_path)

    player_avatar = GENERATED / "player_circle_avatar.png"
    if player_avatar.exists():
        REFERENCE_OUT.mkdir(parents=True, exist_ok=True)
        (REFERENCE_OUT / "player_circle_avatar_reference.png").write_bytes(player_avatar.read_bytes())

    make_contact_sheet(outputs)
    print(f"Wrote {len(outputs)} circle avatars to {GENERATED}")
    print(f"Player reference: {REFERENCE_OUT / 'player_circle_avatar_reference.png'}")
    print(f"Contact sheet: {CONTACT_OUT}")


if __name__ == "__main__":
    main()
