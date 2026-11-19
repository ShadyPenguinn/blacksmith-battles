# Splat scenes for the toy's world strip

The Mine and Forge spots in the sliding strip at the top of the toy draw ink-studio splat art instead of
placeholder shapes. The art is pre-rendered, so the page only plays sprites on a 2D canvas: about 80 KB in all,
no WebGL, fine on older tablets. If the files fail to load, the old shapes stay.

- `art/toy-forge.js`, `art/toy-mine.js`: the ink-studio scenes (a grand forge hall with a slim smith; a lantern-lit cavern with a miner).
- `tools/render.js <forge|mine>`: renders every frame with the ink-studio CLI vendored in `forge-splat-test/addons/splats/tools/ink-studio`.
- `tools/pack.py <forge|mine>`: keeps only the pixels each frame changes against the empty room, and packs them into `<scene>.png` + `<scene>.json`.
- `splat-scenes.js`: plays them. The toy calls `SPLAT.mine.swing()` on each Mine ore tap, and `SPLAT.forge.start(arch)`, `.hit('P'|'G'|'M'|'O')`, `.finish()` from the forge minigame.

To change the art: edit a scene, then `node splat/tools/render.js forge && python3 splat/tools/pack.py forge` (needs Node, Python with Pillow and NumPy).
