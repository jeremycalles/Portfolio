#!/usr/bin/env python3
"""Generate app icon sizes from a source image with transparent background."""
from pathlib import Path
from PIL import Image

SRC = Path("/Users/jcalles/.cursor/projects/Users-jcalles-github-PortfolioMultiplatform/assets/image-0df30865-3908-4db0-b81c-4bba4cb06804.png")
OUT_DIR = Path(__file__).resolve().parent.parent / "Shared/Assets.xcassets/AppIcon.appiconset"

# (pixel_size, [filenames])
SIZES = [
    (20, ["icon-20.png"]),
    (40, ["icon-20@2x.png", "icon-20@2x-ipad.png"]),
    (60, ["icon-20@3x.png"]),
    (29, ["icon-29.png"]),
    (58, ["icon-29@2x.png", "icon-29@2x-ipad.png"]),
    (87, ["icon-29@3x.png"]),
    (40, ["icon-40.png"]),
    (80, ["icon-40@2x.png", "icon-40@2x-ipad.png"]),
    (120, ["icon-40@3x.png"]),
    (120, ["icon-60@2x.png"]),
    (180, ["icon-60@3x.png"]),
    (76, ["icon-76.png"]),
    (152, ["icon-76@2x.png"]),
    (167, ["icon-83.5@2x.png"]),
    (1024, ["icon-1024.png"]),
    (16, ["icon-mac-16.png"]),
    (32, ["icon-mac-16@2x.png", "icon-mac-32.png"]),
    (64, ["icon-mac-32@2x.png"]),
    (128, ["icon-mac-128.png"]),
    (256, ["icon-mac-128@2x.png", "icon-mac-256.png"]),
    (512, ["icon-mac-256@2x.png", "icon-mac-512.png"]),
    (1024, ["icon-mac-512@2x.png"]),
]


def make_background_transparent(img: Image.Image, threshold: int = 235) -> Image.Image:
    """Replace light gray/white background with transparency."""
    img = img.convert("RGBA")
    data = img.getdata()
    new_data = []
    for item in data:
        r, g, b, a = item
        if r >= threshold and g >= threshold and b >= threshold:
            new_data.append((r, g, b, 0))
        else:
            new_data.append(item)
    img.putdata(new_data)
    return img


def main():
    out_dir = OUT_DIR
    out_dir.mkdir(parents=True, exist_ok=True)
    im = Image.open(SRC).convert("RGB")
    w, h = im.size
    if w != h:
        s = min(w, h)
        left = (w - s) // 2
        top = (h - s) // 2
        im = im.crop((left, top, left + s, top + s))
    im = make_background_transparent(im)
    # Dedupe by size so we only resize once per pixel size
    seen_size = {}
    for size, filenames in SIZES:
        if size not in seen_size:
            resized = im.resize((size, size), Image.Resampling.LANCZOS)
            seen_size[size] = resized
        for name in filenames:
            out_path = out_dir / name
            seen_size[size].save(out_path, "PNG")
            print(out_path)


if __name__ == "__main__":
    main()
