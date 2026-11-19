# Forge splat test

A phone test for live pixel-art Gaussian splats in Godot. Tap to put a hot piece on the anvil, tap again to slam; five slams finish a piece.
[godot-splats](https://github.com/xDavidLeon/godot-splats) addon (MIT, in `addons/splats/`), with an FPS readout.
Separate from the tablet toy at the site root.

Live at https://shadypenguinn.github.io/blacksmith-battles/forge-splat-test/web/ once on `main`.

- `art/forge-live.js`: the ink-studio scene (room + smith in one clip holding idle, raise, ready, slam and recover poses; the game picks the frame). `art/piece-*.js`: hot sword, axe and spear props for the anvil. Sparks are drawn by Godot (`sparks.gd`) because the addon only draws plain and boned splats.
- `splats/assets.json`: the asset manifest. `splats/forge.bytes` is the built asset (1 s hammer loop at 24 fps).

Rebuild the asset, then the web build (Godot 4.7 with the `web_nothreads_*` export templates):

```
cd forge-splat-test
node addons/splats/tools/build.js
godot --headless --path . --export-release "Web" web/index.html
```
