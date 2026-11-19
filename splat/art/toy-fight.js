// Blacksmith Battles: Fight, the town gate at sunset. A great stone gatehouse with two round towers and red banners,
// its iron portcullis closed across the arch; through the bars the road runs out to the hills under a red sky.
// A gate warden with a horn stands beside the arch; your equipped heroes (props) wait in two files on the road.
// Environment variables: TOY_WORKER=0 parks the warden and the portcullis; TOY_PROP=h0..h11 adds one hero
// (three ranks of four, h0 nearest the gate, later ranks further back, so they overlap correctly when drawn in order).
// The clip: idle 0-1 s, act 1-1.6 (the warden blows the horn and the portcullis lifts: up 1-1.2, hold, down 1.4-1.6).
module.exports = ({ makeBuilder, makeSculpt, KIT: K }) => {
  const PAL = [
    0x08060a, 0x18121a, 0x261c26, 0x382a34, 0x4e3a44, 0x6a5058, 0x8a6a6a, // 0-6 rose-grey stone
    0x3a1a1a, 0x7a2a24, 0xb8402e, 0xe0703a, 0xf8b060, 0xffe0a0, // 7-12 sunset sky, high to low
    0x5a2a2a, 0x8a3a30, // 13-14 far hills
    0x2a2228, 0x4a4048, 0x7a7078, // 15-17 iron
    0x6a1818, 0xa82a24, 0xc8a040, // 18-20 banner red, gold
    0x6a5a40, 0x8a7654, // 21-22 road
    0x2a1e18, 0x4a3628, 0xd8a07a, // 23-25 trousers, boots, skin
    0x5a6070, 0x9aa2b0, // 26-27 steel
    0x2a3a5a, 0x3a5a8a, 0x2a4a2a, 0x3a6a3a, 0x5a2a5a, 0x7a3a7a, // 28-33 capes
    0xff8a3a, 0xffc060 // 34-35 torch
  ];
  function build(seed) {
    const env = (typeof process !== 'undefined' && process.env) || {};
    const LAYER = { worker: env.TOY_WORKER !== '0', prop: env.TOY_PROP || '' };
    const OFF = 60;
    const B = makeBuilder(seed, PAL);
    const S = K.sculpt(makeSculpt(B));
    const tags = K.deform.tags(S);
    S.sun = B.norm([0.4, 0.5, 0.75]);
    S.res = 0.08;
    S.amb = 0.16;
    S.sky = 0.2;
    const STONE = { r: [0, 1, 2, 3, 4, 5, 6] };
    const IRON = { r: [0, 15, 16, 17] };
    const RED = { r: [0, 18, 19] }, GOLD = { r: [0, 20] };
    const FLAME = { r: [34, 35, 12], em: true };
    const TORCH = [[-1.06, 1.9, -1.72], [1.06, 1.9, -1.72]];
    for (const p of TORCH) S.lights.push({ p: [p[0], p[1], p[2] + 0.5], r: 2.4, s: 1.4 });
    S.lights.push({ p: [0, 2.0, 1.2], r: 3.5, s: 0.8 });

    // ---- sky, hills and the road beyond the gate ----
    for (const [y, h, c] of [[-0.5, 1.2, 12], [1.2, 0.5, 11], [2.2, 0.5, 10], [3.2, 0.5, 9], [4.4, 0.7, 8], [6.4, 1.3, 7]]) S.box([0, y, -14], [30, h, 0.2], { r: [c], em: true }, { res: 0.15 });
    S.ball([-3, -0.6, -11], [6, 1.6, 1.2], { r: [0, 13, 14] }, { res: 0.15 });
    S.ball([4, -0.6, -10], [5, 1.2, 1.2], { r: [0, 13, 14] }, { res: 0.15 });
    S.box([0, -0.25, -3], [13, 0.25, 7], { r: [1, 2, 3] }, { res: 0.1 });
    S.box([0, 0.01, -3], [0.75, 0.02, 7], { r: [0, 21, 22] }, { res: 0.05 });
    S.bake();
    // ---- the gatehouse: a wall, two round towers, an arched passage ----
    S.box([0, 1.5, -2.2], [12, 1.5, 0.4], STONE, { res: 0.1 });
    for (const sx of [-1, 1]) {
      S.lathe([sx * 2.0, 0, -1.9], 4.0, 0.85, STONE, { res: 0.08 });
      for (let i = 0; i < 8; i++) { const a = Math.PI * 2 * i / 8; S.box([sx * 2.0 + Math.cos(a) * 0.8, 4.15, -1.9 + Math.sin(a) * 0.8], [0.14, 0.18, 0.14], STONE, { res: 0.04 }); }
    }
    for (let i = 0; i < 24; i++) S.box([-11.5 + i * 1.0, 3.15, -2.0], [0.25, 0.2, 0.2], STONE, { res: 0.05 }); // wall crenels
    const arch = []; for (let i = 0; i <= 14; i++) { const a = Math.PI * (i / 14); arch.push([Math.cos(a) * 0.95, 1.5 + Math.sin(a) * 0.95]); } arch.push([-0.95, 0], [0.95, 0]);
    S.extrude([arch], [0, 0, -2.2], 2.0, STONE, { neg: true, ax: [[1, 0, 0], [0, 1, 0], [0, 0, 1]] });
    S.bake();
    // banners on the towers, torches beside the arch
    for (const sx of [-1, 1]) {
      S.box([sx * 2.0, 2.75, -1.02], [0.26, 0.6, 0.02], RED, { res: 0.02 });
      S.lathe([sx * 2.0, 2.8, -0.99], 0.02, 0.12, GOLD, { res: 0.012 });
    }
    for (const [x, y, z] of TORCH) {
      S.tube([[x, y - 0.35, z], [x, y, z + 0.08]], 0.035, 0.045, { r: [0, 7] }, { res: 0.015 });
      S.lathe([x, y, z + 0.08], 0.16, t => 0.08 * (1 - 0.6 * t), FLAME, { res: 0.015 });
    }
    S.bake();

    // ---- the heroes on the road: two files facing the gate ----
    if (LAYER.prop) {
      const i = +LAYER.prop.slice(1), row = Math.floor(i / 4), side = i % 2 ? 1 : -1;
      const x = [-0.25, 0.25, -0.75, 0.75][i % 4] - (row % 2) * 0.25, z = -1.0 + row * 0.5;
      const [a, b] = [[28, 29], [30, 31], [32, 33], [18, 19]][(row + (i % 2)) % 4];
      const CAPE = { r: [0, a, b] };
      for (const d of [-0.07, 0.07]) S.tube([[x + d, 0.05, z], [x + d, 0.5, z]], 0.045, 0.05, { r: [0, 23] }, { res: 0.012 });
      S.tube([[x, 0.45, z], [x, 0.98, z]], 0.12, 0.12, { r: [0, 26, 27] }, { res: 0.014 });
      S.box([x, 0.66, z + 0.12], [0.14, 0.34, 0.03], CAPE, { res: 0.012 }); // cape on the back, toward us
      S.ball([x, 1.13, z], [0.11, 0.1, 0.11], { r: [0, 26, 27] }, { res: 0.01 }); // helm from behind
      if (i % 3 === 0) S.tube([[x + side * 0.18, 0.1, z], [x + side * 0.18, 1.55, z]], 0.014, 0.014, { r: [0, 24] }, { res: 0.01 });
      if (i % 3 === 0) S.lathe([x + side * 0.18, 1.55, z], 0.12, t => 0.032 * (1 - t), { r: [0, 26, 27] }, { res: 0.008 });
      if (i % 3 === 1) S.ball([x - side * 0.17, 0.7, z + 0.04], [0.04, 0.17, 0.14], CAPE, { res: 0.01 });
    }
    S.bake();

    // ---- the portcullis (moves with the warden layer) ----
    const off = LAYER.worker ? 0 : OFF;
    const GZ = -1.95, TOP = 2.5;
    for (let i = -4; i <= 4; i++) S.box([off + i * 0.22, 1.2, GZ], [0.03, 1.25, 0.03], IRON, { tag: 'gate', res: 0.012 });
    for (const y of [0.4, 0.95, 1.5, 2.05]) S.box([off, y, GZ], [0.95, 0.03, 0.03], IRON, { tag: 'gate', res: 0.012 });
    for (let i = -4; i <= 4; i++) S.lathe([off + i * 0.22, -0.05, GZ], 0.1, t => 0.03 * (1 - t), IRON, { tag: 'gate', res: 0.008, ax: [[1, 0, 0], [0, -1, 0], [0, 0, 1]] });
    // ---- the warden, beside the arch on the right ----
    const hx = 1.3 + off, hz = -1.2;
    const P = (x, y, z) => [hx + x, y, hz + z];
    const COAT = { r: [0, 18, 19] }, SKIN = { r: [0, 25] };
    for (const d of [-0.07, 0.07]) S.tube([P(d, 0.05, 0), P(d, 0.55, 0)], 0.045, 0.05, { r: [0, 23] }, { tag: 'body', res: 0.012 });
    S.lathe(P(0, 0.4, 0), 0.65, t => 0.14 - 0.03 * t, COAT, { tag: 'body', res: 0.014 });
    S.ball(P(0, 1.17, 0), 0.1, SKIN, { tag: 'body', res: 0.012 });
    S.ball(P(0, 1.21, 0), [0.11, 0.07, 0.11], { r: [0, 26, 27] }, { tag: 'body', res: 0.01 }); // kettle helm
    S.lathe(P(0, 1.19, 0), 0.02, 0.16, { r: [0, 26, 27] }, { tag: 'body', res: 0.01 });
    S.tube([P(0.15, 1.0, 0), P(0.18, 0.7, 0.06)], 0.035, 0.035, COAT, { tag: 'body', res: 0.012 });
    S.tube([P(0.2, 0.05, 0.05), P(0.2, 1.7, 0.05)], 0.015, 0.015, { r: [0, 24] }, { tag: 'body', res: 0.01 }); // halberd shaft
    S.box(P(0.27, 1.62, 0.05), [0.08, 0.1, 0.015], { r: [0, 26, 27] }, { tag: 'body', res: 0.01 });
    // the horn arm (sculpted raised to the lips; posed down at rest)
    const SH = P(-0.15, 1.0, 0);
    const HAND = P(-0.12, 1.12, 0.17);
    S.tube([SH, HAND], 0.035, 0.032, COAT, { tag: 'arm', res: 0.012 });
    S.lathe(HAND, 0.26, t => 0.015 + 0.05 * t * t, { r: [0, 20, 12] }, { tag: 'arm', res: 0.008, ax: [[1, 0, 0], [0, 0.5, -0.87], [0, 0.87, 0.5]].map(v => v) });
    S.bake();

    const W = B.finish({ cam: { target: [0, 1.6, -1], dist: 16, pitch: 0.2, yaw: 0 }, detail: 26, dither: 0, radius: 11 });
    K.puppet(W, {
      parts: {
        body: { ids: tags.body, pivot: P(0, 0, 0), slices: 4 },
        arm: { ids: tags.arm, pivot: SH, parent: 'body', slices: 2 },
        gate: { ids: tags.gate, pivot: [off, TOP, GZ], slices: 1 }
      },
      pose(t, dt, pup) {
        const ease = x => x * x * (3 - 2 * x);
        let a = 1, breathe = 0; // 1 = horn down and gate shut, 0 = horn up and gate raised
        if (t < 1) breathe = Math.sin(t * Math.PI * 2);
        else if (t < 1.2) a = 1 - ease((t - 1) / 0.2);
        else if (t < 1.4) a = 0;
        else a = ease(Math.min(1, (t - 1.4) / 0.2));
        pup.pose.arm = { rot: [a * 70, 0, 0] };
        pup.pose.body = { rot: [-(1 - a) * 4, 0, 0], scale: [1, 1 + 0.012 * breathe, 1] };
        pup.pose.gate = { scale: [1, 0.25 + 0.75 * a, 1] };
      }
    });
    return W;
  }
  return { id: 'bb-fight', name: 'Town gate', seed: 23, build };
};
