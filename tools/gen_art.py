"""Generates Bloom's branding art (icon, splash, logo). Run: python tools/gen_art.py"""
import math
import os
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "branding")
FONT = os.path.join(ROOT, "assets", "fonts", "Outfit.ttf")
os.makedirs(OUT, exist_ok=True)

BG_TOP = (14, 12, 38)
BG_BOT = (6, 6, 20)
PETALS = [(255, 94, 160), (255, 160, 90), (255, 224, 110), (110, 240, 190), (90, 190, 255), (170, 120, 255)]


def gradient(w, h):
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        c = tuple(int(BG_TOP[i] * (1 - t) + BG_BOT[i] * t) for i in range(3))
        for x in range(w):
            px[x, y] = c
    return img


def glow_layer(size, draw_fn, blurs=(4, 14, 36), gains=(1.0, 0.9, 0.8)):
    """Draw with draw_fn onto black, then stack blurred copies additively (fake bloom)."""
    base = Image.new("RGB", size, (0, 0, 0))
    draw_fn(ImageDraw.Draw(base))
    out = base
    for b, g in zip(blurs, gains):
        blurred = base.filter(ImageFilter.GaussianBlur(b)).point(lambda v, g=g: min(255, int(v * g * 1.6)))
        out = ImageChops.add(out, blurred)
    return out


def bloom_flower(draw, cx, cy, r, rot=0.0):
    n = len(PETALS)
    for i, col in enumerate(PETALS):
        a = rot + i * math.tau / n
        px, py = cx + math.cos(a) * r * 0.52, cy + math.sin(a) * r * 0.52
        pr = r * 0.40
        draw.ellipse((px - pr, py - pr, px + pr, py + pr), outline=col, width=max(2, int(r * 0.07)))
    cr = r * 0.22
    draw.ellipse((cx - cr, cy - cr, cx + cr, cy + cr), fill=(255, 255, 255))


def make_icon(size=512, padded=False):
    bg = gradient(size, size)
    scale = 0.30 if padded else 0.40
    layer = glow_layer((size, size), lambda d: bloom_flower(d, size / 2, size / 2, size * scale, 0.3))
    img = ImageChops.add(bg, layer)
    return img


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, img.size[0] - 1, img.size[1] - 1), radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def word(draw, cx, cy, size, text="bloom"):
    font = ImageFont.truetype(FONT, size)
    try:
        font.set_variation_by_axes([380])
    except Exception:
        pass
    bbox = draw.textbbox((0, 0), text, font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text((cx - w / 2 - bbox[0], cy - h / 2 - bbox[1]), text, font=font, fill=(255, 255, 255))


def make_splash(w=1280, h=720):
    bg = gradient(w, h)

    def d(draw):
        bloom_flower(draw, w / 2, h / 2 - 70, 120, 0.3)
        word(draw, w / 2, h / 2 + 130, 120)

    layer = glow_layer((w, h), d, blurs=(3, 12, 30), gains=(1.0, 0.7, 0.6))
    return ImageChops.add(bg, layer)


def make_logo(w=1024, h=512):
    # transparent logo: render on black then use luminance as alpha
    def d(draw):
        bloom_flower(draw, w / 2, h / 2 - 90, 150, 0.3)
        word(draw, w / 2, h / 2 + 150, 170)

    layer = glow_layer((w, h), d, blurs=(3, 12, 30), gains=(1.0, 0.7, 0.6))
    alpha = layer.convert("L").point(lambda v: min(255, int(v * 1.4)))
    out = layer.convert("RGBA")
    out.putalpha(alpha)
    return out


if __name__ == "__main__":
    icon = make_icon(512)
    rounded(icon, 112).save(os.path.join(OUT, "icon.png"))
    make_icon(432, padded=True).save(os.path.join(OUT, "icon_adaptive_bg.png"))
    # adaptive foreground: flower only on transparent
    fg = make_icon(432, padded=True)
    fg_layer = glow_layer((432, 432), lambda d: bloom_flower(d, 216, 216, 432 * 0.30, 0.3))
    fa = fg_layer.convert("L").point(lambda v: min(255, int(v * 1.4)))
    fgr = fg_layer.convert("RGBA")
    fgr.putalpha(fa)
    fgr.save(os.path.join(OUT, "icon_adaptive_fg.png"))
    make_splash().save(os.path.join(OUT, "splash.png"))
    make_logo().save(os.path.join(OUT, "logo.png"))
    icon.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, "icon_256.png"))
    icon.save(os.path.join(OUT, "icon.ico"), sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    print("art generated in", OUT)
