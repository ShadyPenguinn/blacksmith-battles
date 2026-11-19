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
    const HOT = { r: [3, 4, 5], em: true }, EDGE = { r: [2, 3], em: true }, Y = 0.9, X = 0.5, Z = 0.45;
    if (kind === 'sword') {
      S.box([X + 0.04, Y, Z], [0.24, 0.018, 0.045], HOT, { rd: 0.01 });
      S.tube([[X + 0.28, Y, Z], [X + 0.36, Y, Z]], 0.04, 0.004, HOT, {});
      S.box([X - 0.22, Y, Z], [0.03, 0.022, 0.09], EDGE, { rd: 0.01 }); // crossguard
      S.box([X - 0.33, Y, Z], [0.08, 0.016, 0.018], EDGE, { rd: 0.008 }); // tang
    } else if (kind === 'axe') {
      S.lathe([X + 0.05, Y - 0.02, Z], 0.04, t => 0.15, HOT, {});
      S.box([X - 0.08, Y, Z], [0.1, 0.02, 0.05], HOT, { rd: 0.01 });
      S.ball([X - 0.14, Y, Z], [0.04, 0.03, 0.04], EDGE, {}); // eye of the head
    } else {
      S.tube([[X - 0.25, Y, Z], [X + 0.02, Y, Z]], 0.03, 0.03, EDGE, {}); // socket
      S.tube([[X + 0.02, Y, Z], [X + 0.3, Y, Z]], 0.075, 0.004, HOT, {}); // leaf blade
    }
    S.bake();
    return B.finish({ cam: { target: [X, Y, Z], dist: 3, pitch: 0.4, yaw: 0.32 }, detail: 26 });
  }
});
