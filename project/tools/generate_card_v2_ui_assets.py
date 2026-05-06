from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = ROOT.parent
REF = PROJECT_ROOT / "ui" / "final_references"
OUT = ROOT / "assets" / "generated" / "ui" / "card"


PALETTE = {
    "red": (172, 14, 28, 255),
    "red_dark": (75, 7, 16, 255),
    "purple": (74, 37, 102, 255),
    "purple_dark": (35, 22, 52, 255),
    "teal": (0, 118, 112, 255),
    "teal_dark": (0, 55, 60, 255),
    "yellow": (240, 162, 17, 255),
    "gold": (247, 187, 39, 255),
    "black": (6, 7, 10, 255),
    "panel": (15, 17, 22, 248),
    "line": (2, 4, 7, 255),
}


ARTIFACTS = [
    ("moon_lantern", "crystal", "red"),
    ("ink_feather_jar", "keycard", "teal"),
    ("cracked_gold_seal", "crown", "purple"),
    ("snake_marrow_vial", "target", "gold"),
    ("deer_bell", "dagger", "blue"),
    ("wolf_oath_blade", "amulet", "purple"),
    ("debt_silk", "silk", "red"),
    ("ash_map", "map", "teal"),
    ("silent_coin", "coin", "gold"),
    ("red_market_mask", "mask", "red"),
]


TOOLS = [
    ("info", "eye", (13, 118, 108, 255)),
    ("bag", "bag", (162, 103, 9, 255)),
    ("history", "scroll", (80, 50, 116, 255)),
    ("rules", "book", (147, 28, 32, 255)),
    ("status", "heart", (35, 102, 150, 255)),
    ("settings", "gear", (72, 74, 80, 255)),
]


def ensure() -> None:
    OUT.mkdir(parents=True, exist_ok=True)


def save(img: Image.Image, name: str) -> None:
    ensure()
    img.save(OUT / name)


def poly_mask(size: tuple[int, int], inset: int = 18, cut: int = 42) -> Image.Image:
    w, h = size
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    pts = [
        (inset + cut, inset),
        (w - inset - cut, inset),
        (w - inset, inset + cut),
        (w - inset, h - inset - cut),
        (w - inset - cut, h - inset),
        (inset + cut // 2, h - inset),
        (inset, h - inset - cut // 2),
        (inset, inset + cut),
    ]
    d.polygon(pts, fill=255)
    return mask


def texture_layer(size: tuple[int, int], color: tuple[int, int, int, int], seed: int, scratches := True) -> Image.Image:
    random.seed(seed)
    w, h = size
    base = Image.new("RGBA", size, color)
    noise = Image.effect_noise(size, 30).convert("L")
    noise = ImageEnhance.Contrast(noise).enhance(1.45)
    tint = Image.new("RGBA", size, (255, 255, 255, 0))
    tint.putalpha(noise.point(lambda p: max(0, min(28, p // 9))))
    base = Image.alpha_composite(base, tint)
    d = ImageDraw.Draw(base)
    if scratches:
        for _ in range(9):
            x = random.randint(-w // 4, w)
            y = random.randint(0, h)
            length = random.randint(w // 6, w // 3)
            col = (0, 0, 0, random.randint(18, 42))
            d.line((x, y, x + length, y - random.randint(12, 48)), fill=col, width=random.randint(2, 5))
    for _ in range(8):
        x = random.randint(0, w)
        y = random.randint(0, h)
        d.rectangle((x, y, x + random.randint(3, 10), y + random.randint(1, 3)), fill=(255, 255, 255, random.randint(14, 30)))
    return base


def framed_panel(name: str, size: tuple[int, int], tone: str, cut: int = 42, scratches := True) -> Image.Image:
    color = {
        "red": PALETTE["red_dark"],
        "purple": PALETTE["purple_dark"],
        "teal": PALETTE["teal_dark"],
        "dark": PALETTE["panel"],
        "yellow": PALETTE["yellow"],
    }[tone]
    accent = {
        "red": PALETTE["red"],
        "purple": PALETTE["purple"],
        "teal": PALETTE["teal"],
        "dark": (31, 34, 42, 255),
        "yellow": PALETTE["gold"],
    }[tone]
    w, h = size
    shadow_mask = poly_mask(size, 18, cut)
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow_layer = Image.new("RGBA", size, (0, 0, 0, 220))
    shifted = ImageChops.offset(shadow_mask, 13, 13)
    shadow.paste(shadow_layer, (0, 0), shifted.filter(ImageFilter.GaussianBlur(4)))

    body = texture_layer(size, color, abs(hash(name)) % 10_000, scratches)
    mask = poly_mask(size, 18, cut)
    panel = Image.new("RGBA", size, (0, 0, 0, 0))
    panel = Image.alpha_composite(panel, shadow)
    panel.paste(body, (0, 0), mask)
    d = ImageDraw.Draw(panel)
    pts = [
        (18 + cut, 18),
        (w - 18 - cut, 18),
        (w - 18, 18 + cut),
        (w - 18, h - 18 - cut),
        (w - 18 - cut, h - 18),
        (18 + cut // 2, h - 18),
        (18, h - 18 - cut // 2),
        (18, 18 + cut),
        (18 + cut, 18),
    ]
    d.line(pts, fill=PALETTE["line"], width=14, joint="curve")
    d.line(pts, fill=accent, width=5, joint="curve")
    d.polygon([(28, 24), (w * 0.58, 24), (w * 0.46, 76), (28, 95)], fill=accent)
    d.line((34, 96, w - 38, 96), fill=(2, 4, 7, 210), width=5)
    return panel


def title_banner() -> Image.Image:
    size = (820, 185)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(shadow)
    pts = [(0, 36), (740, 0), (665, 138), (0, 180)]
    d.polygon([(x + 12, y + 12) for x, y in pts], fill=(0, 0, 0, 210))
    shadow = shadow.filter(ImageFilter.GaussianBlur(3))
    img = Image.alpha_composite(img, shadow)
    body = texture_layer(size, PALETTE["red"], 2001, True)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    img.paste(body, (0, 0), mask)
    return img


def label_plate(tone: str, size: tuple[int, int]) -> Image.Image:
    img = framed_panel(f"label_{tone}_{size}", size, tone, cut=24, scratches=False)
    return img


def button_asset(primary: bool) -> Image.Image:
    size = (360, 86)
    tone = "yellow" if primary else "dark"
    img = framed_panel("button_primary" if primary else "button_secondary", size, tone, cut=24, scratches=False)
    return img


def background_from_reference() -> Image.Image:
    ref = Image.open(REF / "round_start_opponent_select_final_effect_v4_card.png").convert("RGBA")
    bg = ref.resize((1920, 1080), Image.Resampling.LANCZOS)
    bg = bg.filter(ImageFilter.GaussianBlur(7))
    veil = Image.new("RGBA", bg.size, (0, 0, 0, 155))
    return Image.alpha_composite(bg, veil)


def crop_portraits() -> None:
    round_ref = Image.open(REF / "round_start_opponent_select_final_effect_v4_card.png").convert("RGBA")
    # Crops retain the exact concept-art character rendering and card background texture.
    fox = round_ref.crop((42, 155, 460, 605)).resize((520, 560), Image.Resampling.LANCZOS)
    wolf = round_ref.crop((512, 218, 802, 615)).resize((430, 560), Image.Resampling.LANCZOS)
    save(fox, "avatar_fox_card.png")
    save(wolf, "avatar_wolf_card.png")


def icon_base(tone: str) -> Image.Image:
    col = {
        "red": (150, 8, 25, 255),
        "teal": (0, 116, 112, 255),
        "purple": (60, 35, 92, 255),
        "gold": (177, 109, 8, 255),
        "blue": (36, 53, 78, 255),
    }[tone]
    return framed_panel(f"tile_{tone}", (256, 256), "dark", cut=26).resize((256, 256)).copy().convert("RGBA").point(lambda p: p)


def draw_artifact(shape: str, tone: str) -> Image.Image:
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    bg = Image.new("RGBA", (256, 256), {
        "red": (123, 9, 23, 255),
        "teal": (0, 88, 88, 255),
        "purple": (58, 34, 89, 255),
        "gold": (176, 112, 8, 255),
        "blue": (35, 48, 72, 255),
    }[tone])
    mask = poly_mask((256, 256), 18, 30)
    img.paste(texture_layer((256, 256), bg.getpixel((0, 0)), abs(hash(shape)) % 10_000), (0, 0), mask)
    d = ImageDraw.Draw(img)
    black = PALETTE["black"]
    white = (242, 236, 218, 255)
    red = (232, 27, 48, 255)
    gold = PALETTE["gold"]
    teal = (0, 204, 184, 255)
    purple = (148, 72, 210, 255)
    if shape == "crystal":
        d.polygon([(128, 22), (184, 92), (146, 228), (76, 112)], fill=red, outline=black)
        d.line((128, 22, 128, 214), fill=white, width=6)
        d.line((82, 112, 184, 92), fill=white, width=5)
    elif shape == "keycard":
        d.polygon([(92, 42), (178, 58), (158, 210), (70, 190)], fill=(0, 134, 129, 255), outline=black)
        d.line((104, 78, 150, 86), fill=gold, width=14)
        d.ellipse((114, 94, 158, 138), outline=gold, width=10)
        d.line((134, 136, 118, 174), fill=gold, width=12)
    elif shape == "crown":
        d.polygon([(44, 166), (72, 78), (112, 138), (128, 56), (148, 138), (190, 78), (212, 166)], fill=white, outline=black)
        d.line((66, 170, 194, 170), fill=black, width=12)
    elif shape == "target":
        d.polygon([(70, 48), (174, 72), (192, 188), (84, 208)], fill=(197, 137, 59, 255), outline=black)
        d.ellipse((96, 92, 166, 162), outline=red, width=9)
        d.ellipse((116, 112, 146, 142), fill=red, outline=black)
    elif shape == "dagger":
        d.polygon([(170, 22), (142, 152), (82, 226), (108, 136)], fill=white, outline=black)
        d.polygon([(82, 138), (138, 154), (110, 178)], fill=red, outline=black)
    elif shape == "amulet":
        d.polygon([(128, 54), (198, 172), (128, 220), (58, 172)], fill=purple, outline=black)
        d.polygon([(128, 78), (166, 164), (128, 192), (90, 164)], fill=(42, 18, 70, 255), outline=gold)
        d.arc((44, 30, 212, 120), 190, 350, fill=gold, width=7)
    elif shape == "silk":
        d.polygon([(50, 76), (142, 54), (208, 104), (104, 132)], fill=gold, outline=black)
        d.polygon([(58, 136), (150, 106), (204, 158), (104, 190)], fill=red, outline=black)
    elif shape == "map":
        d.polygon([(48, 68), (105, 48), (150, 78), (206, 58), (196, 188), (138, 210), (93, 178), (52, 198)], fill=(210, 148, 65, 255), outline=black)
        d.line((84, 104, 130, 145, 172, 110), fill=red, width=9)
    elif shape == "coin":
        d.ellipse((56, 56, 200, 200), fill=gold, outline=black, width=13)
        d.polygon([(128, 84), (164, 128), (128, 174), (92, 128)], fill=purple, outline=black)
    elif shape == "mask":
        d.polygon([(48, 82), (122, 48), (116, 170), (64, 188)], fill=red, outline=black)
        d.polygon([(208, 82), (134, 48), (140, 170), (192, 188)], fill=red, outline=black)
        d.ellipse((86, 108, 112, 130), fill=black)
        d.ellipse((144, 108, 170, 130), fill=black)
    return img


def draw_tool_icon(kind: str, color: tuple[int, int, int, int]) -> Image.Image:
    img = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((20, 20, 236, 236), fill=color, outline=PALETTE["line"], width=10)
    white = (236, 232, 218, 255)
    black = PALETTE["black"]
    if kind == "eye":
        d.ellipse((52, 86, 204, 170), outline=white, width=16)
        d.ellipse((110, 100, 146, 158), fill=white)
    elif kind == "bag":
        d.polygon([(74, 96), (182, 96), (198, 194), (58, 194)], fill=white, outline=black)
        d.arc((94, 54, 162, 118), 180, 360, fill=white, width=13)
    elif kind == "scroll":
        d.rounded_rectangle((68, 58, 178, 198), radius=10, fill=white, outline=black, width=8)
        for y in (92, 124, 156):
            d.line((94, y, 154, y), fill=black, width=7)
    elif kind == "book":
        d.rectangle((56, 68, 122, 188), fill=white, outline=black, width=8)
        d.rectangle((134, 68, 200, 188), fill=white, outline=black, width=8)
    elif kind == "heart":
        d.polygon([(128, 202), (56, 114), (82, 70), (128, 96), (174, 70), (200, 114)], fill=white, outline=black)
        d.line((76, 132, 108, 132, 126, 102, 148, 162, 178, 162), fill=color, width=10)
    elif kind == "gear":
        for a in range(0, 360, 45):
            r = math.radians(a)
            x, y = 128 + math.cos(r) * 66, 128 + math.sin(r) * 66
            d.rectangle((x - 13, y - 13, x + 13, y + 13), fill=white)
        d.ellipse((68, 68, 188, 188), fill=white, outline=black, width=8)
        d.ellipse((108, 108, 148, 148), fill=color, outline=black, width=7)
    return img


def main() -> None:
    ensure()
    save(background_from_reference(), "bg_card_city.png")
    crop_portraits()
    save(title_banner(), "ui_title_banner_red.png")
    save(framed_panel("card_player_red", (470, 780), "red", 46), "ui_card_player_red.png")
    save(framed_panel("card_option_red", (365, 620), "red", 40), "ui_card_option_red.png")
    save(framed_panel("card_option_purple", (365, 620), "purple", 40), "ui_card_option_purple.png")
    save(framed_panel("card_option_teal", (365, 620), "teal", 40), "ui_card_option_teal.png")
    save(framed_panel("card_dark_teal", (620, 720), "teal", 42), "ui_panel_teal_large.png")
    save(framed_panel("card_dark", (620, 720), "dark", 42), "ui_panel_dark_large.png")
    save(framed_panel("req_red", (560, 260), "red", 36), "ui_panel_req_red.png")
    save(framed_panel("req_purple", (560, 360), "purple", 36), "ui_panel_req_purple.png")
    save(framed_panel("bag_purple", (420, 720), "purple", 38), "ui_panel_bag_purple.png")
    save(framed_panel("item_red", (300, 460), "red", 32), "ui_card_item_red.png")
    save(framed_panel("item_teal", (300, 460), "teal", 32), "ui_card_item_teal.png")
    save(framed_panel("item_purple", (300, 460), "purple", 32), "ui_card_item_purple.png")
    save(label_plate("red", (260, 64)), "ui_label_red.png")
    save(label_plate("teal", (260, 64)), "ui_label_teal.png")
    save(label_plate("purple", (260, 64)), "ui_label_purple.png")
    save(label_plate("dark", (330, 64)), "ui_stat_row_dark.png")
    save(button_asset(True), "ui_button_primary.png")
    save(button_asset(False), "ui_button_secondary.png")
    save(label_plate("dark", (112, 112)), "ui_item_tile_dark.png")
    save(label_plate("red", (112, 112)), "ui_item_tile_red.png")
    save(label_plate("teal", (112, 112)), "ui_item_tile_teal.png")
    save(label_plate("purple", (112, 112)), "ui_item_tile_purple.png")
    save(label_plate("dark", (440, 96)), "ui_meta_plate_dark.png")
    for artifact_id, shape, tone in ARTIFACTS:
        save(draw_artifact(shape, tone), f"artifact_{artifact_id}.png")
    for name, kind, bg in TOOLS:
        save(draw_tool_icon(kind, bg), f"icon_{name}.png")
    print(f"Wrote v2 card UI assets to {OUT}")


if __name__ == "__main__":
    main()
