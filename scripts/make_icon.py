"""Generate a calendar + note themed app icon for Calanderwala.

Renders a teal rounded-square background with a white calendar card
overlapping a yellow note card. Used to update web/Android/macOS icons.
"""
from PIL import Image, ImageDraw, ImageFont
import os, math

ROOT = r"e:\calanderwala\calanderwala"

# App palette - warm teal background, white calendar, yellow note
BG = (20, 138, 132, 255)        # teal-700
BG_DARK = (15, 110, 106, 255)   # shadow
ACCENT = (255, 193, 7, 255)     # note yellow
NOTE_LINE = (235, 170, 0, 255)
CAL_HEADER = (229, 57, 53, 255) # red header band
CAL_TEXT = (33, 37, 41, 255)
CAL_GRID = (180, 180, 180, 255)
WHITE = (255, 255, 255, 255)


def rounded_rect(draw, xy, radius, fill):
    draw.rounded_rectangle(xy, radius=radius, fill=fill)


def draw_icon(size: int, maskable: bool = False) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # For maskable, leave 12% safe area
    if maskable:
        pad = int(size * 0.12)
    else:
        pad = 0
    inner = size - 2 * pad

    # Background rounded square
    rounded_rect(d, (pad, pad, pad + inner - 1, pad + inner - 1),
                 radius=int(inner * 0.22), fill=BG)

    # Soft inner shadow on top
    overlay = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.rounded_rectangle((pad, pad, pad + inner - 1, pad + inner - 1),
                         radius=int(inner * 0.22), fill=BG_DARK)
    # fade at bottom
    for i in range(int(inner * 0.3)):
        a = int(60 * (i / (inner * 0.3)))
        od.line([(pad + int(inner * 0.05), pad + inner - i),
                 (pad + inner - int(inner * 0.05), pad + inner - i)],
                fill=(0, 0, 0, a))
    img = Image.alpha_composite(img, overlay)
    d = ImageDraw.Draw(img)

    # ---- Yellow note card (rotated, behind calendar) ----
    note_w = int(inner * 0.55)
    note_h = int(inner * 0.55)
    note_x = pad + int(inner * 0.08)
    note_y = pad + int(inner * 0.40)
    note_cx = note_x + note_w / 2
    note_cy = note_y + note_h / 2
    rot = -8  # degrees

    note_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    nd = ImageDraw.Draw(note_layer)
    nd.rounded_rectangle((note_x, note_y, note_x + note_w, note_y + note_h),
                         radius=int(inner * 0.06), fill=ACCENT)
    # fold corner
    fold = int(inner * 0.08)
    nd.polygon([(note_x + note_w - fold, note_y),
                (note_x + note_w, note_y + fold),
                (note_x + note_w - fold, note_y + fold)],
               fill=(245, 215, 110, 255))
    # ruled lines
    for i in range(1, 4):
        ly = note_y + int(note_h * (i / 4.0))
        nd.line([(note_x + int(note_w * 0.12), ly),
                 (note_x + note_w - int(note_w * 0.15), ly)],
                fill=NOTE_LINE, width=max(2, int(inner * 0.008)))
    note_layer = note_layer.rotate(rot, resample=Image.BICUBIC, center=(size / 2, size / 2))
    # re-anchor so rotated note stays roughly in its spot
    img = Image.alpha_composite(img, note_layer)
    d = ImageDraw.Draw(img)

    # ---- White calendar card (front) ----
    cal_w = int(inner * 0.68)
    cal_h = int(inner * 0.72)
    cal_x = pad + (inner - cal_w) // 2 + int(inner * 0.04)
    cal_y = pad + int(inner * 0.10)
    d.rounded_rectangle((cal_x, cal_y, cal_x + cal_w, cal_y + cal_h),
                         radius=int(inner * 0.05), fill=WHITE)
    # subtle shadow
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((cal_x + 2, cal_y + 4, cal_x + cal_w + 2, cal_y + cal_h + 4),
                         radius=int(inner * 0.05), fill=(0, 0, 0, 35))
    blur = __import__("PIL.ImageFilter", fromlist=["GaussianBlur"]).GaussianBlur(radius=int(inner * 0.015))
    shadow = shadow.filter(blur)
    img = Image.alpha_composite(shadow, img)
    d = ImageDraw.Draw(img)

    # red header band
    hdr_h = int(cal_h * 0.20)
    d.rounded_rectangle((cal_x, cal_y, cal_x + cal_w, cal_y + hdr_h),
                         radius=int(inner * 0.05), fill=CAL_HEADER)
    # mask bottom of header to flat
    d.rectangle((cal_x, cal_y + hdr_h - int(inner * 0.05),
                 cal_x + cal_w, cal_y + hdr_h), fill=CAL_HEADER)

    # binder rings
    ring_y = cal_y - int(inner * 0.02)
    ring_r = max(2, int(inner * 0.025))
    inner_ring_r = max(1, ring_r - 2)
    for rx_frac in (0.30, 0.70):
        rx = cal_x + int(cal_w * rx_frac)
        d.ellipse((rx - ring_r, ring_y - ring_r, rx + ring_r, ring_y + ring_r),
                  fill=(90, 90, 90, 255))
        d.ellipse((rx - inner_ring_r, ring_y - inner_ring_r,
                   rx + inner_ring_r, ring_y + inner_ring_r),
                  fill=(160, 160, 160, 255))

    # date number (today feel)
    font_main = None
    font_label = None
    try:
        # Try a clean sans
        font_path = r"C:\Windows\Fonts\segoeuib.ttf"
        if os.path.exists(font_path):
            font_main = ImageFont.truetype(font_path, int(inner * 0.32))
        font_path_l = r"C:\Windows\Fonts\segoeuib.ttf"
        if os.path.exists(font_path_l):
            font_label = ImageFont.truetype(font_path_l, int(inner * 0.07))
    except Exception:
        pass
    if font_main is None:
        font_main = ImageFont.load_default()
    if font_label is None:
        font_label = ImageFont.load_default()

    num = "29"
    bbox = d.textbbox((0, 0), num, font=font_main)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    d.text((cal_x + (cal_w - tw) / 2 - bbox[0],
            cal_y + hdr_h + (cal_h - hdr_h - th) / 2 - bbox[1] - int(inner * 0.02)),
           num, fill=CAL_TEXT, font=font_main)

    # month label inside header
    month = "JUL"
    bbox2 = d.textbbox((0, 0), month, font=font_label)
    d.text((cal_x + (cal_w - (bbox2[2] - bbox2[0])) / 2 - bbox2[0],
            cal_y + (hdr_h - (bbox2[3] - bbox2[1])) / 2 - bbox2[1] - int(inner * 0.01)),
           month, fill=WHITE, font=font_label)

    # small grid dots below number
    grid_y = cal_y + cal_h - int(inner * 0.08)
    for i in range(5):
        cx = cal_x + int(cal_w * (0.2 + 0.15 * i))
        d.ellipse((cx - 2, grid_y - 2, cx + 2, grid_y + 2), fill=CAL_GRID)

    return img


def main():
    # Web icons
    web = os.path.join(ROOT, "web", "icons")
    os.makedirs(web, exist_ok=True)
    draw_icon(192).save(os.path.join(web, "Icon-192.png"))
    draw_icon(512).save(os.path.join(web, "Icon-512.png"))
    draw_icon(192, maskable=True).save(os.path.join(web, "Icon-maskable-192.png"))
    draw_icon(512, maskable=True).save(os.path.join(web, "Icon-maskable-512.png"))

    # Android launcher icons (square, no maskable safe area needed in mipmap)
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    android_res = os.path.join(ROOT, "android", "app", "src", "main", "res")
    for folder, sz in android_sizes.items():
        out = os.path.join(android_res, folder, "ic_launcher.png")
        draw_icon(sz).save(out)

    # macOS app icons
    mac_sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    mac_dir = os.path.join(ROOT, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    for name, sz in mac_sizes.items():
        draw_icon(sz).save(os.path.join(mac_dir, name))

    # Windows runner icons (use 256)
    win_icons = os.path.join(ROOT, "windows", "runner", "resources")
    if os.path.isdir(win_icons):
        for name in ("app_icon.ico",):
            # ICO with multiple sizes
            base = draw_icon(256)
            base.save(os.path.join(win_icons, name), format="ICO",
                      sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

    print("Icons generated.")


if __name__ == "__main__":
    main()
