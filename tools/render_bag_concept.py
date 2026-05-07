from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
import random


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ui" / "concepts" / "gameplay" / "dialogue_overlay_bag_ai_final_hades_flat_square.png"
FONT = ROOT / "project" / "assets" / "fonts" / "AlibabaPuHuiTi-3-105-Heavy.ttf"
ASSET_DIR = ROOT / "project" / "assets" / "generated" / "ui" / "card"

W, H = 1920, 1080


def font(size):
    return ImageFont.truetype(str(FONT), size=size)


def rgba(hex_color, alpha=255):
    hex_color = hex_color.lstrip("#")
    return tuple(int(hex_color[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def chamfer(x, y, w, h, c=18):
    return [
        (x + c, y),
        (x + w - c, y),
        (x + w, y + c),
        (x + w, y + h - c),
        (x + w - c, y + h),
        (x + c, y + h),
        (x, y + h - c),
        (x, y + c),
    ]


def banner(x, y, w, h, side="left", cut=34):
    if side == "left":
        return [(x + cut, y), (x + w, y), (x + w - cut, y + h), (x, y + h), (x + 14, y + h // 2)]
    return [(x, y), (x + w - cut, y), (x + w, y + h // 2), (x + w - cut, y + h), (x, y + h)]


def shadow_poly(draw, pts, off=(10, 12), blur=False):
    sx, sy = off
    draw.polygon([(x + sx, y + sy) for x, y in pts], fill=rgba("#000000", 115))


def draw_chamfer_panel(draw, x, y, w, h, fill, outline, c=26, width=5):
    pts = chamfer(x, y, w, h, c)
    shadow_poly(draw, pts)
    draw.polygon(pts, fill=fill, outline=outline)
    for i in range(width - 1):
        draw.line(pts + [pts[0]], fill=outline, width=width - i)
    draw.line([(x + c + 8, y + 10), (x + w - c - 12, y + 10)], fill=rgba("#ffd272", 70), width=2)


def text(draw, xy, s, size, fill="#f7edda", anchor="la", stroke=3, align="left"):
    draw.text(
        xy,
        s,
        font=font(size),
        fill=rgba(fill),
        anchor=anchor,
        stroke_width=stroke,
        stroke_fill=rgba("#12090a", 225),
        align=align,
    )


def fit_text(draw, box, s, max_size, fill="#f7edda", min_size=18):
    x, y, w, h = box
    size = max_size
    while size >= min_size:
        f = font(size)
        bbox = draw.textbbox((0, 0), s, font=f, stroke_width=2)
        if bbox[2] - bbox[0] <= w and bbox[3] - bbox[1] <= h:
            draw.text((x + w / 2, y + h / 2), s, font=f, fill=rgba(fill), anchor="mm", stroke_width=2, stroke_fill=rgba("#14090a"))
            return
        size -= 1
    draw.text((x + w / 2, y + h / 2), s, font=font(min_size), fill=rgba(fill), anchor="mm", stroke_width=2, stroke_fill=rgba("#14090a"))


def make_background():
    im = Image.new("RGBA", (W, H), rgba("#08090c"))
    d = ImageDraw.Draw(im, "RGBA")
    random.seed(7)
    d.rectangle((0, 0, W, H), fill=rgba("#08090c"))
    d.polygon([(0, 0), (600, 0), (150, H), (0, H)], fill=rgba("#5c111c", 105))
    d.polygon([(1320, 0), (W, 0), (W, H), (1530, H), (1210, 260)], fill=rgba("#053f43", 125))
    d.polygon([(700, 0), (1130, 0), (940, H), (500, H)], fill=rgba("#25123f", 90))
    for x in range(-120, W + 220, 190):
        d.line((x, H, x + 560, 0), fill=rgba("#000000", 58), width=7)
    for x in range(0, W, 96):
        d.line((x, 0, x, H), fill=rgba("#26171b", 80), width=1)
    for y in range(0, H, 96):
        d.line((0, y, W, y), fill=rgba("#26171b", 62), width=1)
    # Stylized roof silhouettes and lanterns, kept quiet behind the UI.
    for base_x in [250, 560, 1220, 1570]:
        d.polygon(
            [(base_x - 260, 210), (base_x + 70, 108), (base_x + 400, 210), (base_x + 330, 250), (base_x - 190, 250)],
            fill=rgba("#050405", 180),
        )
        d.line((base_x - 180, 230, base_x + 310, 230), fill=rgba("#4b1a16", 170), width=8)
    for x, y, c in [(850, 100, "#dcb629"), (1415, 72, "#1fb7a6"), (330, 180, "#c43137"), (1690, 165, "#d98b28")]:
        d.rectangle((x - 5, y, x + 5, y + 60), fill=rgba("#090506", 180))
        d.ellipse((x - 18, y + 50, x + 18, y + 90), fill=rgba(c, 170), outline=rgba("#120909", 220), width=3)
    return im.filter(ImageFilter.GaussianBlur(0.4))


def paste_icon(base, path, center, size):
    icon = Image.open(path).convert("RGBA")
    bbox = icon.getbbox()
    if bbox:
        icon = icon.crop(bbox)
    icon.thumbnail((size, size), Image.Resampling.LANCZOS)
    shadow = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    shadow.alpha_composite(icon)
    shadow = shadow.filter(ImageFilter.GaussianBlur(5))
    sx = int(center[0] - icon.width / 2 + 8)
    sy = int(center[1] - icon.height / 2 + 10)
    base.alpha_composite(shadow, (sx, sy))
    base.alpha_composite(icon, (int(center[0] - icon.width / 2), int(center[1] - icon.height / 2)))


def item_tile(base, draw, x, y, size, name, icon, color, count=None, need=None):
    pts = chamfer(x, y, size, size, 16)
    draw.polygon([(px + 8, py + 10) for px, py in pts], fill=rgba("#000000", 130))
    draw.polygon(pts, fill=rgba(color, 55), outline=rgba(color, 230))
    draw.line(pts + [pts[0]], fill=rgba("#08080b", 215), width=8)
    draw.line(pts + [pts[0]], fill=rgba(color, 210), width=4)
    draw.line((x + 20, y + 10, x + size - 24, y + 10), fill=rgba("#f6c76d", 45), width=2)
    paste_icon(base, icon, (x + size / 2, y + size * 0.43), int(size * 0.54))
    label_h = int(size * 0.25)
    draw.polygon(
        [(x + 12, y + size - label_h), (x + size - 12, y + size - label_h), (x + size - 24, y + size - 10), (x + 22, y + size - 10)],
        fill=rgba("#0b090c", 190),
    )
    fit_text(draw, (x + 24, y + size - label_h + 3, size - 48, label_h - 10), name, 31)
    if count is not None:
        tag = chamfer(x + size - 54, y + 10, 44, 44, 7)
        draw.polygon(tag, fill=rgba("#111016", 245), outline=rgba("#6f7a7d", 230))
        fit_text(draw, (x + size - 52, y + 12, 38, 38), str(count), 32)
    if need is not None:
        fit_text(draw, (x + 16, y + size - 52, size - 32, 40), need, 29)


def requirement_tile(base, draw, x, y, size, icon, color, need="0/1"):
    pts = chamfer(x, y, size, size, 14)
    draw.polygon([(px + 8, py + 10) for px, py in pts], fill=rgba("#000000", 130))
    draw.polygon(pts, fill=rgba(color, 62), outline=rgba(color, 235))
    draw.line(pts + [pts[0]], fill=rgba("#08080b", 225), width=8)
    draw.line(pts + [pts[0]], fill=rgba(color, 220), width=4)
    draw.line((x + 18, y + 10, x + size - 22, y + 10), fill=rgba("#f6c76d", 58), width=2)
    paste_icon(base, icon, (x + size / 2, y + size * 0.44), int(size * 0.62))
    label_h = 40
    draw.polygon(
        [(x + 12, y + size - label_h - 4), (x + size - 12, y + size - label_h - 4), (x + size - 22, y + size - 8), (x + 22, y + size - 8)],
        fill=rgba("#0b090c", 210),
    )
    fit_text(draw, (x + 18, y + size - label_h - 1, size - 36, label_h - 6), need, 31)


def top_resource(draw, x, label, value, color):
    pts = chamfer(x, 50, 205, 70, 14)
    draw.polygon(pts, fill=rgba("#111015", 235), outline=rgba("#403037", 255))
    draw.line(pts + [pts[0]], fill=rgba("#07070a", 250), width=6)
    draw.line(pts + [pts[0]], fill=rgba("#3a3339", 255), width=3)
    text(draw, (x + 28, 85), label, 28, anchor="lm", stroke=2)
    text(draw, (x + 138, 85), value, 30, fill=color, anchor="mm", stroke=2)


def main():
    base = make_background()
    d = ImageDraw.Draw(base, "RGBA")

    # Title shard and top bar.
    title_pts = [(36, 34), (532, 24), (500, 156), (12, 188), (48, 111)]
    d.polygon([(x + 10, y + 14) for x, y in title_pts], fill=rgba("#000000", 145))
    d.polygon(title_pts, fill=rgba("#bb1e26", 238), outline=rgba("#070507", 255))
    d.line(title_pts + [title_pts[0]], fill=rgba("#060405", 255), width=8)
    d.line((62, 42, 495, 31), fill=rgba("#ff5d52", 90), width=3)
    text(d, (132, 104), "背包", 82, anchor="lm", stroke=5)

    top_pts = chamfer(980, 48, 880, 86, 20)
    d.polygon([(x + 9, y + 11) for x, y in top_pts], fill=rgba("#000000", 135))
    d.polygon(top_pts, fill=rgba("#111015", 235), outline=rgba("#2d252b", 255))
    d.line(top_pts + [top_pts[0]], fill=rgba("#08070a", 255), width=7)
    d.line(top_pts + [top_pts[0]], fill=rgba("#42353a", 255), width=3)
    top_resource(d, 1010, "能量", "128", "#ff3038")
    top_resource(d, 1228, "背包", "24/40", "#e6aa37")
    top_resource(d, 1446, "灵光", "35", "#bb54ff")
    top_resource(d, 1664, "印记", "6", "#1fb7a6")

    # Panels use simple chamfered rectangles with uniform bevels for future slicing.
    draw_chamfer_panel(d, 50, 214, 700, 806, rgba("#151218", 232), rgba("#111016", 255), c=24, width=5)
    draw_chamfer_panel(d, 775, 182, 1090, 838, rgba("#073b3b", 220), rgba("#063033", 255), c=24, width=5)

    # Section banners.
    for bx, by, bw, bh, label, col in [
        (72, 218, 295, 70, "统治需求", "#bb1e32"),
        (72, 586, 295, 70, "深化需求", "#6e2a91"),
        (820, 178, 910, 70, "当前持有", "#087a74"),
    ]:
        pts = banner(bx, by, bw, bh)
        d.polygon([(x + 8, y + 9) for x, y in pts], fill=rgba("#000000", 120))
        d.polygon(pts, fill=rgba(col, 235), outline=rgba("#0a0609", 255))
        d.line(pts + [pts[0]], fill=rgba("#090509", 255), width=6)
        text(d, (bx + 64, by + bh / 2), label, 41, anchor="lm", stroke=4)

    icons = [
        "artifact_snake_marrow_vial.png",
        "artifact_deer_bell.png",
        "artifact_cracked_gold_seal.png",
        "artifact_ash_map.png",
        "artifact_debt_silk.png",
        "artifact_silent_coin.png",
        "artifact_wolf_oath_blade.png",
        "artifact_moon_lantern.png",
        "artifact_ink_feather_jar.png",
        "artifact_red_market_mask.png",
    ]
    paths = [ASSET_DIR / n for n in icons]

    # Requirement tiles, now strictly square.
    req_top = [
        ("血契棱镜", paths[0], "#bd1f35"),
        ("月厅密钥", paths[1], "#0a8c82"),
        ("灰冠契印", paths[2], "#6a4a86"),
        ("契约书", paths[3], "#8a6940"),
    ]
    req_bot = [
        ("虚空吊坠", paths[4], "#6a4a86"),
        ("回响石", paths[5], "#0a8c82"),
        ("噬灵匕首", paths[6], "#245c8c"),
        ("权柄圣杯", paths[7], "#a56a21"),
    ]
    sx, gap, tile = 82, 22, 138
    for i, (name, icon, col) in enumerate(req_top):
        requirement_tile(base, d, sx + i * (tile + gap), 330, tile, icon, col, need="0/1")
    for i, (name, icon, col) in enumerate(req_bot):
        requirement_tile(base, d, sx + i * (tile + gap), 698, tile, icon, col, need="0/1")

    # Inventory grid, all square cards.
    names = ["血契棱镜", "月厅密钥", "灰冠契印", "虚空吊坠", "契约书", "回响石", "噬灵匕首", "幽冥之火", "权柄圣杯", "无面面具", "生机玉环", "灵光碎片"]
    inv_icons = [paths[0], paths[1], paths[2], paths[4], paths[3], paths[5], paths[6], paths[8], paths[7], paths[9], paths[5], paths[0]]
    cols = ["#bd1f35", "#0a8c82", "#6a4a86", "#6a4a86", "#8a6940", "#0a8c82", "#245c8c", "#6a2b91", "#a56a21", "#6a4a86", "#0a8c82", "#245c8c"]
    counts = [8, 3, 2, 1, 2, 6, 4, 5, 2, 1, 3, 7]
    size, gx, gy = 216, 36, 28
    start_x, start_y = 820, 268
    for idx, name in enumerate(names):
        r, c = divmod(idx, 4)
        item_tile(base, d, start_x + c * (size + gx), start_y + r * (size + gy), size, name, inv_icons[idx], cols[idx], count=counts[idx])

    # Bottom buttons with consistent chamfers and isolated icon/text groups.
    for x, label, col in [(72, "返回", "#bb1e32"), (410, "整理", "#d69b22")]:
        pts = chamfer(x, 956, 280, 70, 16)
        d.polygon([(px + 8, py + 8) for px, py in pts], fill=rgba("#000000", 130))
        d.polygon(pts, fill=rgba(col, 240), outline=rgba("#090508", 255))
        d.line(pts + [pts[0]], fill=rgba("#070406", 255), width=6)
        if label == "返回":
            d.polygon([(x + 64, 991), (x + 108, 963), (x + 108, 981), (x + 156, 981), (x + 156, 1001), (x + 108, 1001), (x + 108, 1019)], fill=rgba("#080405", 255))
            tx = x + 175
        else:
            cx, cy = x + 86, 991
            d.polygon([(cx, cy - 28), (cx + 34, cy), (cx, cy + 28), (cx - 34, cy)], outline=rgba("#080405", 255), fill=None, width=7)
            d.polygon([(cx, cy - 13), (cx + 16, cy), (cx, cy + 13), (cx - 16, cy)], outline=rgba("#080405", 255), fill=None, width=6)
            tx = x + 160
        if label == "返回":
            text(d, (tx, 992), label, 43, fill="#fff0d0", anchor="lm", stroke=2)
        else:
            d.text((tx, 992), label, font=font(43), fill=rgba("#18100b"), anchor="lm")

    # Small crop guide ticks integrated into the style.
    for x, y in [(770, 180), (1858, 180), (770, 1012), (1858, 1012), (48, 214), (744, 1014)]:
        d.line((x, y, x + 34, y), fill=rgba("#000000", 200), width=6)
        d.line((x, y, x, y + 34), fill=rgba("#000000", 200), width=6)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    base.convert("RGB").save(OUT, quality=95)
    print(OUT)


if __name__ == "__main__":
    main()
