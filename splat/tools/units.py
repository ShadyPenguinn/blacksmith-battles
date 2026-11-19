"""Renders and packs the fighters for the battlefield: every weapon, for heroes and for foes, from art/toy-unit.js.
Each (weapon, side) is drawn as one ink-studio sheet of all its frames against a flat magenta backdrop, cut out
here by that colour, and packed into ../units.png with ../units.json (where each frame is and where its feet are).
Also renders the open field they fight on (art/toy-field.js) to ../field.png.
Usage: python3 splat/tools/units.py"""
import json, os, subprocess
from concurrent.futures import ThreadPoolExecutor
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..')
CLI = os.path.join(ROOT, '..', 'forge-splat-test', 'addons', 'splats', 'tools', 'ink-studio', 'cli', 'ink-studio.js')
FR = os.path.join(HERE, 'frames', 'units')
os.makedirs(FR, exist_ok=True)
ARCHS = ['Sword', 'Axe', 'Spear', 'Bow', 'Staff', 'Shield', 'Warhammer', 'Grimoire']
SIDES = ['hero', 'foe']
# the clip in art/toy-unit.js: idle 0-1, walk 1-2, attack 2-2.6, hurt 3-3.3, down 4-4.5
SEG = {
    'idle': [0, 0.25, 0.5, 0.75],
    'walk': [1, 1.1667, 1.3333, 1.5, 1.6667, 1.8333],
    'atk': [2.0, 2.15, 2.27, 2.33, 2.4, 2.5],
    'hurt': [3.15],
    'down': [4.12, 4.28, 4.5],
}
TS = [t for v in SEG.values() for t in v]
CELL, PX, TOP = 192, 2, 8  # sheet cell (image px), art-pixel size, art rows under the sheet's time label


def sheet(job):
    arch, side = job
    out = os.path.join(FR, f'{arch}-{side}.png')
    env = {**os.environ, 'UNIT_ARCH': arch, 'UNIT_SIDE': side}
    subprocess.run(['node', CLI, 'sheet', os.path.join(ROOT, 'art', 'toy-unit.js'), '--t', ','.join(map(str, TS)),
                    '--cols', str(len(TS)), '--clean', '--px', str(PX), '--tone', 'off', '--zoom', '1.8', '--target', '0,0.85,0', '--w', str(CELL), '--h', str(CELL),
                    '--out', out], env=env, check=True, stdout=subprocess.DEVNULL)
    return out


jobs = [(a, s) for a in ARCHS for s in SIDES]
with ThreadPoolExecutor(4) as ex:
    paths = list(ex.map(sheet, jobs))

frames = {}  # name -> rgba (art pixels), cell offset
for (arch, side), p in zip(jobs, paths):
    im = np.asarray(Image.open(p).convert('RGB'))[::PX, ::PX].astype(int)
    c = CELL // PX
    key = im[c - 2, 2]  # the backdrop, from a corner clear of the label
    for i, t in enumerate(TS):
        a = im[:, i * c:(i + 1) * c].copy()
        m = np.abs(a - key).sum(2) > 60
        m[:TOP] = False
        frames[(arch, side, i)] = (a, m)

# one box for all of a fighter's frames keeps the feet still; the atlas stores each frame cropped to its own pixels
names, items = [], []
for (arch, side, i), (a, m) in frames.items():
    ys, xs = np.nonzero(m)
    if not len(xs):
        continue
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    rgba = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    rgba[..., :3] = a[y0:y1, x0:x1]
    rgba[..., 3] = m[y0:y1, x0:x1] * 255
    names.append(f'{arch}-{side}-{i}')
    items.append((rgba, int(x0), int(y0)))

# the feet: the lowest row of the first idle frame of a Sword hero, and its middle there
a, m = frames[('Sword', 'hero', 0)]
ys, xs = np.nonzero(m)
foot_y = int(ys.max()) + 1
body = xs[ys >= foot_y - 10]
foot_x = int(round(np.median(body)))

# shelf-pack, tallest first
order = sorted(range(len(items)), key=lambda k: -items[k][0].shape[0])
W, x, y, row, pos = 1024, 0, 0, 0, {}
for k in order:
    h, w = items[k][0].shape[:2]
    if x + w > W:
        x, y, row = 0, y + row + 1, 0
    pos[k] = (x, y)
    x += w + 1
    row = max(row, h)
H = y + row
atlas = np.zeros((H, W, 4), np.uint8)
sprites = {}
for k, (rgba, ox, oy) in enumerate(items):
    ax, ay = pos[k]
    h, w = rgba.shape[:2]
    atlas[ay:ay + h, ax:ax + w] = rgba
    sprites[names[k]] = [ax, ay, w, h, ox, oy]
Image.fromarray(atlas, 'RGBA').save(os.path.join(ROOT, 'units.png'), optimize=True)
seg, n = {}, 0
for k, v in SEG.items():
    seg[k] = list(range(n, n + len(v)))
    n += len(v)
json.dump({'cell': CELL // PX, 'foot': [foot_x, foot_y], 'seg': seg, 'archs': ARCHS, 'sprites': sprites},
          open(os.path.join(ROOT, 'units.json'), 'w'), separators=(',', ':'))
print(f'units: {len(sprites)} frames, atlas {W}x{H}, feet at {foot_x},{foot_y}')

# the open field behind them (art/toy-field.js), stored at art-pixel size
bgp = os.path.join(FR, 'field.png')
subprocess.run(['node', CLI, 'render', os.path.join(ROOT, 'art', 'toy-field.js'), '--clean', '--px', str(PX), '--tone', 'off',
                '--zoom', '1.0', '--target', '0,1.6,0', '--w', '960', '--h', '420', '--out', bgp], check=True, stdout=subprocess.DEVNULL)
Image.fromarray(np.asarray(Image.open(bgp).convert('RGB'))[::PX, ::PX]).save(os.path.join(ROOT, 'field.png'), optimize=True)
print('field: 480x210')
