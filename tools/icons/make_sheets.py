"""Packs the 512 px item icons into small sprite sheets for small slots (reels, pick-any tiles, reward cells).

    /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/icons/make_sheets.py

One sheet per group: Glassies, and Cosmetics (Rideables, Finishers, Machines). CELL px per icon on a COLUMNS-wide
grid; each icon is scaled to CELL - 2 * PAD and centred, so filtering never bleeds a neighbour into a cell.
Writes assets/icons/items/sheets/<sheet>.png, sheets/layout.json ({"<sheet>": {"Cell", "Columns", "Width",
"Height", "Items": {"<Category>/<id>": index}}}) and sheets/upload_list.json for tools/opencloud/upload_assets.py.
Roblox's guidance: small UI images, and sprite sheets for many small icons (docs/testing/loading/REPORT.md).
"""
import json
import os

import bpy
import numpy as np

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(REPO, "assets/icons/items/512")
OUT = os.path.join(REPO, "assets/icons/items/sheets")
CELL, PAD, COLUMNS = 128, 2, 8
SHEETS = {"Glassies": ("glassies",), "Cosmetics": ("rideables", "finishers", "machines")}
CATEGORY = {"glassies": "Glassies", "rideables": "Rideables", "finishers": "Finishers", "machines": "Machines"}


def item_key(name):
    prefix, rest = name[:-4].split("_", 1)
    if prefix == "machines":  # machines_Glassies_Coins -> Glassies:Coins
        rest = rest.replace("_", ":", 1)
    return CATEGORY[prefix], rest


def icon_pixels(path, size):
    image = bpy.data.images.load(path)
    image.scale(size, size)
    pixels = np.empty(size * size * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    bpy.data.images.remove(image)
    return pixels.reshape(size, size, 4)  # rows bottom-up, straight alpha


def main():
    os.makedirs(OUT, exist_ok=True)
    layout, uploads = {}, []
    files = sorted(f for f in os.listdir(SRC) if f.endswith(".png"))
    for sheet, prefixes in SHEETS.items():
        names = [f for f in files if f.split("_", 1)[0] in prefixes]
        rows = (len(names) + COLUMNS - 1) // COLUMNS
        width, height = COLUMNS * CELL, rows * CELL
        atlas = np.zeros((height, width, 4), dtype=np.float32)
        items = {}
        inner = CELL - 2 * PAD
        for index, name in enumerate(names):
            col, row = index % COLUMNS, index // COLUMNS
            top = row * CELL + PAD  # from the top of the image
            y0 = height - top - inner  # Blender rows count from the bottom
            x0 = col * CELL + PAD
            atlas[y0 : y0 + inner, x0 : x0 + inner] = icon_pixels(os.path.join(SRC, name), inner)
            category, item = item_key(name)
            items[f"{category}/{item}"] = index
        image = bpy.data.images.new(f"sheet_{sheet}", width, height, alpha=True)
        image.pixels.foreach_set(atlas.ravel())
        path = os.path.join(OUT, f"{sheet.lower()}.png")
        image.filepath_raw = path
        image.file_format = "PNG"
        image.save()
        layout[sheet] = {"Cell": CELL, "Columns": COLUMNS, "Width": width, "Height": height, "Items": items}
        uploads.append({"Key": f"sheet/{sheet.lower()}", "Path": os.path.relpath(path, REPO), "Type": "Decal",
                        "Name": f"GC icon sheet {sheet.lower()}"})
        print(f"{sheet}: {len(names)} icons -> {width}x{height} {path}")
    with open(os.path.join(OUT, "layout.json"), "w") as f:
        json.dump(layout, f, indent=1, sort_keys=True)
    with open(os.path.join(OUT, "upload_list.json"), "w") as f:
        json.dump({"Record": "assets/icons/items/sheets/roblox_assets.json", "Items": uploads}, f, indent=1)


main()
