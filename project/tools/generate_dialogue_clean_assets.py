from __future__ import annotations

from pathlib import Path
import random

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "generated" / "ui" / "dialogue"

INK = (8, 6, 5, 255)
ALLY_FILL = (218, 139, 39, 255)
ENEMY_FILL = (164, 31, 39, 255)
NAMEPLATE_FILL = (96, 82, 66, 255)
ALLY_NAME_ACCENT = (207, 135, 37, 255)
ENEMY_NAME_ACCENT = (178, 35, 45, 255)


def scaled_polygon(points: list[tuple[float, float]], scale: int) -> list[tuple[int, int]]:
    return [(round(x * scale), round(y * scale)) for x, y in points]


def jittered_edge(
    a: tuple[float, float],
    b: tuple[float, float],
    steps: int,
    jitter: float,
    rng: random.Random,
) -> list[tuple[float, float]]:
    points: list[tuple[float, float]] = []
    for i in range(steps):
        t = i / float(steps)
        x = a[0] + (b[0] - a[0]) * t
        y = a[1] + (b[1] - a[1]) * t
        points.append((x + rng.uniform(-jitter, jitter), y + rng.uniform(-jitter, jitter)))
    return points


def jittered_polygon(points: list[tuple[float, float]], jitter: float, seed: int) -> list[tuple[float, float]]:
    rng = random.Random(seed)
    result: list[tuple[float, float]] = []
    for i, a in enumerate(points):
        b = points[(i + 1) % len(points)]
        result.extend(jittered_edge(a, b, 18, jitter, rng))
    return result


def draw_hand_border(
    draw: ImageDraw.ImageDraw,
    points: list[tuple[float, float]],
    scale: int,
    seed: int,
    width: int,
    accent: tuple[int, int, int, int] | None = None,
) -> None:
    for pass_index in range(3):
        line = scaled_polygon(jittered_polygon(points, 1.6 + pass_index * 0.7, seed + pass_index), scale)
        draw.line(line + [line[0]], fill=INK, width=max(1, (width - pass_index * 2) * scale), joint="curve")
    if accent is not None:
        inner = scaled_polygon(jittered_polygon(points, 0.8, seed + 20), scale)
        draw.line(inner + [inner[0]], fill=accent, width=max(1, width // 3) * scale, joint="curve")


def hard_alpha(img: Image.Image) -> Image.Image:
    output = img.convert("RGBA")
    data = []
    for r, g, b, a in output.getdata():
        data.append((r, g, b, 255) if a >= 96 else (0, 0, 0, 0))
    output.putdata(data)
    return output


def clean_panel(size: tuple[int, int], fill: tuple[int, int, int, int], points: list[tuple[int, int]], seed: int) -> Image.Image:
    scale = 4
    img = Image.new("RGBA", (size[0] * scale, size[1] * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    pts = scaled_polygon(points, scale)
    draw.polygon(pts, fill=fill)
    draw_hand_border(draw, points, scale, seed, 8)
    return hard_alpha(img.resize(size, Image.Resampling.LANCZOS))


def nameplate(size: tuple[int, int], accent: tuple[int, int, int, int], seed: int, points: list[tuple[int, int]]) -> Image.Image:
    scale = 4
    left = min(x for x, _y in points)
    right = max(x for x, _y in points)
    mid_y = size[1] / 2.0
    inner = [
        (left + 13, 13),
        (right - 19, 13),
        (right - 8, mid_y),
        (right - 19, size[1] - 13),
        (left + 13, size[1] - 13),
        (left + 24, mid_y),
    ]
    img = Image.new("RGBA", (size[0] * scale, size[1] * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw.polygon(scaled_polygon(points, scale), fill=NAMEPLATE_FILL)
    draw_hand_border(draw, points, scale, seed, 5, accent)
    inner_line = scaled_polygon(jittered_polygon(inner, 0.35, seed + 7), scale)
    draw.line(inner_line + [inner_line[0]], fill=accent, width=2 * scale, joint="curve")
    return hard_alpha(img.resize(size, Image.Resampling.LANCZOS))


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)

    lower_points = [
        (18, 18),
        (1317, 18),
        (1326, 175),
        (31, 175),
    ]
    upper_points = [
        (15, 13),
        (935, 13),
        (943, 112),
        (24, 112),
    ]

    lower_gold = clean_panel((1339, 194), ALLY_FILL, lower_points, 1101)
    upper_gold = clean_panel((953, 127), ALLY_FILL, upper_points, 1102)
    lower_red = clean_panel((1339, 194), ENEMY_FILL, lower_points, 2101)
    upper_red = clean_panel((953, 127), ENEMY_FILL, upper_points, 2102)

    outputs = {
        "dialogue_gold_blank.png": upper_gold,
        "dialogue_lower_gold_full.png": lower_gold,
        "dialogue_red_blank.png": lower_red,
        "dialogue_upper_red_full.png": upper_red,
        "nameplate_left_exact.png": nameplate(
            (184, 51),
            ALLY_NAME_ACCENT,
            6401,
            [(7, 7), (161, 7), (177, 25), (161, 44), (7, 44), (21, 25)],
        ),
        "nameplate_right_exact.png": nameplate(
            (209, 52),
            ENEMY_NAME_ACCENT,
            7401,
            [(8, 7), (184, 7), (202, 26), (184, 45), (8, 45), (23, 26)],
        ),
    }
    for name, image in outputs.items():
        image.save(OUT / name)

    print(f"Wrote clean dialogue panels to {OUT}")


if __name__ == "__main__":
    main()
