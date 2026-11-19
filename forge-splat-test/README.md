# Forge splat test

A phone test for live pixel-art Gaussian splats in Godot. It shows the Blacksmith Battles forge diorama drawn every frame by the
[godot-splats](https://github.com/xDavidLeon/godot-splats) addon (MIT, in `addons/splats/`), with an FPS readout.
Separate from the tablet toy at the site root.

Live at https://shadypenguinn.github.io/blacksmith-battles/forge-splat-test/web/ once on `main`.

- `art/forge-live.js`: the ink-studio scene (the forge v2 diorama, with static flame tongues: the addon only draws plain and boned splats, so no animated flames or particles).
- `splats/assets.json`: the asset manifest. `splats/forge.bytes` is the built asset (1 s hammer loop at 24 fps).

Rebuild the asset, then the web build (Godot 4.7 with the `web_nothreads_*` export templates):

```
cd forge-splat-test
node addons/splats/tools/build.js
godot --headless --path . --export-release "Web" web/index.html
```
