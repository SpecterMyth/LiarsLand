from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Callable
import html

from PIL import Image, ImageDraw, ImageFont, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ui" / "concepts" / "gameplay"
W, H = 1920, 1080
SCALE = 2


TOKENS = {
    "bg": "#120b0d",
    "panel": "#241114",
    "panel_2": "#32171b",
    "panel_3": "#171114",
    "line": "#d5a34a",
    "line_dark": "#7d4f24",
    "text": "#f6e9cb",
    "muted": "#a99779",
    "teal": "#1fb7a6",
    "teal_dark": "#0f554f",
    "bag": "#b77725",
    "danger": "#b5423c",
    "gold": "#e4b85b",
    "gray": "#5c5960",
    "ink": "#080607",
    "spec": "#55c7ff",
    "purple": "#7a3fb2",
    "red": "#b01731",
}

FONT_REG = Path("C:/Windows/Fonts/NotoSansSC-VF.ttf")
FONT_BOLD = Path("C:/Windows/Fonts/msyhbd.ttc")


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_BOLD if bold and FONT_BOLD.exists() else FONT_REG
    return ImageFont.truetype(str(path), size * SCALE)


def rgb(color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    color = color.lstrip("#")
    return tuple(int(color[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def pts(x: int, y: int, w: int, h: int, cut: int = 18) -> list[tuple[int, int]]:
    return [
        (x + cut, y),
        (x + w, y),
        (x + w, y + h - cut),
        (x + w - cut, y + h),
        (x, y + h),
        (x, y + cut),
    ]


def sp(points: list[tuple[int, int]]) -> list[tuple[int, int]]:
    return [(x * SCALE, y * SCALE) for x, y in points]


def wrap_text(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont, max_w: int) -> list[str]:
    max_w *= SCALE
    lines: list[str] = []
    for para in text.split("\n"):
        current = ""
        for ch in para:
            trial = current + ch
            if draw.textbbox((0, 0), trial, font=fnt)[2] <= max_w or not current:
                current = trial
            else:
                lines.append(current)
                current = ch
        lines.append(current)
    return lines


class Svg:
    def __init__(self, title: str):
        self.title = title
        self.parts: list[str] = [
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
            "<defs>",
            '<style>text{font-family:"Noto Sans SC","Microsoft YaHei",sans-serif;dominant-baseline:text-before-edge}.title{font-weight:700}</style>',
            "</defs>",
        ]

    def polygon(self, points, fill, stroke="none", sw=0, opacity=1):
        p = " ".join(f"{x},{y}" for x, y in points)
        self.parts.append(f'<polygon points="{p}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{opacity}"/>')

    def rect(self, x, y, w, h, fill, stroke="none", sw=0, opacity=1):
        self.parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" opacity="{opacity}"/>')

    def line(self, x1, y1, x2, y2, stroke, sw=2, opacity=1):
        self.parts.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" stroke-width="{sw}" opacity="{opacity}"/>')

    def text(self, x, y, text, size=22, fill=None, bold=False, anchor="start", opacity=1):
        fill = fill or TOKENS["text"]
        cls = ' class="title"' if bold else ""
        safe = html.escape(text)
        self.parts.append(f'<text x="{x}" y="{y}" font-size="{size}" fill="{fill}" text-anchor="{anchor}" opacity="{opacity}"{cls}>{safe}</text>')

    def save(self, path: Path):
        path.write_text("\n".join(self.parts + ["</svg>\n"]), encoding="utf-8")


class Canvas:
    def __init__(self, title: str):
        self.img = Image.new("RGBA", (W * SCALE, H * SCALE), rgb(TOKENS["bg"]))
        self.d = ImageDraw.Draw(self.img)
        self.svg = Svg(title)
        self.svg.rect(0, 0, W, H, TOKENS["bg"])
        self.bg()

    def bg(self):
        # Deterministic, implementation-friendly mood layer: flat geometry and low-frequency texture.
        for y in range(H * SCALE):
            t = y / float(H * SCALE)
            r = int(18 + 10 * t)
            g = int(8 + 4 * t)
            b = int(12 + 8 * t)
            self.d.line([(0, y), (W * SCALE, y)], fill=(r, g, b, 255))
        shapes = [
            [(0, 120), (420, 0), (660, 0), (180, 1080), (0, 1080)],
            [(1420, 0), (1920, 0), (1920, 1080), (1680, 1080), (1320, 360)],
            [(760, 0), (1140, 0), (980, 1080), (600, 1080)],
        ]
        colors = [("#6d0d21", 85), ("#075b5d", 80), ("#3e1455", 65)]
        for points, (color, alpha) in zip(shapes, colors):
            self.d.polygon(sp(points), fill=rgb(color, alpha))
            self.svg.polygon(points, color, opacity=alpha / 255.0)
        for x in range(-100, W, 240):
            self.d.line(sp([(x, 1080), (x + 520, 0)]), fill=rgb("#000000", 70), width=10 * SCALE)
            self.svg.line(x, 1080, x + 520, 0, "#000000", 5, 0.25)
        for i in range(0, W, 96):
            c = rgb("#1d1013", 80 if i % 192 == 0 else 45)
            self.d.line([(i * SCALE, 0), (i * SCALE, H * SCALE)], fill=c, width=1)
            self.svg.line(i, 0, i, H, "#1d1013", 1, 0.45)
        for y in range(0, H, 96):
            self.d.line([(0, y * SCALE), (W * SCALE, y * SCALE)], fill=rgb("#1d1013", 45), width=1)
            self.svg.line(0, y, W, y, "#1d1013", 1, 0.3)
        # Tiny deterministic speckles, kept subtle enough to be optional in implementation.
        for n in range(900):
            x = (n * 73) % (W * SCALE)
            y = (n * 151) % (H * SCALE)
            a = 18 + (n % 20)
            self.d.point((x, y), fill=(235, 168, 72, a))

    def panel(self, x, y, w, h, fill=None, stroke=None, cut=22, width=3):
        fill = fill or TOKENS["panel"]
        stroke = stroke or TOKENS["line"]
        shadow = [(px + 10, py + 12) for px, py in pts(x, y, w, h, cut)]
        self.d.polygon(sp(shadow), fill=rgb("#000000", 120))
        self.d.polygon(sp(pts(x, y, w, h, cut)), fill=rgb(fill), outline=rgb(stroke))
        self.d.line(sp([(x + 4, y + h - 4), (x + w - cut, y + h - 4), (x + w - 4, y + h - cut)]), fill=rgb("#000000", 95), width=3 * SCALE)
        self.d.line(sp([(x + cut, y + 8), (x + w - 28, y + 8)]), fill=rgb("#f2ca73", 120), width=2 * SCALE)
        self.svg.polygon(shadow, "#000000", opacity=0.35)
        self.svg.polygon(pts(x, y, w, h, cut), fill, stroke, width)
        self.svg.line(x + cut, y + 8, x + w - 28, y + 8, "#f2ca73", 2, 0.45)

    def text(self, x, y, s, size=22, fill=None, bold=False, max_w=None, anchor="start"):
        fill = fill or TOKENS["text"]
        fnt = font(size, bold)
        if max_w:
            yy = y
            for line in wrap_text(self.d, s, fnt, max_w):
                self.d.text((x * SCALE, yy * SCALE), line, font=fnt, fill=rgb(fill))
                self.svg.text(x, yy, line, size, fill, bold)
                yy += int(size * 1.35)
        else:
            draw_x = x * SCALE
            if anchor == "middle":
                bbox = self.d.textbbox((0, 0), s, font=fnt)
                draw_x -= (bbox[2] - bbox[0]) // 2
            self.d.text((draw_x, y * SCALE), s, font=fnt, fill=rgb(fill))
            self.svg.text(x, y, s, size, fill, bold, anchor=anchor)

    def button(self, x, y, w, h, label, kind="primary", active=False):
        palette = {
            "primary": (TOKENS["gold"], "#4b3014"),
            "secondary": (TOKENS["gray"], "#242226"),
            "danger": (TOKENS["danger"], "#3a1414"),
            "option": (TOKENS["teal"] if active else TOKENS["line_dark"], "#142625" if active else "#211716"),
        }[kind]
        self.panel(x, y, w, h, palette[1], palette[0], cut=12, width=2)
        self.text(x + w // 2, y + (h - 28) // 2, label, 24, TOKENS["text"], True, anchor="middle")

    def tag(self, x, y, label, color):
        self.d.rounded_rectangle((x*SCALE, y*SCALE, (x+112)*SCALE, (y+32)*SCALE), radius=0, fill=rgb(color, 210), outline=rgb(TOKENS["line"]))
        self.svg.rect(x, y, 112, 32, color, TOKENS["line"], 1, 0.9)
        self.text(x + 14, y + 3, label, 18, TOKENS["text"], True)

    def item(self, x, y, label, sub="", color=None):
        self.panel(x, y, 152, 142, TOKENS["panel_3"], color or TOKENS["bag"], cut=14, width=2)
        cx, cy = x + 76, y + 44
        self.d.polygon(sp([(cx, cy-28), (cx+32, cy), (cx, cy+28), (cx-32, cy)]), fill=rgb(color or TOKENS["bag"]))
        self.svg.polygon([(cx, cy-28), (cx+32, cy), (cx, cy+28), (cx-32, cy)], color or TOKENS["bag"])
        self.text(x + 18, y + 82, label, 20, TOKENS["text"], True)
        if sub:
            self.text(x + 18, y + 110, sub, 16, TOKENS["muted"])

    def artifact_icon(self, x: int, y: int, size: int, kind: str = "gem", color: str | None = None):
        color = color or TOKENS["bag"]
        cx, cy = x + size // 2, y + size // 2
        if kind == "key":
            self.d.ellipse((x*SCALE, (y+8)*SCALE, (x+size*0.52)*SCALE, (y+size*0.52)*SCALE), outline=rgb(color), width=5*SCALE)
            self.d.line(sp([(cx-4, cy), (x+size-10, y+size-12)]), fill=rgb(color), width=8*SCALE)
            self.d.rectangle(((x+size-25)*SCALE, (y+size-22)*SCALE, (x+size-10)*SCALE, (y+size-14)*SCALE), fill=rgb(color))
        elif kind == "seal":
            self.d.polygon(sp([(cx, y+8), (x+size-8, cy), (cx, y+size-8), (x+8, cy)]), fill=rgb("#d8d8d8"), outline=rgb(color))
            self.d.polygon(sp([(cx, y+24), (x+size-24, cy), (cx, y+size-24), (x+24, cy)]), fill=rgb("#343234"))
        elif kind == "dagger":
            self.d.polygon(sp([(cx+8, y+8), (cx+20, y+52), (cx+6, y+size-8), (cx-8, y+52)]), fill=rgb("#d9d7d0"), outline=rgb(color))
            self.d.rectangle(((cx-32)*SCALE, (cy+18)*SCALE, (cx+32)*SCALE, (cy+28)*SCALE), fill=rgb(color))
        else:
            self.d.polygon(sp([(cx, y+6), (x+size-16, cy), (cx, y+size-6), (x+16, cy)]), fill=rgb(color), outline=rgb("#f6d27a"))
            self.d.line(sp([(cx, y+6), (cx, y+size-6)]), fill=rgb("#fff2b6", 180), width=3*SCALE)
        self.svg.rect(x, y, size, size, "none", color, 1, 0.01)

    def attr_icon(self, x: int, y: int, kind: str, color: str):
        self.panel(x, y, 72, 72, "#121013", color, cut=10, width=2)
        cx, cy = x + 36, y + 36
        if kind == "heart":
            self.d.ellipse(((cx-21)*SCALE, (cy-18)*SCALE, (cx+2)*SCALE, (cy+8)*SCALE), fill=rgb(color))
            self.d.ellipse(((cx-2)*SCALE, (cy-18)*SCALE, (cx+21)*SCALE, (cy+8)*SCALE), fill=rgb(color))
            self.d.polygon(sp([(cx-25, cy-2), (cx+25, cy-2), (cx, cy+28)]), fill=rgb(color))
        elif kind == "sword":
            self.d.line(sp([(cx-18, cy+20), (cx+20, cy-18)]), fill=rgb(color), width=7*SCALE)
            self.d.rectangle(((cx-22)*SCALE, (cy+10)*SCALE, (cx+10)*SCALE, (cy+16)*SCALE), fill=rgb("#f6e9cb"))
        elif kind == "shield":
            self.d.polygon(sp([(cx, cy-24), (cx+24, cy-12), (cx+18, cy+22), (cx, cy+30), (cx-18, cy+22), (cx-24, cy-12)]), fill=rgb(color))
        elif kind == "mask":
            self.d.polygon(sp([(cx-28, cy-10), (cx, cy-24), (cx+28, cy-10), (cx+20, cy+18), (cx, cy+28), (cx-20, cy+18)]), fill=rgb(color))
            self.d.ellipse(((cx-16)*SCALE, (cy-6)*SCALE, (cx-6)*SCALE, (cy+4)*SCALE), fill=rgb("#120b0d"))
            self.d.ellipse(((cx+6)*SCALE, (cy-6)*SCALE, (cx+16)*SCALE, (cy+4)*SCALE), fill=rgb("#120b0d"))
        else:
            self.d.polygon(sp([(cx, cy-26), (cx+26, cy), (cx, cy+26), (cx-26, cy)]), fill=rgb(color))

    def intel_thumb(self, x: int, y: int, w: int, h: int, image_name: str, accent: str):
        path = ROOT / "project" / "assets" / "generated" / image_name
        if path.exists():
            src = Image.open(path).convert("RGBA")
            src.thumbnail((w * SCALE, h * SCALE), Image.Resampling.LANCZOS)
            crop = Image.new("RGBA", (w*SCALE, h*SCALE), rgb("#090708"))
            crop.alpha_composite(src, ((w*SCALE-src.width)//2, (h*SCALE-src.height)//2))
            self.img.alpha_composite(crop, (x*SCALE, y*SCALE))
        else:
            self.d.rectangle((x*SCALE, y*SCALE, (x+w)*SCALE, (y+h)*SCALE), fill=rgb("#120d10"))
            self.artifact_icon(x + 16, y + 8, min(w, h) - 16, "gem", accent)
        self.d.rectangle((x*SCALE, y*SCALE, (x+w)*SCALE, (y+h)*SCALE), outline=rgb(accent), width=2*SCALE)
        self.svg.rect(x, y, w, h, "#120d10", accent, 2)

    def card(self, x, y, w, h, title, body="", accent=None, selected=False):
        self.panel(x, y, w, h, "#1b1113", accent or TOKENS["line_dark"], cut=16, width=2)
        if selected:
            self.d.rectangle((x*SCALE, y*SCALE, (x+8)*SCALE, (y+h)*SCALE), fill=rgb(accent or TOKENS["teal"]))
            self.svg.rect(x, y, 8, h, accent or TOKENS["teal"])
        self.text(x + 20, y + 16, title, 22, TOKENS["text"], True)
        if body:
            self.text(x + 20, y + 52, body, 18, TOKENS["muted"], max_w=w - 40)

    def save(self, name: str):
        OUT.mkdir(parents=True, exist_ok=True)
        self.svg.save(OUT / f"{name}.svg")
        self.img.resize((W, H), Image.Resampling.LANCZOS).save(OUT / f"{name}.png")


def title(c: Canvas, title: str, sub: str, x=240, y=96, w=1440):
    c.panel(x, y, w, 112, "#211014", TOKENS["line"], cut=24)
    c.text(x + 40, y + 24, title, 40, TOKENS["text"], True)
    c.text(x + 42, y + 74, sub, 18, TOKENS["muted"])


def footer(c: Canvas, labels=("返回", "确认"), danger=False):
    c.panel(240, 880, 1440, 104, "#1a1012", TOKENS["line_dark"], cut=18, width=2)
    c.button(1112, 904, 224, 56, labels[0], "secondary")
    c.button(1360, 904, 264, 56, labels[1], "danger" if danger else "primary")


@dataclass
class SpecRect:
    name: str
    rect: tuple[int, int, int, int]


def spec_png(name: str, rects: list[SpecRect]):
    base = Image.open(OUT / f"{name}.png").convert("RGBA")
    overlay = Image.new("RGBA", base.size, (8, 10, 14, 105))
    base.alpha_composite(overlay)
    d = ImageDraw.Draw(base)
    f = ImageFont.truetype(str(FONT_REG), 22)
    d.text((48, 34), "SPEC 1920x1080 / grid 8px / margins 96px", font=f, fill=rgb(TOKENS["spec"]))
    for item in rects:
        x, y, w, h = item.rect
        d.rectangle((x, y, x + w, y + h), outline=rgb(TOKENS["spec"]), width=3)
        d.text((x + 8, y + 8), f"{item.name} {w}x{h} @ {x},{y}", font=f, fill=rgb(TOKENS["spec"]))
    base.save(OUT / f"{name}_spec.png")


def screen_intel():
    c = Canvas("世界设定档案")
    title(c, "世界设定档案", "每张候选卡包含图片、文本与支持者头像；选择只代表你的判断，不显示真假。")
    c.panel(176, 232, 1568, 648, "#160e12", TOKENS["teal"], cut=26)
    questions = [
        ("谎言从哪里来", [
            ("谎言来自月亮", "ui/intel/q01_01_lie_origin_moon.png", ["绯尾", "鸦账"]),
            ("谎言来自名字", "ui/intel/q01_02_lie_origin_name.png", ["银针"]),
            ("谎言来自债务", "ui/intel/q01_03_lie_origin_debt.png", []),
        ]),
        ("旧王朝为什么消失", [
            ("被亲近者出卖", "ui/intel/q02_01_old_dynasty_betrayed.png", ["绯尾"]),
            ("被法器吞掉", "ui/intel/q02_02_old_dynasty_devoured_by_artifacts.png", []),
            ("旧王族仍藏着", "ui/intel/q02_03_old_dynasty_hidden_royals.png", ["灰冠", "灯婆"]),
        ]),
        ("动物族群共同禁忌", [
            ("第一份礼物", "ui/intel/q03_01_common_taboo_first_gift.png", []),
            ("门槛上真话", "ui/intel/q03_02_common_taboo_threshold_truth.png", ["绯尾"]),
            ("死者遗物", "ui/intel/q03_03_common_taboo_dead_relic.png", ["鸦账"]),
        ]),
        ("夜市真正尊重什么", [
            ("公平交易", "ui/intel/q04_01_market_respect_fair_trade.png", ["灯婆"]),
            ("漂亮谎言", "ui/intel/q04_02_market_respect_beautiful_lies.png", []),
            ("守住秘密", "ui/intel/q04_03_market_respect_kept_secrets.png", ["银针"]),
        ]),
        ("法器到底是什么", [
            ("记忆容器", "ui/intel/q05_01_artifact_nature_memory_vessel.png", ["灰冠"]),
            ("活着的债主", "ui/intel/q05_02_artifact_nature_living_creditor.png", ["绯尾"]),
            ("身份伪装", "ui/intel/q05_03_artifact_nature_identity_disguise.png", []),
        ]),
        ("本章背叛像什么", [
            ("政治清洗", "ui/intel/q06_01_betrayal_shape_purge.png", []),
            ("古老祭仪", "ui/intel/q06_02_betrayal_shape_ritual.png", ["鸦账"]),
            ("身份误认", "ui/intel/q06_03_betrayal_shape_mistaken_identity.png", ["灯婆"]),
        ]),
    ]
    for i, (q, opts) in enumerate(questions):
        x = 208 + (i % 2) * 768
        y = 256 + (i // 2) * 200
        c.panel(x, y, 720, 176, "#211014", TOKENS["line_dark"], cut=18, width=2)
        c.text(x + 24, y + 22, f"{i+1:02d}  {q}", 24, TOKENS["gold"], True)
        for j, (label, img, supporters) in enumerate(opts):
            ox = x + 24 + j * 224
            selected = (i + j) % 4 == 0
            c.panel(ox, y + 62, 208, 92, "#151013", TOKENS["teal"] if selected else TOKENS["line_dark"], cut=10, width=2)
            c.intel_thumb(ox + 8, y + 72, 60, 60, img, TOKENS["teal"] if selected else TOKENS["line"])
            c.text(ox + 78, y + 70, label, 16, TOKENS["text"], True, max_w=112)
            c.text(ox + 78, y + 114, "支持：" + ("、".join(supporters) if supporters else "无"), 13, TOKENS["muted"], max_w=112)
    footer(c, ("返回", "提交档案"), danger=False)
    c.save("dialogue_overlay_intel_world_archive")
    spec_png("dialogue_overlay_intel_world_archive", [
        SpecRect("Title", (240, 96, 1440, 112)), SpecRect("QuestionGrid", (176, 232, 1568, 648)), SpecRect("Footer", (240, 880, 1440, 104))
    ])


def screen_bag():
    c = Canvas("背包")
    title(c, "背包", "左侧固定显示统治与升华需求，右侧展示当前持有的所有道具。")
    c.panel(176, 248, 432, 608, "#1b1013", TOKENS["danger"], cut=24)
    c.text(216, 288, "统治需求", 28, TOKENS["danger"], True)
    def req_slot(y: int, label: str, kind: str, color: str, state_text: str):
        c.panel(216, y, 352, 72, "#141013", color, cut=12, width=2)
        c.artifact_icon(232, y + 10, 52, kind, color)
        c.text(300, y + 12, label, 20, TOKENS["text"], True)
        c.text(300, y + 42, state_text, 16, TOKENS["muted"])
    for i, (label, kind, state_text) in enumerate([("血契棱镜", "gem", "已持有"), ("月厅密钥", "key", "已持有"), ("灰冠契印", "seal", "未完成")]):
        req_slot(344 + i * 88, label, kind, TOKENS["danger"], state_text)
    c.text(216, 632, "升华需求", 28, TOKENS["teal"], True)
    for i, (label, kind) in enumerate([("银针袖扣", "dagger"), ("失落本名", "seal")]):
        req_slot(688 + i * 88, label, kind, TOKENS["teal"], "需求")
    c.panel(656, 248, 1088, 608, "#160e12", TOKENS["bag"], cut=26)
    c.text(704, 288, "当前持有", 32, TOKENS["bag"], True)
    items = [("血契棱镜", "gem", "x2"), ("月厅密钥", "key", "x1"), ("灰冠契印", "seal", "x0"), ("赤金短匕", "dagger", "x3"), ("旧血誓约", "gem", "x1"), ("夜市旧债", "key", "x1"), ("皮下地图", "seal", "x1"), ("银针袖扣", "dagger", "x2")]
    for i, (label, kind, count) in enumerate(items):
        x = 712 + (i % 4) * 244
        y = 360 + (i // 4) * 216
        c.panel(x, y, 200, 176, "#1b1013", TOKENS["bag"] if i != 2 else TOKENS["gray"], cut=16)
        c.artifact_icon(x + 58, y + 24, 84, kind, TOKENS["bag"] if i != 2 else TOKENS["gray"])
        c.text(x + 24, y + 116, label, 20, TOKENS["text"], True)
        c.text(x + 150, y + 130, count, 28, TOKENS["gold"], True)
    footer(c, ("整理", "返回"))
    c.save("dialogue_overlay_bag")
    spec_png("dialogue_overlay_bag", [
        SpecRect("Title", (240, 96, 1440, 112)), SpecRect("Requirements", (176, 248, 432, 608)), SpecRect("Inventory", (656, 248, 1088, 608)), SpecRect("Footer", (240, 880, 1440, 104))
    ])


def screen_rules():
    c = Canvas("行为文件")
    title(c, "行为文件", "三段策略并列编辑，下方为完整自由输入区。")
    c.panel(216, 248, 1488, 608, "#160e12", TOKENS["line"], cut=24)
    specs = [("决策基调", "冷静、谨慎、礼貌，不轻易暴露真实目的。"), ("对话策略", "先提升好感，试探世界设定与法器需求。"), ("行动策略", "风险不清时撤离，收益明确时再交易或决斗。")]
    for i, (h, body) in enumerate(specs):
        x = 256 + i * 480
        c.panel(x, 304, 432, 188, "#211014", [TOKENS["danger"], TOKENS["teal"], TOKENS["bag"]][i], cut=18)
        c.text(x + 28, 332, h, 28, [TOKENS["danger"], TOKENS["teal"], TOKENS["bag"]][i], True)
        c.text(x + 28, 384, body, 22, TOKENS["text"], max_w=368)
    c.text(256, 536, "自由输入", 28, TOKENS["gold"], True)
    c.panel(256, 584, 1408, 224, "#100b0d", TOKENS["line_dark"], cut=16)
    c.text(296, 624, "在这里补充你希望角色长期遵循的细节，例如优先保护哪些目标、如何判断交换收益、何时停止追问。", 22, TOKENS["muted"], max_w=1328)
    footer(c, ("放弃修改", "保存行为文件"))
    c.save("dialogue_overlay_rules_behavior_file")
    spec_png("dialogue_overlay_rules_behavior_file", [
        SpecRect("Title", (240, 96, 1440, 112)), SpecRect("ThreeInputs", (256, 304, 1408, 188)), SpecRect("FreeInput", (256, 584, 1408, 224)), SpecRect("Footer", (240, 880, 1440, 104))
    ])


def screen_status():
    c = Canvas("状态")
    title(c, "状态", "左侧为章节和当前 NPC，右侧用图标化属性展示玩家状态。")
    c.panel(176, 248, 456, 608, "#1b1013", TOKENS["line"], cut=24)
    c.text(216, 288, "章节 / 回合", 28, TOKENS["gold"], True)
    c.card(216, 340, 376, 132, "第 2 章：赤金夜市", "回合 06 / 10\n对话 03 / 08", TOKENS["gold"])
    c.text(216, 520, "当前 NPC", 28, TOKENS["teal"], True)
    c.card(216, 572, 376, 200, "灯下账房", "身份：狐面商人\n地盘：月债市场\n敌友判断：未知\n亲近度：42", TOKENS["teal"], True)
    c.panel(680, 248, 1064, 608, "#160e12", TOKENS["teal"], cut=26)
    c.text(728, 288, "玩家属性", 32, TOKENS["teal"], True)
    attrs = [
        ("heart", "生命", "12 / 18", TOKENS["danger"]),
        ("gem", "能量", "128", TOKENS["gold"]),
        ("gem", "字符", "1240 / 3000", TOKENS["teal"]),
        ("mask", "魅力", "7", TOKENS["purple"]),
        ("sword", "正面攻击", "5", TOKENS["bag"]),
        ("shield", "正面防御", "4", TOKENS["teal"]),
        ("dagger", "暗杀攻击", "6", TOKENS["danger"]),
        ("shield", "暗杀防御", "3", TOKENS["gray"]),
    ]
    for i, (kind, label, value, color) in enumerate(attrs):
        x = 728 + (i % 2) * 488
        y = 360 + (i // 2) * 112
        c.panel(x, y, 432, 88, "#211014", color, cut=16)
        c.attr_icon(x + 20, y + 8, kind, color)
        c.text(x + 112, y + 18, label, 22, TOKENS["muted"], True)
        c.text(x + 300, y + 18, value, 30, TOKENS["text"], True)
    footer(c, ("刷新", "返回"))
    c.save("dialogue_overlay_status")
    spec_png("dialogue_overlay_status", [
        SpecRect("Title", (240, 96, 1440, 112)), SpecRect("ChapterNpc", (176, 248, 456, 608)), SpecRect("PlayerAttributes", (680, 248, 1064, 608)), SpecRect("Footer", (240, 880, 1440, 104))
    ])


def screen_history():
    c = Canvas("历史对话")
    title(c, "历史对话", "左侧为完整对话时间流，右侧为行动与发现。")
    c.panel(216, 240, 1008, 616, "#1a1012", TOKENS["line"], cut=22)
    c.panel(1256, 240, 448, 616, "#171114", TOKENS["teal"], cut=22)
    c.text(256, 280, "对话记录", 28, TOKENS["gold"], True)
    y = 340
    for who, line in [("玩家", "关于旧王朝的债，你们市场还认账吗？"), ("NPC", "认账的人不多，怕的是月亮还记得。"), ("玩家", "如果名字也能抵押，谁会保存契据？"), ("NPC", "账房保存副本，但副本也会说谎。")]:
        c.tag(256, y, who, TOKENS["teal"] if who == "玩家" else TOKENS["bag"])
        c.text(392, y + 2, line, 22, TOKENS["text"], max_w=720)
        y += 104
    c.text(1296, 280, "行动与发现", 28, TOKENS["teal"], True)
    for i, line in enumerate(["获得证词：月亮欠债", "NPC 提出交换法器", "好感度上升", "风险：身份被追问"]):
        c.card(1296, 340 + i * 112, 368, 80, line, "", TOKENS["teal" if i != 3 else "danger"])
    footer(c, ("复制摘要", "返回"))
    c.save("dialogue_overlay_history")
    spec_png("dialogue_overlay_history", [
        SpecRect("Title", (240, 96, 1440, 112)), SpecRect("Timeline", (216, 240, 1008, 616)), SpecRect("EventList", (1256, 240, 448, 616)), SpecRect("Footer", (240, 880, 1440, 104))
    ])


def screen_settings():
    c = Canvas("设置")
    title(c, "设置", "音量与自动确认分开设置；自动确认选项互不影响。", 480, 112, 960)
    c.panel(544, 264, 832, 560, "#1b1013", TOKENS["line"], cut=24)
    c.text(600, 312, "音量", 28, TOKENS["gold"], True)
    c.d.rectangle((720*SCALE, 326*SCALE, 1260*SCALE, 340*SCALE), fill=rgb(TOKENS["gray"]))
    c.d.rectangle((720*SCALE, 326*SCALE, 1120*SCALE, 340*SCALE), fill=rgb(TOKENS["gold"]))
    c.svg.rect(720, 326, 540, 14, TOKENS["gray"])
    c.svg.rect(720, 326, 400, 14, TOKENS["gold"])
    c.text(1280, 308, "74%", 24, TOKENS["text"], True)
    c.text(600, 408, "自动确认", 28, TOKENS["teal"], True)
    options = [("自动对话", True), ("游戏行动", False), ("商店购买", False), ("升华统治", False)]
    for i, (label, checked) in enumerate(options):
        y = 468 + i * 72
        c.panel(600, y, 720, 48, "#211014", TOKENS["teal"] if checked else TOKENS["line_dark"], cut=10, width=2)
        c.d.rectangle((624*SCALE, (y+12)*SCALE, 648*SCALE, (y+36)*SCALE), outline=rgb(TOKENS["teal"] if checked else TOKENS["gray"]), width=3*SCALE)
        if checked:
            c.d.line(sp([(628, y+25), (637, y+34), (646, y+16)]), fill=rgb(TOKENS["teal"]), width=4*SCALE)
        c.text(672, y + 9, label, 22, TOKENS["text"], True)
    c.button(840, 736, 240, 56, "关闭", "primary")
    c.save("dialogue_overlay_settings")
    spec_png("dialogue_overlay_settings", [
        SpecRect("Title", (480, 112, 960, 112)), SpecRect("Volume", (600, 312, 720, 56)), SpecRect("AutoConfirm", (600, 408, 720, 336)), SpecRect("CloseButton", (840, 736, 240, 56))
    ])


def popup_base(name: str, heading: str, body: str, buttons: tuple[str, str], danger=False, selector=False):
    c = Canvas(heading)
    c.panel(520, 260, 880, 456 if selector else 360, "#211014", TOKENS["line"], cut=24)
    c.text(568, 312, heading, 40, TOKENS["text"], True)
    c.text(568, 374, body, 22, TOKENS["muted"], max_w=784)
    if selector:
        for i, label in enumerate(["月债灯", "狐面契", "骨印章", "灰银杯"]):
            c.item(568 + i * 184, 466, label, "x1", TOKENS["bag"] if i != 1 else TOKENS["teal"])
        c.button(944, 650, 184, 56, buttons[0], "secondary")
        c.button(1152, 650, 184, 56, buttons[1], "primary")
    else:
        c.button(904, 512, 200, 56, buttons[0], "secondary")
        c.button(1132, 512, 220, 56, buttons[1], "danger" if danger else "primary")
    c.save(name)
    spec_png(name, [SpecRect("Modal", (520, 260, 880, 456 if selector else 360)), SpecRect("Actions", (904, 512 if not selector else 650, 448, 56))])


def screen_npc_offer():
    c = Canvas("NPC 提出法器交换")
    c.panel(392, 196, 1136, 688, "#211014", TOKENS["line"], cut=26)
    c.text(448, 252, "NPC 提出法器交换", 40, TOKENS["text"], True)
    c.text(448, 310, "灯下账房想与你交换法器。下方同时显示你的统治与升华需求，便于判断风险。", 22, TOKENS["muted"], max_w=1000)
    c.panel(448, 380, 456, 196, "#160e12", TOKENS["teal"], cut=18)
    c.text(480, 412, "NPC 给出", 24, TOKENS["teal"], True)
    c.panel(480, 456, 160, 96, "#111012", TOKENS["teal"], cut=12)
    c.artifact_icon(512, 468, 72, "key", TOKENS["teal"])
    c.text(664, 466, "月厅密钥", 28, TOKENS["text"], True)
    c.text(664, 510, "交换获得后进入背包", 18, TOKENS["muted"])
    c.panel(1016, 380, 456, 196, "#160e12", TOKENS["danger"], cut=18)
    c.text(1048, 412, "你交出", 24, TOKENS["danger"], True)
    c.panel(1048, 456, 160, 96, "#111012", TOKENS["danger"], cut=12)
    c.artifact_icon(1088, 468, 72, "gem", TOKENS["danger"])
    c.text(1232, 466, "血契棱镜", 28, TOKENS["text"], True)
    c.text(1232, 510, "统治需求之一", 18, TOKENS["muted"])
    c.d.line(sp([(922, 486), (982, 486)]), fill=rgb(TOKENS["gold"]), width=8*SCALE)
    c.d.polygon(sp([(982, 486), (960, 472), (960, 500)]), fill=rgb(TOKENS["gold"]))
    c.d.line(sp([(982, 526), (922, 526)]), fill=rgb(TOKENS["gold"]), width=8*SCALE)
    c.d.polygon(sp([(922, 526), (944, 512), (944, 540)]), fill=rgb(TOKENS["gold"]))
    c.svg.line(922, 486, 982, 486, TOKENS["gold"], 8)
    c.svg.polygon([(982, 486), (960, 472), (960, 500)], TOKENS["gold"])
    c.svg.line(982, 526, 922, 526, TOKENS["gold"], 8)
    c.svg.polygon([(922, 526), (944, 512), (944, 540)], TOKENS["gold"])
    c.panel(448, 616, 496, 144, "#171114", TOKENS["danger"], cut=16)
    c.text(480, 644, "我的统治需求", 24, TOKENS["danger"], True)
    for i, (label, kind) in enumerate([("血契棱镜", "gem"), ("月厅密钥", "key"), ("灰冠契印", "seal")]):
        c.artifact_icon(480 + i * 140, 686, 52, kind, TOKENS["danger"] if i == 0 else TOKENS["bag"])
        c.text(536 + i * 140, 700, label[:2], 16, TOKENS["text"], True)
    c.panel(976, 616, 496, 144, "#171114", TOKENS["teal"], cut=16)
    c.text(1008, 644, "我的升华需求", 24, TOKENS["teal"], True)
    for i, (label, kind) in enumerate([("银针袖扣", "dagger"), ("失落本名", "seal")]):
        c.artifact_icon(1008 + i * 160, 686, 52, kind, TOKENS["teal"])
        c.text(1064 + i * 160, 700, label[:2], 16, TOKENS["text"], True)
    c.button(968, 796, 200, 56, "拒绝", "secondary")
    c.button(1200, 796, 240, 56, "接受交换", "primary")
    c.save("dialogue_popup_npc_offer")
    spec_png("dialogue_popup_npc_offer", [
        SpecRect("Modal", (392, 196, 1136, 688)),
        SpecRect("TradeCards", (448, 380, 1024, 196)),
        SpecRect("Requirements", (448, 616, 1024, 144)),
        SpecRect("Actions", (968, 796, 472, 56)),
    ])


def screen_banner():
    c = Canvas("行动结果")
    c.panel(360, 156, 1200, 128, "#271215", TOKENS["gold"], cut=18)
    c.text(416, 190, "手动行动：施法", 34, TOKENS["gold"], True)
    c.text(416, 238, "月债灯命中目标需求，获得对方背包全部法器。", 22, TOKENS["text"])
    c.button(1312, 192, 176, 56, "继续", "primary")
    c.save("dialogue_banner_action_result")
    spec_png("dialogue_banner_action_result", [SpecRect("ResultBanner", (360, 156, 1200, 128)), SpecRect("Continue", (1312, 192, 176, 56))])


def components():
    c = Canvas("组件表")
    title(c, "Gameplay UI Components", "所有页面从这些可实现组件拆解：面板、按钮、卡片、物品格、输入区、提示条。")
    c.panel(240, 260, 1440, 560, "#1a1012", TOKENS["line"], cut=24)
    c.button(300, 324, 220, 56, "主按钮", "primary")
    c.button(548, 324, 220, 56, "次按钮", "secondary")
    c.button(796, 324, 220, 56, "危险按钮", "danger")
    c.button(1044, 324, 220, 56, "选项按钮", "option", True)
    c.card(300, 440, 420, 152, "信息卡", "标题 22px，正文 18px；固定内边距 20px。", TOKENS["teal"], True)
    c.item(780, 448, "物品格", "152x142", TOKENS["bag"])
    c.panel(980, 448, 560, 144, "#211014", TOKENS["line_dark"], cut=14)
    c.text(1012, 480, "输入/文本区", 24, TOKENS["text"], True)
    c.text(1012, 524, "使用硬边轻斜切容器，禁止复杂纹理和模糊光效。", 18, TOKENS["muted"])
    c.panel(300, 660, 920, 80, "#271215", TOKENS["gold"], cut=14)
    c.text(332, 684, "提示条：行动结果一句话", 26, TOKENS["gold"], True)
    c.save("gameplay_ui_components")


def spec_doc():
    text = """# Gameplay UI Spec

## Canvas And Grid
- Canvas: 1920 x 1080.
- Base grid: 8 px.
- Allowed spacing: 8 / 16 / 24 / 32 / 48 px.
- Main overlay width: 1440 px. Standard left edge: x=240.
- No hand-drawn borders, bitmap textures, blur stacks, random scratches, or non-parametric decoration.

## Typography
- Page title: 40 px, bold.
- Section title: 28 px, bold.
- Body: 22 px.
- Assistive text: 18 px.
- Button label: 24 px, bold.
- Font target: Noto Sans SC or Microsoft YaHei. Godot fallback may use any CJK sans font with the same sizes.

## Color Tokens
| Token | Hex | Use |
| --- | --- | --- |
| background | #120b0d | Page background |
| panel | #241114 | Primary panel |
| panel_2 | #32171b | Raised panel |
| panel_3 | #171114 | Item/card inner panel |
| line | #d5a34a | Main gold border |
| line_dark | #7d4f24 | Secondary border |
| text | #f6e9cb | Main text |
| muted | #a99779 | Secondary text |
| teal | #1fb7a6 | Intel/status accent |
| bag | #b77725 | Bag/item accent |
| danger | #b5423c | Risk/destructive accent |
| gold | #e4b85b | Confirm/success accent |
| gray | #5c5960 | Disabled/secondary accent |

## Components
- Panel: clipped-corner polygon, 18-24 px cut, 3 px border, 10 x 12 px shadow.
- Card: clipped panel, 16 px cut, 20 px horizontal padding, title/body only.
- Item slot: 152 x 142 px, icon diamond centered at y=44, label at y=82.
- Button: clipped panel, 12 px cut. Standard sizes: 224 x 56, 264 x 56, compact 184 x 40.
- Footer: x=240 y=880 w=1440 h=104. Right-aligned secondary and primary actions.
- Modal: centered x=520 w=880. Standard action row y=512; selector modal y=650.

## Button States For Godot
- Normal: component base fill + accent border.
- Hover: increase border brightness by 20%, add 2 px top highlight.
- Pressed: move content down 2 px, darken fill by 15%.
- Disabled: use gray border, reduce text alpha to 55%, no hover highlight.

## Screen Element Counts
- Intel: 1 title, 6 question panels, 18 option cards, each option has image/title/supporters, 2 footer buttons.
- Bag: left requirements panel with 3 dominion + 2 ascension slots, right inventory panel with 8 item slots, 2 footer buttons.
- Rules: 3 horizontal strategy input boxes, 1 large free-text input area, 2 footer buttons.
- Status: left chapter/NPC panel, right player attribute panel with 8 icon rows, 2 footer buttons.
- History: 1 dialogue timeline, 1 event list, 2 footer buttons.
- Settings: 1 volume slider, 1 auto-confirm block with 4 independent checkboxes, 1 close button.
- NPC offer popup: 2 artifact trade cards, 2 requirement strips, 2 buttons.
- Confirm/submit popups: title, body, 2 buttons.
- Artifact select popup: title, body, 4 item slots, 2 buttons.
- Result banner: title, result text, 1 continue button.
"""
    (OUT / "gameplay_ui_spec.md").write_text(text, encoding="utf-8")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    screen_intel()
    screen_bag()
    screen_rules()
    screen_status()
    screen_history()
    screen_settings()
    screen_npc_offer()
    popup_base("dialogue_popup_player_action_confirm", "确认玩家行动", "你方角色决定执行「决斗」。目标：灯下账房。是否允许本次行动？", ("取消", "确定"), danger=True)
    popup_base("dialogue_popup_artifact_select", "选择施法法器", "选择一个当前持有的法器用于本次施法。", ("取消", "确认选择"), selector=True)
    popup_base("dialogue_popup_submit_world_intel", "提交世界设定档案", "提交后无法修改。全部 6 条设定正确才会胜利，任意错误都会失败。", ("返回检查", "提交"), danger=True)
    screen_banner()
    components()
    spec_doc()


if __name__ == "__main__":
    main()
