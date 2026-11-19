// Blacksmith Battles: the Barracks, a training yard on a clear morning. A timber barracks hall with green banners
// and a tall palisade behind, practice dummies and a weapon stand, packed sand underfoot. A captain in a long blue
// coat stands on a low drill platform at the right; your heroes (props) stand in two ranks in front of him.
// Environment variables: TOY_WORKER=0 parks the captain; TOY_PROP=h0..h11 adds one hero
// (h0-h5 the front rank from right to left, h6-h11 the back rank, set half a step over).
// The clip: idle 0-1 s, act 1-1.6 (the captain raises his sword in salute: up 1-1.15, hold, down 1.45-1.6).
module.exports = ({ makeBuilder, makeSculpt, KIT: K }) => {
  const PAL = [
    0x0a0a10, 0x2a2a34, // 0-1 deep shade
    0x6a5a40, 0x8a7654, 0xb09a70, 0xd0bc8c, // 2-5 sand
    0x2a1a10, 0x4a2e1a, 0x6e4628, 0x946238, 0xb88450, // 6-10 timber
    0x4a6a8a, 0x7a9cbc, 0xaecbe0, 0xdcecf4, // 11-14 morning sky
    0x1a4a2a, 0x2e6e3e, 0xc8a040, // 15-17 banner green, gold
    0x1e2a4a, 0x34487a, // 18-19 captain's coat
    0x2a1e18, 0x4a3628, 0xd8a07a, // 20-22 trousers, boots, skin
    0x5a6070, 0x9aa2b0, 0xd0d8e0, // 23-25 steel
    0x7a2a24, 0xb04238, 0x6a5a2a, 0xa08a40, 0x3a2a5a, 0x5a4488, 0x2a5a5a, 0x3a8a8a, // 26-33 heroes' tabards
    0x8a8a70, 0xb0b090 // 34-35 straw
  ];
  function build(seed) {
    const env = (typeof process !== 'undefined' && process.env) || {};
    const LAYER = { worker: env.TOY_WORKER !== '0', prop: env.TOY_PROP || '' };
    const OFF = 60;
    const B = makeBuilder(seed, PAL);
    const S = K.sculpt(makeSculpt(B));
    const tags = K.deform.tags(S);
    S.sun = B.norm([-0.5, 0.75, 0.5]); // morning sun from the upper left, in front
    S.res = 0.08;
    S.amb = 0.16;
    S.sky = 0.18;
    const SAND = { r: [1, 2, 3, 4, 5] };
    const WOOD = { r: [0, 6, 7, 8, 9, 10] };
    const STEEL = { r: [0, 23, 24, 25] };
    const GREEN = { r: [0, 15, 16] }, GOLD = { r: [0, 17] };

    // ---- sky, ground, palisade ----
    for (const [y, h, c] of [[0.8, 1.0, 14], [2.6, 0.8, 13], [4.2, 0.8, 12], [6.0, 1.0, 11]]) S.box([0, y, -9], [30, h, 0.2], { r: [c], em: true }, { res: 0.15 });
    S.box([0, -0.25, -3], [13, 0.25, 6], SAND, { res: 0.1 });
    for (let i = 0; i < 44; i++) { const x = -10.75 + i * 0.5; S.tube([[x, 0, -5.0], [x, 2.2 + (i % 3) * 0.12, -5.0]], 0.24, 0.24, WOOD, { res: 0.05 }); S.lathe([x, 2.2 + (i % 3) * 0.12, -5.0], 0.25, t => 0.24 * (1 - t), WOOD, { res: 0.04 }); }
    S.bake();
    // ---- the barracks hall behind the yard ----
    S.box([-0.6, 1.3, -3.6], [2.8, 1.3, 0.8], WOOD, { res: 0.06 });
    S.extrude([[[-3.1, 0], [0, 1.5], [3.1, 0]]], [-0.6, 2.6, -4.5], 1.8, { r: [0, 26, 27] }, { res: 0.06 }); // red tiled roof
    for (const x of [-3.0, -1.5, 0.3, 1.8]) S.box([x, 1.3, -2.78], [0.08, 1.3, 0.04], { r: [0, 6, 7] }, { res: 0.025 });
    S.box([-0.6, 1.3, -2.78], [2.82, 0.05, 0.04], { r: [0, 6, 7] }, { res: 0.025 });
    S.box([-0.6, 0.65, -2.79], [0.5, 0.65, 0.03], { r: [0, 6, 7] }, { res: 0.025 }); // door
    for (const x of [-2.25, 1.05]) S.box([x, 1.8, -2.79], [0.32, 0.25, 0.03], { r: [0, 1] }, { res: 0.02 }); // windows
    for (const x of [-1.45, 0.25]) { // long green banners on the front of the hall
      S.box([x, 1.95, -2.72], [0.22, 0.6, 0.02], GREEN, { res: 0.02 });
      S.box([x, 2.2, -2.7], [0.12, 0.12, 0.02], GOLD, { res: 0.015 });
    }
    // a tall flag pole on the left
    S.tube([[-3.9, 0, -2.0], [-3.9, 4.0, -2.0]], 0.04, 0.035, WOOD, { res: 0.015 });
    S.box([-3.45, 3.65, -2.0], [0.42, 0.26, 0.02], GREEN, { res: 0.02 });
    // ---- practice dummies, a weapon stand and a drill platform ----
    for (const [x, z] of [[-3.4, -0.6], [4.0, -2.3]]) {
      S.tube([[x, 0, z], [x, 1.1, z]], 0.04, 0.04, WOOD, { res: 0.015 });
      S.tube([[x - 0.3, 0.85, z], [x + 0.3, 0.85, z]], 0.035, 0.035, WOOD, { res: 0.015 });
      S.ball([x, 0.75, z], [0.17, 0.3, 0.15], { r: [1, 34, 35] }, { res: 0.02 });
      S.ball([x, 1.17, z], 0.12, { r: [1, 34, 35] }, { res: 0.015 });
    }
    S.box([-2.6, 0.75, -2.3], [0.6, 0.04, 0.08], WOOD, { res: 0.02 });
    for (const dx of [-0.45, -0.15, 0.15, 0.45]) S.tube([[-2.6 + dx, 0.05, -2.2], [-2.6 + dx, 1.25, -2.35]], 0.018, 0.018, dx > 0 ? STEEL : WOOD, { res: 0.01 });
    S.box([1.9, 0.15, 0.1], [0.5, 0.15, 0.42], WOOD, { res: 0.03, rd: 0.02 });
    S.bake();

    // ---- the heroes: two ranks facing the camera ----
    if (LAYER.prop) {
      const i = +LAYER.prop.slice(1), back = i >= 6, k = i % 6;
      const x = 0.65 - k * 0.62 - (back ? 0.31 : 0), z = back ? -0.75 : 0.05;
      const [a, b] = [[26, 27], [28, 29], [30, 31], [32, 33], [18, 19], [15, 16]][i % 6];
      const R = { r: [0, a, b] }, SKIN = { r: [0, 22] };
      for (const d of [-0.07, 0.07]) S.tube([[x + d, 0.05, z], [x + d, 0.5, z]], 0.045, 0.05, { r: [0, 20] }, { res: 0.012 });
      S.tube([[x, 0.45, z], [x, 0.98, z]], 0.12, 0.12, STEEL, { res: 0.014 }); // mail
      S.box([x, 0.7, z + 0.1], [0.1, 0.28, 0.03], R, { res: 0.012 }); // tabard
      S.ball([x, 1.12, z], 0.1, SKIN, { res: 0.012 });
      S.ball([x, 1.17, z], [0.11, 0.08, 0.11], STEEL, { res: 0.01 }); // helm
      for (const sx of [-1, 1]) S.tube([[x + sx * 0.15, 0.97, z], [x + sx * 0.17, 0.66, z + 0.03]], 0.034, 0.034, STEEL, { res: 0.012 });
      // a shield on the left arm for odd heroes, a spear on the right for the rest
      if (i % 2) S.ball([x - 0.2, 0.68, z + 0.08], [0.05, 0.17, 0.14], R, { res: 0.01 });
      else S.tube([[x + 0.19, 0.05, z + 0.03], [x + 0.19, 1.6, z + 0.03]], 0.014, 0.014, WOOD, { res: 0.01 });
      if (!(i % 2)) S.lathe([x + 0.19, 1.6, z + 0.03], 0.13, t => 0.035 * (1 - t), STEEL, { res: 0.008 });
    }
    S.bake();

    // ---- the captain on the drill platform ----
    const hx = 1.9 + (LAYER.worker ? 0 : OFF), hz = 0.1, fy = 0.3;
    const P = (x, y, z) => [hx + x, fy + y, hz + z];
    const COAT = { r: [0, 18, 19] }, SKIN = { r: [0, 22] };
    for (const d of [-0.07, 0.07]) S.tube([P(d, 0.05, 0), P(d, 0.5, 0)], 0.045, 0.05, { r: [0, 21] }, { tag: 'body', res: 0.012 });
    S.lathe(P(0, 0.35, 0), 0.7, t => 0.15 - 0.03 * t, COAT, { tag: 'body', res: 0.014 }); // long coat
    S.box(P(0, 0.72, 0.13), [0.12, 0.03, 0.02], GOLD, { tag: 'body', res: 0.01 }); // belt
    S.ball(P(0, 1.17, 0), 0.1, SKIN, { tag: 'body', res: 0.012 });
    S.lathe(P(0, 1.22, 0), 0.06, 0.13, COAT, { tag: 'body', res: 0.01 }); // hat brim
    S.lathe(P(0, 1.27, 0), 0.1, 0.08, COAT, { tag: 'body', res: 0.01 });
    S.box(P(0.06, 1.37, 0), [0.015, 0.06, 0.015], { r: [0, 26, 27] }, { tag: 'body', res: 0.008 }); // plume
    S.tube([P(-0.15, 1.0, 0), P(-0.17, 0.72, 0.06)], 0.035, 0.035, COAT, { tag: 'body', res: 0.012 });
    // the sword arm (sculpted raised; posed down at rest)
    const SH = P(0.15, 1.0, 0);
    const HAND = P(0.3, 1.45, 0.15);
    S.tube([SH, HAND], 0.035, 0.032, COAT, { tag: 'arm', res: 0.012 });
    S.box([HAND[0], HAND[1] + 0.33, HAND[2]], [0.025, 0.32, 0.012], STEEL, { tag: 'arm', res: 0.01 });
    S.box([HAND[0], HAND[1] - 0.01, HAND[2]], [0.03, 0.02, 0.1], GOLD, { tag: 'arm', res: 0.01 });
    S.bake();

    const W = B.finish({ cam: { target: [0, 1.6, -1], dist: 16, pitch: 0.2, yaw: 0 }, detail: 26, dither: 0, radius: 11 });
    K.puppet(W, {
      parts: { body: { ids: tags.body, pivot: P(0, 0, 0), slices: 4 }, arm: { ids: tags.arm, pivot: SH, parent: 'body', slices: 2 } },
      pose(t, dt, pup) {
        const ease = x => x * x * (3 - 2 * x);
        let a = 1, breathe = 0; // 1 = sword lowered, 0 = raised in salute
        if (t < 1) breathe = Math.sin(t * Math.PI * 2);
        else if (t < 1.15) a = 1 - ease((t - 1) / 0.15);
        else if (t < 1.45) a = 0;
        else a = ease(Math.min(1, (t - 1.45) / 0.15));
        pup.pose.arm = { rot: [a * 80, 0, 0] };
        pup.pose.body = { rot: [-(1 - a) * 3, 0, 0], scale: [1, 1 + 0.012 * breathe, 1] };
      }
    });
    return W;
  }
  return { id: 'bb-barracks', name: 'Training yard', seed: 19, build };
};
