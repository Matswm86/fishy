"""Bake the original Fishy (XGen Studios, 2003) SWF exports into Godot sprite sheets.

Input: a JPEXS FFDec export of Fishy.swf at zoom 4 (sprites, shapes, buttons),
rendered screen overlays (frames 13-19 of a copy of the SWF with every
dynamic object removed), and a bounds table computed from the SWF XML.

Output: assets/gfx/*.png sheets and scripts/atlas_data.gd, a const dictionary
the game reads for frame counts, grid layout and registration offsets.

Usage: python3 tools/bake_assets.py <export_dir>
"""

import json
import sys
from pathlib import Path

from PIL import Image

MAX_TEX = 4096
# Drawn on the black intro stage, so stored flattened as JPEG to stay small.
JPEG_ON_BLACK = {"intro_x"}
SRC_ZOOM = 4.0

ROOT = Path(__file__).resolve().parent.parent
GFX = ROOT / "assets" / "gfx"

# name: (kind, id, zoom, frames-or-None, recolor)
#   kind "sprite" -> <export>/x4/sprites/DefineSprite_<id>/<n>.png
#   kind "shape"  -> <export>/x4/shapes/<id>.png
#   kind "button" -> <export>/x4/buttons/DefineButton2_<id>/1_up.png
#   kind "stage"  -> <export>/ov/<id>.png (full 550x400 stage render)
ASSETS = {
    "bg": ("shape", 132, 3.0, None),
    "sand_menu": ("shape", 145, 3.0, None),
    "sand_game": ("shape", 186, 3.0, None),
    "win_bg": ("shape", 226, 3.0, None),
    "player": ("sprite", 179, 4.0, None),
    "enemy": ("sprite", 192, 2.0, None),
    "bubble": ("sprite", 201, 4.0, None),
    "pbone": ("sprite", 205, 4.0, None),
    "bone": ("sprite", 207, 4.0, None),
    "soul": ("shape", 208, 1.5, "white"),
    "plant_a": ("sprite", 138, 1.5, None),
    "plant_b": ("sprite", 144, 1.5, None),
    "letter_1": ("sprite", 154, 3.0, (58, 150, 213)),
    "letter_2": ("sprite", 156, 3.0, (58, 150, 213)),
    "letter_3": ("sprite", 158, 3.0, (58, 150, 213)),
    "letter_4": ("sprite", 160, 3.0, (58, 150, 213)),
    "letter_5": ("sprite", 162, 3.0, (58, 150, 213)),
    "letter_6": ("sprite", 164, 3.0, (58, 150, 213)),
    "letter_7": ("sprite", 165, 3.0, (58, 150, 213)),
    "intro_text": ("sprite", 117, 2.0, None),
    "intro_x": ("sprite", 128, 0.5, None),
    "sound": ("sprite", 197, 4.0, None),
    "quality": ("button", 199, 4.0, None),
    "ov_title": ("stage", 13, 3.0, None),
    "ov_instructions": ("stage", 14, 3.0, None),
    "ov_gulp": ("stage", 16, 3.0, None),
    "ov_again": ("stage", 17, 3.0, None),
    "ov_scores": ("stage", 18, 3.0, None),
    "ov_win": ("stage", 19, 3.0, None),
}


def load_frames(export: Path, kind: str, cid: int) -> list[Image.Image]:
    if kind == "sprite":
        d = export / "x4" / "sprites" / f"DefineSprite_{cid}"
        n = len(list(d.glob("*.png")))
        return [Image.open(d / f"{i}.png").convert("RGBA") for i in range(1, n + 1)]
    if kind == "shape":
        return [Image.open(export / "x4" / "shapes" / f"{cid}.png").convert("RGBA")]
    if kind == "button":
        p = export / "x4" / "buttons" / f"DefineButton2_{cid}" / "1_up.png"
        return [Image.open(p).convert("RGBA")]
    return [Image.open(export / "ov" / f"{cid}.png").convert("RGBA")]


def recolor(im: Image.Image, mode) -> Image.Image:
    if mode is None:
        return im
    rgb = (255, 255, 255) if mode == "white" else mode
    solid = Image.new("RGBA", im.size, rgb + (255,))
    solid.putalpha(im.getchannel("A"))
    return solid


def bake(export: Path, bounds: dict) -> dict:
    GFX.mkdir(parents=True, exist_ok=True)
    meta = {}
    for name, (kind, cid, zoom, mode) in ASSETS.items():
        frames = [recolor(f, mode) for f in load_frames(export, kind, cid)]
        sizes = {f.size for f in frames}
        if len(sizes) != 1:
            raise ValueError(f"{name}: frame sizes differ {sizes}")
        w, h = frames[0].size
        k = zoom / SRC_ZOOM
        fw, fh = max(1, round(w * k)), max(1, round(h * k))
        cols = max(1, min(len(frames), MAX_TEX // fw))
        rows = (len(frames) + cols - 1) // cols
        if rows * fh > MAX_TEX:
            raise ValueError(f"{name}: sheet {cols * fw}x{rows * fh} exceeds {MAX_TEX}")
        sheet = Image.new("RGBA", (cols * fw, rows * fh), (0, 0, 0, 0))
        for i, f in enumerate(frames):
            f = f.resize((fw, fh), Image.LANCZOS)
            sheet.paste(f, ((i % cols) * fw, (i // cols) * fh))
        if name in JPEG_ON_BLACK:
            flat = Image.new("RGB", sheet.size, (0, 0, 0))
            flat.paste(sheet, (0, 0), sheet)
            flat.save(GFX / f"{name}.jpg", quality=88)
        else:
            sheet.save(GFX / f"{name}.png", optimize=True)
        # Registration: local-unit bounds min, when known; else centre the image.
        b = bounds.get(str(cid)) if kind in ("sprite", "shape") else None
        if kind == "stage":
            ox, oy = 0.0, 0.0
        elif b:
            ox, oy = b[0] * zoom, b[2] * zoom
        else:
            ox, oy = -fw / 2.0, -fh / 2.0
        meta[name] = {
            "frames": len(frames),
            "cols": cols,
            "rows": rows,
            "zoom": zoom,
            "ox": round(ox, 2),
            "oy": round(oy, 2),
        }
        print(f"{name:16s} {len(frames):4d}f {fw}x{fh} grid {cols}x{rows}")
    return meta


def write_gd(meta: dict) -> None:
    lines = [
        "# Generated by tools/bake_assets.py. Do not edit by hand.",
        "extends RefCounted",
        "",
        "const ATLAS := {",
    ]
    for name, m in meta.items():
        lines.append(
            f'\t"{name}": {{"frames": {m["frames"]}, "cols": {m["cols"]}, '
            f'"rows": {m["rows"]}, "zoom": {m["zoom"]}, '
            f'"ox": {m["ox"]}, "oy": {m["oy"]}}},'
        )
    lines.append("}")
    (ROOT / "scripts" / "atlas_data.gd").write_text("\n".join(lines) + "\n")


def main() -> None:
    export = Path(sys.argv[1]).expanduser()
    bounds = json.loads((export / "bounds.json").read_text())
    write_gd(bake(export, bounds))


if __name__ == "__main__":
    main()
