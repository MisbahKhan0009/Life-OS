"""Draws the Life OS "Orbit" mark: a ring of 24 dots like a day going round, the first one red,
with a dot at the centre. Run from the repo root: python3 tool/make_logo.py .  (needs Pillow)."""
import math, os, random, sys
from PIL import Image, ImageDraw, ImageFilter

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'
BG = (14, 14, 15, 255)
LIT = (237, 237, 234, 255)
DIM = (52, 52, 54, 255)
RED = (229, 38, 46, 255)
SS = 4

def blob(img, box, color, blur):
    l = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(l).ellipse(box, fill=color)
    return Image.alpha_composite(img, l.filter(ImageFilter.GaussianBlur(blur)))

def grain(img, amt=0.05, seed=3):
    s = img.size[0]
    n0 = max(1, s // 4)
    rnd = random.Random(seed)
    n = Image.new('L', (n0, n0))
    n.putdata([rnd.randint(0, 255) for _ in range(n0 * n0)])
    n = n.resize((s, s), Image.NEAREST)
    g = Image.new('RGBA', (s, s), (255, 255, 255, 0))
    g.putalpha(n.point(lambda v: int(v * amt)))
    return Image.alpha_composite(img, g)

def ground(size):
    s = size * SS
    img = Image.new('RGBA', (s, s), BG)
    img = blob(img, (-s * 0.2, -s * 0.3, s * 0.78, s * 0.68), (60, 56, 54, 160), s * 0.17)
    return grain(img)

def ring(img, scale=1.0, mono=False, dim=True):
    """Draws the ring. scale 1.0 spans about 68% of the canvas."""
    s = img.size[0]
    d = ImageDraw.Draw(img)
    c = s / 2
    r = s * 0.30 * scale
    for i in range(24):
        a = -math.pi / 2 + i * 2 * math.pi / 24
        x, y = c + math.cos(a) * r, c + math.sin(a) * r
        rad = s * (0.039 if i == 0 else 0.0254) * scale
        if i == 0:
            col = (255, 255, 255, 255) if mono else RED
        elif i < 17:
            col = (255, 255, 255, 255) if mono else LIT
        else:
            if not dim:
                continue
            col = DIM
        d.ellipse((x - rad, y - rad, x + rad, y + rad), fill=col)
    cr = s * 0.033 * scale
    d.ellipse((c - cr, c - cr, c + cr, c + cr), fill=(255, 255, 255, 255) if mono else LIT)
    return img

def rounded(img):
    s = img.size[0]
    m = Image.new('L', (s, s), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, s - 1, s - 1), radius=int(s * 0.225), fill=255)
    img.putalpha(m)
    return img

def clear(size):
    return Image.new('RGBA', (size * SS, size * SS), (0, 0, 0, 0))

def out(img, size):
    return img.resize((size, size), Image.LANCZOS)

def full(size, scale=1.0, round_corners=True):
    img = ring(ground(size), scale)
    return out(rounded(img) if round_corners else img, size)

def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)

res = os.path.join(ROOT, 'platform/android/app/src/main/res')
for name, legacy, adaptive in [('mdpi', 48, 108), ('hdpi', 72, 162), ('xhdpi', 96, 216), ('xxhdpi', 144, 324), ('xxxhdpi', 192, 432)]:
    save(full(legacy), f'{res}/mipmap-{name}/ic_launcher.png')
    # Adaptive layers: 108dp canvas, ring inside the 66dp safe circle.
    save(out(ring(clear(adaptive), 0.84), adaptive), f'{res}/mipmap-{name}/ic_launcher_foreground.png')
    save(out(ground(adaptive), adaptive), f'{res}/mipmap-{name}/ic_launcher_background.png')
    save(out(ring(clear(adaptive), 0.84, mono=True, dim=False), adaptive), f'{res}/mipmap-{name}/ic_launcher_monochrome.png')
save(out(ring(clear(288), 1.25), 288), f'{res}/drawable-nodpi/splash_logo.png')

web = os.path.join(ROOT, 'platform/web')
save(full(32, scale=1.25), f'{web}/favicon.png')
save(full(192), f'{web}/icons/Icon-192.png')
save(full(512), f'{web}/icons/Icon-512.png')
save(full(192, scale=0.84, round_corners=False), f'{web}/icons/Icon-maskable-192.png')
save(full(512, scale=0.84, round_corners=False), f'{web}/icons/Icon-maskable-512.png')

save(full(1024), os.path.join(ROOT, 'assets/brand/icon-1024.png'))
print('done')
