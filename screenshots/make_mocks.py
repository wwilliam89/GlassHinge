#!/usr/bin/env python3
"""Mock App Store screenshots for GlassHinge (2560x1600).

Faithful mocks of the shipped design: a desktop that folds top-down —
a fold line sweeps down from the top edge, the desktop above it
dissolves into real Gaussian blur + blue liquid-glass tint, a band of
light rides the crease, and a glow sits on the top edge — all driven by
one progress value, the same recipe as GlassOverlayView.swift.
UI shots mirror SettingsView / the menu-bar popover. These are mocks for
review/marketing, not captures from a running Mac.
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import pathlib, math

W, H = 2560, 1600
OUT = pathlib.Path(__file__).parent
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

def F(size, bold=False):
    return ImageFont.truetype(BOLD if bold else REG, size)

# ---------------------------------------------------------------- desktop
def desktop():
    img = Image.new("RGB", (W, H), (30, 40, 90))
    # wallpaper: soft colour blobs, heavily blurred (Sonoma-style abstract)
    blobs = Image.new("RGB", (W, H), (24, 32, 80))
    bd = ImageDraw.Draw(blobs)
    for (x, y, r, c) in [
        (300, 200, 700, (70, 90, 200)), (2100, 150, 650, (150, 70, 170)),
        (1300, 900, 800, (40, 130, 210)), (400, 1300, 600, (230, 120, 90)),
        (2300, 1250, 620, (90, 60, 180)), (900, 500, 480, (60, 180, 220)),
    ]:
        bd.ellipse([x - r, y - r, x + r, y + r], fill=c)
    img = blobs.filter(ImageFilter.GaussianBlur(180))
    d = ImageDraw.Draw(img, "RGBA")

    # menu bar
    d.rectangle([0, 0, W, 54], fill=(245, 245, 250, 190))
    d.text((36, 12), "GlassHinge   File   Edit   View   Window   Help",
           font=F(28, True), fill=(30, 30, 40))
    d.text((2080, 12), "Mon Oct 19   11:36 PM", font=F(28), fill=(30, 30, 40))
    for i, cx in enumerate((1880, 1950, 2020)):
        d.ellipse([cx, 14, cx + 26, 40], outline=(30, 30, 40), width=3)

    # window 1 — light app window
    def window(x, y, w, h, dark=False, title=""):
        d.rounded_rectangle([x, y, x + w, y + h], radius=22,
                            fill=(28, 30, 38) if dark else (248, 248, 250))
        d.rounded_rectangle([x, y, x + w, y + 64], radius=22,
                            fill=(45, 48, 58) if dark else (232, 232, 236))
        d.rectangle([x, y + 40, x + w, y + 64], fill=(45, 48, 58) if dark else (232, 232, 236))
        for i, c in enumerate(((255, 95, 86), (255, 189, 46), (39, 201, 63))):
            d.ellipse([x + 26 + i * 44, y + 20, x + 50 + i * 44, y + 44], fill=c)
        d.text((x + 190, y + 14), title, font=F(26), fill=(120, 120, 130))
    window(280, 200, 1240, 830, title="Quarterly notes")
    # content of window 1: text lines + a chart block
    for i in range(9):
        lw = 1050 - (i % 3) * 190
        d.rounded_rectangle([340, 330 + i * 62, 340 + lw, 356 + i * 62], radius=12,
                            fill=(205, 208, 216))
    d.rounded_rectangle([340, 920, 1460, 990], radius=14, fill=(70, 130, 235))
    # window 2 — dark editor
    window(1300, 560, 1000, 760, dark=True, title="hinge.swift")
    palette = [(120, 200, 255), (255, 170, 90), (160, 240, 170), (230, 150, 220), (150, 160, 200)]
    for i in range(10):
        x0 = 1360 + (i % 4) * 46
        lw = 760 - (i * 67) % 380
        d.rounded_rectangle([x0, 680 + i * 58, x0 + lw, 702 + i * 58], radius=10,
                            fill=palette[i % len(palette)])
    # dock
    dw = 1180
    d.rounded_rectangle([(W - dw) // 2, H - 128, (W + dw) // 2, H - 24], radius=30,
                        fill=(240, 240, 245, 120), outline=(255, 255, 255, 90), width=2)
    cols = [(70, 130, 235), (255, 120, 90), (90, 200, 140), (250, 190, 60), (170, 110, 240),
            (90, 190, 230), (240, 110, 160), (120, 130, 150), (60, 170, 190), (200, 90, 90),
            (100, 110, 220), (140, 200, 90)]
    for i, c in enumerate(cols):
        x = (W - dw) // 2 + 26 + i * 96
        d.rounded_rectangle([x, H - 114, x + 76, H - 38], radius=18, fill=c)
    return img

# ---------------------------------------------------------------- effect
def apply_effect(base, p):
    """Same recipe as GlassOverlayView: top-down fold. The fold line
    starts at the top edge and sweeps down as p grows; above the line
    the desktop is folded glass (blur + tint + milky wash), below it
    clear, with a crease shadow on the folded side and a band of light
    (with a faint chromatic fringe) riding the crease."""
    foldY = H * p
    band = 180  # soft edge around the crease, px
    # fold mask: 255 above the crease, 0 below, smooth over the band
    mask = Image.new("L", (W, H), 0)
    md = ImageDraw.Draw(mask)
    for y in range(H):
        t = (y - (foldY - band)) / (2 * band)
        t = max(0.0, min(1.0, t))
        s = t * t * (3 - 2 * t)  # smoothstep
        md.line([(0, y), (W, y)], fill=int(255 * (1 - s)))
    blurred = base.filter(ImageFilter.GaussianBlur(4 + 30 * p))
    img = Image.composite(blurred, base, mask.point(lambda v: int(v * p * 0.96))).convert("RGBA")
    # liquid-glass tint: vertical blue -> cyan, masked to the fold
    tint = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    td = ImageDraw.Draw(tint)
    steps = 80
    for i in range(steps):
        t = i / steps
        col = (int(40 + 30 * t), int(110 + 60 * t), int(235 - 40 * t), 255)
        td.line([(0, int(H * t)), (W, int(H * t))], fill=col, width=int(H / steps) + 2)
    tint.putalpha(mask.point(lambda v: int(v * p * 0.9)))
    img.alpha_composite(tint.filter(ImageFilter.GaussianBlur(40)))
    # milky wash over the folded region, peaking mid-fold
    milk = int(255 * math.sin(math.pi * p) * 0.28)
    wash = Image.new("RGBA", (W, H), (255, 255, 255, milk))
    wash.putalpha(mask.point(lambda v: int(v * math.sin(math.pi * p) * 0.28)))
    img.alpha_composite(wash)
    # crease shadow: dark band just above the fold line
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rectangle([0, foldY - 165, W, foldY - 55], fill=(0, 0, 0, int(56 * p)))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))
    # crease shine: white core with a faint cyan/blue fringe, riding the line
    shine = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shine)
    sh = 220
    sd.rectangle([0, foldY - sh / 2, W, foldY - 40], fill=(120, 220, 255, int(70 * p)))
    sd.rectangle([0, foldY - 60, W, foldY + 60], fill=(255, 255, 255, int(150 * p)))
    sd.rectangle([0, foldY + 40, W, foldY + sh / 2], fill=(90, 120, 255, int(70 * p)))
    img.alpha_composite(shine.filter(ImageFilter.GaussianBlur(60)))
    # top-edge glow where the fold starts
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(40):
        a = int(90 * p * (1 - i / 40))
        gd.line([(0, i * 5), (W, i * 5)], fill=(190, 225, 255, a), width=5)
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(18)))
    return img.convert("RGB")

# ---------------------------------------------------------------- UI bits
def toggle(d, x, y, on=True):
    d.rounded_rectangle([x, y, x + 92, y + 54], radius=27,
                        fill=(46, 199, 89) if on else (190, 190, 196))
    cx = x + 65 if on else x + 27
    d.ellipse([cx - 22, y + 5, cx + 22, y + 49], fill=(255, 255, 255))

def slider(d, x, y, w, frac, label, val):
    d.text((x, y), label, font=F(30), fill=(35, 35, 45))
    d.rounded_rectangle([x + 300, y + 12, x + 300 + w, y + 24], radius=6, fill=(205, 205, 212))
    d.rounded_rectangle([x + 300, y + 12, x + 300 + int(w * frac), y + 24], radius=6, fill=(40, 120, 245))
    kx = x + 300 + int(w * frac)
    d.ellipse([kx - 17, y + 1, kx + 17, y + 35], fill=(255, 255, 255), outline=(170, 170, 178), width=2)
    d.text((x + 330 + w, y), val, font=F(30), fill=(90, 90, 100))

def section(d, x, y, w, title, rows_h):
    d.text((x + 6, y), title.upper(), font=F(24, True), fill=(130, 130, 140))
    d.rounded_rectangle([x, y + 44, x + w, y + 44 + rows_h], radius=18, fill=(255, 255, 255),
                        outline=(215, 215, 222), width=2)
    return y + 44

# ---------------------------------------------------------------- shots
base = desktop()
apply_effect(base.copy(), 0.5).save(OUT / "01-effect-mid-close.png")
apply_effect(base.copy(), 0.75).save(OUT / "02-effect-wake-dissolve.png")

# Shot 3 — Settings window over the desktop
img = base.copy()
d = ImageDraw.Draw(img, "RGBA")
d.rectangle([0, 0, W, H], fill=(10, 12, 24, 70))
wx, wy, ww, wh = 560, 130, 1440, 1340
d.rounded_rectangle([wx, wy, wx + ww, wy + wh], radius=24, fill=(242, 242, 246))
d.rounded_rectangle([wx, wy, wx + ww, wy + 74], radius=24, fill=(228, 228, 233))
d.rectangle([wx, wy + 50, wx + ww, wy + 74], fill=(228, 228, 233))
for i, c in enumerate(((255, 95, 86), (255, 189, 46), (39, 201, 63))):
    d.ellipse([wx + 28 + i * 48, wy + 24, wx + 56 + i * 48, wy + 52], fill=c)
d.text((wx + 220, wy + 16), "GlassHinge Settings", font=F(32, True), fill=(40, 40, 50))
x, w = wx + 56, ww - 112
y = section(d, x, wy + 120, w, "Effect", 330)
d.text((x + 28, y + 30), "Enable glass effect", font=F(30), fill=(35, 35, 45)); toggle(d, x + w - 130, y + 24)
d.line([x + 28, y + 108, x + w - 28, y + 108], fill=(225, 225, 230), width=2)
d.text((x + 28, y + 132), "Glass style", font=F(30), fill=(35, 35, 45))
seg = ["Ocean Blue", "Clear Glass", "Frost"]
sx = x + 560
for i, s in enumerate(seg):
    sel = i == 0
    d.rounded_rectangle([sx + i * 252, y + 124, sx + (i + 1) * 252 - 8, y + 182], radius=12,
                        fill=(40, 120, 245) if sel else (232, 232, 238))
    tw = d.textlength(s, font=F(26))
    d.text((sx + i * 252 + (244 - tw) / 2, y + 138), s, font=F(26),
           fill=(255, 255, 255) if sel else (70, 70, 80))
d.line([x + 28, y + 216, x + w - 28, y + 216], fill=(225, 225, 230), width=2)
slider(d, x + 28, y + 240, 560, 0.66, "Intensity", "1.0x")
d.rounded_rectangle([x + 28, y + 240 + 58, x + 300, y + 240 + 118], radius=12, fill=(40, 120, 245))
d.text((x + 52, y + 240 + 72), "Play effect now", font=F(27, True), fill=(255, 255, 255))
y = section(d, x, wy + 545, w, "When it plays", 190)
d.text((x + 28, y + 28), "Play when the lid opens (on wake)", font=F(30), fill=(35, 35, 45)); toggle(d, x + w - 130, y + 22)
d.line([x + 28, y + 100, x + w - 28, y + 100], fill=(225, 225, 230), width=2)
d.text((x + 28, y + 122), "Play when the display goes to sleep", font=F(30), fill=(35, 35, 45)); toggle(d, x + w - 130, y + 116, on=False)
y = section(d, x, wy + 835, w, "Sensor status", 170)
d.ellipse([x + 30, y + 34, x + 52, y + 56], fill=(46, 199, 89))
d.text((x + 72, y + 24), "Lid angle sensor", font=F(30, True), fill=(35, 35, 45))
d.text((x + 72, y + 68), "Connected  ·  current angle: 84 degrees", font=F(27), fill=(95, 95, 105))
d.text((x + 72, y + 112), "The hinge scrubs the effect in real time on this Mac.", font=F(27), fill=(95, 95, 105))
y = section(d, x, wy + 1095, w, "General", 108)
d.text((x + 28, y + 28), "Launch at login", font=F(30), fill=(35, 35, 45)); toggle(d, x + w - 130, y + 22)
img.save(OUT / "03-settings.png")

# Shot 4 — menu-bar popover
img = base.copy()
d = ImageDraw.Draw(img, "RGBA")
px, py, pw, ph = 1760, 74, 700, 600
d.rounded_rectangle([px, py, px + pw, py + ph], radius=22, fill=(250, 250, 252),
                    outline=(200, 200, 208), width=2)
# mini app icon (laptop, horizontal hinge)
ix, iy = px + 36, py + 34
d.rounded_rectangle([ix, iy, ix + 84, iy + 84], radius=20, fill=(14, 20, 40))
d.rounded_rectangle([ix + 14, iy + 16, ix + 70, iy + 54], radius=6, outline=(170, 205, 255), width=4)
d.line([ix + 16, iy + 54, ix + 68, iy + 54], fill=(225, 246, 255), width=4)
d.rectangle([ix + 10, iy + 64, ix + 74, iy + 70], fill=(70, 120, 190))
d.text((ix + 108, py + 44), "GlassHinge", font=F(38, True), fill=(30, 30, 40))
d.rounded_rectangle([px + pw - 218, py + 42, px + pw - 36, py + 92], radius=25, fill=(225, 240, 230))
d.text((px + pw - 192, py + 52), "Sensor ON", font=F(25, True), fill=(25, 130, 60))
d.text((px + 40, py + 150), "Lid angle: 84 degrees", font=F(31), fill=(80, 80, 92))
d.text((px + 40, py + 204), "The glass effect follows your hinge\nin real time.", font=F(28), fill=(110, 110, 122))
d.rounded_rectangle([px + 40, py + 320, px + 330, py + 392], radius=14, fill=(40, 120, 245))
d.text((px + 82, py + 340), "Play effect", font=F(29, True), fill=(255, 255, 255))
d.text((px + 380, py + 340), "Cmd+Shift+G", font=F(26), fill=(140, 140, 150))
d.line([px + 40, py + 440, px + pw - 40, py + 440], fill=(225, 225, 230), width=2)
d.text((px + 40, py + 468), "Settings...", font=F(30), fill=(35, 35, 45))
d.text((px + 40, py + 528), "Quit GlassHinge", font=F(30), fill=(35, 35, 45))
img.save(OUT / "04-menubar-popover.png")
print("saved 4 screenshots to", OUT)
