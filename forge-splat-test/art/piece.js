// Hot pieces that sit on the anvil while forging, one prop each. Same world space as forge-live.js,
// so every prop is placed at the origin. Anvil face top is y 0.87, centre x 0.45, z 0.45.
module.exports = kind => ({ makeBuilder, makeSculpt, KIT: K }, opts = {}) => ({
  id: 'piece-' + kind,
  name: 'Hot ' + kind,
  seed: 3,
  build(seed) {
    const B = makeBuilder(seed, [0x07080b, 0x7a1810, 0xc8321e, 0xff6a20, 0xffb838, 0xfff0a0, 0x4a2e1e, 0x74482a]);
    const S = K.sculpt(makeSculpt(B));
    if (opts.sun) S.sun = B.norm(opts.sun);
    if (opts.onSculpt) opts.onSculpt(B, S);
    S.res = 0.015;
    const HOT = { r: [2, 3, 4, 4, 5] }, EDGE = { r: [1, 2, 3, 3] }, WHITE = { r: [5], em: true }, Y = 0.9, X = 0.5, Z = 0.45;
    if (kind === 'sword') {
      S.box([X + 0.04, Y, Z], [0.24, 0.018, 0.045], HOT, { rd: 0.01 });
      S.tube([[X + 0.28, Y, Z], [X + 0.36, Y, Z]], 0.04, 0.004, HOT, {});
      S.box([X - 0.22, Y, Z], [0.03, 0.022, 0.09], EDGE, { rd: 0.01 }); // crossguard
      S.box([X - 0.33, Y, Z], [0.08, 0.016, 0.018], EDGE, { rd: 0.008 }); // tang
    } else if (kind === 'axe') {
      // a bearded axe head lying flat, cut from an outline: horned top, curved edge, hooked beard, socket eye
      const FLAT = { ax: [[1, 0, 0], [0, 0, 1], [0, 1, 0]] }; // outline in x/z, thickness along y
      const outline = [[-0.2, 0.04], [-0.05, 0.035], [0.04, 0.08], [0.12, 0.13], [0.15, 0.08], [0.17, 0.0], [0.16, -0.08],
        [0.12, -0.15], [0.07, -0.2], [0.04, -0.13], [-0.01, -0.07], [-0.05, -0.04], [-0.2, -0.04]];
      S.extrude([outline], [X, Y, Z], 0.04, HOT, Object.assign({ rd: 0.006 }, FLAT));
      const edge = [[0.12, 0.13], [0.15, 0.08], [0.17, 0.0], [0.16, -0.08], [0.12, -0.15], [0.07, -0.2]];
      const inner = edge.map(([x, z]) => { const dx = -0.02 - x, dz = -0.03 - z, l = Math.hypot(dx, dz); return [x + (dx / l) * 0.028, z + (dz / l) * 0.028]; });
      S.extrude([edge.concat(inner.reverse())], [X, Y, Z], 0.044, WHITE, FLAT); // white-hot cutting edge
      S.lathe([X - 0.19, Y - 0.03, Z], 0.06, 0.065, EDGE, {}); // eye
      S.box([X - 0.27, Y, Z], [0.025, 0.026, 0.04], EDGE, { rd: 0.012 }); // poll
      S.lathe([X - 0.19, Y - 0.05, Z], 0.1, 0.03, EDGE, { neg: true }); // the hole the haft goes through
    } else {
      // a leaf-bladed spear head: wide leaf, raised midrib, sharp point, collar and socket
      S.ball([X + 0.08, Y, Z], [0.2, 0.016, 0.07], HOT, {}); // leaf
      S.tube([[X + 0.2, Y, Z], [X + 0.36, Y, Z]], 0.035, 0.003, HOT, {}); // point
      S.tube([[X - 0.1, Y + 0.012, Z], [X + 0.3, Y + 0.008, Z]], 0.012, 0.004, WHITE, {}); // midrib
      S.lathe([X - 0.13, Y - 0.03, Z], 0.06, 0.03, EDGE, { ax: [[0, 1, 0], [1, 0, 0], [0, 0, 1]] }); // collar
      S.tube([[X - 0.14, Y, Z], [X - 0.34, Y, Z]], 0.024, 0.032, EDGE, {}); // socket
      S.tube([[X - 0.33, Y, Z], [X - 0.36, Y, Z]], 0.036, 0.036, EDGE, {}); // socket mouth
    }
    S.bake();
    return B.finish({ cam: { target: [X, Y, Z], dist: 3, pitch: 0.4, yaw: 0.32 }, detail: 26 });
  }
});
