from __future__ import annotations

import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "generated" / "ui" / "shop_v2"

COLORS = {
    "red": (173, 14, 29, 255),
    "red_dark": (92, 7, 18, 246),
    "teal": (0, 126, 119, 255),
    "teal_dark": (0, 58, 63, 246),
    "purple": (83, 44, 112, 255),
    "purple_dark": (43, 25, 58, 246),
    "gold": (245, 176, 27, 255),
    "gold_dark": (166, 101, 5, 255),
    "dark": (9, 11, 16, 248),
    "ink": (2, 3, 6, 255),
    "line": (5, 6, 10, 255),
}


def save(img: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    img.save(OUT / name)


def poly_points(size: tuple[int, int], inset: int, cut: int) -> list[tuple[int, int]]:
    w, h = size
    return [
        (inset + cut, inset),
        (w - inset - cut, inset),
        (w - inset, inset + cut),
        (w - inset, h - inset - cut),
        (w - inset - cut, h - inset),
        (inset + cut // 2, h - inset),
        (inset, h - inset - cut // 2),
        (inset, inset + cut),
    ]


def mask_for(size: tuple[int, int], inset: int, cut: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(poly_points(size, inset, cut), fill=255)
    return mask


def texture(size: tuple[int, int], color: tuple[int, int, int, int], seed: int, strength: int = 24) -> Image.Image:
    random.seed(seed)
    base = Image.new("RGBA", size, color)
    noise = Image.effect_noise(size, 26).convert("L")
    noise = ImageEnhance.Contrast(noise).enhance(1.35)
    tint = Image.new("RGBA", size, (255, 255, 255, 0))
    tint.putalpha(noise.point(lambda p: max(0, min(strength, p // 10))))
    base = Image.alpha_composite(base, tint)
    d = ImageDraw.Draw(base)
    w, h = size
    for _ in range(max(2, w // 180)):
        x = random.randint(-w // 5, w)
        y = random.randint(0, h)
        d.line(
            (x, y, x + random.randint(w // 8, w // 4), y - random.randint(6, 22)),
            fill=(0, 0, 0, random.randint(8, 18)),
            width=random.randint(1, 2),
        )
    return base


def framed(name: str, size: tuple[int, int], tone: str, cut: int = 34, inset: int = 16, top_sash: bool = True) -> Image.Image:
    body_color = COLORS[f"{tone}_dark"] if f"{tone}_dark" in COLORS else COLORS[tone]
    accent = COLORS[tone]
    mask = mask_for(size, inset, cut)
    shadow_mask = ImageChops.offset(mask, 10, 10).filter(ImageFilter.GaussianBlur(5))
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    img.paste(Image.new("RGBA", size, (0, 0, 0, 160)), (0, 0), shadow_mask)
    img.paste(texture(size, body_color, abs(hash(name)) % 10000), (0, 0), mask)
    d = ImageDraw.Draw(img)
    pts = poly_points(size, inset, cut) + [poly_points(size, inset, cut)[0]]
    d.line(pts, fill=COLORS["line"], width=12, joint="curve")
    d.line(pts, fill=accent, width=4, joint="curve")
    if top_sash:
        w, _h = size
        sash = [(inset + 10, inset + 8), (w - inset - cut, inset + 8), (w - inset - cut // 2, inset + 48), (inset + cut // 2, inset + 58)]
        d.polygon(sash, fill=accent)
        d.line(sash + [sash[0]], fill=COLORS["line"], width=5)
    return img


def banner() -> Image.Image:
    size = (760, 170)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    body = texture(size, COLORS["red"], 6401, 18)
    pts = [(0, 34), (720, 0), (645, 130), (0, 168)]
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(pts, fill=255)
    img.paste(body, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.line(pts + [pts[0]], fill=COLORS["line"], width=9)
    d.line(pts + [pts[0]], fill=COLORS["red"], width=4)
    for x in (110, 310, 520):
        d.line((x, 42, x + 120, 34), fill=(0, 0, 0, 90), width=5)
    return img


def plate(name: str, size: tuple[int, int], tone: str, cut: int = 22) -> Image.Image:
    return framed(name, size, tone, cut=cut, inset=10, top_sash=False)


def button(name: str, disabled: bool = False) -> Image.Image:
    tone = "dark" if disabled else "gold"
    img = framed(name, (360, 90), tone, cut=20, inset=10, top_sash=False)
    d = ImageDraw.Draw(img)
    if disabled:
        d.rectangle((0, 0, 360, 90), fill=(20, 20, 24, 120))
    else:
        d.polygon([(28, 20), (332, 12), (316, 76), (44, 82)], fill=(255, 206, 61, 70))
    return img


def slot(name: str, tone: str, filled: bool) -> Image.Image:
    img = framed(name, (128, 128), tone, cut=20, inset=12, top_sash=False)
    if not filled:
        veil = Image.new("RGBA", img.size, (0, 0, 0, 115))
        img = Image.alpha_composite(img, veil)
    return img


def artifact_frame(name: str, tone: str) -> Image.Image:
    img = framed(name, (160, 160), tone, cut=24, inset=12, top_sash=False)
    d = ImageDraw.Draw(img)
    d.rectangle((32, 32, 128, 128), outline=(0, 0, 0, 170), width=5)
    return img


def main() -> None:
    save(banner(), "shop_title_banner_red.png")
    save(plate("status", (520, 90), "dark", 20), "shop_status_bar_dark.png")
    save(framed("player_card", (470, 770), "red", 42, 18, True), "shop_player_card_red.png")
    save(plate("nameplate", (320, 70), "red", 20), "shop_nameplate_red.png")
    save(plate("stat_row", (330, 56), "dark", 16), "shop_stat_row_dark.png")
    save(framed("req_red", (560, 210), "red", 28, 14, False), "shop_requirement_panel_red.png")
    save(framed("req_teal", (560, 210), "teal", 28, 14, False), "shop_requirement_panel_teal.png")
    save(plate("req_title_red", (280, 58), "red", 18), "shop_requirement_title_red.png")
    save(plate("req_title_teal", (280, 58), "teal", 18), "shop_requirement_title_teal.png")
    save(slot("slot_empty", "dark", False), "shop_slot_empty.png")
    save(slot("slot_filled", "red", True), "shop_slot_filled_red.png")
    save(slot("slot_missing", "dark", False), "shop_slot_missing_dark.png")
    save(artifact_frame("frame_red", "red"), "shop_artifact_frame_red.png")
    save(artifact_frame("frame_teal", "teal"), "shop_artifact_frame_teal.png")
    save(artifact_frame("frame_purple", "purple"), "shop_artifact_frame_purple.png")
    save(plate("section_teal", (520, 70), "teal", 20), "shop_section_title_teal.png")
    save(framed("item_red", (320, 460), "red", 30, 14, False), "shop_item_card_red.png")
    save(framed("item_teal", (320, 460), "teal", 30, 14, False), "shop_item_card_teal.png")
    save(framed("item_purple", (320, 460), "purple", 30, 14, False), "shop_item_card_purple.png")
    save(plate("price", (240, 66), "dark", 16), "shop_price_plate_dark.png")
    save(button("button_gold", False), "shop_button_gold.png")
    save(button("button_disabled", True), "shop_button_disabled.png")
    save(framed("backpack", (360, 700), "purple", 34, 16, False), "shop_backpack_panel_purple.png")
    save(plate("backpack_title", (300, 70), "purple", 18), "shop_backpack_title_purple.png")
    save(plate("count_badge", (66, 54), "dark", 12), "shop_count_badge_dark.png")
    print(f"Wrote shop v2 assets to {OUT}")


if __name__ == "__main__":
    main()
