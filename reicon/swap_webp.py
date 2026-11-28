#!/usr/bin/env python3
"""Swap Walletify launcher-icon WEBP entries inside a built APK with the new
glossy-black wallet icon. Only pixel content of known icon entries changes;
everything else stays byte-identical.

Usage: swap_webp.py IN.apk NEWDIR OUT.apk
NEWDIR holds fg432.png, mono432.png, round432.png (circle-masked master),
icon512.png (opaque square master over #07080D).

Classification (works for both the old silver-wallet assets and the new
glossy-black assets, so re-running is safe):
- square webp at 108/162/216/324/432: flat pure-white -> monochrome layer,
  anything else -> adaptive foreground layer.
- square webp at 48/72/96/144/192: transparent top-left corner -> round icon,
  opaque corner -> square legacy icon.
"""
import io
import sys
import zipfile

from PIL import Image

LAYER = {108, 162, 216, 324, 432}
LEGACY = {48, 72, 96, 144, 192}


def classify(name, data):
    if not name.endswith(".webp"):
        return None
    try:
        im = Image.open(io.BytesIO(data)).convert("RGBA")
    except Exception:
        return None
    w, h = im.size
    if w != h:
        return None
    hist = im.getchannel("A").histogram()
    opaque = sum(hist[128:]) / float(w * h)
    if w in LAYER and opaque < 0.6:
        rs = [p[0] for p in im.getdata() if p[3] > 128]
        if not rs:
            return None
        mean = sum(rs) / len(rs)
        var = sum((v - mean) ** 2 for v in rs) / len(rs)
        if mean > 235.0 and var < 25.0:
            return ("mono", w)
        return ("fg", w)
    if w in LEGACY and opaque > 0.5:
        corner = im.crop((0, 0, 4, 4)).getchannel("A")
        if sum(corner.getdata()) / 16.0 < 128:
            return ("round", w)
        return ("legacy", w)
    return None


def render(master, w, webp=True):
    im = master.resize((w, w), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "WEBP", lossless=True)
    return buf.getvalue()


def main():
    src, newdir, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    fg = Image.open(f"{newdir}/fg432.png").convert("RGBA")
    mono = Image.open(f"{newdir}/mono432.png").convert("RGBA")
    icon = Image.open(f"{newdir}/icon512.png").convert("RGBA")
    rnd = Image.open(f"{newdir}/round432.png").convert("RGBA")
    zin = zipfile.ZipFile(src)
    replacements = {}
    for name in zin.namelist():
        data = zin.read(name)
        kind = classify(name, data)
        if kind:
            replacements[name] = kind
    if not replacements:
        print(f"NO ICON ENTRIES FOUND in {src}", file=sys.stderr)
        sys.exit(1)
    with zipfile.ZipFile(dst, "w") as zout:
        for info in zin.infolist():
            data = zin.read(info.filename)
            if info.filename in replacements:
                kind, w = replacements[info.filename]
                master = {"fg": fg, "mono": mono, "legacy": icon, "round": rnd}[kind]
                data = render(master, w)
                print(f"swap {info.filename} <- {kind}-{w}")
            zi = zipfile.ZipInfo(info.filename, date_time=info.date_time)
            zi.compress_type = zipfile.ZIP_DEFLATED
            zi.external_attr = info.external_attr
            zout.writestr(zi, data)
    print(f"wrote {dst} ({len(replacements)} icon entries swapped)")


if __name__ == "__main__":
    main()
