// Blacksmith Battles: Upgrades, an observatory study at dusk. A domed room with its roof slit open to the stars and a
// great brass telescope aimed up through it; a big chalkboard covered in diagrams; a long workbench along the back.
// A slim researcher in a green coat works at the chalkboard on the left.
// Environment variables: TOY_WORKER=0 parks the researcher; TOY_PROP=i0..i7 adds one instrument to the bench
// (the toy shows one per Researcher, up to 8).
// The clip: idle 0-1 s, act 1-1.6 (the researcher taps the board with a pointer: up 1-1.12, hold, down 1.4-1.6).
module.exports = ({ makeBuilder, makeSculpt, KIT: K }) => {
  const PAL = [
    0x05080a, 0x0c1418, 0x142028, 0x1e2e38, 0x2c404c, 0x405866, 0x5a7480, // 0-6 slate teal stone
    0x4a3010, 0x8a6020, 0xc89838, 0xf0d070, // 7-10 brass
    0x2a1a10, 0x4a2e1a, 0x6e4628, 0x946238, // 11-14 timber
    0x1a2a3a, 0x2a4058, 0x4a6a8a, // 15-17 dusk sky through the slit
    0xd9e6ff, 0xfff4c0, // 18-19 stars, lamp
    0x18301e, 0x2a5030, 0x3e7044, // 20-22 green coat
    0x2a1e18, 0xd8a07a, 0xe8e8e8, // 23-25 boots, skin, chalk
    0x10181a, 0x1a2628, // 26-27 chalkboard
    0x6a2a24, 0x2a4a7a // 28-29 globe sea/land accents
  ];
  function build(seed) {
    const env = (typeof process !== 'undefined' && process.env) || {};
    const LAYER = { worker: env.TOY_WORKER !== '0', prop: env.TOY_PROP || '' };
    const OFF = 60;
    const B = makeBuilder(seed, PAL);
    const S = K.sculpt(makeSculpt(B));
    const tags = K.deform.tags(S);
    S.sun = B.norm([0.2, 0.6, 0.75]);
    S.res = 0.08;
    S.amb = 0.11;
    S.sky = 0.13;
    const STONE = { r: [0, 1, 2, 3, 4, 5, 6] };
    const BRASS = { r: [7, 8, 9, 10] };
    const WOOD = { r: [0, 11, 12, 13, 14] };
    const LAMP = [[-0.5, 1.35, -2.0], [3.6, 1.35, -2.0]];
    for (const p of LAMP) S.lights.push({ p: [p[0], p[1] + 0.2, p[2] + 0.4], r: 2.2, s: 1.5 });
    S.lights.push({ p: [0, 3.0, -1.0], r: 3.6, s: 0.8 }, { p: [-1.6, 1.6, 0.8], r: 2.4, s: 0.8 });

    // ---- the room: floor, back wall, a dome with an open slit ----
    S.box([0, -0.25, -0.8], [8, 0.25, 2.6], STONE, { res: 0.1 });
        S.torus([0, 0.02, -0.8], 1.6, 0.03, BRASS, { res: 0.02 });
    S.box([0, 1.6, -2.9], [8, 1.6, 0.3], STONE, { res: 0.1 });
    S.lathe([0, 3.2, -1.2], 3.2, t => 4.2 * Math.cos(t * Math.PI / 2), STONE, { res: 0.09 });
    S.lathe([0, 3.1, -1.2], 3.2, t => 3.9 * Math.cos(t * Math.PI / 2), STONE, { neg: true });
    S.box([0, 5, 3.0], [9, 5, 4.2], STONE, { neg: true }); // cut the front half of the dome away
    S.box([0.6, 5.2, -2.5], [0.55, 2.6, 2.4], STONE, { neg: true }); // the slit
    S.bake();
    S.box([0.6, 5, -5.2], [1.2, 2.6, 0.05], { r: [15, 16, 17], em: true }, { res: 0.06 });
    S.box([0, 6, -7], [14, 4, 0.1], { r: [1, 2], em: true }, { res: 0.12 }); // night beyond the dome
    for (const [x, y] of [[0.3, 3.7], [0.9, 4.2], [0.5, 4.8], [0.85, 3.5], [0.2, 4.4]]) S.ball([x, y, -5.1], 0.03, { r: [18], em: true }, { res: 0.01 });
    for (const sx of [-1, 1]) S.box([0.6 + sx * 0.58, 4.6, -2.0], [0.05, 1.6, 0.05], BRASS, { res: 0.02 }); // slit rails
    // ---- the great telescope on a brass mount ----
    S.lathe([0.9, 0, -1.2], 0.9, t => 0.32 - 0.18 * t, BRASS, { res: 0.03 });
    S.ball([0.9, 1.0, -1.2], 0.15, BRASS, { res: 0.02 });
    S.tube([[0.4, 0.55, -0.6], [1.2, 4.0, -2.2]], 0.2, 0.13, { r: [0, 8, 9, 10] }, { res: 0.025 });
    for (const k of [0.15, 0.45, 0.75]) { const p = [0.4 + 0.8 * k, 0.55 + 3.45 * k, -0.6 - 1.6 * k]; S.torus(p, 0.2 - 0.07 * k, 0.025, { r: [7, 8] }, { res: 0.015, ax: [[1, 0, 0], [0, 0.42, 0.91], [0, -0.91, 0.42]] }); }
    S.lathe([0.38, 0.45, -0.58], 0.18, 0.05, { r: [7, 8] }, { res: 0.01 }); // eyepiece
    // ---- the chalkboard on the left ----
    S.box([-1.9, 1.5, -2.5], [1.05, 0.7, 0.04], { r: [26, 27] }, { res: 0.03 });
    S.box([-1.9, 1.5, -2.53], [1.12, 0.77, 0.03], WOOD, { res: 0.02 });
    S.box([-1.9, 0.78, -2.44], [1.05, 0.03, 0.06], WOOD, { res: 0.015 });
    const CH = { r: [25], em: true };
    S.torus([-2.35, 1.6, -2.45], 0.28, 0.008, CH, { res: 0.006, ax: [[1, 0, 0], [0, 0, 1], [0, -1, 0]] });
    S.torus([-2.35, 1.6, -2.45], 0.12, 0.008, CH, { res: 0.006, ax: [[1, 0, 0], [0, 0, 1], [0, -1, 0]] });
    S.tube([[-2.35, 1.6, -2.45], [-2.1, 1.85, -2.45]], 0.008, 0.008, CH, { res: 0.006 });
    for (let i = 0; i < 4; i++) S.box([-1.45, 1.95 - i * 0.16, -2.45], [0.35 - (i % 2) * 0.12, 0.008, 0.004], CH, { res: 0.005 });
    S.tube([[-1.75, 1.0, -2.45], [-1.45, 1.3, -2.45], [-1.2, 1.15, -2.45], [-0.95, 1.45, -2.45]], 0.008, 0.008, CH, { res: 0.006 });
    // ---- the long workbench at the back right, lamps on it ----
    S.box([2.2, 0.8, -2.3], [1.5, 0.04, 0.4], WOOD, { res: 0.03 });
    for (const dx of [-1.4, 1.4]) S.box([2.2 + dx, 0.4, -2.3], [0.05, 0.4, 0.35], WOOD, { res: 0.02 });
    for (const [x, y, z] of LAMP) {
      if (x < 0) continue;
      S.lathe([x, 0.84, z], 0.3, 0.03, BRASS, { res: 0.01 });
      S.ball([x, 1.2, z], 0.09, { r: [10, 19], em: true }, { res: 0.012 });
    }
    // a hanging lamp over the chalkboard
    S.tube([[-0.5, 3.2, -2.0], [-0.5, 1.5, -2.0]], 0.006, 0.006, { r: [0, 7] }, { res: 0.005 });
    S.ball([-0.5, 1.4, -2.0], 0.09, { r: [10, 19], em: true }, { res: 0.012 });
    S.bake();

    // ---- one instrument per prop on the bench ----
    if (LAYER.prop) {
      const i = +LAYER.prop.slice(1), x = 1.5 + i * 0.26, y = 0.84, z = -2.25 + (i % 2) * 0.12;
      if (i === 0) { S.lathe([x, y, z], 0.08, 0.06, WOOD, { res: 0.008 }); S.ball([x, y + 0.2, z], 0.12, { r: [0, 29, 28, 13] }, { res: 0.01 }); } // globe
      else if (i === 1) { S.tube([[x, y, z], [x, y + 0.3, z]], 0.01, 0.01, BRASS, { res: 0.006 }); S.ball([x, y + 0.3, z], 0.05, { r: [9, 10, 19], em: true }, { res: 0.008 }); for (const r of [0.1, 0.16]) S.torus([x, y + 0.3, z], r, 0.006, BRASS, { res: 0.005 }); } // orrery
      else if (i === 2) { S.lathe([x, y, z], 0.1, t => 0.06 * (1 - t) + 0.01, { r: [17, 18] }, { res: 0.008 }); S.lathe([x, y + 0.1, z], 0.1, t => 0.01 + 0.06 * t, { r: [17, 18] }, { res: 0.008 }); } // hourglass
      else if (i === 3) { S.torus([x, y + 0.16, z], 0.13, 0.012, BRASS, { res: 0.006, ax: [[1, 0, 0], [0, 0, 1], [0, -1, 0]] }); S.box([x, y + 0.16, z], [0.13, 0.008, 0.008], BRASS, { res: 0.005 }); } // astrolabe
      else if (i === 4) { for (let k = 0; k < 4; k++) S.box([x, y + 0.03 + k * 0.05, z], [0.13 - k * 0.01, 0.024, 0.09], { r: [0, 28 + (k % 2), 13] }, { res: 0.008 }); } // stack of books
      else if (i === 5) { S.ball([x, y + 0.08, z], 0.08, { r: [21, 22], em: true }, { res: 0.008 }); S.tube([[x, y + 0.14, z], [x, y + 0.28, z]], 0.02, 0.02, { r: [18] }, { res: 0.006 }); } // glowing flask
      else if (i === 6) { S.tube([[x - 0.12, y + 0.08, z], [x + 0.12, y + 0.22, z]], 0.035, 0.022, BRASS, { res: 0.006 }); S.tube([[x, y, z], [x, y + 0.14, z]], 0.008, 0.008, WOOD, { res: 0.005 }); } // small telescope
      else { S.box([x, y + 0.12, z], [0.11, 0.12, 0.02], { r: [0, 16, 17] }, { res: 0.008 }); S.box([x, y + 0.12, z + 0.025], [0.08, 0.09, 0.004], { r: [25] }, { res: 0.005 }); } // star chart
    }
    S.bake();

    // ---- the researcher at the chalkboard ----
    const hx = -0.9 + (LAYER.worker ? 0 : OFF), hz = -1.4;
    const P = (x, y, z) => [hx + x, y, hz + z];
    const COAT = { r: [0, 20, 21, 22] }, SKIN = { r: [0, 24] };
    for (const d of [-0.07, 0.07]) S.tube([P(d, 0.05, 0), P(d, 0.5, 0)], 0.045, 0.05, { r: [0, 23] }, { tag: 'body', res: 0.012 });
    S.lathe(P(0, 0.35, 0), 0.68, t => 0.14 - 0.03 * t, COAT, { tag: 'body', res: 0.014 });
    S.ball(P(0, 1.15, 0), 0.1, SKIN, { tag: 'body', res: 0.012 });
    S.ball(P(0, 1.2, -0.01), [0.105, 0.06, 0.1], { r: [0, 12, 13] }, { tag: 'body', res: 0.012 }); // hair
    S.box(P(0, 1.16, 0.095), [0.07, 0.015, 0.005], BRASS, { tag: 'body', res: 0.006 }); // spectacles
    S.tube([P(0.15, 0.98, 0), P(0.18, 0.7, 0.06)], 0.035, 0.035, COAT, { tag: 'body', res: 0.012 });
    // the pointer arm (sculpted reaching up to the board; posed down at rest)
    const SH = P(-0.15, 0.98, 0);
    const HAND = P(-0.4, 1.35, -0.25);
    S.tube([SH, HAND], 0.035, 0.032, COAT, { tag: 'arm', res: 0.012 });
    S.tube([HAND, [HAND[0] - 0.3, HAND[1] + 0.3, HAND[2] - 0.5]], 0.01, 0.006, WOOD, { tag: 'arm', res: 0.006 });
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
        pup.pose.arm = { rot: [-a * 70, 0, 0] };
        pup.pose.body = { rot: [(1 - a) * 3, 0, 0], scale: [1, 1 + 0.012 * breathe, 1] };
      }
    });
    return W;
  }
  return { id: 'bb-upg', name: 'Observatory', seed: 37, build };
};
