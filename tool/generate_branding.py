from __future__ import annotations

import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "branding"
OUT.mkdir(parents=True, exist_ok=True)

BLUE = (37, 99, 235)
TEAL = (32, 199, 181)
NAVY = (15, 33, 58)
WHITE = (255, 255, 255)
MUTED = (92, 106, 126)


def gradient(size: int) -> Image.Image:
    image = Image.new("RGB", (size, size))
    px = image.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(round(BLUE[i] * (1 - t) + TEAL[i] * t) for i in range(3))
    return image


def draw_mark(size: int = 1024) -> Image.Image:
    image = gradient(size)
    draw = ImageDraw.Draw(image)
    s = size / 1024

    def box(coords):
        return tuple(round(v * s) for v in coords)

    line = round(58 * s)
    radius = round(86 * s)
    draw.rounded_rectangle(box((212, 172, 758, 780)), radius=radius, outline=WHITE, width=line)
    draw.ellipse(box((458, 254, 510, 306)), fill=WHITE)

    for bounds in [
        (284, 390, 628, 708),
        (348, 466, 632, 720),
        (416, 548, 628, 728),
    ]:
        draw.arc(box(bounds), start=205, end=276, fill=WHITE, width=line)

    shadow = box((578, 584, 926, 932))
    badge = box((566, 566, 914, 914))
    draw.ellipse(shadow, fill=(16, 92, 112))
    draw.ellipse(badge, fill=WHITE)
    check = [box((650, 744)), box((716, 810)), box((832, 670))]
    draw.line(check, fill=(18, 166, 161), width=round(54 * s), joint="curve")
    return image


def font(size: int, bold: bool = False):
    candidates = [
        Path(r"C:\Windows\Fonts\segoeuib.ttf" if bold else r"C:\Windows\Fonts\segoeui.ttf"),
        Path(r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def draw_logo() -> Image.Image:
    canvas = Image.new("RGB", (1800, 560), WHITE)
    mark = draw_mark(420)
    canvas.paste(mark, (80, 70))
    draw = ImageDraw.Draw(canvas)
    draw.text((560, 145), "TagVerity", fill=NAVY, font=font(132, bold=True))
    draw.text(
        (566, 310),
        "NFC Inspector  •  Tag Checker  •  Batch Scan",
        fill=MUTED,
        font=font(42),
    )
    return canvas


def save_platform_icons(source: Image.Image) -> None:
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    android_res = ROOT / "android" / "app" / "src" / "main" / "res"
    if android_res.exists():
        for folder, size in android_sizes.items():
            target = android_res / folder / "ic_launcher.png"
            target.parent.mkdir(parents=True, exist_ok=True)
            source.resize((size, size), Image.Resampling.LANCZOS).save(target, optimize=True)

    appicon = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    contents = appicon / "Contents.json"
    if contents.exists():
        data = json.loads(contents.read_text(encoding="utf-8"))
        for item in data.get("images", []):
            filename = item.get("filename")
            size_text = item.get("size")
            scale_text = item.get("scale")
            if not filename or not size_text or not scale_text:
                continue
            points = float(size_text.split("x", 1)[0])
            scale = float(scale_text.removesuffix("x"))
            pixels = round(points * scale)
            source.resize((pixels, pixels), Image.Resampling.LANCZOS).save(
                appicon / filename,
                optimize=True,
            )


mark = draw_mark()
mark.save(OUT / "tagverity_app_icon.png", optimize=True)
draw_logo().save(OUT / "tagverity_logo.png", optimize=True)
save_platform_icons(mark)
print("TagVerity branding generated and platform icons updated.")
