"""Export the exact grass outlines without opening or changing Blender scenes."""
import ast
import hashlib
import json
import math
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
source = (ROOT / 'tools/blender/build_sky_islands.py').read_text(encoding='utf-8')
tree = ast.parse(source)


class Vector(list):
    def __sub__(self, other):
        return Vector(a - b for a, b in zip(self, other))

    @property
    def length(self):
        return math.sqrt(sum(a * a for a in self))

    def lerp(self, other, alpha):
        return Vector(a + (b - a) * alpha for a, b in zip(self, other))


scope = {'math': math, 'random': random, 'Vector': Vector}
for node in tree.body:
    if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id in ('N', 'SPECS') for t in node.targets):
        scope[node.targets[0].id] = ast.literal_eval(node.value)
outline = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'outline')
exec(compile(ast.Module(body=[outline], type_ignores=[]), 'original_sky_outline', 'exec'), scope)
paths = {}
for name, width, length, exponent, seed, *_ in scope['SPECS']:
    rim = scope['outline'](width, length, exponent, seed)
    paths[name] = {'Size': [width, length], 'Points': [[round(p[0], 7), round(-p[1], 7)] for p in rim],
                   'NorthGate': name != 'Isle_Featured', 'SouthGate': name != 'Isle_Lobby'}
out = ROOT / 'assets/blender/map/sky/fence_paths.json'
out.write_text(json.dumps({'SourceSHA256': hashlib.sha256(source.encode()).hexdigest(), 'Islands': paths}, indent=2) + '\n', encoding='utf-8')
for filename in ('fit_island_fences.luau', 'verify_fences.luau'):
    target = ROOT / 'tools/studio' / filename
    if target.exists():
        text = target.read_text(encoding='utf-8')
        replacement = '-- BEGIN_GENERATED_RIMS\nlocal Paths = game:GetService("HttpService"):JSONDecode([==[' + json.dumps(paths, separators=(',', ':')) + ']==])\n-- END_GENERATED_RIMS'
        text, changed = re.subn(r'-- BEGIN_GENERATED_RIMS.*?-- END_GENERATED_RIMS', lambda _: replacement, text, count=1, flags=re.S)
        assert changed == 1, f'Generated markers missing in {target}'
        target.write_text(text, encoding='utf-8')
print(f'Exported exact grass rims: {len(paths)} islands, {sum(len(p["Points"]) for p in paths.values())} vertices')
