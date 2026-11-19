// Blacksmith Battles: forge diorama v2.
// Lessons borrowed from other ink-studio work: a cut-away diorama on a thick slab against a dark void,
// detail from structure (bricks, iron bands, rivets, hoops) not noise, quiet flat areas, and a chibi
// smith (big head, big eyes with a highlight, chunky boots and gloves) so he reads at small sizes.
module.exports = ({ makeBuilder, makeSculpt, KIT: K, flame }) => {
  const PAL = [
    0x07080b, // 0 void / ink
    0x16141a, // 1 deep shadow
    0x2a2630, // 2 dark stone
    0x423c44, // 3 stone
    0x5e5560, // 4 light stone
    0x847a80, // 5 pale stone
    0x2a1a14, // 6 dark wood
    0x4a2e1e, // 7 wood
    0x74482a, // 8 light wood
    0x1c1e26, // 9 dark iron
    0x343a48, // 10 iron
    0x56607a, // 11 light iron
    0x9aa6c0, // 12 iron shine
    0x5a2414, // 13 dark copper
    0x9a4a22, // 14 copper
    0xd88038, // 15 bright copper
    0xb02a18, // 16 ember red
    0xff6a20, // 17 orange
    0xffb838, // 18 yellow
    0xfff0a0, // 19 white hot
    0x3a2418, // 20 apron dark
    0x6a4228, // 21 apron
    0xb87850, // 22 skin
    0xe0a476, // 23 skin light
    0x2a3a5a, // 24 shirt dark
    0x3e5a8a, // 25 shirt
    0x101014, // 26 coal
    0x2a2a32, // 27 coal shine
    0x8a3a2a, // 28 beard dark (ginger)
    0xc0602e, // 29 beard
    0xe08a40, // 30 beard light
    0xffffff, // 31 eye highlight
    0xe07a6a, // 32 blush
    0x3a2a22, // 33 mortar
    0x5a3a2a, // 34 brick dark
    0x7a4a32, // 35 brick
    0x9a6040 // 36 brick light
  ];
  const T = 1.0; // one hammer blow per second
  const IMPACT = 0.78; // when in the blow the hammer lands

  function build(seed) {
    const B = makeBuilder(seed, PAL);
    const S = K.sculpt(makeSculpt(B));
    S.sun = B.norm([-0.35, 0.85, 0.5]);
    S.res = 0.08;
    S.amb = 0.2;
    S.sky = 0.25;
    const rnd = (i, s) => K.hash(i, s); // stable 0..1 per index
    const WOOD = { r: [6, 7, 8] };
    const IRON = { r: [9, 10, 11] };
    const IRONHI = { r: [10, 11, 12] };
    const COPPER = { r: [13, 14, 15] };
    const COAL = { r: [26, 27] };
    const BRICKS = [{ r: [34, 35, 35] }, { r: [34, 35, 35] }, { r: [34, 34, 35] }];
    const FLAGS = [{ r: [2, 3, 4] }, { r: [2, 3, 3] }, { r: [3, 4, 5] }];

    // fire light: one big warm lamp in the furnace mouth, a small one on the anvil
    S.lights.push({ p: [-1.9, 0.9, 0.2], r: 4.2, s: 1.0 }, { p: [0.45, 1.3, 0.5], r: 1.2, s: 0.45 });

    // ---- the slab: a thick stone island the room sits on ----
    S.box([0, -0.35, 0.0], [3.6, 0.35, 2.1], { r: [1, 2, 2, 3] }, { res: 0.1, rd: 0.12 });
    // flagstones on top, each its own slab with a mortar gap
    const fw = 0.9, fd = 0.75;
    for (let ix = 0; ix < 8; ix++)
      for (let iz = 0; iz < 5; iz++) {
        const x = -3.6 + fw * 0.5 + ix * fw + (iz % 2) * 0.2,
          z = -2.1 + fd * 0.5 + iz * fd;
        if (x > 3.3) continue;
        const h = 0.04 + 0.02 * rnd(ix * 9 + iz, 3);
        S.box([x, h, z], [fw * 0.5 - 0.04, h, fd * 0.5 - 0.04], FLAGS[(ix * 7 + iz * 3) % 3], { res: 0.08, rd: 0.03 });
      }

    // ---- two brick walls, back and left, cut low at the front edge like a diorama ----
    const bw = 0.5, bh = 0.25;
    for (let row = 0; row < 13; row++) {
      const y = 0.08 + bh * 0.5 + row * bh;
      for (let i = 0; i < 15; i++) {
        const x = -3.55 + bw * 0.5 + i * bw + (row % 2) * bw * 0.5;
        if (x > 3.5) continue;
        S.box([x, y, -2.05], [bw * 0.5 - 0.04, bh * 0.5 - 0.035, 0.14], BRICKS[(i * 5 + row * 3) % 3], { res: 0.07, rd: 0.02 });
      }
      // left wall steps down toward the viewer so it never hides the room
      const runs = Math.max(0, Math.min(9, 13 - row) - 1);
      for (let i = 0; i < runs; i++) {
        const z = -1.85 + bw * 0.5 + i * bw + (row % 2) * bw * 0.5;
        if (z > 2.3) continue;
        S.box([-3.45, y, z], [0.14, bh * 0.5 - 0.035, bw * 0.5 - 0.04], BRICKS[(i * 3 + row * 5) % 3], { res: 0.07, rd: 0.02 });
      }
    }
    // mortar behind the bricks so gaps read dark, not see-through
    S.box([0, 1.7, -2.15], [3.55, 1.62, 0.06], { r: [33] }, { res: 0.12 });
    S.box([-3.55, 1.3, 0.2], [0.06, 1.22, 2.05], { r: [33] }, { res: 0.12 });

    // ---- furnace: stone body, arched mouth, iron bands with rivets, copper hood and chimney ----
    const FX = -1.9, FZ = -1.2;
    const STONE = { r: [2, 3, 4, 5] };
    S.box([FX, 0.75, FZ], [0.95, 0.68, 0.75], STONE, { res: 0.07, rd: 0.08 });
    S.box([FX, 0.5, FZ + 0.55], [0.42, 0.32, 0.5], STONE, { neg: true });
    S.ball([FX, 0.82, FZ + 0.55], [0.42, 0.34, 0.5], STONE, { neg: true });
    // stone lip around the mouth
    S.torus ? null : null;
    for (const y of [0.32, 1.28]) {
      S.box([FX, y, FZ + 0.76], [0.97, 0.05, 0.02], IRON, { res: 0.035 });
      for (let k = 0; k < 7; k++) {
        const x = FX - 0.84 + k * 0.28;
        if (Math.abs(x - FX) < 0.42 && y < 1) continue;
        S.ball([x, y, FZ + 0.79], 0.03, IRONHI, { res: 0.018 });
      }
    }
    S.bake(); // bake the carved furnace first so its mouth carve does not eat the fire
    // coals and fire in the mouth
    for (let i = 0; i < 9; i++)
      S.ball([FX - 0.32 + i * 0.08, 0.24 + 0.04 * (i % 2), FZ + 0.4 + 0.12 * ((i * 5) % 3)], 0.07, { r: [16, 17, 18], em: true }, { res: 0.03 });
    // static flame tongues: orange outside, yellow inside, white-hot core
    const tongue = (x, z, h, w) => {
      S.lathe([x, 0.26, z], h, t => w * Math.pow(1 - t, 0.8) * (0.6 + 0.4 * Math.sin(Math.min(1, t * 3) * 1.57)), { r: [16, 17], em: true }, { res: 0.022 });
      S.lathe([x, 0.27, z + 0.03], h * 0.72, t => w * 0.66 * Math.pow(1 - t, 0.8), { r: [18], em: true }, { res: 0.02 });
      S.lathe([x, 0.27, z + 0.06], h * 0.38, t => w * 0.36 * (1 - t), { r: [19], em: true }, { res: 0.016 });
    };
    tongue(FX - 0.12, FZ + 0.5, 0.5, 0.15);
    tongue(FX + 0.13, FZ + 0.55, 0.36, 0.12);
    tongue(FX - 0.3, FZ + 0.58, 0.26, 0.09);
    // copper hood and chimney
    S.lathe([FX, 1.43, FZ], 0.42, t => 0.85 - 0.5 * t, COPPER, { res: 0.05 });
    S.lathe([FX, 1.85, FZ], 2.0, 0.26, COPPER, { res: 0.05 });
    for (const y of [1.48, 2.3, 3.1]) S.lathe([FX, y, FZ], 0.06, y < 2 ? 0.86 : 0.3, IRON, { res: 0.03 });

    // ---- bellows beside the furnace ----
    const BX = -0.7, BZ = -1.35;
    S.box([BX, 0.42, BZ], [0.32, 0.05, 0.22], WOOD, { res: 0.04, rd: 0.02 });
    S.box([BX, 0.62, BZ], [0.3, 0.12, 0.19], { r: [20, 21] }, { res: 0.04, rd: 0.08 });
    S.box([BX, 0.8, BZ], [0.32, 0.05, 0.22], WOOD, { res: 0.04, rd: 0.02 });
    S.tube([[BX - 0.32, 0.6, BZ], [FX + 0.95, 0.55, BZ]], 0.05, 0.04, IRON, { res: 0.03 });
    S.tube([[BX + 0.3, 0.8, BZ], [BX + 0.55, 0.95, BZ]], 0.03, 0.03, WOOD, { res: 0.025 });
    S.lathe([BX + 0.1, 0.08, BZ], 0.3, 0.07, WOOD, { res: 0.03 });

    // ---- tool rack on the back wall: a board with tongs and hammers hanging ----
    S.box([1.3, 2.05, -1.86], [0.9, 0.07, 0.05], WOOD, { res: 0.04, rd: 0.02 });
    for (const [x, kind] of [[0.65, 'tongs'], [1.0, 'hammer'], [1.35, 'tongs'], [1.75, 'hammer']]) {
      S.ball([x, 2.02, -1.8], 0.025, IRONHI, { res: 0.015 });
      if (kind === 'hammer') {
        S.tube([[x, 1.98, -1.78], [x, 1.45, -1.78]], 0.028, 0.028, WOOD, { res: 0.02 });
        S.box([x, 1.42, -1.78], [0.11, 0.05, 0.05], IRONHI, { res: 0.02, rd: 0.01 });
      } else {
        S.tube([[x, 1.98, -1.78], [x - 0.06, 1.4, -1.78]], 0.02, 0.018, IRON, { res: 0.018 });
        S.tube([[x, 1.98, -1.78], [x + 0.06, 1.4, -1.78]], 0.02, 0.018, IRON, { res: 0.018 });
      }
    }

    // ---- anvil on a ringed stump ----
    const AX = 0.45, AZ = 0.45, AY = -0.2;
    S.lathe([AX, 0.06, AZ], 0.62 + AY, t => 0.36 - 0.04 * t, WOOD, { res: 0.05 });
    S.lathe([AX, 0.67 + AY, AZ], 0.03, 0.33, { r: [8] }, { res: 0.03 }); // pale cut top
    for (const y of [0.16, 0.36]) S.lathe([AX, y, AZ], 0.04, 0.375, IRON, { res: 0.025 });
    // classic anvil: flared foot, narrow waist, wide face, horn, heel
    S.box([AX, 0.74 + AY, AZ], [0.3, 0.05, 0.2], IRON, { res: 0.03, rd: 0.02 });
    S.box([AX, 0.86 + AY, AZ], [0.15, 0.09, 0.12], IRON, { res: 0.03, rd: 0.02 });
    S.box([AX, 1.0 + AY, AZ], [0.36, 0.07, 0.17], IRONHI, { res: 0.025, rd: 0.02 });
    S.tube([[AX + 0.36, 1.0 + AY, AZ], [AX + 0.72, 1.03 + AY, AZ]], 0.08, 0.015, IRONHI, { res: 0.02 });
    S.box([AX - 0.42, 1.01 + AY, AZ], [0.07, 0.05, 0.12], IRONHI, { res: 0.02, rd: 0.015 });
    // the glowing bar being worked
    S.box([AX + 0.02, 1.1 + AY, AZ], [0.22, 0.03, 0.06], { r: [17, 18, 19], em: true }, { res: 0.018, rd: 0.01 });

    // ---- quench barrel with hoops ----
    S.lathe([2.75, 0.06, 0.75], 0.62, t => 0.3 + 0.05 * Math.sin(t * Math.PI), WOOD, { res: 0.04 });
    for (const y of [0.15, 0.58]) S.lathe([2.75, y, 0.75], 0.04, 0.33, IRON, { res: 0.022 });
    S.lathe([2.75, 0.62, 0.75], 0.02, 0.28, { r: [10, 11, 12] }, { res: 0.03 });

    // ---- ore bin: a wooden crate heaped with copper, iron and coal ----
    const OX = 2.45, OZ = -0.6;
    S.box([OX, 0.3, OZ], [0.65, 0.24, 0.5], WOOD, { res: 0.05, rd: 0.03 });
    S.box([OX, 0.36, OZ], [0.58, 0.24, 0.43], WOOD, { neg: true });
    for (const z of [-0.5, 0.5]) S.box([OX, 0.3, OZ + z], [0.67, 0.04, 0.02], IRON, { res: 0.025 });
    const ores = [COPPER, IRON, COAL, COPPER, IRON, COPPER, COAL, IRON, COPPER, IRON, COAL, COPPER];
    for (let i = 0; i < ores.length; i++) {
      const a = i * 2.39996,
        rr = 0.42 * Math.sqrt((i + 0.5) / ores.length);
      S.rock([OX + Math.cos(a) * rr, 0.5 + 0.18 * (1 - rr / 0.42), OZ + Math.sin(a) * rr * 0.8], 0.15, ores[i], { res: 0.035 });
    }
    // a couple of spilled lumps on the floor
    S.rock([OX - 0.85, 0.13, OZ + 0.55], 0.1, COPPER, { res: 0.03 });
    S.rock([OX - 0.6, 0.12, OZ + 0.8], 0.08, IRON, { res: 0.03 });

    S.bake();

    // ---- the smith: behind the anvil, facing the viewer; baked last so he moves without leaving holes ----
    const tags = K.deform.tags(S);
    const SX = AX - 0.08, SZ = AZ - 0.62;
    const P = (f, y, sd) => [SX + sd, y, SZ + f]; // f: forward toward the viewer, sd: toward his hammer side
    const SKIN = { r: [22, 23] }, SHIRT = { r: [24, 25] }, APRON = { r: [20, 21] }, BEARD = { r: [28, 29, 30] };
    const BOOT = { r: [6, 7] }, GLOVE = { r: [20, 21] }, PANTS = { r: [9, 10] };
    for (const d of [-0.13, 0.13]) {
      S.box(P(0.05, 0.11, d), [0.09, 0.08, 0.14], BOOT, { tag: 'body', res: 0.025, rd: 0.05 });
      S.tube([P(0, 0.18, d), P(0, 0.42, d)], 0.085, 0.09, PANTS, { tag: 'body', res: 0.025 });
    }
    S.ball(P(0, 0.68, 0), [0.29, 0.33, 0.28], SHIRT, { tag: 'body', res: 0.03 });
    S.ball(P(0.08, 0.6, 0), [0.27, 0.3, 0.24], APRON, { tag: 'body', res: 0.025 });
    S.lathe(P(0, 0.5, 0), 0.06, 0.29, { r: [6, 7] }, { tag: 'body', res: 0.02 });
    // off arm on the hip
    S.tube([P(-0.02, 0.86, -0.28), P(0.1, 0.62, -0.33)], 0.075, 0.07, SKIN, { tag: 'body', res: 0.025 });
    S.ball(P(0.12, 0.58, -0.33), 0.08, GLOVE, { tag: 'body', res: 0.02 });
    const HY = 1.17;
    S.ball(P(0.02, HY, 0), 0.3, SKIN, { tag: 'head', res: 0.022 });
    S.lathe(P(0.02, HY + 0.1, 0), 0.06, 0.305, { r: [16, 16] }, { tag: 'head', res: 0.018 }); // red headband
    S.ball(P(0.13, HY - 0.15, 0), [0.24, 0.2, 0.21], BEARD, { tag: 'head', res: 0.02 });
    S.ball(P(0.22, HY - 0.28, 0), [0.14, 0.1, 0.12], BEARD, { tag: 'head', res: 0.02 });
    S.ball(P(0.12, HY - 0.02, 0), [0.22, 0.05, 0.17], BEARD, { tag: 'head', res: 0.016 }); // moustache
    S.ball(P(0.31, HY + 0.02, 0), 0.06, SKIN, { tag: 'head', res: 0.014 }); // nose
    for (const sd of [-1, 1]) {
      const e = sd * 0.13;
      S.ball(P(0.25, HY + 0.06, e), [0.035, 0.06, 0.03], { r: [0] }, { tag: 'head', res: 0.01 });
      S.ball(P(0.275, HY + 0.08, e + 0.012), 0.014, { r: [31], em: true }, { tag: 'head', res: 0.008 });
      S.ball(P(0.23, HY - 0.02, sd * 0.2), [0.04, 0.03, 0.02], { r: [32] }, { tag: 'head', res: 0.01 });
      S.ball(P(0.25, HY + 0.15, e), [0.05, 0.018, 0.02], BEARD, { tag: 'head', res: 0.01 }); // brows
    }
    // hammer arm in the strike pose: shoulder, gloved fist, handle forward, head down on the bar
    const SH = P(0, 0.88, 0.34);
    const HIT = [AX + 0.2, 1.1 + AY, AZ];
    S.ball(SH, 0.1, SHIRT, { tag: 'arm', res: 0.022 });
    S.tube([SH, P(0.3, 0.86, 0.4)], 0.08, 0.075, SKIN, { tag: 'arm', res: 0.022 });
    S.ball(P(0.34, 0.86, 0.4), 0.085, GLOVE, { tag: 'arm', res: 0.02 });
    S.tube([P(0.34, 0.88, 0.4), [HIT[0], HIT[1] + 0.12, HIT[2] - 0.02]], 0.03, 0.03, WOOD, { tag: 'arm', res: 0.018 });
    S.box([HIT[0], HIT[1] + 0.13, HIT[2]], [0.075, 0.1, 0.07], IRONHI, { tag: 'arm', res: 0.018, rd: 0.02 });
    S.bake();

    const W = B.finish({
      cam: { target: [-0.1, 1.15, -0.3], dist: 7.6, pitch: 0.4, yaw: 0.32 },
      detail: 26,
      dither: 0,
      radius: 4.5
    });
    // strike pose is the sculpted pose; rotate the arm back about the shoulder to lift
    const ease = x => x * x * (3 - 2 * x);
    K.puppet(W, {
      parts: {
        body: { ids: tags.body, pivot: [SX, 0.04, SZ], slices: 4 },
        head: { ids: tags.head, pivot: [SX, 0.92, SZ], parent: 'body' },
        arm: { ids: tags.arm, pivot: SH, parent: 'body', slices: 2 }
      },
      pose(t, dt, pup) {
        const u = (t % T) / T;
        let lift, lean, squash;
        if (u < 0.5) lift = ease(u / 0.5); // raise
        else if (u < 0.66) lift = 1 + 0.06 * Math.sin(((u - 0.5) / 0.16) * Math.PI); // hang at the top
        else if (u < IMPACT) { const k = (u - 0.66) / (IMPACT - 0.66); lift = 1 - k * k; } // slam
        else lift = -0.04 * Math.sin(((u - IMPACT) / (1 - IMPACT)) * Math.PI); // rebound
        squash = u >= IMPACT && u < IMPACT + 0.1 ? 1 - (u - IMPACT) / 0.1 : 0;
        lean = lift * 6 - squash * 4;
        pup.pose.arm = { rot: [-lift * 120, 0, 0] };
        pup.pose.body = { rot: [-lean, 0, 0], scale: [1 + 0.05 * squash, 1 - 0.06 * squash, 1 + 0.05 * squash] };
        pup.pose.head = { rot: [lift * 4, 0, 0] };
      }
    });
    return W;
  }
  return { id: 'bb-forge-live', name: 'Forge diorama', seed: 11, build };
};
