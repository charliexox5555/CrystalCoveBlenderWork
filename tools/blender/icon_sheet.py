"""Contact sheet: transparent icons composited over a tile colour in a grid, for side-by-side checks.
    Blender -b --factory-startup -P tools/blender/icon_sheet.py -- <out.png> <cell px> <columns> <bg hex> <icon.png> ...
"""
import sys

import bpy
import numpy as np

args = sys.argv[sys.argv.index("--") + 1 :]
out, cell, cols, bg = args[0], int(args[1]), int(args[2]), args[3]
paths = args[4:]
rows = (len(paths) + cols - 1) // cols
gap = 4
W, H = cols * cell + (cols + 1) * gap, rows * cell + (rows + 1) * gap
srgb = np.array([int(bg[i : i + 2], 16) / 255 for i in (0, 2, 4)])
sheet = np.ones((H, W, 4), dtype=np.float32)
sheet[:, :, :3] = srgb
for n, path in enumerate(paths):
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "Non-Color"  # keep the file's sRGB bytes as they are
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    # nearest-neighbour fit into the cell (icons are square)
    idx = (np.arange(cell) * (w / cell)).astype(int)
    px = px[idx][:, idx]
    r, c = divmod(n, cols)
    y0 = H - (r + 1) * (cell + gap)  # Blender images are bottom-up
    x0 = gap + c * (cell + gap)
    region = sheet[y0 : y0 + cell, x0 : x0 + cell]
    a = px[:, :, 3:4]
    region[:, :, :3] = px[:, :, :3] * a + region[:, :, :3] * (1 - a)
    bpy.data.images.remove(img)
result = bpy.data.images.new("sheet", W, H, alpha=True)
result.colorspace_settings.name = "Non-Color"
result.pixels.foreach_set(sheet.ravel())
result.filepath_raw = out
result.file_format = "PNG"
result.save()
print("SHEET", out, W, H)
