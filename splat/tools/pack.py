"""Packs the frames from render.js into ../<scene>.png (one atlas) and ../<scene>.json (where each sprite is).
Each layer is stored as the pixels that differ from the empty room (bg), cropped to their box, so the
whole scene is one background plus small cut-outs. Usage: python3 splat/tools/pack.py forge|mine"""
import json, os, sys
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
NAME = sys.argv[1]
FR = os.path.join(HERE, 'frames', NAME)
OUT = os.path.join(HERE, '..')
meta = json.load(open(os.path.join(FR, 'jobs.json')))
PX = 2

def load(name):
    a = np.asarray(Image.open(os.path.join(FR, name + '.png')).convert('RGB'))
    s = a[::PX, ::PX]
    assert (np.repeat(np.repeat(s, PX, 0), PX, 1) == a).mean() > 0.995, name + ': not on the art-pixel grid'
    return s

bg = load('bg')
H, W = bg.shape[:2]
sprites = {}  # name -> RGBA crop, offset
def cut(name, base=bg):
    a = load(name)
    m = (a != base).any(2)
    ys, xs = np.nonzero(m)
    if not len(xs):
        return None
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    rgba = np.zeros((y1 - y0, x1 - x0, 4), np.uint8)
    rgba[..., :3] = a[y0:y1, x0:x1]
    rgba[..., 3] = m[y0:y1, x0:x1] * 255
    return rgba, int(x0), int(y0)

items = [('bg', (np.dstack([bg, np.full(bg.shape[:2], 255, np.uint8)]), 0, 0))]
for n in meta['jobs']:
    if n in ('bg', 'hit-a', 'hit-b'):
        continue
    c = cut(n)
    if c:
        items.append((n, c))

# shelf packing into a fixed-width atlas
AW = 1024
x = y = rowh = 0
place = {}
for n, (img, ox, oy) in sorted(items, key=lambda it: -it[1][0].shape[0]):
    h, w = img.shape[:2]
    if x + w > AW:
        x, y, rowh = 0, y + rowh + 1, 0
    place[n] = (x, y, w, h, ox, oy)
    x += w + 1
    rowh = max(rowh, h)
AH = y + rowh
atlas = np.zeros((AH, AW, 4), np.uint8)
for n, (img, ox, oy) in items:
    px, py, w, h, _, _ = place[n]
    atlas[py:py + h, px:px + w] = img
im = Image.fromarray(atlas, 'RGBA')
# palette PNG: the art uses only a few dozen colours
q = im.quantize(colors=255, method=Image.FASTOCTREE)
back = np.asarray(q.convert('RGBA'))
if (back[..., 3] == atlas[..., 3]).all():
    q.save(os.path.join(OUT, NAME + '.png'), optimize=True)
else:  # too many colours for a clean palette: keep full RGBA
    im.save(os.path.join(OUT, NAME + '.png'), optimize=True)

def box_of(a, b):
    m = (load(a) != load(b)).any(2)
    ys, xs = np.nonzero(m)
    return [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]

out = {
    'w': W, 'h': H, 'sprites': {n: list(map(int, v)) for n, v in place.items()},  # name: [atlas x, atlas y, w, h, x, y]
    'loops': meta['loops'], 'seg': meta['seg'], 'variants': meta['variants'],
    'props': meta.get('props', []),
}
if 'hit-a' in meta['jobs']:
    out['hit_box'] = box_of('hit-a', 'hit-b')
for k, names in meta['loops'].items():
    out[k + '_box'] = box_of(names[0], 'bg')
json.dump(out, open(os.path.join(OUT, NAME + '.json'), 'w'), separators=(',', ':'))
print(NAME, 'art', W, H, 'atlas', AW, AH, 'sprites', len(place), 'png', os.path.getsize(os.path.join(OUT, NAME + '.png')), {k: v for k, v in out.items() if k.endswith('_box')})
