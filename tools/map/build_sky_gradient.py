"""Original seamless cubemap gradient for the Crystal Isles sky; no cloud props."""
from pathlib import Path
import math
from PIL import Image

out = Path(__file__).resolve().parents[2] / 'assets/sky/crystal_isles'
out.mkdir(parents=True, exist_ok=True)
stops = [(-1, (191, 221, 251)), (-.12, (191, 221, 251)),
         (0, (255, 224, 184)), (.16, (176, 208, 238)), (1, (76, 155, 234))]
for face in ('side', 'up', 'down'):
    image = Image.new('RGB', (256, 256))
    pixels = []
    for y in range(256):
        for x in range(256):
            u, v = 2 * (x + .5) / 256 - 1, 1 - 2 * (y + .5) / 256
            elevation = (v if face == 'side' else (1 if face == 'up' else -1)) / math.sqrt(1 + u*u + v*v)
            for (a, ca), (b, cb) in zip(stops, stops[1:]):
                if a <= elevation <= b:
                    t = (elevation-a)/(b-a)
                    t = t*t*(3-2*t)
                    pixels.append(tuple(round(ca[i]*(1-t)+cb[i]*t) for i in range(3)))
                    break
    image.putdata(pixels)
    image.save(out / (face + '.png'))
