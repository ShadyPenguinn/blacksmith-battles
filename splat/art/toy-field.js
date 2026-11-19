// Blacksmith Battles: Fight, an open field on a bright afternoon. A wide meadow with a worn dirt track running across it,
// rolling green hills and a far blue range behind, a few trees and boulders at the edges, tufts and wildflowers in the grass.
// Seen side on, so the fighters (art/toy-unit.js, drawn by the toy) march along the track from left to right.
// No actors and no clip: the toy draws the armies, their bars and their blows on top of this backdrop.
module.exports = ({ makeBuilder, makeSculpt, KIT: K }) => {
  const PAL = [
    0x0a0c10, 0x1a2018, // 0-1 deep shade
    0x5aa0e0, 0x7ab8ec, 0x9ccef2, 0xc4e2f6, 0xe6f2f8, // 2-6 sky, high to low
    0x5a6a9a, 0x7a88b4, 0x9aa8cc, // 7-9 far range
    0x2e5a2a, 0x3e7434, 0x528c3e, 0x6aa448, 0x8abc58, // 10-14 grass, dark to light
    0x6a4e30, 0x8a6a44, 0xa88a5c, 0xc4a878, // 15-18 dirt track
    0x3a2a1c, 0x5a4028, // 19-20 bark
    0x1e4a24, 0x2a6430, 0x3a7e3a, 0x58a048, // 21-24 leaves
    0x5a5a60, 0x7a7a80, 0x9c9ca2, // 25-27 stone
    0xf0e070, 0xe87a8a, 0xf4f4f0, 0x9a7ae0, // 28-31 flowers
    0xffffff // 32 cloud
  ];
  function build(seed) {
    const B = makeBuilder(seed, PAL);
    const S = K.sculpt(makeSculpt(B));
    const r = (() => { let s = 7; return () => ((s = (s * 16807) % 2147483647) / 2147483647); })();
    S.sun = B.norm([0.3, 0.8, 0.55]);
    S.res = 0.08;
    S.amb = 0.34;
    S.sky = 0.3;
    const GRASS = { r: [0, 10, 11, 12, 13, 14] }, DIRT = { r: [0, 15, 16, 17, 18] }, BARK = { r: [0, 19, 20] };
    const LEAF = { r: [0, 21, 22, 23, 24] }, STONE = { r: [0, 25, 26, 27] };

    // ---- the sky, high to low, and a few flat clouds ----
    for (const [y, h, c] of [[0.6, 1.6, 6], [2.6, 0.6, 5], [3.8, 0.7, 4], [5.2, 0.8, 3], [7.5, 1.6, 2]]) S.box([0, y, -16], [32, h, 0.2], { r: [c], em: true }, { res: 0.16 });
    for (const [x, y, w] of [[-9, 5.4, 2.4], [-2.5, 6.0, 1.6], [5, 5.6, 2.8], [11, 6.2, 1.8], [-14, 6.4, 1.4]]) {
      S.ball([x, y, -15.5], [w, 0.32, 0.2], { r: [5, 6, 32], em: true }, { res: 0.12 });
      S.ball([x + w * 0.3, y + 0.25, -15.4], [w * 0.5, 0.3, 0.2], { r: [6, 32], em: true }, { res: 0.12 });
    }
    // the far blue range
    for (const [x, h, w] of [[-13, 3.6, 5], [-6, 2.6, 4], [0, 3.2, 5], [7, 2.4, 4], [13, 3.4, 5]]) S.ball([x, 0, -14], [w, h, 0.6], { r: [7, 8, 9] }, { res: 0.14 });
    S.bake();
    // rolling green hills, two layers
    for (const [x, h, w, z] of [[-11, 1.8, 6, -11], [-2, 1.4, 6, -11.5], [8, 1.9, 7, -11], [15, 1.3, 5, -11.5]]) S.ball([x, -0.2, z], [w, h, 1.2], { r: [0, 10, 11, 12] }, { res: 0.12 });
    for (const [x, h, w] of [[-7, 0.9, 6], [4, 1.1, 7], [13, 0.8, 5], [-15, 0.8, 4]]) S.ball([x, -0.2, -8], [w, h, 1.0], { r: [0, 11, 12, 13] }, { res: 0.1 });
    // the meadow and the track across it
    S.box([0, -0.25, -1.5], [26, 0.25, 8], GRASS, { res: 0.09 });
    S.box([0, 0.01, 0.0], [26, 0.02, 0.55], DIRT, { res: 0.05 });
    S.bake();
    // far trees along the hill line
    for (let i = 0; i < 14; i++) {
      const x = -17 + i * 2.6 + r() * 1.2, z = -6.5 - r() * 1.2, h = 0.9 + r() * 0.6;
      if (Math.abs(x) < 2) continue;
      S.tube([[x, 0, z], [x, h, z]], 0.06, 0.05, BARK, { res: 0.05 });
      S.ball([x, h + 0.35, z], [0.45 + r() * 0.2, 0.55, 0.4], LEAF, { res: 0.06 });
    }
    // near trees at the edges of the field
    for (const [x, z, h] of [[-9.2, -2.6, 2.2], [-7.8, -3.4, 1.7], [8.6, -2.4, 2.4], [10.4, -3.2, 1.9]]) {
      S.tube([[x, 0, z], [x + 0.05, h, z]], 0.13, 0.09, BARK, { res: 0.03 });
      S.tube([[x, h * 0.6, z], [x + 0.4, h * 0.85, z + 0.1]], 0.05, 0.03, BARK, { res: 0.025 });
      S.ball([x, h + 0.4, z], [0.95, 0.75, 0.8], LEAF, { res: 0.05 });
      S.ball([x + 0.5, h + 0.15, z + 0.2], [0.6, 0.5, 0.55], LEAF, { res: 0.05 });
      S.ball([x - 0.5, h + 0.2, z + 0.1], [0.55, 0.45, 0.5], LEAF, { res: 0.05 });
    }
    // boulders
    for (const [x, z, s] of [[-6.2, -1.6, 0.35], [-5.7, -1.4, 0.18], [6.6, -1.8, 0.4], [3.5, -3.6, 0.22], [-3.2, -4.2, 0.25]]) S.ball([x, s * 0.5, z], [s * 1.3, s, s], STONE, { res: 0.03 });
    S.bake();
    // tufts and wildflowers through the meadow, kept off the track
    for (let i = 0; i < 220; i++) {
      const x = -16 + r() * 32, z = -5.5 + r() * 9.5;
      if (Math.abs(z) < 0.7) continue;
      const h = 0.08 + r() * 0.1;
      S.ball([x, h * 0.5, z], [0.07, h, 0.05], { r: [0, 11, 13, 14] }, { res: 0.02 });
      if (r() < 0.22) S.ball([x + 0.05, h + 0.03, z + 0.02], 0.03, { r: [[28, 29, 30, 31][i % 4]] }, { res: 0.015 });
    }
    // pebbles along the track
    for (let i = 0; i < 40; i++) S.ball([-16 + r() * 32, 0.03, -0.5 + r() * 1.0], [0.04, 0.025, 0.03], STONE, { res: 0.012 });
    S.bake();
    return B.finish({ cam: { target: [0, 0.75, 0], dist: 9, pitch: 0.2, yaw: 0 }, detail: 26, dither: 0.3, radius: 4 });
  }
  return { id: 'toy-field', name: 'Fight: the open field', seed: 11, build };
};
