// Blacksmith Battles: the Job Board (the toy's hiring spot, formerly "Workshop"), in the same clean "grand space, small worker" style.
// A cobbled town square at night: a two-storey timber notice board with a little roof, lantern posts, dark town houses with lit
// windows, a road leading in. A slim clerk in a blue coat and tall hat stands on a ladder against the board and pins a notice on each hire.
// Environment variables pick what is drawn (for the toy's sprite layers): TOY_WORKER=0 parks the clerk out of view;
// TOY_PROP=n0..n11 adds one extra notice (the board fills up as more kinds of worker are hired).
// The clip: idle 0-1 s (clerk waits, notice in hand), act 1-1.6 (reach up and pin it: reach 1-1.2, press 1.2-1.35, back 1.35-1.6).
module.exports = ({ makeBuilder, makeSculpt, KIT: K }) => {
  const PAL = [
    0x05060c, 0x0c1020, 0x141a30, 0x1e2842, 0x2c3a58, 0x40506e, 0x5a6a88, // 0-6 night stone (blue)
    0x2a1a10, 0x4a2e1a, 0x6e4628, 0x946238, // 7-10 timber
    0xff9a30, 0xffd060, 0xfff2c0, // 11-13 lantern light
    0x8a7a60, 0xc8b890, 0xf0e6c8, // 14-16 paper
    0x6a4428, 0x9a6634, 0xc8904a, // 17-19 lantern-lit stone
    0x1a2a5a, 0x2a4488, 0x3e62b0, // 20-22 clerk's blue coat
    0x2a1e18, 0x4a3628, // 23-24 trousers, boots
    0xd8a07a, // 25 skin
    0x1a1418, 0x3a2e34, // 26-27 hat
    0x9a2a20, 0xd84a30, // 28-29 red wax seal / roof tiles
    0x2a2e36, 0x5a606a // 30-31 iron
  ];
  function build(seed) {
    const env = (typeof process !== 'undefined' && process.env) || {};
    const LAYER = { worker: env.TOY_WORKER !== '0', prop: env.TOY_PROP || '' };
    const OFF = 60;
    const B = makeBuilder(seed, PAL);
    const S = K.sculpt(makeSculpt(B));
    const tags = K.deform.tags(S);
    S.sun = B.norm([0.3, 0.6, 0.7]);
    S.res = 0.08;
    S.amb = 0.06;
    S.sky = 0.08;
    const STONE = { r: [0, 1, 2, 3, 4, 17, 18, 19] };
    const WALL = { r: [0, 1, 2, 3, 4, 5] };
    const WOOD = { r: [0, 7, 8, 9, 10] };
    const PAPER = { r: [14, 15, 16] };
    const IRON = { r: [0, 30, 31] };
    const LAMP = { r: [11, 12, 13], em: true };
    const ROOF = { r: [0, 26, 28] };
    const BZ = -1.2; // the board's face
    const LAMPS = [[-2.6, 2.3, 0.2], [2.7, 2.3, 0.6]];
    // lights before the first bake: a bake shades with the lights it has
    for (const p of LAMPS) S.lights.push({ p: [p[0], p[1] + 0.2, p[2]], r: 3.0, s: 2.8 });
    S.lights.push({ p: [0, 3.2, 0.8], r: 3.5, s: 0.7 }, { p: [0.3, 1.8, 0.4], r: 1.6, s: 0.5 });
    S.lights.push({ p: [-3.6, 2, -4], r: 1.5, s: 1.0 }, { p: [3.2, 2.6, -4.2], r: 1.5, s: 1.0 }); // window glow on the houses

    // ---- the square: a wide cobbled slab ----
    S.box([0, -0.25, -1], [6, 0.25, 4], STONE, { res: 0.1 });
    for (let i = 0; i < 40; i++) {
      const x = -5.5 + (i % 10) * 1.2 + (Math.floor(i / 10) % 2) * 0.6, z = -4.5 + Math.floor(i / 10) * 1.6;
      S.box([x, 0.01, z], [0.5, 0.02, 0.7], STONE, { res: 0.06, rd: 0.05 });
    }
    // ---- town houses behind: tall boxes with pitched roofs and lit windows ----
    const roofAx = { ax: [[1, 0, 0], [0, 1, 0], [0, 0, 1]] };
    for (const [x, w, h, d] of [[-4.6, 1.3, 4.2, 1.2], [-2.3, 1.0, 5.4, 1.1], [2.4, 1.2, 4.8, 1.2], [4.7, 1.1, 3.9, 1.1]]) {
      S.box([x, h / 2, -5], [w, h / 2, d], WALL, { res: 0.1 });
      S.extrude([[[-w - 0.15, 0], [w + 0.15, 0], [0, w * 0.9]]], [x, h, -5], d * 2 + 0.2, ROOF, { ...roofAx, res: 0.08 });
    }
    S.bake();
    for (const [x, y] of [[-4.9, 1.6], [-4.3, 2.9], [-2.3, 3.8], [-2.0, 1.4], [2.1, 2.2], [2.7, 3.4], [4.5, 1.7]]) {
      S.box([x, y, -3.78], [0.17, 0.25, 0.03], LAMP, { res: 0.03 });
      S.box([x, y, -3.76], [0.02, 0.25, 0.04], WOOD, { res: 0.02 });
    }
    // the road coming in from the right, between the houses
    S.box([3.6, 0.02, -3.1], [0.6, 0.02, 1.2], { r: [0, 1, 2, 3] }, { res: 0.06 });

    // ---- the great notice board: posts, a wide board, a little roof ----
    for (const sx of [-1.45, 1.45]) S.box([sx, 2.1, BZ - 0.05], [0.13, 2.1, 0.13], WOOD, { res: 0.05 });
    S.box([0, 2.5, BZ - 0.1], [1.4, 1.35, 0.06], WOOD, { res: 0.05 });
    S.box([0, 2.5, BZ - 0.02], [1.3, 1.25, 0.04], { r: [0, 8, 9, 10] }, { res: 0.05 }); // cork-dark face
    S.extrude([[[-1.75, 0], [1.75, 0], [0, 0.75]]], [0, 3.95, BZ - 0.1], 0.7, ROOF, { ...roofAx, res: 0.05 });
    S.box([0, 3.9, BZ - 0.1], [1.75, 0.06, 0.36], WOOD, { res: 0.04 });
    // notices always pinned: paper rectangles with a red seal
    const NOTE = (x, y, w, h, tilt) => {
      const c = Math.cos(tilt), s = Math.sin(tilt);
      S.box([x, y, BZ + 0.04], [w, h, 0.012], PAPER, { res: 0.02, ax: [[c, s, 0], [-s, c, 0], [0, 0, 1]] });
      S.ball([x, y + h - 0.06, BZ + 0.06], 0.035, { r: [28, 29] }, { res: 0.015 });
      for (let k = 0; k < 3; k++) S.box([x, y + h * 0.4 - k * h * 0.3, BZ + 0.055], [w * 0.7, 0.012, 0.004], { r: [8] }, { res: 0.01 });
    };
    const BASE = [[-0.9, 3.2, 0.22, 0.3, 0.05], [-0.35, 3.0, 0.2, 0.26, -0.06], [0.55, 3.25, 0.24, 0.28, 0.03], [1.0, 2.8, 0.18, 0.24, -0.04]];
    BASE.forEach(n => NOTE(...n));
    // twelve spare spots: one fills for each kind of worker hired
    const SPOTS = [[-1.0, 2.5], [-0.45, 2.35], [0.1, 2.75], [0.65, 2.55], [1.05, 2.15], [-0.95, 1.85], [-0.4, 1.7], [0.2, 2.05], [0.75, 1.75], [0.25, 3.3], [-0.6, 2.95], [0.95, 3.35]];
    if (LAYER.prop) {
      const i = +LAYER.prop.slice(1);
      const [x, y] = SPOTS[i];
      NOTE(x, y, 0.19, 0.24, ((i * 37) % 9 - 4) * 0.02);
    }
    // ---- lantern posts ----
    for (const [x, y, z] of LAMPS) {
      S.tube([[x, 0, z], [x, y + 0.35, z]], 0.06, 0.05, IRON, { res: 0.02 });
      S.box([x, y + 0.42, z], [0.12, 0.03, 0.12], IRON, { res: 0.015 });
      S.box([x, y + 0.15, z], [0.1, 0.03, 0.1], IRON, { res: 0.015 });
      S.box([x, y + 0.28, z], [0.08, 0.11, 0.08], LAMP, { res: 0.015 });
    }
    // ---- a ladder leaning on the board ----
    const LX = 0.55;
    for (const dx of [-0.2, 0.2]) S.tube([[LX + dx, 0, BZ + 0.85], [LX + dx, 2.6, BZ + 0.12]], 0.025, 0.025, WOOD, { res: 0.015 });
    for (let k = 1; k < 9; k++) { const t = k / 9; S.tube([[LX - 0.2, 2.6 * t, BZ + 0.85 - 0.73 * t], [LX + 0.2, 2.6 * t, BZ + 0.85 - 0.73 * t]], 0.018, 0.018, WOOD, { res: 0.012 }); }
    // a crate and a barrel by the board for scale
    S.box([-2.0, 0.25, -0.6], [0.25, 0.25, 0.25], WOOD, { res: 0.04, rd: 0.02 });
    S.lathe([-1.6, 0, -0.2], 0.55, t => 0.22 + 0.04 * Math.sin(t * Math.PI), WOOD, { res: 0.04 });
    S.bake();

    // ---- the clerk on the ladder: slim, blue coat, tall hat, a notice in hand ----
    const t0 = 5 / 9; // standing on the 5th rung
    const hx = LX + (LAYER.worker ? 0 : OFF), hz = BZ + 0.85 - 0.73 * t0 + 0.15, hy = 2.6 * t0;
    const P = (x, y, z) => [hx + x, hy + y, hz + z]; // facing the board (-z)
    const COAT = { r: [0, 20, 21, 22] }, PANTS = { r: [0, 23] }, BOOT = { r: [0, 23, 24] }, SKIN = { r: [25] }, HAT = { r: [0, 26, 27] };
    for (const d of [-0.07, 0.07]) S.tube([P(d, 0.02, 0.05), P(d, 0.4, 0)], 0.045, 0.05, PANTS, { tag: 'body', res: 0.012 });
    for (const d of [-0.07, 0.07]) S.box(P(d, 0.03, 0.02), [0.05, 0.03, 0.08], BOOT, { tag: 'body', res: 0.012 });
    S.tube([P(0, 0.38, 0), P(0, 0.85, 0)], 0.12, 0.12, COAT, { tag: 'body', res: 0.014 });
    S.tube([P(0, 0.38, 0.02), P(0, 0.2, 0.06)], 0.13, 0.11, COAT, { tag: 'body', res: 0.014 }); // coat tails
    S.ball(P(0, 1.0, 0), 0.1, SKIN, { tag: 'body', res: 0.012 });
    S.lathe(P(0, 1.06, 0), 0.03, 0.15, HAT, { tag: 'body', res: 0.01 });
    S.lathe(P(0, 1.07, 0), 0.22, 0.09, HAT, { tag: 'body', res: 0.012 });
    S.tube([P(-0.15, 0.82, 0), P(-0.18, 0.62, -0.08)], 0.035, 0.035, COAT, { tag: 'body', res: 0.012 }); // holding the ladder
    // the pinning arm, sculpted pressing a notice to the board
    const SH = P(0.14, 0.82, 0);
    const HAND = [hx + 0.3, hy + 1.05, BZ + 0.1];
    S.tube([SH, HAND], 0.035, 0.032, COAT, { tag: 'arm', res: 0.012 });
    S.box([HAND[0], HAND[1] + 0.05, BZ + 0.05], [0.16, 0.2, 0.012], PAPER, { tag: 'arm', res: 0.015 });
    S.ball([HAND[0], HAND[1] + 0.2, BZ + 0.07], 0.03, { r: [28, 29] }, { tag: 'arm', res: 0.012 });
    S.bake();

    const W = B.finish({ cam: { target: [0, 2, -1], dist: 16, pitch: 0.22, yaw: 0 }, detail: 26, dither: 0, radius: 7 });
    K.puppet(W, {
      parts: { body: { ids: tags.body, pivot: P(0, 0, 0), slices: 4 }, arm: { ids: tags.arm, pivot: SH, parent: 'body', slices: 2 } },
      pose(t, dt, pup) {
        const ease = x => x * x * (3 - 2 * x), REST = 1; // 1 = arm down by his side holding the notice, 0 = pressed to the board
        let a, breathe = 0;
        if (t < 1) { breathe = Math.sin(t * Math.PI * 2); a = REST; }
        else if (t < 1.2) a = REST * (1 - ease((t - 1) / 0.2));
        else if (t < 1.35) a = 0;
        else a = REST * ease(Math.min(1, (t - 1.35) / 0.25));
        pup.pose.arm = { rot: [-a * 70, 0, -a * 20] };
        pup.pose.body = { rot: [a * 0 - (1 - a) * 4, 0, 0], scale: [1, 1 + 0.012 * breathe, 1] };
      }
    });
    return W;
  }
  return { id: 'bb-jobs', name: 'Job Board', seed: 9, build };
};
