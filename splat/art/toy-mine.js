// Blacksmith Battles: the web toy's mine, in the same clean "grand space, small worker" style as toy-forge.js.
// A cut-away cavern: a rock dome, timber frames with hanging lanterns, a tunnel mouth with rails and an ore cart,
// puddles on the floor, a copper vein in the wall, and a slim miner who swings a pickaxe at an ore boulder.
// Environment variables pick what is drawn (for the toy's sprite layers): TOY_WORKER=0 parks the miner out of view.
// The clip: idle 0-1 s (pick resting), swing 1-1.6 (raise 1-1.3, strike 1.3-1.45, recover 1.45-1.6).
module.exports = ({ makeBuilder, makeSculpt, KIT: K }) => {
  const PAL = [
    0x070605, 0x14100e, 0x211a16, 0x30261f, 0x42352b, 0x584738, 0x725d4a, // 0-6 cave stone (umber)
    0x2a1a10, 0x4a2e1a, 0x6e4628, 0x946238, // 7-10 timber
    0xff9a30, 0xffd060, 0xfff2c0, // 11-13 lantern light
    0x0c1820, 0x1a3040, 0x346078, 0x8ac0d8, // 14-17 water
    0x5a2a14, 0x9a4a22, 0xd88038, 0xf0b070, // 18-21 copper ore
    0x1e3e32, 0x2e6450, 0x4a8a6c, // 22-24 miner's green tunic
    0x2a1e18, 0x4a3628, // 25-26 trousers, boots
    0xd8a07a, // 27 skin
    0x8a6020, 0xc89838, // 28-29 brass helmet
    0x2a2e36, 0x5a606a, 0x9aa2b0, // 30-32 iron (pick head, rails, cart bands)
    0x6a4428, 0x9a6634, 0xc8904a // 33-35 lantern-lit stone
  ];
  function build(seed) {
    const env = (typeof process !== 'undefined' && process.env) || {};
    const LAYER = { worker: env.TOY_WORKER !== '0' };
    const OFF = 60;
    const B = makeBuilder(seed, PAL);
    const S = K.sculpt(makeSculpt(B));
    const tags = K.deform.tags(S);
    S.sun = B.norm([0.3, 0.5, 0.8]);
    S.res = 0.08;
    S.amb = 0.025;
    S.sky = 0.02; // nearly black: the lanterns do the lighting
    const ROCK = { r: [0, 0, 1, 2, 33, 34, 35] };
    const FLOOR = { r: [0, 1, 2, 33, 34, 35] };
    const WOOD = { r: [7, 8, 9, 10] };
    const IRON = { r: [0, 30, 31, 32] };
    const LAMP = { r: [11, 12, 13], em: true };
    const WATER = { r: [14, 15, 16] };
    const ORE = { r: [18, 19, 20, 21] };
    const R = 5.2, RI = 4.6, H = 6.5;
    // every light goes in before the first bake: a bake shades with the lights it has at the time
    const LAMPS = [[-0.95, 0.8], [0.75, 0.8]].map(([a]) => [Math.sin(a) * (RI - 0.55), 2.3, -Math.cos(a) * (RI - 0.55)]);
    LAMPS.push([-0.9, 2.0, -RI + 0.15]);
    for (const [x, y, z] of LAMPS) S.lights.push({ p: [x, y - 0.6, z + 0.35], r: 3.0, s: 1.5 });
    S.lights.push({ p: [2.65, 1.7, 1.0], r: 3.2, s: 1.8 }, { p: [1.0, 1.5, 1.3], r: 1.5, s: 0.6 }); // the lantern on a post by the boulder; a little light on the miner

    // ---- floor and a rock dome, front half cut away ----
    S.lathe([0, -0.5, 0], 0.5, R + 0.3, FLOOR, { res: 0.1 });
    S.bake(); // the floor keeps its front half
    S.lathe([0, 0, 0], H, t => R * Math.sqrt(Math.max(0.02, 1 - Math.pow(t, 2.2))), ROCK, { res: 0.1 });
    S.lathe([0, -0.1, 0], H - 0.5, t => RI * Math.sqrt(Math.max(0.02, 1 - Math.pow(t, 2.2))), ROCK, { neg: true });
    S.box([0, H / 2, R], [R + 1, H / 2 + 1, R], ROCK, { neg: true });
    // the tunnel mouth at the back
    const arch = (w, h) => { const p = []; for (let i = 0; i <= 12; i++) { const a = Math.PI * (i / 12); p.push([Math.cos(a) * w, h + Math.sin(a) * w]); } p.push([-w, 0], [w, 0]); return p; };
    S.extrude([arch(0.8, 1.1)], [-0.9, 0, -RI], 2.4, ROCK, { neg: true });
    S.bake();
    // boulders along the foot of the wall, so the cave reads as rock not plaster
    for (let i = 0; i < 16; i++) {
      const a = -Math.PI * 0.5 + Math.PI * (i / 15) + 0.08 * Math.sin(i * 3.1);
      if (Math.abs(a + 0.19) < 0.2) continue; // keep the tunnel clear
      const rr = RI - 0.15, sz = 0.35 + 0.25 * K.hash(i, 3);
      S.rock([Math.sin(a) * rr, sz * 0.45, -Math.cos(a) * rr], sz, ROCK, { res: 0.07 });
    }
    // a few ledges up the wall
    for (const [a, y, sz] of [[-1.05, 2.4, 0.5], [0.9, 3.1, 0.45], [1.25, 1.6, 0.55], [-1.3, 3.6, 0.4]])
      S.rock([Math.sin(a) * (RI - 0.1), y, -Math.cos(a) * (RI - 0.1)], sz, ROCK, { res: 0.07 });
    S.bake();

    // ---- timber in the tunnel mouth and two frames against the wall ----
    const frame = (x, z, rot, w, h) => {
      const c = Math.cos(rot), s = Math.sin(rot), at = (dx, y) => [x + c * dx, y, z + s * dx];
      for (const sd of [-1, 1]) S.box(at(sd * w, h / 2), [0.1, h / 2, 0.1], WOOD, { res: 0.04 });
      S.tube([at(-w - 0.15, h), at(w + 0.15, h)], 0.11, 0.11, WOOD, { res: 0.04 });
      return at;
    };
    frame(-0.9, -RI + 0.15, 0, 0.85, 2.0);
    const lampAt = [];
    for (const [a, w] of [[-0.95, 0.8], [0.75, 0.8]]) {
      const x = Math.sin(a) * (RI - 0.55), z = -Math.cos(a) * (RI - 0.55);
      const at = frame(x, z, a, w, 2.3);
      lampAt.push(at(0, 2.3));
    }
    // lanterns hanging from the frames and one from a hook in the tunnel
    lampAt.push([-0.9, 2.0, -RI + 0.15]);
    for (const [x, y, z] of lampAt) {
      S.tube([[x, y - 0.1, z + 0.12], [x, y - 0.35, z + 0.12]], 0.012, 0.012, IRON, { res: 0.01 });
      S.box([x, y - 0.38, z + 0.12], [0.09, 0.025, 0.09], IRON, { res: 0.015 });
      S.box([x, y - 0.68, z + 0.12], [0.1, 0.025, 0.1], IRON, { res: 0.015 });
      S.box([x, y - 0.53, z + 0.12], [0.07, 0.13, 0.07], LAMP, { res: 0.015 });
    }

    // ---- rails out of the tunnel, and an ore cart ----
    for (const sd of [-1, 1]) S.tube([[-0.9 + sd * 0.38, 0.04, -RI - 0.5], [-0.9 + sd * 0.38, 0.04, 1.5]], 0.03, 0.03, IRON, { res: 0.02 });
    for (let i = 0; i < 9; i++) S.box([-0.9, 0.02, -RI + 0.1 + i * 0.66], [0.55, 0.03, 0.07], WOOD, { res: 0.025 });
    const CZ = -2.9;
    S.box([-0.9, 0.55, CZ], [0.45, 0.3, 0.6], WOOD, { res: 0.04, rd: 0.03 });
    S.box([-0.9, 0.7, CZ], [0.38, 0.2, 0.53], WOOD, { neg: true });
    S.bake();
    for (const dz of [-0.45, 0.45]) S.box([-0.9, 0.55, CZ + dz], [0.47, 0.32, 0.03], IRON, { res: 0.02 });
    for (const dz of [-0.4, 0.4]) for (const sd of [-1, 1]) S.lathe([-0.9 + sd * 0.44, 0.17, CZ + dz], 0.06, 0.13, IRON, { res: 0.02, ax: [[0, 1, 0], [1, 0, 0], [0, 0, 1]] });
    for (let i = 0; i < 6; i++) S.rock([-1.15 + (i % 3) * 0.25, 0.85 + 0.05 * (i % 2), CZ - 0.3 + Math.floor(i / 3) * 0.4], 0.18, ORE, { res: 0.03 });

    // ---- a copper vein in the right wall ----
    for (let i = 0; i < 6; i++) {
      const a = 0.45 + 0.07 * i, y = 0.9 + 0.3 * i + 0.15 * Math.sin(i * 2.3);
      const rr = RI * Math.sqrt(Math.max(0.02, 1 - Math.pow(y / (H - 0.5), 2.2))) - 0.02;
      S.rock([Math.sin(a) * rr, y, -Math.cos(a) * rr], 0.16 + 0.06 * K.hash(i, 9), ORE, { res: 0.03 });
    }

    // ---- puddles on the floor: flat water with a pale glint ----
    for (const [x, z, rx, rz] of [[2.6, 1.7, 0.55, 0.3], [-2.4, 0.9, 0.42, 0.26], [0.3, 1.9, 0.32, 0.18], [-1.7, 2.5, 0.5, 0.22], [0.9, -1.9, 0.35, 0.2]]) {
      S.lathe([x, 0, z], 0.03, rx, { r: [14, 15, 16] }, { res: 0.025 });
      S.lathe([x + rz * 0.6, 0, z - rz * 0.4], 0.03, rz * 0.9, { r: [14, 15, 16] }, { res: 0.025 });
      S.box([x + rx * 0.2, 0.035, z - rz * 0.2], [rx * 0.3, 0.006, 0.012], { r: [17] }, { res: 0.012 }); // glint
    }

    // a lantern on a post beside the boulder, so the miner works in its pool of light
    S.box([3.15, 1.15, 1.0], [0.06, 1.15, 0.06], WOOD, { res: 0.03 });
    S.box([2.97, 2.3, 1.0], [0.24, 0.04, 0.04], WOOD, { res: 0.025 });
    S.box([2.75, 2.12, 1.0], [0.06, 0.018, 0.06], IRON, { res: 0.012 });
    S.box([2.75, 1.9, 1.0], [0.07, 0.018, 0.07], IRON, { res: 0.012 });
    S.box([2.75, 2.01, 1.0], [0.05, 0.09, 0.05], LAMP, { res: 0.012 });
    S.tube([[2.75, 2.13, 1.0], [2.75, 2.28, 1.0]], 0.01, 0.01, IRON, { res: 0.01 });
    // ---- the ore boulder the miner works ----
    const OX = 1.7, OZ = 0.6;
    S.rock([OX, 0.35, OZ], 0.5, ROCK, { res: 0.04 });
    for (const [dx, dy, dz, s] of [[-0.32, 0.45, 0.25, 0.17], [-0.1, 0.72, 0.15, 0.15], [0.15, 0.55, 0.38, 0.16], [-0.38, 0.2, 0.35, 0.13], [0.3, 0.3, 0.42, 0.12]])
      S.rock([OX + dx, dy, OZ + dz], s, ORE, { res: 0.025 });
    S.bake();

    // ---- the miner: slim, green tunic, brass helmet with a lamp, pickaxe on its own part ----
    const hx = OX - 0.95 + (LAYER.worker ? 0 : OFF), hz = OZ + 0.15; // left of the boulder, facing it (+x); P(side, y, forward)
    const P = (x, y, z) => [hx + z, y, hz - x];
    const TUNIC = { r: [22, 23, 24] }, PANTS = { r: [0, 25] }, BOOT = { r: [0, 25, 26] }, SKIN = { r: [27] };
    for (const d of [-0.07, 0.07]) S.tube([P(d, 0.2, 0), P(d, 0.6, 0)], 0.045, 0.05, PANTS, { tag: 'body', res: 0.012 });
    for (const d of [-0.07, 0.07]) S.box(P(d, 0.22, 0.04), [0.08, 0.035, 0.055], BOOT, { tag: 'body', res: 0.012 });
    S.tube([P(0, 0.58, 0), P(0, 1.03, 0)], 0.12, 0.12, TUNIC, { tag: 'body', res: 0.014 });
    S.box(P(0, 0.64, 0), [0.07, 0.03, 0.13], { r: [7, 8] }, { tag: 'body', res: 0.01 }); // belt (sideways)
    S.ball(P(0, 1.18, 0), 0.1, SKIN, { tag: 'body', res: 0.012 });
    S.ball(P(0, 1.23, 0), [0.115, 0.07, 0.115], { r: [28, 29] }, { tag: 'body', res: 0.012 }); // helmet dome
    S.lathe(P(0, 1.2, 0), 0.015, 0.14, { r: [28, 29] }, { tag: 'body', res: 0.01 }); // brim
    S.ball(P(0, 1.25, 0.11), 0.03, LAMP, { tag: 'body', res: 0.01 }); // helmet lamp
    S.box(P(-0.05, 0.85, -0.13), [0.09, 0.12, 0.05], { r: [8, 9] }, { tag: 'body', res: 0.012, rd: 0.02 }); // satchel
    S.tube([P(-0.15, 1.0, 0), P(-0.15, 0.7, 0.05)], 0.035, 0.035, TUNIC, { tag: 'body', res: 0.012 }); // off arm
    // the pick arm in the strike pose: both hands on the haft, pick head biting the boulder
    const SH = P(0.12, 1.0, 0);
    const HAND = P(0.08, 0.82, 0.32);
    const TIP = [OX - 0.3, 0.6, OZ + 0.12];
    S.tube([SH, HAND], 0.035, 0.035, TUNIC, { tag: 'arm', res: 0.012 });
    S.tube([P(0.08, 0.78, 0.22), TIP.map((v, i) => v + [0.0, 0.18, 0][i])], 0.018, 0.018, WOOD, { tag: 'arm', res: 0.01 });
    const HEAD = [TIP[0], TIP[1] + 0.2, TIP[2]];
    S.tube([[HEAD[0] - 0.02, HEAD[1] + 0.2, HEAD[2]], [HEAD[0] + 0.02, HEAD[1] + 0.02, HEAD[2]]], 0.035, 0.03, IRON, { tag: 'arm', res: 0.01 });
    S.tube([[HEAD[0] + 0.02, HEAD[1] + 0.02, HEAD[2]], [TIP[0] + 0.06, TIP[1] - 0.02, TIP[2]]], 0.03, 0.006, IRON, { tag: 'arm', res: 0.01 });
    S.bake();

    const W = B.finish({ cam: { target: [0, 2.2, -0.4], dist: 16.5, pitch: 0.3, yaw: 0 }, detail: 26, dither: 0, radius: 7 });
    K.puppet(W, {
      parts: { body: { ids: tags.body, pivot: P(0, 0.2, 0), slices: 4 }, arm: { ids: tags.arm, pivot: SH, parent: 'body', slices: 2 } },
      pose(t, dt, pup) {
        const ease = x => x * x * (3 - 2 * x), DOWN = -0.35;
        let lift, squash = 0, breathe = 0;
        if (t < 1) { lift = DOWN; breathe = Math.sin(t * Math.PI * 2); }
        else if (t < 1.3) lift = DOWN + (1 - DOWN) * ease((t - 1) / 0.3);
        else if (t < 1.45) { const k = (t - 1.3) / 0.15; lift = 1 - k * k; if (k > 0.8) squash = 1; }
        else { const k = (t - 1.45) / 0.15; lift = DOWN * ease(k); squash = Math.max(0, 1 - k * 2.5); }
        pup.pose.arm = { rot: [0, 0, lift * 120] };
        pup.pose.body = { rot: [0, 0, Math.max(0, lift) * 6 - squash * 4], scale: [1 + 0.04 * squash, 1 - 0.05 * squash + 0.012 * breathe, 1 + 0.04 * squash] };
      }
    });
    return W;
  }
  return { id: 'bb-mine', name: 'Mine cavern', seed: 7, build };
};
