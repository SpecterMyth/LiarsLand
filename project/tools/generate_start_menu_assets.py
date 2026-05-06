from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "generated" / "ui" / "start_menu"
FONT_DIR = Path("C:/Windows/Fonts")


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    path = FONT_DIR / name
    if path.exists():
        return ImageFont.truetype(str(path), size)
    return ImageFont.truetype(str(FONT_DIR / "georgiab.ttf"), size)


def vertical_gradient(size: tuple[int, int], stops: list[tuple[float, tuple[int, int, int, int]]]) -> Image.Image:
    width, height = size
    img = Image.new("RGBA", size)
    px = img.load()
    for y in range(height):
        t = y / max(1, height - 1)
        left = stops[0]
        right = stops[-1]
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                left = stops[i]
                right = stops[i + 1]
                break
        span = max(0.0001, right[0] - left[0])
        local = (t - left[0]) / span
        color = tuple(round(left[1][c] + (right[1][c] - left[1][c]) * local) for c in range(4))
        for x in range(width):
            px[x, y] = color
    return img


def rounded_rect_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def save_button(path: Path, size: tuple[int, int], radius: int, mode: str, primary: bool) -> None:
    w, h = size
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((10, 14, w - 10, h - 10), radius, fill=(0, 0, 0, 145))
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    img.alpha_composite(shadow)

    if primary:
        if mode == "pressed":
            stops = [(0, (232, 83, 34, 255)), (0.45, (255, 163, 37, 255)), (1, (148, 17, 39, 255))]
            top_line = (255, 214, 82, 190)
        elif mode == "hover":
            stops = [(0, (255, 249, 126, 255)), (0.4, (255, 188, 45, 255)), (1, (246, 38, 75, 255))]
            top_line = (255, 255, 195, 230)
        else:
            stops = [(0, (255, 236, 96, 255)), (0.4, (255, 175, 38, 255)), (1, (230, 31, 70, 255))]
            top_line = (255, 248, 181, 210)
        border = (255, 220, 111, 255)
        inner = (255, 246, 198, 170)
    else:
        if mode == "pressed":
            stops = [(0, (22, 15, 14, 250)), (1, (5, 4, 5, 250))]
            border = (154, 88, 27, 255)
        elif mode == "hover":
            stops = [(0, (42, 25, 21, 250)), (1, (8, 6, 7, 250))]
            border = (232, 161, 58, 255)
        else:
            stops = [(0, (29, 18, 16, 250)), (1, (6, 5, 6, 250))]
            border = (201, 138, 54, 255)
        top_line = (255, 210, 112, 100)
        inner = (143, 90, 36, 150)

    content_box = (8, 6, w - 8, h - 10)
    mask = rounded_rect_mask((w - 16, h - 16), radius)
    fill = vertical_gradient((w - 16, h - 16), stops)
    fill.putalpha(mask)
    img.alpha_composite(fill, (8, 6))

    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(content_box, radius, outline=border, width=4 if primary else 3)
    draw.rounded_rectangle((24, 24, w - 24, h - 26), max(4, radius - 3), outline=inner, width=2)
    draw.line((42, 8, w - 42, 8), fill=top_line, width=4 if primary else 2)
    if primary:
        draw.line((48, h - 12, w - 48, h - 12), fill=(90, 13, 17, 120), width=4)
    img.save(path)


def save_logo(path: Path) -> None:
    size = (980, 260)
    scale = 3
    canvas = Image.new("RGBA", (size[0] * scale, size[1] * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    text = "LIARS LAND"
    typeface = font("ALGER.TTF", 108 * scale)
    bbox = draw.textbbox((0, 0), text, font=typeface, stroke_width=0)
    x = (canvas.width - (bbox[2] - bbox[0])) // 2
    y = 58 * scale

    for dy in range(14 * scale, 4 * scale, -2):
        draw.text((x, y + dy), text, font=typeface, fill=(0, 0, 0, 42), stroke_width=7 * scale, stroke_fill=(0, 0, 0, 70))

    stroke_w = 5 * scale
    draw.text((x, y), text, font=typeface, fill=(255, 242, 187, 255), stroke_width=stroke_w + 3 * scale, stroke_fill=(13, 5, 6, 255))
    text_mask = Image.new("L", canvas.size, 0)
    mask_draw = ImageDraw.Draw(text_mask)
    mask_draw.text((x, y), text, font=typeface, fill=255, stroke_width=0)
    grad = vertical_gradient(canvas.size, [
        (0, (255, 246, 195, 255)),
        (0.46, (252, 202, 94, 255)),
        (0.76, (216, 132, 47, 255)),
        (1, (230, 45, 72, 255)),
    ])
    grad.putalpha(text_mask)
    canvas.alpha_composite(grad)
    highlight_mask = Image.new("L", canvas.size, 0)
    highlight_draw = ImageDraw.Draw(highlight_mask)
    highlight_draw.text((x, y - 2 * scale), text, font=typeface, fill=120, stroke_width=0)
    highlight = Image.new("RGBA", canvas.size, (255, 251, 212, 0))
    highlight.putalpha(highlight_mask.filter(ImageFilter.GaussianBlur(0.25 * scale)))
    canvas.alpha_composite(highlight)

    arc_color = (240, 197, 111, 220)
    red_color = (241, 32, 71, 160)
    draw.arc((160 * scale, 26 * scale, 820 * scale, 210 * scale), 200, 340, fill=red_color, width=3 * scale)
    draw.arc((150 * scale, 70 * scale, 830 * scale, 238 * scale), 20, 160, fill=arc_color, width=4 * scale)
    draw.polygon(
        [(46 * scale, 132 * scale), (84 * scale, 112 * scale), (70 * scale, 154 * scale)],
        fill=(255, 212, 104, 255),
        outline=(20, 6, 7, 255),
    )
    draw.polygon(
        [(934 * scale, 132 * scale), (896 * scale, 112 * scale), (910 * scale, 154 * scale)],
        fill=(255, 212, 104, 255),
        outline=(20, 6, 7, 255),
    )
    canvas = canvas.resize(size, Image.Resampling.LANCZOS)
    canvas.save(path)


def save_vignette(path: Path) -> None:
    size = (1600, 900)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    px = img.load()
    cx, cy = size[0] / 2, size[1] * 0.42
    max_d = math.hypot(cx, cy)
    for y in range(size[1]):
        for x in range(size[0]):
            d = math.hypot((x - cx) * 1.05, (y - cy) * 1.25) / max_d
            alpha = int(max(0, min(190, (d - 0.25) * 250)))
            center_glow = max(0, 1 - math.hypot((x - cx) / 520, (y - cy) / 310))
            r = int(8 + 42 * center_glow)
            g = int(4 + 26 * center_glow)
            b = int(5 + 18 * center_glow)
            px[x, y] = (r, g, b, alpha)
    img.save(path)


def save_border(path: Path) -> None:
    size = (1600, 900)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.rectangle((44, 44, 1556, 856), outline=(201, 138, 54, 150), width=2)
    draw.line((644, 794, 956, 794), fill=(201, 138, 54, 220), width=2)
    img.save(path)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    save_logo(OUT / "logo_liars_land.png")
    for mode in ("normal", "hover", "pressed"):
        save_button(OUT / f"button_start_{mode}.png", (620, 144), 10, mode, True)
        save_button(OUT / f"button_small_{mode}.png", (288, 92), 8, mode, False)
    save_vignette(OUT / "menu_panel_vignette.png")
    save_border(OUT / "menu_border.png")


if __name__ == "__main__":
    main()
