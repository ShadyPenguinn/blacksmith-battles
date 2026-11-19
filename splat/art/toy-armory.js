// Blacksmith Battles: the Armory, a tall stone vault. Two long weapon racks run along the back wall under a high
// moonlit window and a hanging banner; torches burn on the side walls. A slim armourer in a steel-grey tabard
// works a grindstone at the front right.
// Environment variables: TOY_WORKER=0 parks the armourer (and the grindstone's moving parts);
// TOY_PROP=w0..w11 adds one weapon to the racks (the toy shows one per weapon you own).
// The clip: idle 0-1 s, act 1-1.6 (the armourer presses the blade to the wheel: in 1-1.15, hold, back 1.45-1.6).
module.exports = ({ makeBuilder, makeSculpt, KIT: K }) => {
  const PAL = [
    0x05060a, 0x0e1219, 0x182029, 0x24303c, 0x34444f, 0x4a5c66, 0x66787e, // 0-6 slate stone
    0x2a1a10, 0x4a2e1a, 0x6e4628, 0x946238, // 7-10 timber
    0xff8a3a, 0xffc060, 0xfff0b0, // 11-13 torch flame
    0x6a4a32, 0x9a6a44, // 14-15 torchlit stone
    0x3a4048, 0x6a7480, 0xa8b4c0, 0xdde6ee, // 16-19 steel
    0x6a1a20, 0xa02a30, 0xc8a040, // 20-22 banner red, gold
    0x2a2e38, 0x4a5262, // 23-24 tabard
    0x2a1e18, 0x4a3628, 0xd8a07a, // 25-27 trousers, boots, skin
    0x8aa8d8, 0xc8dcf8 // 28-29 moonlight
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
    S.amb = 0.11;
    S.sky = 0.1;
    const STONE = { r: [0, 1, 2, 3, 4, 5, 6] };
    const WOOD = { r: [0, 7, 8, 9, 10] };
    const STEEL = { r: [0, 16, 17, 18, 19] };
    const FLAME = { r: [11, 12, 13], em: true };
    const TORCH = [[-3.6, 2.0, -2.0], [3.6, 2.0, -2.0]];
    // all lights before the first bake
    for (const p of TORCH) S.lights.push({ p: [p[0] * 0.8, p[1] + 0.1, p[2] + 0.4], r: 2.6, s: 1.3 });
    S.lights.push({ p: [0, 2.0, -0.6], r: 3.6, s: 0.9 }, { p: [2.2, 1.4, 0.9], r: 1.8, s: 0.8 }, { p: [0, 4.5, -2.0], r: 2.2, s: 0.6 });

    // ---- the vault: floor, back wall, side walls, a barrel ceiling ----
    S.box([0, -0.25, -0.5], [4.6, 0.25, 2.6], STONE, { res: 0.1 });
    for (let i = -4; i <= 4; i++) S.box([i * 1.0, 0.005, -0.5], [0.02, 0.01, 2.5], { r: [0, 1] }, { res: 0.03 });
    S.box([0, 3.0, -2.9], [4.6, 3.0, 0.3], STONE, { res: 0.1 });
    for (const sx of [-1, 1]) S.box([sx * 4.3, 3.0, -1.2], [0.3, 3.0, 1.7], STONE, { res: 0.1 });
    // buttresses splitting the back wall into bays
    for (const x of [-3.0, 3.0]) S.box([x, 3.0, -2.55], [0.22, 3.0, 0.12], STONE, { res: 0.06 });
    S.bake();
    // banner beneath the window
    S.tube([[-0.6, 3.3, -2.5], [0.6, 3.3, -2.5]], 0.03, 0.03, WOOD, { res: 0.015 });
    S.box([0, 2.95, -2.52], [0.5, 0.33, 0.02], { r: [0, 20, 21] }, { res: 0.025 });
    S.lathe([0, 2.95, -2.48], 0.02, 0.15, { r: [21, 22] }, { res: 0.015 });
    // ---- two long racks on the back wall ----
    for (const y of [0.55, 1.85]) {
      S.box([0, y - 0.38, -2.4], [2.8, 0.05, 0.12], WOOD, { res: 0.03 }); // foot rail
      S.box([0, y + 0.62, -2.45], [2.8, 0.05, 0.08], WOOD, { res: 0.03 }); // pegs rail
      for (const i of [-3, 0, 3]) S.box([i * 0.93, y + 0.12, -2.45], [0.04, 0.55, 0.06], WOOD, { res: 0.02 });
    }
    // torches in iron brackets
    for (const [x, y, z] of TORCH) {
      S.tube([[x * 1.0, y - 0.35, z], [x * 0.95, y, z]], 0.04, 0.05, WOOD, { res: 0.015 });
      S.lathe([x * 0.95, y, z], 0.18, t => 0.09 * (1 - 0.6 * t), FLAME, { res: 0.015 });
    }
    // a chest and a barrel of spears by the left wall, a stack of shields
    S.box([-3.3, 0.28, -0.3], [0.45, 0.28, 0.3], WOOD, { res: 0.04, rd: 0.03 });
    S.box([-3.3, 0.57, -0.3], [0.47, 0.03, 0.32], STEEL, { res: 0.02 });
    S.lathe([-3.5, 0, 0.6], 0.6, 0.24, WOOD, { res: 0.03 });
    for (const [dx, dz] of [[-0.08, 0], [0.07, 0.05], [0, -0.08]]) S.tube([[-3.5 + dx, 0.5, 0.6 + dz], [-3.5 + dx * 2, 1.5, 0.6 + dz * 2]], 0.015, 0.015, WOOD, { res: 0.01 });
    S.bake();

    // ---- the weapons, one prop each, six to a rack ----
    if (LAYER.prop) {
      const i = +LAYER.prop.slice(1), row = i < 6 ? 0 : 1, col = i % 6;
      const x = -2.33 + col * 0.93, y = row ? 1.85 : 0.55, z = -2.3;
      const kind = [0, 3, 1, 4, 2, 0, 1, 2, 3, 0, 4, 1][i];
      const GRIP = { r: [0, 8, 9] }, GOLD = { r: [0, 22] };
      if (kind === 0) { // sword
        S.box([x, y + 0.2, z], [0.035, 0.42, 0.012], STEEL, { res: 0.01 });
        S.box([x, y - 0.24, z], [0.13, 0.025, 0.03], GOLD, { res: 0.01 });
        S.box([x, y - 0.37, z], [0.025, 0.11, 0.025], GRIP, { res: 0.01 });
      } else if (kind === 1) { // axe
        S.tube([[x, y - 0.42, z], [x, y + 0.55, z]], 0.025, 0.025, GRIP, { res: 0.01 });
        S.extrude([[[0, 0.18], [0.25, 0.28], [0.3, 0], [0.25, -0.28], [0, -0.16]]], [x, y + 0.36, z - 0.02], 0.04, STEEL, { res: 0.01 });
      } else if (kind === 2) { // spear
        S.tube([[x, y - 0.42, z], [x, y + 0.6, z]], 0.02, 0.02, GRIP, { res: 0.01 });
        S.lathe([x, y + 0.6, z], 0.22, t => 0.055 * (1 - t), STEEL, { res: 0.008 });
      } else if (kind === 3) { // shield
        S.ball([x, y + 0.1, z + 0.02], [0.3, 0.36, 0.06], { r: [0, 20, 21] }, { res: 0.012 });
        S.ball([x, y + 0.1, z + 0.07], [0.08, 0.08, 0.04], GOLD, { res: 0.01 });
      } else { // warhammer
        S.tube([[x, y - 0.42, z], [x, y + 0.4, z]], 0.025, 0.025, GRIP, { res: 0.01 });
        S.box([x, y + 0.42, z], [0.2, 0.09, 0.09], STEEL, { res: 0.012 });
      }
    }
    S.bake();

    // ---- the armourer at the grindstone (front right) ----
    const off = LAYER.worker ? 0 : OFF;
    const GX = 2.15 + off, GY = 0.62, GZ = 0.35;
    S.box([GX, 0.22, GZ], [0.35, 0.22, 0.2], WOOD, { res: 0.025 }); // trough
    for (const sx of [-0.3, 0.3]) S.box([GX + sx, 0.5, GZ], [0.03, 0.12, 0.17], WOOD, { res: 0.015 });
    const wheel = []; for (let i = 0; i < 20; i++) { const a = Math.PI * 2 * i / 20; wheel.push([Math.cos(a) * 0.33, Math.sin(a) * 0.33]); }
    S.extrude([wheel], [GX, GY, GZ - 0.07], 0.14, { r: [0, 3, 4, 5, 6] }, { res: 0.018 });
    S.tube([[GX - 0.32, GY, GZ], [GX + 0.32, GY, GZ]], 0.025, 0.025, STEEL, { res: 0.01 });

    const hx = 1.5 + off, hz = 0.35;
    const P = (x, y, z) => [hx + x, y, hz + z];
    const TAB = { r: [0, 23, 24] }, SKIN = { r: [0, 27] };
    for (const d of [-0.07, 0.07]) S.tube([P(d, 0.05, 0), P(d, 0.55, 0)], 0.045, 0.05, { r: [0, 25] }, { tag: 'body', res: 0.012 });
    for (const d of [-0.07, 0.07]) S.ball(P(d, 0.06, 0.02), [0.05, 0.05, 0.08], { r: [0, 26] }, { tag: 'body', res: 0.012 });
    S.tube([P(0, 0.5, 0), P(0, 1.02, 0)], 0.12, 0.12, { r: [0, 17, 18] }, { tag: 'body', res: 0.014 }); // mail shirt
    S.box(P(0, 0.72, 0.09), [0.1, 0.3, 0.03], TAB, { tag: 'body', res: 0.012 }); // tabard
    S.ball(P(0, 1.17, 0), 0.1, SKIN, { tag: 'body', res: 0.012 });
    S.ball(P(0, 1.21, -0.01), [0.105, 0.06, 0.1], { r: [0, 7, 8] }, { tag: 'body', res: 0.012 }); // hair
    S.tube([P(-0.15, 1.0, 0), P(-0.18, 0.72, 0.06)], 0.035, 0.035, { r: [0, 17, 18] }, { tag: 'body', res: 0.012 });
    // the working arm and the blade pressed to the top of the wheel (sculpted pressed in)
    const SH = P(0.15, 1.0, 0);
    const HAND = P(0.38, 0.88, 0.05);
    S.tube([SH, HAND], 0.035, 0.032, { r: [0, 17, 18] }, { tag: 'arm', res: 0.012 });
    S.box([HAND[0] + 0.25, HAND[1] + 0.03, HAND[2]], [0.26, 0.022, 0.035], STEEL, { tag: 'arm', res: 0.01, ax: [[0.97, -0.24, 0], [0.24, 0.97, 0], [0, 0, 1]] });
    S.box([HAND[0] - 0.02, HAND[1] + 0.01, HAND[2]], [0.02, 0.025, 0.09], { r: [0, 22] }, { tag: 'arm', res: 0.01 });
    S.bake();

    const W = B.finish({ cam: { target: [0, 1.6, -1], dist: 16, pitch: 0.2, yaw: 0 }, detail: 26, dither: 0, radius: 7 });
    K.puppet(W, {
      parts: { body: { ids: tags.body, pivot: P(0, 0, 0), slices: 4 }, arm: { ids: tags.arm, pivot: SH, parent: 'body', slices: 2 } },
      pose(t, dt, pup) {
        const ease = x => x * x * (3 - 2 * x);
        let a = 1, breathe = 0; // 1 = blade lifted off the wheel, 0 = pressed in
        if (t < 1) breathe = Math.sin(t * Math.PI * 2);
        else if (t < 1.15) a = 1 - ease((t - 1) / 0.15);
        else if (t < 1.45) a = 0;
        else a = ease(Math.min(1, (t - 1.45) / 0.15));
        pup.pose.arm = { rot: [0, 0, a * 22] };
        pup.pose.body = { rot: [(1 - a) * 5, 0, 0], scale: [1, 1 + 0.012 * breathe, 1] };
      }
    });
    return W;
  }
  return { id: 'bb-armory', name: 'Armory vault', seed: 17, build };
};
