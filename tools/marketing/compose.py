"""Glass Clash thumbnails: finish the ChatGPT picks and export them for Roblox.

  python3 tools/marketing/compose.py          (needs Pillow: pip install pillow)

For each pick in PICKS it reads assets/marketing/thumbnails/from_chatgpt/<source>, applies a light finish
(gentle sharpen + saturation, soft vignette that keeps the clear zone calm), and writes
  final/<id>.jpg        1920x1080 with the jewel wordmark in the clear zone (under 3 MB)
  final/clean/<id>.jpg  the same without the logo
plus final/contact_sheet.png: every thumbnail at 300 px wide on light and dark backgrounds, with the
bottom-15% line Roblox can cover.
"""

import os

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
THUMBS = os.path.join(REPO, "assets", "marketing", "thumbnails")
SRC = os.path.join(THUMBS, "from_chatgpt")
OUT = os.path.join(THUMBS, "final")
LOGO = os.path.join(REPO, "assets", "marketing", "logo", "wordmark_jewel.png")
SIZE = (1920, 1080)
MAX_BYTES = 3 * 1024 * 1024

# id: (source file in from_chatgpt/, logo zone, logo width in px). Upload order = list order.
PICKS = {
    "T1a": ("T1a.png", "TL", 640),
    "T3a": ("T3a.png", "TL", 560),
    "T2a": ("T2a.png", "TL", 660),
    "T1c": ("T1c.png", "TL", 640),
    "T5a": ("T5a.png", "TL", 560),
    "T1h": ("T1h.png", "TL", 600),
    "T2c": ("T2c.png", "TL", 660),
    "T4a": ("T4a.png", "TL", 600),
    "T3b": ("T3b.png", "TC", 560),
    "T1b": ("T1b.png", "TC", 640),
}
# Spares (exported clean only, for swapping in after the first test week).
SPARES = {
    "T4b": ("T4b.png", "TC", 520),
    "T5b": ("T5b.png", "TC", 520),
    "T2b": ("T2b.png", "TC", 560),
    "T1d": ("alt/T1d_b.png", "TC", 600),
}


def finish(im):
    im = im.convert("RGB").resize(SIZE, Image.LANCZOS)
    im = im.filter(ImageFilter.UnsharpMask(radius=1.6, percent=45, threshold=3))
    im = ImageEnhance.Color(im).enhance(1.06)
    # Soft vignette: darkens the far corners a touch so the subject pops on a small tile.
    w, h = SIZE
    mask = Image.new("L", (w // 8, h // 8), 0)
    d = ImageDraw.Draw(mask)
    d.ellipse([-w // 40, -h // 40, w // 8 + w // 40, h // 8 + h // 40], fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(18)).resize(SIZE, Image.LANCZOS)
    dark = ImageEnhance.Brightness(im).enhance(0.82)
    return Image.composite(im, dark, mask)


def logo_layer(zone, width):
    logo = Image.open(LOGO).convert("RGBA")
    logo = logo.crop(logo.getbbox())
    logo = logo.resize((width, round(logo.height * width / logo.width)), Image.LANCZOS)
    margin_x, margin_y = 56, 44
    x = margin_x if zone == "TL" else (SIZE[0] - logo.width) // 2
    pos = (x, margin_y)
    # A soft dark glow behind the letters so they read on bright skies too.
    glow = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    shadow = Image.new("RGBA", logo.size, (20, 14, 40, 0))
    shadow.putalpha(logo.getchannel("A").point(lambda a: int(a * 0.55)))
    glow.alpha_composite(shadow, (pos[0] + 6, pos[1] + 10))
    glow = glow.filter(ImageFilter.GaussianBlur(14))
    layer = Image.new("RGBA", SIZE, (0, 0, 0, 0))
    layer.alpha_composite(glow)
    layer.alpha_composite(logo, pos)
    return layer


def save_jpg(im, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for q in (92, 90, 88, 85, 82):
        im.save(path, "JPEG", quality=q, optimize=True, progressive=True, subsampling=0)
        if os.path.getsize(path) < MAX_BYTES:
            return q
    raise RuntimeError(f"{path} is still over 3 MB")


def contact_sheet(paths, out):
    tw, th, gap = 300, 169, 12
    cols = 5
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (tw + gap) + gap, 2 * (rows * (th + gap + 16) + gap)), (0, 0, 0))
    for half, bg in enumerate([(242, 242, 245), (25, 27, 31)]):
        top = half * (rows * (th + gap + 16) + gap)
        ImageDraw.Draw(sheet).rectangle([0, top, sheet.width, top + rows * (th + gap + 16) + gap], fill=bg)
        for i, (name, p) in enumerate(paths):
            x = gap + (i % cols) * (tw + gap)
            y = top + gap + (i // cols) * (th + gap + 16)
            t = Image.open(p).convert("RGB").resize((tw, th), Image.LANCZOS)
            d = ImageDraw.Draw(t)
            d.line([(0, int(th * 0.85)), (tw, int(th * 0.85))], fill=(255, 60, 60))
            sheet.paste(t, (x, y))
            ImageDraw.Draw(sheet).text((x, y + th + 2), name, fill=(128, 128, 128))
    sheet.save(out)


def main():
    made = []
    for group, with_logo in ((PICKS, True), (SPARES, False)):
        for sid, (src, zone, width) in group.items():
            base = finish(Image.open(os.path.join(SRC, src)))
            q = save_jpg(base, os.path.join(OUT, "clean", f"{sid}.jpg"))
            line = f"{sid}: clean q{q}"
            if with_logo:
                im = base.convert("RGBA")
                im.alpha_composite(logo_layer(zone, width))
                path = os.path.join(OUT, f"{sid}.jpg")
                q = save_jpg(im.convert("RGB"), path)
                made.append((sid, path))
                line += f", logo {zone} q{q} {os.path.getsize(path) / 1e6:.2f} MB"
            print(line)
    contact_sheet(made, os.path.join(OUT, "contact_sheet.png"))
    print("contact sheet:", os.path.join(OUT, "contact_sheet.png"))


if __name__ == "__main__":
    main()
