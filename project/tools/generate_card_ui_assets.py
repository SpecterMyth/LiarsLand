from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "generated" / "ui" / "card"

ARTIFACTS = [
    ("moon_lantern", "lantern", (238, 62, 64), (246, 183, 45)),
    ("ink_feather_jar", "jar", (76, 46, 137), (87, 211, 188)),
    ("cracked_gold_seal", "seal", (235, 158, 36), (235, 61, 66)),
    ("snake_marrow_vial", "vial", (52, 206, 147), (240, 76, 91)),
    ("deer_bell", "bell", (246, 188, 51), (60, 202, 167)),
    ("wolf_oath_blade", "blade", (96, 107, 126), (242, 188, 54)),
    ("debt_silk", "silk", (197, 92, 39), (247, 198, 69)),
    ("ash_map", "map", (44, 179, 174), (239, 74, 86)),
    ("silent_coin", "coin", (224, 169, 47), (126, 71, 186)),
    ("red_market_mask", "mask", (223, 48, 66), (247, 194, 71)),
]

TOOLS = [
    ("info", "eye", (37, 156, 142)),
    ("bag", "bag", (224, 145, 28)),
    ("history", "scroll", (110, 75, 169)),
    ("rules", "book", (210, 62, 62)),
    ("status", "heart", (57, 148, 207)),
    ("settings", "gear", (108, 113, 119)),
]


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)


def rounded_shadow(size: tuple[int, int], radius: int, color: tuple[int, int, int, int]) -> Image.Image:
    w, h = size
    base = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(base)
    d.rounded_rectangle((18, 18, w - 10, h - 10), radius=radius, fill=(0, 0, 0, 150))
    base = base.filter(ImageFilter.GaussianBlur(8))
    d = ImageDraw.Draw(base)
    d.rounded_rectangle((8, 8, w - 20, h - 20), radius=radius, fill=color, outline=(7, 8, 12, 255), width=8)
    return base


def avatar(kind: str) -> Image.Image:
    img = Image.new("RGBA", (768, 1024), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if kind == "fox":
        fur = (225, 42, 52, 255)
        cheek = (250, 218, 128, 255)
        coat = (43, 26, 71, 255)
        accent = (248, 181, 45, 255)
    else:
        fur = (112, 118, 128, 255)
        cheek = (48, 50, 58, 255)
        coat = (39, 29, 66, 255)
        accent = (248, 181, 45, 255)

    d.polygon([(210, 870), (270, 420), (498, 420), (570, 870)], fill=coat, outline=(0, 0, 0, 255))
    d.line([(250, 460), (210, 870)], fill=(0, 0, 0, 255), width=16)
    d.line([(520, 460), (570, 870)], fill=(0, 0, 0, 255), width=16)
    d.line([(295, 505), (466, 505)], fill=accent, width=10)
    d.polygon([(250, 275), (295, 70), (370, 285)], fill=fur, outline=(0, 0, 0, 255))
    d.polygon([(420, 282), (548, 80), (510, 332)], fill=fur, outline=(0, 0, 0, 255))
    d.polygon([(288, 120), (318, 260), (334, 174)], fill=cheek, outline=(0, 0, 0, 255))
    d.polygon([(506, 134), (478, 268), (460, 178)], fill=cheek, outline=(0, 0, 0, 255))
    d.ellipse((220, 225, 560, 575), fill=fur, outline=(0, 0, 0, 255), width=14)
    d.polygon([(260, 390), (390, 320), (538, 390), (394, 478)], fill=cheek if kind == "fox" else cheek, outline=(0, 0, 0, 255))
    d.polygon([(300, 350), (410, 326), (486, 356), (390, 392)], fill=(8, 9, 12, 255))
    d.polygon([(323, 348), (386, 338), (405, 350), (356, 363)], fill=accent)
    d.polygon([(420, 350), (470, 346), (486, 356), (438, 367)], fill=accent)
    d.polygon([(384, 430), (425, 430), (404, 455)], fill=(8, 9, 12, 255))
    d.line([(294, 610), (474, 610)], fill=accent, width=12)
    return img


def icon_canvas(bg: tuple[int, int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((20, 20, 236, 236), radius=18, fill=bg + (255,), outline=(4, 5, 8, 255), width=12)
    return img, d


def artifact_icon(kind: str, bg: tuple[int, int, int], accent: tuple[int, int, int]) -> Image.Image:
    img, d = icon_canvas(bg)
    black = (4, 5, 8, 255)
    a = accent + (255,)
    if kind == "lantern":
        d.polygon([(128, 45), (178, 82), (158, 180), (98, 180), (78, 82)], fill=a, outline=black)
        d.rectangle((102, 180, 154, 205), fill=black)
    elif kind == "jar":
        d.rounded_rectangle((74, 68, 182, 190), radius=28, fill=a, outline=black, width=9)
        d.rectangle((96, 45, 160, 82), fill=bg + (255,), outline=black, width=8)
    elif kind == "seal":
        d.polygon([(128, 40), (188, 96), (164, 190), (92, 190), (68, 96)], fill=a, outline=black)
        d.line((92, 122, 164, 122), fill=black, width=10)
    elif kind == "vial":
        d.polygon([(104, 45), (152, 45), (170, 178), (128, 210), (86, 178)], fill=a, outline=black)
        d.rectangle((96, 38, 160, 66), fill=bg + (255,), outline=black, width=8)
    elif kind == "bell":
        d.pieslice((66, 58, 190, 214), 180, 360, fill=a, outline=black, width=10)
        d.rectangle((74, 132, 182, 188), fill=a, outline=black, width=10)
        d.ellipse((112, 182, 144, 214), fill=black)
    elif kind == "blade":
        d.polygon([(136, 32), (174, 152), (128, 222), (82, 152)], fill=a, outline=black)
        d.line((86, 152, 170, 152), fill=black, width=10)
    elif kind == "silk":
        d.polygon([(58, 78), (142, 56), (198, 104), (112, 128)], fill=a, outline=black)
        d.polygon([(68, 128), (154, 104), (196, 154), (110, 178)], fill=a, outline=black)
    elif kind == "map":
        d.polygon([(58, 72), (112, 54), (156, 82), (202, 62), (194, 184), (138, 204), (94, 176), (52, 196)], fill=a, outline=black)
        d.line((85, 110, 132, 146, 174, 110), fill=black, width=9)
    elif kind == "coin":
        d.ellipse((58, 58, 198, 198), fill=a, outline=black, width=11)
        d.polygon([(128, 80), (164, 128), (128, 176), (92, 128)], fill=bg + (255,), outline=black)
    elif kind == "mask":
        d.polygon([(58, 82), (124, 58), (116, 164), (72, 184)], fill=a, outline=black)
        d.polygon([(198, 82), (132, 58), (140, 164), (184, 184)], fill=a, outline=black)
        d.ellipse((88, 112, 110, 130), fill=black)
        d.ellipse((146, 112, 168, 130), fill=black)
    return img


def tool_icon(kind: str, bg: tuple[int, int, int]) -> Image.Image:
    img, d = icon_canvas(bg)
    black = (4, 5, 8, 255)
    white = (240, 232, 210, 255)
    if kind == "eye":
        d.ellipse((54, 86, 202, 170), outline=white, width=14)
        d.ellipse((108, 96, 148, 160), fill=white)
    elif kind == "bag":
        d.polygon([(78, 92), (178, 92), (194, 190), (62, 190)], fill=white, outline=black)
        d.arc((96, 52, 160, 116), 180, 360, fill=white, width=12)
    elif kind == "scroll":
        d.rounded_rectangle((70, 60, 176, 196), radius=14, fill=white, outline=black, width=8)
        for y in [90, 120, 150]:
            d.line((92, y, 154, y), fill=black, width=7)
    elif kind == "book":
        d.rectangle((58, 70, 120, 184), fill=white, outline=black, width=8)
        d.rectangle((132, 70, 198, 184), fill=white, outline=black, width=8)
    elif kind == "heart":
        d.polygon([(128, 196), (58, 112), (82, 70), (128, 94), (174, 70), (198, 112)], fill=white, outline=black)
        d.line((74, 130, 110, 130, 126, 100, 146, 160, 172, 160), fill=bg + (255,), width=9)
    elif kind == "gear":
        for a in range(0, 360, 45):
            r = math.radians(a)
            x, y = 128 + math.cos(r) * 64, 128 + math.sin(r) * 64
            d.rectangle((x - 13, y - 13, x + 13, y + 13), fill=white)
        d.ellipse((70, 70, 186, 186), fill=white, outline=black, width=8)
        d.ellipse((110, 110, 146, 146), fill=bg + (255,), outline=black, width=6)
    return img


def background() -> Image.Image:
    img = Image.new("RGBA", (1920, 1080), (6, 12, 17, 255))
    d = ImageDraw.Draw(img)
    d.polygon([(0, 0), (730, 0), (530, 270), (0, 330)], fill=(83, 9, 22, 255))
    d.polygon([(980, 0), (1920, 0), (1920, 1080), (1450, 1080)], fill=(4, 36, 40, 255))
    d.ellipse((945, -120, 1240, 180), fill=(19, 113, 109, 210))
    for i in range(18):
        x = 80 + i * 108
        h = 360 + (i % 5) * 60
        d.polygon([(x, 1080), (x + 44, 1080 - h), (x + 96, 1080)], fill=(2, 18, 24, 210))
    for i in range(28):
        x = (i * 173) % 1920
        y = 160 + (i * 97) % 780
        d.rectangle((x, y, x + 18, y + 42), fill=(177, 30, 44, 100))
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    save(background(), OUT / "bg_card_city.png")
    save(avatar("fox"), OUT / "avatar_fox_card.png")
    save(avatar("wolf"), OUT / "avatar_wolf_card.png")
    for artifact_id, kind, bg, accent in ARTIFACTS:
        save(artifact_icon(kind, bg, accent), OUT / f"artifact_{artifact_id}.png")
    for name, kind, bg in TOOLS:
        save(tool_icon(kind, bg), OUT / f"icon_{name}.png")
    print(f"Wrote card UI assets to {OUT}")


if __name__ == "__main__":
    main()
