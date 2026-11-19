// Blacksmith Battles: the web toy's forge, rendered into sprite layers by ../tools/render.js and ../tools/pack.py.
// Environment variables pick what is drawn, so each layer can be cut out on its own:
//   TOY_SMITH=0 moves the smith out of view, TOY_FIRE=0 the flames, TOY_PIECE=sword|axe|spear|shield|hammer|bar puts a hot piece on the anvil.
// The clip holds every move (see pose): idle 0-1 s, raise 1-1.5, ready 1.5-2, slam 2-2.25, recover 2.25-2.5.
// "Huge environment, small hero" forge, in the clean foundry-tower style: a tall cut-away stone hall,
// a great furnace built into the back wall with an arched glowing mouth and a hood rising out of frame,
// a molten gold channel across the floor to a casting basin, an anvil on a round dais, and a slim smith
// in a red cape swinging a hammer. Few shades, no texture noise.
module.exports = ({ makeBuilder, makeSculpt, KIT: K, motes }) => {
  const PAL = [
    0x07060a, 0x14111a, 0x201b27, 0x2e2736, 0x3f3548, 0x54485c, 0x6e6074, 0x8c7c8e, // 0-7 void..lit stone (dusty violet)
    0x4a3010, 0x8a6020, 0xc89838, 0xf0d070, // 8-11 brass
    0xff7a20, 0xffc040, 0xfff2b0, // 12-14 molten
    0x5a1010, 0xa82a20, 0xd8a07a, 0x2a2a30, 0x8aa8b0, 0x40505a, // 15-20 cape dark, cape, skin, cloth, iron light, iron
    0x6a3a1a, 0x9a5a2a, // 21-22 warm firelit stone
    0x7a1810, 0xc8321e, // 23-24 cooling reds for the hot pieces
    0x0c0c10, 0x1a1c22, 0x2a2e36, 0x464c56 // 25-28 blackened iron (furnace, hood and chimney)
  ];
  function build(seed) {
    const env = (typeof process !== 'undefined' && process.env) || {};
    const LAYER = { smith: env.TOY_SMITH !== '0', fire: env.TOY_FIRE !== '0', piece: env.TOY_PIECE || '' };
    const OFF = 60; // parked out of view
    const B = makeBuilder(seed, PAL);
    const S = K.sculpt(makeSculpt(B));
    S.sun = B.norm([0.3, 0.5, 0.8]);
    S.res = 0.08;
    const tags = K.deform.tags(S);
    S.amb = 0.1;
    S.sky = 0.12;
    const STONE = { r: [1, 2, 3, 4, 5, 6] };
    const TRIM = { r: [2, 3, 4, 5, 6, 7] };
    const GOLD = { r: [8, 9, 10, 11] };
    const IRON = { r: [1, 20, 19] };
    const HOT = { r: [12, 13, 14], em: true };
    const FURN = { r: [25, 25, 26, 27, 28] };
    const R = 5.2, RI = 4.7, H = 11;
    S.lights.push({ p: [0, 1.4, -3.2], r: 6.5, s: 1.3 }, { p: [0, 1.6, 0.9], r: 3.5, s: 0.7 }, { p: [2.4, 0.6, 1.4], r: 2.2, s: 0.5 });

    // ---- floor and a half-round hall, front cut away ----
    S.lathe([0, -0.5, 0], 0.5, R + 0.3, TRIM, { res: 0.1 });
    S.torus([0, 0.02, 0], R + 0.15, 0.1, TRIM, { res: 0.05 });
    S.lathe([0, 0, 0], H, R, STONE, { res: 0.1 });
    S.lathe([0, -0.1, 0], H + 0.2, RI, STONE, { neg: true });
    S.box([0, H / 2, R], [R + 1, H / 2 + 1, R], STONE, { neg: true });
    // tall narrow windows up the side walls (not behind the furnace)
    const arch = (w, h) => { const p = []; for (let i = 0; i <= 12; i++) { const a = Math.PI * (i / 12); p.push([Math.cos(a) * w, h + Math.sin(a) * w]); } p.push([-w, 0], [w, 0]); return p; };
    for (const k of [-3, -2, 2, 3]) {
      const a = (k / 7) * Math.PI;
      const rad = [Math.sin(a), 0, -Math.cos(a)], tan = [Math.cos(a), 0, Math.sin(a)];
      for (const [y0, w, h] of [[0.9, 0.42, 1.5], [4.3, 0.36, 1.2]]) S.extrude([arch(w, h)], [rad[0] * (R + RI) / 2, y0, rad[2] * (R + RI) / 2], 2, STONE, { ax: [tan, [0, 1, 0], rad], neg: true });
    }
    S.bake(); // the hall's inner carve would eat the furnace if they shared a bake
    // the furnace: a great block in the back wall, an arched mouth carved into it
    const FZ = -RI + 0.6;
    S.box([0, 1.7, FZ - 0.3], [1.7, 1.7, 0.9], FURN, { res: 0.08 });
    S.extrude([arch(0.85, 0.9)], [0, 0, FZ + 0.6], 1.6, STONE, { neg: true });
    S.box([0, 3.4, FZ - 0.3], [1.5, 0.12, 0.8], FURN, { res: 0.06 }); // a step back above the mouth
    S.bake();
    // hood narrowing into a chimney that leaves the top of the frame
    S.lathe([0, 3.4, FZ - 0.3], 1.4, t => 1.7 - 1.0 * t, FURN, { res: 0.08 });
    S.box([0, 8, FZ - 0.4], [0.7, 3.4, 0.6], FURN, { res: 0.08 });
    for (const y of [5.2, 7.4, 9.6]) S.box([0, y, FZ - 0.4], [0.74, 0.05, 0.64], GOLD, { res: 0.04 }); // brass bands on the chimney
    S.lathe([0, 4.78, FZ - 0.3], 0.06, 0.74, GOLD, { res: 0.03 }); // brass collar where the hood meets the chimney
    // gold bands: around the furnace, the mouth, and the hall
    S.box([0, 3.38, FZ + 0.61], [1.72, 0.05, 0.03], GOLD, { res: 0.025 });
    for (const sx of [-1, 1]) S.box([sx * 1.71, 1.7, FZ + 0.61], [0.04, 1.7, 0.03], GOLD, { res: 0.025 });
    S.bake();
    const mouth = [];
    for (let i = 0; i <= 14; i++) { const a = Math.PI * (i / 14); mouth.push([Math.cos(a) * 0.98, 0.9 + Math.sin(a) * 0.98]); }
    for (let i = 14; i >= 0; i--) { const a = Math.PI * (i / 14); mouth.push([Math.cos(a) * 0.86, 0.9 + Math.sin(a) * 0.86]); }
    S.extrude([mouth], [0, 0, FZ + 0.62], 0.06, GOLD, { res: 0.025 });
    S.torus([0, 6.2, 0], RI - 0.02, 0.05, GOLD, { res: 0.04 });
    S.box([0, 6.2, R - 0.2], [R + 1, 0.4, R], GOLD, { neg: true });
    S.bake();
    // the fire inside the mouth: a bed of coals and a white-hot core
    S.box([0, 0.12, FZ + 0.25], [0.75, 0.12, 0.3], { r: [12, 13], em: true }, { res: 0.04 });
    const FL = [];
    for (let [x, h, w, z] of [[-0.3, 0.8, 0.2, 0.2], [0.05, 1.15, 0.26, 0.1], [0.38, 0.7, 0.18, 0.25], [-0.55, 0.45, 0.12, 0.4], [0.6, 0.4, 0.1, 0.45]]) {
      const tag = 'f' + FL.length; x += LAYER.fire ? 0 : OFF; FL.push([x, 0.2, FZ + z]);
      S.lathe([x, 0.2, FZ + z], h, t => w * Math.pow(1 - t, 0.7) * (0.55 + 0.45 * Math.sin(Math.min(1, t * 3) * 1.57)), { r: [12], em: true }, { tag, res: 0.025 });
      S.lathe([x, 0.21, FZ + z + w * 0.4], h * 0.6, t => w * 0.55 * Math.pow(1 - t, 0.8), { r: [13, 14], em: true }, { tag, res: 0.025 });
    }

    // ---- molten channel from the furnace mouth to a round casting basin ----
    const CX = 2.1, CZ = -0.6;
    S.lathe([CX, 0, CZ], 0.3, 0.7, TRIM, { res: 0.06 });
    S.lathe([CX, 0.18, CZ], 0.3, 0.56, TRIM, { neg: true });
    S.torus([CX, 0.3, CZ], 0.7, 0.035, GOLD, { res: 0.03 });
    S.bake();
    // the channel: a molten line between two low stone curbs, from the mouth to the basin
    const ch = [[0.6, FZ + 0.75], [0.6, FZ + 1.5], [CX - 0.6, CZ]];
    for (let i = 0; i < ch.length - 1; i++) {
      const [x0, z0] = ch[i], [x1, z1] = ch[i + 1], l = Math.hypot(x1 - x0, z1 - z0), nx = -(z1 - z0) / l, nz = (x1 - x0) / l;
      for (const sd of [-1, 1]) S.tube([[x0 + nx * 0.13 * sd, 0.04, z0 + nz * 0.13 * sd], [x1 + nx * 0.13 * sd, 0.04, z1 + nz * 0.13 * sd]], 0.05, 0.05, TRIM, { res: 0.025 });
      S.tube([[x0, 0.02, z0], [x1, 0.02, z1]], 0.07, 0.07, HOT, { res: 0.025 });
    }
    S.lathe([CX, 0.18, CZ], 0.05, 0.56, HOT, { res: 0.04 });

    // ---- quench trough and a rack of finished blades on the left ----
    S.box([-2.6, 0.32, -0.2], [0.35, 0.32, 0.8], TRIM, { res: 0.05, rd: 0.03 });
    S.box([-2.6, 0.62, -0.2], [0.27, 0.05, 0.72], { r: [3, 4, 5] }, { res: 0.04 });
    for (let i = 0; i < 4; i++) S.box([-3.3 + i * 0.22, 0.95, -1.9 - i * 0.2], [0.03, 0.85, 0.08], IRON, { res: 0.03 });
    S.box([-2.95, 1.75, -2.25], [0.55, 0.05, 0.08], GOLD, { res: 0.03 });

    // ---- central dais and anvil ----
    const AX = 0, AZ = 0.9;
    S.lathe([AX, 0, AZ], 0.22, 1.4, TRIM, { res: 0.07 });
    S.torus([AX, 0.23, AZ], 1.2, 0.03, GOLD, { res: 0.025 });
    S.box([AX, 0.42, AZ], [0.36, 0.2, 0.24], IRON, { res: 0.035, rd: 0.03 });
    S.box([AX, 0.7, AZ], [0.2, 0.1, 0.16], IRON, { res: 0.03, rd: 0.02 });
    S.box([AX, 0.86, AZ], [0.5, 0.08, 0.2], IRON, { res: 0.03, rd: 0.02 });
    S.tube([[AX + 0.5, 0.87, AZ], [AX + 0.9, 0.9, AZ]], 0.1, 0.02, IRON, { res: 0.025 });
    S.bake();
    piece(S, LAYER.piece, AX - 0.05, 0.96, AZ);
    S.bake();

    // ---- the smith: slim, red cape, hammer arm on its own part ----
    const hx = AX - 0.78 + (LAYER.smith ? 0 : OFF), hz = AZ + 0.05; // left of the anvil, facing it (+x); P(side, y, forward)
    const P = (x, y, z) => [hx + z, y, hz - x];
    const CLOTH = { r: [1, 18] }, SKIN = { r: [17] }, CAPE = { r: [15, 16] };
    for (const d of [-0.07, 0.07]) S.tube([P(d, 0.22, 0), P(d, 0.62, 0)], 0.045, 0.05, CLOTH, { tag: 'body', res: 0.012 });
    for (const d of [-0.07, 0.07]) S.box(P(d, 0.24, 0.04), [0.08, 0.03, 0.05], CLOTH, { tag: 'body', res: 0.012 });
    S.tube([P(0, 0.62, 0), P(0, 1.05, 0)], 0.11, 0.13, { r: [18, 20] }, { tag: 'body', res: 0.014 }); // torso
    S.box(P(0, 0.82, 0.06), [0.06, 0.18, 0.1], { r: [15, 16] }, { tag: 'body', res: 0.012 }); // red tabard
    S.ball(P(0, 1.2, 0), 0.1, SKIN, { tag: 'body', res: 0.012 }); // head
    S.ball(P(0, 1.25, -0.02), [0.1, 0.06, 0.105], { r: [8, 9] }, { tag: 'body', res: 0.012 }); // hair
    S.box(P(0, 0.72, -0.12), [0.03, 0.36, 0.15], CAPE, { tag: 'body', res: 0.012, rd: 0.02 }); // cape
    S.tube([P(-0.15, 1.02, 0), P(-0.17, 0.7, 0.03)], 0.035, 0.035, CLOTH, { tag: 'body', res: 0.012 }); // off arm
    // hammer arm in the strike pose: hammer head down on the blade
    const SH = P(0.15, 1.02, 0);
    S.tube([SH, P(0.2, 0.92, 0.32)], 0.035, 0.035, CLOTH, { tag: 'arm', res: 0.012 });
    S.tube([P(0.2, 0.92, 0.32), [AX - 0.1, 1.0, AZ - 0.15]], 0.018, 0.018, { r: [8, 9] }, { tag: 'arm', res: 0.01 });
    S.box([AX - 0.06, 1.03, AZ - 0.15], [0.06, 0.05, 0.05], IRON, { tag: 'arm', res: 0.012, rd: 0.01 });
    S.bake();


    const W = B.finish({ cam: { target: [0, 2.9, -0.6], dist: 16.5, pitch: 0.3, yaw: 0 }, detail: 26, dither: 0, radius: 7 });
    K.puppet(W, {
      parts: { body: { ids: tags.body, pivot: P(0, 0.22, 0), slices: 4 }, arm: { ids: tags.arm, pivot: SH, parent: 'body', slices: 2 },
        ...Object.fromEntries(FL.map((p, i) => ['f' + i, { ids: tags['f' + i], pivot: p, slices: 4 }])) },
      pose(t, dt, pup) {
        const TAU = Math.PI * 2;
        FL.forEach((p, i) => { const a = i * 1.7, k = 1 + 0.2 * Math.sin(TAU * 2 * t + a) + 0.1 * Math.sin(TAU * 5 * t + a * 2); pup.pose['f' + i] = { scale: [1 - 0.3 * (k - 1), k, 1 - 0.3 * (k - 1)], rot: [0, 0, 8 * Math.sin(TAU * 1 * t + a)] }; });
        const ease = x => x * x * (3 - 2 * x), DOWN = -0.5;
        let lift, squash = 0, breathe = 0;
        if (t < 1) { lift = DOWN; breathe = Math.sin(t * TAU); }
        else if (t < 1.5) lift = DOWN + (1 - DOWN) * ease((t - 1) / 0.5);
        else if (t < 2) lift = 1 + 0.05 * Math.sin(((t - 1.5) / 0.5) * TAU);
        else if (t < 2.25) { const k = (t - 2) / 0.25; lift = 1 - k * k; if (k > 0.8) squash = 1; }
        else { const k = (t - 2.25) / 0.25; lift = ease(k); squash = Math.max(0, 1 - k * 2.5); }
        pup.pose.arm = { rot: [0, 0, lift * 110] };
        pup.pose.body = { rot: [0, 0, Math.max(0, lift) * 4 - squash * 3], scale: [1 + 0.04 * squash, 1 - 0.05 * squash + 0.012 * breathe, 1 + 0.04 * squash] };
      }
    });
    return W;
  }
  // hot pieces lying on the anvil face, centred at (X, Y, Z), long axis along x
  function piece(S, kind, X, Y, Z) {
    if (!kind) return;
    const HOT = { r: [24, 12, 13, 13, 14] }, EDGE = { r: [23, 24, 12, 12] }, WHITE = { r: [14], em: true }, o = { res: 0.012 };
    const FLAT = { ax: [[1, 0, 0], [0, 0, 1], [0, 1, 0]] };
    if (kind === 'sword') {
      S.box([X + 0.04, Y, Z], [0.24, 0.018, 0.045], HOT, { ...o, rd: 0.01 });
      S.tube([[X + 0.28, Y, Z], [X + 0.36, Y, Z]], 0.04, 0.004, HOT, o);
      S.box([X - 0.22, Y, Z], [0.03, 0.022, 0.09], EDGE, { ...o, rd: 0.01 });
      S.box([X - 0.33, Y, Z], [0.08, 0.016, 0.018], EDGE, { ...o, rd: 0.008 });
    } else if (kind === 'axe') {
      const outline = [[-0.2, 0.04], [-0.05, 0.035], [0.04, 0.08], [0.12, 0.13], [0.15, 0.08], [0.17, 0.0], [0.16, -0.08],
        [0.12, -0.15], [0.07, -0.2], [0.04, -0.13], [-0.01, -0.07], [-0.05, -0.04], [-0.2, -0.04]];
      S.extrude([outline], [X, Y, Z], 0.04, HOT, { ...o, rd: 0.006, ...FLAT });
      const edge = [[0.12, 0.13], [0.15, 0.08], [0.17, 0.0], [0.16, -0.08], [0.12, -0.15], [0.07, -0.2]];
      const inner = edge.map(([x, z]) => { const dx = -0.02 - x, dz = -0.03 - z, l = Math.hypot(dx, dz); return [x + (dx / l) * 0.028, z + (dz / l) * 0.028]; });
      S.extrude([edge.concat(inner.reverse())], [X, Y, Z], 0.044, WHITE, { ...o, ...FLAT });
      S.lathe([X - 0.19, Y - 0.03, Z], 0.06, 0.065, EDGE, o);
      S.box([X - 0.27, Y, Z], [0.025, 0.026, 0.04], EDGE, { ...o, rd: 0.012 });
      S.lathe([X - 0.19, Y - 0.05, Z], 0.1, 0.03, EDGE, { neg: true });
    } else if (kind === 'spear') {
      S.ball([X + 0.08, Y, Z], [0.2, 0.016, 0.07], HOT, o);
      S.tube([[X + 0.2, Y, Z], [X + 0.36, Y, Z]], 0.035, 0.003, HOT, o);
      S.tube([[X - 0.1, Y + 0.012, Z], [X + 0.3, Y + 0.008, Z]], 0.012, 0.004, WHITE, o);
      S.lathe([X - 0.13, Y - 0.03, Z], 0.06, 0.03, EDGE, { ...o, ax: [[0, 1, 0], [1, 0, 0], [0, 0, 1]] });
      S.tube([[X - 0.14, Y, Z], [X - 0.34, Y, Z]], 0.024, 0.032, EDGE, o);
    } else if (kind === 'shield') {
      S.lathe([X, Y - 0.015, Z], 0.03, 0.2, EDGE, o);
      S.lathe([X, Y - 0.005, Z], 0.03, 0.16, HOT, o);
      S.ball([X, Y + 0.02, Z], [0.06, 0.03, 0.06], WHITE, o);
    } else if (kind === 'hammer') {
      S.box([X + 0.05, Y + 0.02, Z], [0.12, 0.05, 0.06], HOT, { ...o, rd: 0.012 });
      S.box([X + 0.18, Y + 0.02, Z], [0.03, 0.065, 0.075], WHITE, { ...o, rd: 0.01 });
      S.tube([[X - 0.07, Y + 0.02, Z], [X - 0.22, Y + 0.01, Z]], 0.045, 0.006, EDGE, o);
    } else {
      S.box([X, Y, Z], [0.22, 0.03, 0.05], HOT, { ...o, rd: 0.015 });
      S.box([X + 0.02, Y + 0.02, Z], [0.14, 0.012, 0.03], WHITE, { ...o, rd: 0.008 });
    }
  }
  return { id: 'bb-forge-hall', name: 'Forge hall', seed: 21, build };
};
