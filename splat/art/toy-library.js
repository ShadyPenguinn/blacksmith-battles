// Blacksmith Battles: the Library, a scriptorium at night. Tall bookcases climb both sides of a stone room, a great
// round window lets in blue moonlight, and a wall of pigeonholes in the middle waits for scrolls. A slim scribe in
// a blue robe works at a lectern by candlelight on the right.
// Environment variables: TOY_WORKER=0 parks the scribe; TOY_PROP=s0..s11 rolls one scroll into a pigeonhole
// (the toy shows one per kind of scroll you hold).
// The clip: idle 0-1 s (the quill scratches), act 1-1.6 (the scribe holds a finished scroll up: up 1-1.2, hold, down 1.4-1.6).
module.exports = ({ makeBuilder, makeSculpt, KIT: K }) => {
  const PAL = [
    0x05060c, 0x0c1020, 0x141a30, 0x1e2842, 0x2c3a58, 0x40547a, // 0-5 night stone (blue)
    0x2a1a10, 0x4a2e1a, 0x6e4628, 0x946238, // 6-9 timber
    0x8ac8f0, 0xc8ecff, // 10-11 moonlight
    0xff9a40, 0xffd070, 0xfff4c0, // 12-14 candle
    0xe8dcb8, 0xc8b890, 0x8a7a5a, // 15-17 parchment
    0x1a2a5a, 0x2a4488, // 18-19 robe
    0x2a1e18, 0xd8a07a, // 20-21 boots, skin
    0x6a1a20, 0x1a4a2a, 0x2a2a6a, 0x6a5a1a, // 22-25 book spines
    0x6a4a32, 0x9a6a44 // 26-27 candlelit wood
  ];
  function build(seed) {
    const env = (typeof process !== 'undefined' && process.env) || {};
    const LAYER = { worker: env.TOY_WORKER !== '0', prop: env.TOY_PROP || '' };
    const OFF = 60;
    const B = makeBuilder(seed, PAL);
    const S = K.sculpt(makeSculpt(B));
    const tags = K.deform.tags(S);
    S.sun = B.norm([0.0, 0.5, 0.85]);
    S.res = 0.08;
    S.amb = 0.1;
    S.sky = 0.12;
    const STONE = { r: [0, 1, 2, 3, 4, 5] };
    const WOOD = { r: [0, 6, 7, 8, 9] };
    const CANDLE = [1.9, 1.25, 0.15];
    S.lights.push({ p: [CANDLE[0], CANDLE[1] + 0.3, CANDLE[2] + 0.2], r: 2.2, s: 1.8 }, { p: [0, 2.8, -1.4], r: 3.0, s: 0.9 }, { p: [0, 1.4, 0.8], r: 3.2, s: 0.7 });

    // ---- the room ----
    S.box([0, -0.25, -0.8], [8, 0.25, 2.4], STONE, { res: 0.1 });
    for (let i = -7; i <= 7; i++) S.box([i * 1.0, 0.005, -0.8], [0.015, 0.01, 2.35], { r: [0, 1] }, { res: 0.03 });
    S.box([0, 3, -2.9], [8, 3, 0.3], STONE, { res: 0.1 });
    // the great round window, carved through the back wall
    const ring = []; for (let i = 0; i < 28; i++) { const a = Math.PI * 2 * i / 28; ring.push([Math.cos(a) * 0.95, Math.sin(a) * 0.95]); }
    S.extrude([ring], [0, 3.0, -2.9], 1.0, STONE, { neg: true, ax: [[1, 0, 0], [0, 1, 0], [0, 0, 1]] });
    S.bake();
    S.box([0, 3.0, -3.6], [1.2, 1.2, 0.05], { r: [10, 11], em: true }, { res: 0.05 });
    S.torus([0, 3.0, -2.6], 0.95, 0.06, WOOD, { res: 0.025, ax: [[1, 0, 0], [0, 0, 1], [0, -1, 0]] });
    S.box([0, 3.0, -2.62], [0.03, 0.95, 0.03], WOOD, { res: 0.015 });
    S.box([0, 3.0, -2.62], [0.95, 0.03, 0.03], WOOD, { res: 0.015 });
    // ---- tall bookcases on both sides ----
    for (const sx of [-1, 1]) {
      const cx = sx * 2.75;
      S.box([cx, 2.2, -2.35], [1.15, 2.2, 0.25], WOOD, { res: 0.05 });
      for (let r = 0; r < 6; r++) {
        const y = 0.35 + r * 0.7;
        S.box([cx, y - 0.04, -2.12], [1.08, 0.03, 0.05], { r: [0, 8, 9] }, { res: 0.02 });
        for (let b = 0; b < 14; b++) {
          const h = 0.22 + ((b * 7 + r * 3) % 5) * 0.035, c = 22 + ((b + r * 2) % 4);
          S.box([cx - 0.98 + b * 0.15, y + h / 2, -2.14], [0.06, h / 2, 0.08], { r: [0, c] }, { res: 0.015 });
        }
      }
    }
    // the pigeonhole wall: a 6 x 2 grid of cubbies under the window
    S.box([0, 1.3, -2.52], [1.45, 0.62, 0.1], WOOD, { res: 0.04 });
    for (let c = 0; c < 6; c++) for (let r = 0; r < 2; r++) S.box([-1.15 + c * 0.46, 1.0 + r * 0.6, -2.42], [0.19, 0.24, 0.12], { r: [0, 1] }, { res: 0.02, neg: true });
    S.bake();
    // a reading table with open books at the left, a stool
    S.box([-1.6, 0.7, -0.2], [0.65, 0.04, 0.35], WOOD, { res: 0.03 });
    for (const [dx, dz] of [[-0.55, -0.28], [0.55, -0.28], [-0.55, 0.28], [0.55, 0.28]]) S.box([-1.6 + dx, 0.34, -0.2 + dz], [0.03, 0.34, 0.03], WOOD, { res: 0.015 });
    S.box([-1.7, 0.76, -0.2], [0.22, 0.02, 0.15], { r: [16, 15] }, { res: 0.015 });
    S.box([-1.3, 0.8, -0.25], [0.12, 0.06, 0.16], { r: [0, 22] }, { res: 0.015 });
    S.lathe([-1.0, 0, 0.35], 0.42, 0.15, WOOD, { res: 0.025 });
    // the lectern and the candle
    S.tube([[1.75, 0, 0.1], [1.75, 0.95, 0.1]], 0.05, 0.05, WOOD, { res: 0.02 });
    S.box([1.75, 1.0, 0.1], [0.3, 0.03, 0.22], WOOD, { res: 0.02, ax: [[1, 0, 0], [0, 0.94, 0.34], [0, -0.34, 0.94]] });
    S.box([1.72, 1.04, 0.12], [0.22, 0.012, 0.16], { r: [16, 15] }, { res: 0.012, ax: [[1, 0, 0], [0, 0.94, 0.34], [0, -0.34, 0.94]] });
    S.lathe([CANDLE[0], CANDLE[1] - 0.14, CANDLE[2]], 0.12, 0.025, { r: [15] }, { res: 0.008 });
    S.lathe([CANDLE[0], CANDLE[1] - 0.02, CANDLE[2]], 0.07, t => 0.018 * (1 - t), { r: [12, 13, 14], em: true }, { res: 0.006 });
    S.bake();

    // ---- one rolled scroll per pigeonhole ----
    if (LAYER.prop) {
      const i = +LAYER.prop.slice(1), c = i % 6, r = i < 6 ? 0 : 1;
      const x = -1.15 + c * 0.46, y = 0.84 + r * 0.6, z = -2.34;
      for (const [dx, dy] of [[-0.07, 0], [0.07, 0], [0, 0.12]]) {
        S.tube([[x + dx, y + dy + 0.05, z - 0.1], [x + dx, y + dy + 0.05, z + 0.1]], 0.065, 0.065, { r: [17, 16, 15] }, { res: 0.01 });
      }
      S.box([x, y + 0.06, z + 0.02], [0.13, 0.012, 0.012], { r: [0, 22 + (i % 4)] }, { res: 0.008 }); // ribbon
    }
    S.bake();

    // ---- the scribe at the lectern, facing left toward the room ----
    const hx = 1.35 + (LAYER.worker ? 0 : OFF), hz = 0.1;
    const P = (x, y, z) => [hx + x, y, hz + z];
    const ROBE = { r: [0, 18, 19] }, SKIN = { r: [0, 21] };
    S.lathe(P(0, 0, 0), 1.0, t => 0.17 - 0.06 * t, ROBE, { tag: 'body', res: 0.014 });
    S.ball(P(0, 1.13, 0), 0.1, SKIN, { tag: 'body', res: 0.012 });
    S.lathe(P(0, 1.08, -0.02), 0.22, t => 0.12 * (1 - t * 0.7), ROBE, { tag: 'body', res: 0.012 }); // hood down the back
    S.ball(P(0, 1.2, -0.01), [0.1, 0.05, 0.1], { r: [0, 15, 16] }, { tag: 'body', res: 0.01 }); // white hair
    S.tube([P(-0.15, 0.98, 0), P(-0.18, 0.7, 0.06)], 0.04, 0.035, ROBE, { tag: 'body', res: 0.012 });
    // the writing arm, sculpted holding a scroll up high (posed down onto the lectern at rest)
    const SH = P(0.15, 0.98, 0);
    const HAND = P(0.25, 1.45, 0.15);
    S.tube([SH, HAND], 0.04, 0.035, ROBE, { tag: 'arm', res: 0.012 });
    S.tube([[HAND[0] - 0.14, HAND[1] + 0.06, HAND[2]], [HAND[0] + 0.14, HAND[1] + 0.06, HAND[2]]], 0.04, 0.04, { r: [17, 16, 15] }, { tag: 'arm', res: 0.01 });
    S.box([HAND[0], HAND[1] - 0.1, HAND[2] + 0.005], [0.12, 0.12, 0.005], { r: [16, 15] }, { tag: 'arm', res: 0.01 });
    S.bake();

    const W = B.finish({ cam: { target: [0, 1.6, -1], dist: 16, pitch: 0.2, yaw: 0 }, detail: 26, dither: 0, radius: 9 });
    K.puppet(W, {
      parts: { body: { ids: tags.body, pivot: P(0, 0, 0), slices: 4 }, arm: { ids: tags.arm, pivot: SH, parent: 'body', slices: 2 } },
      pose(t, dt, pup) {
        const ease = x => x * x * (3 - 2 * x);
        let a = 1, scratch = 0;
        if (t < 1) scratch = Math.sin(t * Math.PI * 6) * 4;
        else if (t < 1.2) a = 1 - ease((t - 1) / 0.2);
        else if (t < 1.4) a = 0;
        else a = ease(Math.min(1, (t - 1.4) / 0.2));
        pup.pose.arm = { rot: [a * 75, 0, a * scratch] };
        pup.pose.body = { rot: [a * 6 - (1 - a) * 3, 0, 0] };
      }
    });
    return W;
  }
  return { id: 'bb-library', name: 'Scriptorium', seed: 29, build };
};
