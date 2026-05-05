from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "generated"
SOURCE_OUT = OUT / "source"


def _chunk(name: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + name + data + struct.pack(">I", zlib.crc32(name + data) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, painter) -> None:
    rows = []
    for y in range(height):
        row = bytearray([0])
        for x in range(width):
            row.extend(painter(x, y, width, height))
        rows.append(bytes(row))
    data = b"".join(rows)
    png = b"\x89PNG\r\n\x1a\n"
    png += _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += _chunk(b"IDAT", zlib.compress(data, 9))
    png += _chunk(b"IEND", b"")
    path.write_bytes(png)


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def portrait(theme: str):
    dark = (31, 23, 20)
    paper = (216, 192, 154)
    red = (184, 68, 52)
    blue = (72, 104, 145)
    accent = blue if theme == "player" else red

    def paint(x: int, y: int, w: int, h: int) -> bytes:
        cx = (x - w / 2) / (w / 2)
        cy = (y - h / 2) / (h / 2)
        bg = mix((25, 20, 19), (58, 45, 38), y / h)
        col = bg
        if abs(cx) < 0.42 and -0.12 < cy < 0.72:
            col = mix(dark, accent, 0.28)
        head = ((cx / 0.34) ** 2 + ((cy + 0.36) / 0.32) ** 2) < 1
        if head:
            col = paper
        hat = abs(cx) < 0.48 and -0.82 < cy < -0.46 and y > abs(x - w / 2) * 0.18 + h * 0.08
        if hat:
            col = mix(dark, accent, 0.45)
        mask = abs(cx) < 0.30 and -0.42 < cy < -0.18
        if mask:
            col = (236, 218, 178)
        if head and (abs(cx - 0.13) < 0.035 or abs(cx + 0.13) < 0.035) and -0.36 < cy < -0.27:
            col = dark
        if 0.40 < math.sqrt(cx * cx + cy * cy) < 0.43:
            col = accent
        return bytes((*col, 255))

    return paint


def transparent_animal_portrait(theme: str):
    palettes = {
        "player": ((36, 24, 42), (222, 54, 62), (42, 190, 170)),
        "fox": ((44, 24, 32), (226, 82, 40), (236, 183, 65)),
        "crow": ((20, 18, 28), (73, 184, 175), (199, 55, 73)),
        "deer": ((38, 25, 31), (236, 192, 82), (55, 178, 150)),
        "snake": ((24, 30, 28), (62, 201, 151), (209, 54, 76)),
        "wolf": ((30, 26, 34), (210, 59, 55), (236, 174, 72)),
    }
    dark, warm, cool = palettes.get(theme, palettes["player"])

    def paint(x: int, y: int, w: int, h: int) -> bytes:
        cx = (x - w / 2) / (w / 2)
        cy = (y - h / 2) / (h / 2)
        alpha = 0
        col = (0, 0, 0)
        body = abs(cx) < 0.34 + max(cy, 0) * 0.18 and -0.08 < cy < 0.84
        head = (cx / 0.30) ** 2 + ((cy + 0.42) / 0.26) ** 2 < 1
        if body or head:
            alpha = 255
            col = mix(dark, warm, 0.22 + max(0.0, -cx) * 0.16)
        if head:
            col = mix((204, 172, 125), warm, 0.35)
        ear_left = abs(cx + 0.23) + abs(cy + 0.72) < 0.18
        ear_right = abs(cx - 0.23) + abs(cy + 0.72) < 0.18
        if theme in ("fox", "wolf", "player") and (ear_left or ear_right):
            alpha = 255
            col = mix(dark, warm, 0.55)
        if theme == "deer" and (-0.58 < cy < -0.30) and (abs(abs(cx) - 0.26) < 0.035 or abs(abs(cx) - 0.38) < 0.025):
            alpha = 255
            col = (218, 184, 114)
        if theme == "crow" and (abs(cx) < 0.20 and -0.56 < cy < -0.42):
            alpha = 255
            col = (26, 22, 32)
        if theme == "snake" and head and abs(cx) < 0.24:
            col = mix((66, 150, 110), cool, 0.55)
        if body and abs(cx) < 0.08:
            col = cool
        if head and (abs(cx - 0.10) < 0.025 or abs(cx + 0.10) < 0.025) and -0.47 < cy < -0.37:
            col = (248, 225, 141)
        if alpha > 0 and (0.36 < math.sqrt(cx * cx + (cy + 0.05) * (cy + 0.05)) < 0.39):
            col = (236, 184, 70)
        return bytes((*col, alpha))

    return paint


def background(theme: str):
    palettes = {
        "border": ((23, 16, 25), (161, 47, 42), (49, 174, 154)),
        "market": ((32, 18, 30), (219, 91, 43), (40, 184, 165)),
        "archive": ((22, 18, 28), (191, 147, 67), (44, 154, 150)),
        "garden": ((25, 24, 31), (205, 58, 74), (58, 188, 144)),
        "alley": ((18, 15, 22), (187, 46, 55), (41, 168, 160)),
    }
    dark, warm, cool = palettes.get(theme, palettes["market"])

    def paint(x: int, y: int, w: int, h: int) -> bytes:
        t = y / h
        col = mix(dark, (57, 34, 42), t)
        glow = math.exp(-(((x - w * 0.68) / (w * 0.26)) ** 2 + ((y - h * 0.28) / (h * 0.22)) ** 2))
        col = mix(col, warm, glow * 0.55)
        cool_glow = math.exp(-(((x - w * 0.24) / (w * 0.22)) ** 2 + ((y - h * 0.36) / (h * 0.25)) ** 2))
        col = mix(col, cool, cool_glow * 0.35)
        if y > h * 0.74:
            col = mix(col, (10, 8, 12), (y / h - 0.74) * 2.2)
        if (x // 90 + y // 70) % 7 == 0 and y < h * 0.72:
            col = mix(col, (226, 176, 75), 0.16)
        return bytes((*col, 255))

    return paint


def card_frame(kind: str):
    accent = (210, 63, 64) if kind == "identity" else (52, 178, 156) if kind == "clue" else (224, 171, 69)

    def paint(x: int, y: int, w: int, h: int) -> bytes:
        edge = min(x, y, w - 1 - x, h - 1 - y)
        col = mix((31, 20, 29), (82, 40, 44), y / h)
        if edge < 22:
            col = mix((10, 8, 12), accent, edge / 22)
        if 34 < edge < 42:
            col = accent
        if w * 0.16 < x < w * 0.84 and h * 0.18 < y < h * 0.78:
            col = mix(col, (18, 14, 21), 0.65)
        return bytes((*col, 255))

    return paint


def simple_icon(kind: str):
    colors = {
        "friend": (64, 199, 143), "enemy": (222, 57, 63), "unknown": (206, 169, 75),
        "affinity": (230, 174, 66), "exposed": (230, 72, 95), "char_budget": (69, 187, 174),
        "invite": (77, 198, 143), "assassinate": (193, 49, 64), "duel": (226, 154, 60),
        "leave": (93, 139, 194), "victory": (78, 205, 126), "failure": (223, 59, 70)
    }
    accent = colors.get(kind, (230, 174, 66))

    def paint(x: int, y: int, w: int, h: int) -> bytes:
        cx = (x - w / 2) / (w / 2)
        cy = (y - h / 2) / (h / 2)
        r = math.sqrt(cx * cx + cy * cy)
        col = (0, 0, 0, 0)
        if r < 0.72:
            col = (*mix((25, 18, 28), accent, 0.35), 255)
        if 0.56 < r < 0.64:
            col = (226, 176, 76, 255)
        if abs(cx) < 0.12 or abs(cy) < 0.12:
            col = (*accent, 255)
        if kind in ("assassinate", "duel") and abs(cx - cy) < 0.08:
            col = (246, 224, 148, 255)
        if kind in ("victory", "failure") and r < 0.28:
            col = (246, 224, 148, 255)
        return bytes(col)

    return paint


def parchment(x: int, y: int, w: int, h: int) -> bytes:
    edge = min(x, y, w - 1 - x, h - 1 - y)
    grain = ((x * 17 + y * 31) % 23) / 23.0
    base = mix((181, 148, 101), (229, 205, 160), 0.65 + grain * 0.12)
    if edge < 10:
        base = mix((44, 32, 26), base, edge / 10)
    if edge in (14, 15):
        base = (81, 52, 40)
    return bytes((*base, 255))


def mark(kind: str):
    color = (105, 168, 92) if kind == "victory" else (190, 65, 55)

    def paint(x: int, y: int, w: int, h: int) -> bytes:
        cx = (x - w / 2) / (w / 2)
        cy = (y - h / 2) / (h / 2)
        r = math.sqrt(cx * cx + cy * cy)
        col = (0, 0, 0, 0)
        if r < 0.72:
            col = (*mix((75, 38, 30), color, 0.72), 255)
        if 0.52 < r < 0.58:
            col = (236, 208, 158, 255)
        if kind == "victory" and abs(cy + cx * 0.55) < 0.06 and -0.35 < cx < 0.42:
            col = (247, 231, 187, 255)
        if kind == "failure" and (abs(cx - cy) < 0.06 or abs(cx + cy) < 0.06) and r < 0.45:
            col = (247, 231, 187, 255)
        return bytes(col)

    return paint


def type_icon(kind: str):
    color = (213, 76, 61) if kind == "fruit" else (94, 136, 92)

    def paint(x: int, y: int, w: int, h: int) -> bytes:
        cx = (x - w / 2) / (w / 2)
        cy = (y - h / 2) / (h / 2)
        col = (0, 0, 0, 0)
        if kind == "fruit":
            if (cx / 0.48) ** 2 + ((cy - 0.08) / 0.55) ** 2 < 1:
                col = (*color, 255)
            if -0.08 < cx < 0.05 and -0.72 < cy < -0.45:
                col = (74, 45, 31, 255)
            if (cx / 0.28) ** 2 + ((cy + 0.62) / 0.16) ** 2 < 1 and cx > 0:
                col = (78, 135, 83, 255)
        else:
            if (cx / 0.55) ** 2 + (cy / 0.38) ** 2 < 1:
                col = (*color, 255)
            if (cx + 0.35) ** 2 + (cy + 0.33) ** 2 < 0.09 or (cx - 0.35) ** 2 + (cy + 0.33) ** 2 < 0.09:
                col = (*color, 255)
            if abs(cx) < 0.08 and -0.05 < cy < 0.18:
                col = (32, 25, 22, 255)
        return bytes(col)

    return paint


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    SOURCE_OUT.mkdir(parents=True, exist_ok=True)
    write_png(OUT / "player_portrait.png", 512, 512, portrait("player"))
    write_png(OUT / "opponent_portrait.png", 512, 512, portrait("opponent"))
    for name in ["player", "fox", "crow", "deer", "snake", "wolf"]:
        filename = "player_portrait.png" if name == "player" else f"npc_{name}_portrait.png"
        write_png(OUT / filename, 512, 768, transparent_animal_portrait(name))
        write_png(SOURCE_OUT / filename, 512, 768, transparent_animal_portrait(name))
    for filename, theme in [
        ("bg_border_gate.png", "border"),
        ("bg_moon_market.png", "market"),
        ("bg_archive_hall.png", "archive"),
        ("bg_embassy_garden.png", "garden"),
        ("bg_duel_alley.png", "alley"),
        ("web_cover.png", "market"),
        ("loading_splash.png", "archive"),
    ]:
        write_png(OUT / filename, 1024, 576, background(theme))
    for filename, kind in [
        ("card_identity_back.png", "identity"),
        ("card_identity_frame.png", "identity"),
        ("card_clue_back.png", "clue"),
        ("card_clue_frame.png", "clue"),
        ("card_ally_frame.png", "ally"),
    ]:
        write_png(OUT / filename, 512, 768, card_frame(kind))
    for kind in [
        "friend", "enemy", "unknown", "affinity", "exposed", "char_budget",
        "invite", "assassinate", "duel", "leave", "victory", "failure",
    ]:
        write_png(OUT / f"icon_{kind}.png", 256, 256, simple_icon(kind))
    write_png(OUT / "web_icon.png", 256, 256, simple_icon("victory"))
    write_png(OUT / "dialogue_panel.png", 768, 256, parchment)
    write_png(OUT / "victory_mark.png", 256, 256, mark("victory"))
    write_png(OUT / "failure_mark.png", 256, 256, mark("failure"))
    write_png(OUT / "type_fruit.png", 256, 256, type_icon("fruit"))
    write_png(OUT / "type_animal.png", 256, 256, type_icon("animal"))
    print(f"Wrote placeholder assets to {OUT}")


if __name__ == "__main__":
    main()
