from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "generated"

CARDS = {
    "blood_oath": ((135, 30, 46), (233, 178, 84), "oath"),
    "silver_needle": ((68, 96, 126), (226, 231, 219), "needle"),
    "lost_name": ((80, 64, 122), (232, 180, 219), "name"),
    "market_debt": ((126, 77, 36), (229, 178, 80), "debt"),
    "hidden_map": ((35, 108, 104), (219, 193, 103), "map"),
    "clue_betrayer": ((82, 38, 50), (222, 96, 91), "mask"),
    "clue_location": ((39, 76, 92), (91, 187, 184), "gate"),
    "clue_token": ((88, 67, 28), (234, 196, 91), "seal"),
    "identity_info": ((73, 58, 93), (196, 174, 236), "eye"),
}


def lerp(a: int, b: int, t: float) -> int:
    return round(a + (b - a) * t)


def gradient(size: tuple[int, int], a: tuple[int, int, int], b: tuple[int, int, int]) -> Image.Image:
    w, h = size
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(h):
        for x in range(w):
            t = (x / w * 0.35) + (y / h * 0.65)
            px[x, y] = (
                lerp(a[0], b[0], t),
                lerp(a[1], b[1], t),
                lerp(a[2], b[2], t),
                255,
            )
    return img


def draw_pattern(draw: ImageDraw.ImageDraw, kind: str, accent: tuple[int, int, int]) -> None:
    w, h = 420, 280
    c = accent + (210,)
    soft = accent + (70,)
    if kind in ("oath", "seal"):
        for r in (38, 72, 106):
            draw.ellipse((w / 2 - r, h / 2 - r, w / 2 + r, h / 2 + r), outline=c, width=3)
        for i in range(8):
            a = i * math.pi / 4
            draw.line((w / 2, h / 2, w / 2 + math.cos(a) * 118, h / 2 + math.sin(a) * 118), fill=soft, width=2)
    elif kind == "needle":
        draw.line((80, 210, 340, 70), fill=c, width=5)
        draw.line((110, 232, 360, 96), fill=soft, width=2)
        draw.ellipse((306, 54, 358, 106), outline=c, width=4)
    elif kind == "name":
        for y in (80, 118, 156, 194):
            draw.arc((70, y - 28, 350, y + 42), 190, 350, fill=c, width=3)
    elif kind == "debt":
        for i in range(5):
            x = 95 + i * 48
            draw.rounded_rectangle((x, 58, x + 28, 218), radius=13, outline=c if i % 2 == 0 else soft, width=3)
    elif kind == "map":
        pts = [(70, 205), (132, 95), (204, 176), (270, 70), (352, 150)]
        draw.line(pts, fill=c, width=5, joint="curve")
        for x, y in pts:
            draw.ellipse((x - 10, y - 10, x + 10, y + 10), fill=accent + (230,))
    elif kind == "mask":
        draw.polygon([(94, 96), (190, 64), (178, 176), (112, 196)], outline=c, fill=soft)
        draw.polygon([(326, 96), (230, 64), (242, 176), (308, 196)], outline=c, fill=soft)
        draw.ellipse((135, 124, 166, 148), fill=(10, 10, 10, 160))
        draw.ellipse((254, 124, 285, 148), fill=(10, 10, 10, 160))
    elif kind == "gate":
        draw.rectangle((102, 82, 318, 220), outline=c, width=5)
        draw.line((210, 82, 210, 220), fill=soft, width=3)
        draw.arc((132, 38, 288, 158), 180, 360, fill=c, width=5)
    elif kind == "eye":
        draw.ellipse((92, 84, 328, 196), outline=c, width=5)
        draw.ellipse((172, 72, 248, 208), outline=soft, width=4)
        draw.ellipse((190, 110, 230, 150), fill=accent + (220,))


def make_card(card_id: str, base: tuple[int, int, int], accent: tuple[int, int, int], kind: str) -> None:
    img = gradient((420, 280), base, tuple(max(0, v - 48) for v in base))
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse((115, -60, 470, 220), fill=accent + (48,))
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    img.alpha_composite(glow)
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle((8, 8, 412, 272), radius=22, outline=accent + (210,), width=4)
    draw.rounded_rectangle((24, 24, 396, 256), radius=16, outline=accent + (82,), width=2)
    for i in range(12):
        x = 26 + i * 34
        draw.line((x, 246, x + 20, 266), fill=accent + (34,), width=2)
    draw_pattern(draw, kind, accent)
    img.save(OUT / f"card_art_{card_id}.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for card_id, (base, accent, kind) in CARDS.items():
        make_card(card_id, base, accent, kind)
    print(f"Generated {len(CARDS)} card art assets in {OUT}")


if __name__ == "__main__":
    main()
