// Blacksmith Battles: the Sanctum, a tower chamber under the stars. Tall arched windows open on a violet night,
// slim pillars hold up the vault, and a glowing rune circle is set into the floor. An arcanist in a deep purple robe
// stands in the circle with a crystal staff; low pedestals ring the circle, each waiting for a floating rune stone.
// Environment variables: TOY_WORKER=0 parks the arcanist; TOY_PROP=r0..r7 lights one rune stone on its pedestal
// (the toy shows one per magic weapon you own).
// The clip: idle 0-1 s, act 1-1.6 (the arcanist raises the staff to bind: up 1-1.12, hold, down 1.4-1.6).
module.exports = ({ makeBuilder, makeSculpt, KIT: K }) => {
  const PAL = [
    0x06040c, 0x100a1c, 0x1a1230, 0x261c42, 0x362a58, 0x4a3c72, 0x64568c, // 0-6 violet stone
    0x2a1a4a, 0x4a2e7a, 0x8a6ad8, // 7-9 night sky
    0xb69cff, 0xd8c8ff, 0xf4eeff, // 10-12 rune glow
    0x2a1040, 0x4a1e6a, 0x6a2e8a, // 13-15 robe
    0xd8a07a, 0xe8e0f0, // 16-17 skin, silver hair
    0x4a3a2a, 0x7a6040, // 18-19 staff wood
    0x8affe0, 0x40c8b0, // 20-21 crystal teal
    0xc8a040 // 22 gold trim
  ];
  function build(seed) {
    const env = (typeof process !== 'undefined' && process.env) || {};
    const LAYER = { worker: env.TOY_WORKER !== '0', prop: env.TOY_PROP || '' };
    const OFF = 60;
    const B = makeBuilder(seed, PAL);
    const S = K.sculpt(makeSculpt(B));
    const tags = K.deform.tags(S);
    S.sun = B.norm([0.0, 0.6, 0.8]);
    S.res = 0.08;
    S.amb = 0.1;
    S.sky = 0.12;
    const STONE = { r: [0, 1, 2, 3, 4, 5, 6] };
    const GLOW = { r: [10, 11, 12], em: true };
    const CZ = -0.6, CR = 1.35; // the rune circle
    S.lights.push({ p: [0, 0.6, CZ], r: 2.6, s: 1.6 }, { p: [0, 2.6, -1.8], r: 3.2, s: 0.7 }, { p: [0, 1.6, 1.0], r: 3.0, s: 0.6 });

    // ---- the chamber: floor, back wall with tall windows, pillars ----
    S.box([0, -0.25, -0.8], [8, 0.25, 2.6], STONE, { res: 0.1 });
    S.box([0, 3.2, -2.9], [8, 3.2, 0.3], STONE, { res: 0.1 });
    const win = []; for (let i = 0; i <= 12; i++) { const a = Math.PI * (i / 12); win.push([Math.cos(a) * 0.42, 1.9 + Math.sin(a) * 0.42]); } win.push([-0.42, 0], [0.42, 0]);
    const WX = [-2.7, -1.35, 1.35, 2.7];
    for (const x of WX) S.extrude([win], [x, 0.9, -2.9], 1.0, STONE, { neg: true, ax: [[1, 0, 0], [0, 1, 0], [0, 0, 1]] });
    S.bake();
    S.box([0, 2.5, -3.7], [8, 2.5, 0.05], { r: [7, 8], em: true }, { res: 0.08 });
    for (const [x, y] of [[-2.8, 2.6], [-2.55, 3.3], [-1.2, 2.2], [-1.45, 3.0], [1.25, 2.9], [1.5, 2.3], [2.6, 3.1], [2.85, 2.4]]) S.ball([x, y, -3.6], 0.035, { r: [11, 12], em: true }, { res: 0.01 });
    S.ball([2.65, 2.75, -3.62], 0.16, { r: [11, 12], em: true }, { res: 0.02 }); // the moon in a window
    for (const x of [-3.4, -2.0, 0, 2.0, 3.4]) {
      if (x === 0) continue;
      S.lathe([x, 0, -2.45], 4.8, 0.14, STONE, { res: 0.04 });
      S.box([x, 0.12, -2.45], [0.22, 0.12, 0.22], STONE, { res: 0.03 });
    }
    // a great arched niche in the middle of the back wall, with a hanging crystal
    S.extrude([win.map(([x, y]) => [x * 1.6, y * 1.25])], [0, 0, -2.62], 0.3, STONE, { neg: true, ax: [[1, 0, 0], [0, 1, 0], [0, 0, 1]] });
    S.bake();
    S.tube([[0, 3.8, -2.75], [0, 3.0, -2.75]], 0.008, 0.008, { r: [0, 22] }, { res: 0.006 });
    S.lathe([0, 2.6, -2.75], 0.4, t => 0.12 * Math.sin(Math.PI * t), { r: [21, 20], em: true }, { res: 0.012 });
    // ---- the rune circle in the floor ----
    S.torus([0, 0.012, CZ], CR, 0.035, GLOW, { res: 0.02 });
    S.torus([0, 0.012, CZ], CR - 0.18, 0.02, GLOW, { res: 0.02 });
    for (let i = 0; i < 12; i++) { const a = Math.PI * 2 * i / 12; S.box([Math.cos(a) * (CR - 0.09), 0.012, CZ + Math.sin(a) * (CR - 0.09)], [0.05, 0.004, 0.02], GLOW, { res: 0.01 }); }
    for (let i = 0; i < 3; i++) { const a0 = Math.PI * 2 * i / 3 + 0.5, a1 = a0 + Math.PI * 2 / 3; S.tube([[Math.cos(a0) * (CR - 0.2), 0.012, CZ + Math.sin(a0) * (CR - 0.2)], [Math.cos(a1) * (CR - 0.2), 0.012, CZ + Math.sin(a1) * (CR - 0.2)]], 0.012, 0.012, GLOW, { res: 0.01 }); }
    // eight low pedestals around the circle
    const PED = []; for (let i = 0; i < 8; i++) { const a = Math.PI * (1 + i / 7); PED.push([Math.cos(a) * (CR + 0.5) * 1.3, CZ + Math.sin(a) * (CR + 0.5) * 0.5 + 0.1]); }
    for (const [x, z] of PED) { S.lathe([x, 0, z], 0.55, 0.12, STONE, { res: 0.02 }); S.lathe([x, 0.55, z], 0.05, 0.17, STONE, { res: 0.02 }); }
    S.bake();

    // ---- one floating rune stone per prop ----
    if (LAYER.prop) {
      const i = +LAYER.prop.slice(1), [x, z] = PED[[3, 4, 2, 5, 1, 6, 0, 7][i]];
      S.ball([x, 0.9, z], [0.12, 0.17, 0.12], { r: [5, 9, 10] }, { res: 0.01 });
      S.box([x, 0.91, z + 0.115], [0.045, 0.08, 0.005], { r: [11, 12], em: true }, { res: 0.006 });
      S.lathe([x, 0.61, z], 0.008, 0.14, { r: [10, 11], em: true }, { res: 0.008 });
    }
    S.bake();

    // ---- the arcanist in the circle ----
    const hx = 0.35 + (LAYER.worker ? 0 : OFF), hz = CZ;
    const P = (x, y, z) => [hx + x, y, hz + z];
    const ROBE = { r: [0, 13, 14, 15] }, SKIN = { r: [0, 16] };
    S.lathe(P(0, 0, 0), 1.0, t => 0.18 - 0.08 * t, ROBE, { tag: 'body', res: 0.014 });
    S.box(P(0, 0.5, 0.15), [0.03, 0.45, 0.01], { r: [0, 22] }, { tag: 'body', res: 0.008 }); // gold hem stripe
    S.ball(P(0, 1.12, 0), 0.1, SKIN, { tag: 'body', res: 0.012 });
    S.lathe(P(0, 1.02, -0.01), 0.42, t => 0.14 * (1 - t), ROBE, { tag: 'body', res: 0.012 }); // tall pointed hood
    S.ball(P(0, 1.03, 0.07), [0.07, 0.06, 0.03], { r: [0, 17] }, { tag: 'body', res: 0.01 }); // beard
    S.tube([P(-0.16, 0.98, 0), P(-0.2, 0.72, 0.08)], 0.045, 0.035, ROBE, { tag: 'body', res: 0.012 });
    // the staff arm, sculpted raised (posed down at rest, the staff on the floor)
    const SH = P(0.16, 0.98, 0);
    const HAND = P(0.3, 1.4, 0.12);
    S.tube([SH, HAND], 0.04, 0.035, ROBE, { tag: 'arm', res: 0.012 });
    S.tube([[HAND[0], HAND[1] - 0.6, HAND[2]], [HAND[0], HAND[1] + 0.45, HAND[2]]], 0.018, 0.015, { r: [0, 18, 19] }, { tag: 'arm', res: 0.008 });
    S.lathe([HAND[0], HAND[1] + 0.45, HAND[2]], 0.2, t => 0.05 * Math.sin(Math.PI * t), { r: [21, 20, 12], em: true }, { tag: 'arm', res: 0.008 });
    S.bake();

    const W = B.finish({ cam: { target: [0, 1.6, -1], dist: 16, pitch: 0.2, yaw: 0 }, detail: 26, dither: 0, radius: 9 });
    K.puppet(W, {
      parts: { body: { ids: tags.body, pivot: P(0, 0, 0), slices: 4 }, arm: { ids: tags.arm, pivot: SH, parent: 'body', slices: 2 } },
      pose(t, dt, pup) {
        const ease = x => x * x * (3 - 2 * x);
        let a = 1, breathe = 0;
        if (t < 1) breathe = Math.sin(t * Math.PI * 2);
        else if (t < 1.12) a = 1 - ease((t - 1) / 0.12);
        else if (t < 1.4) a = 0;
        else a = ease(Math.min(1, (t - 1.4) / 0.2));
        pup.pose.arm = { rot: [a * 50, 0, 0] };
        pup.pose.body = { rot: [-(1 - a) * 4, 0, 0], scale: [1, 1 + 0.012 * breathe, 1] };
      }
    });
    return W;
  }
  return { id: 'bb-sanctum', name: 'Tower sanctum', seed: 31, build };
};
