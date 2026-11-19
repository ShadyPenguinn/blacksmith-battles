// Blacksmith Battles: Orders, the harbour market. A covered trading post on a pier at dusk under a great stone arch:
// a long counter with an awning, crates and a weighing scale, still water, a ship's mast and a low sun behind.
// A slim merchant in a green apron works the counter; customers (props) wait in front, one per open order.
// Environment variables: TOY_WORKER=0 parks the merchant; TOY_PROP=c0..c3 adds one waiting customer.
// The clip: idle 0-1 s, act 1-1.6 (the merchant lifts the delivered weapon high: up 1-1.2, hold, down 1.4-1.6).
module.exports = ({ makeBuilder, makeSculpt, KIT: K }) => {
  const PAL = [
    0x06070a, 0x10141c, 0x1a2230, 0x263244, 0x36465a, 0x4c6070, // 0-5 stone in dusk shadow (slate)
    0x2a1a10, 0x4a2e1a, 0x6e4628, 0x946238, // 6-9 timber
    0x0a1a22, 0x123040, 0x1e4a5c, 0x2e6a7a, // 10-13 harbour water
    0xff8a3a, 0xffb860, 0xffe0a0, // 14-16 sunset light
    0x7a4a30, 0xb0704a, 0xd89a68, // 17-19 sunset-lit stone
    0x1e4a32, 0x2e6a48, // 20-21 green apron
    0x2a1e18, 0x4a3628, 0xd8a07a, // 22-24 trousers, boots, skin
    0x8a2a24, 0xc8463a, 0xe8d8b8, // 25-27 awning red and cream
    0x5a6070, 0x9aa2b0, // 28-29 iron / steel
    0x3a2a5a, 0x5a4488, 0x7a2a5a, 0xa84478, 0x2a4a3a, 0x8a7a40, 0xc0a85a, // 30-36 customers' clothes
    0x2a2448, 0x4a3460, 0x7a4468, 0xb05a5a, 0xe08a5a // 37-41 dusk sky, high to low
  ];
  function build(seed) {
    const env = (typeof process !== 'undefined' && process.env) || {};
    const LAYER = { worker: env.TOY_WORKER !== '0', prop: env.TOY_PROP || '' };
    const OFF = 60;
    const B = makeBuilder(seed, PAL);
    const S = K.sculpt(makeSculpt(B));
    const tags = K.deform.tags(S);
    S.sun = B.norm([0.55, 0.45, 0.7]); // warm late-afternoon light from the front right
    S.res = 0.08;
    S.amb = 0.11;
    S.sky = 0.14;
    const STONE = { r: [0, 1, 2, 3, 17, 18, 19] };
    const WOOD = { r: [0, 6, 7, 8, 9, 17, 18] };
    const WATER = { r: [10, 11, 12, 13] };
    const SUN = { r: [14, 15, 16], em: true };
    S.lights.push({ p: [0, 2.2, 1.2], r: 3.6, s: 1.4 }, { p: [-2.1, 1.75, -0.6], r: 2.0, s: 1.6 }, { p: [2.1, 1.75, -0.6], r: 2.0, s: 1.6 }, { p: [0, 1.6, -0.2], r: 1.6, s: 0.8 });

    // ---- the pier: planks over still water ----
    S.box([0, -0.6, 0], [7, 0.3, 5], WATER, { res: 0.12 });
    S.box([0, -0.1, -0.4], [4.2, 0.12, 2.6], WOOD, { res: 0.08 });
    for (let i = 0; i < 14; i++) S.box([-3.9 + i * 0.6, 0.03, -0.4], [0.26, 0.02, 2.55], WOOD, { res: 0.04 });
    for (const x of [-4, -1.3, 1.3, 4]) S.lathe([x, -0.7, 2.25], 0.75, 0.13, WOOD, { res: 0.04 });
    // the sun low over the sea, and a pale streak on the water
    S.ball([5.6, 1.3, -15], 0.6, SUN, { res: 0.06 });
    S.box([5.2, -0.29, -11], [0.3, 0.01, 3], { r: [14, 15] , em: true }, { res: 0.05 });
    // the dusk sky: glowing bands far behind the harbour
    for (const [y, h, c] of [[0.4, 0.8, 41], [1.6, 0.4, 40], [2.4, 0.4, 39], [3.4, 0.6, 38], [5.2, 1.2, 37]]) S.box([0, y, -16], [34, h, 0.2], { r: [c], em: true }, { res: 0.15 });
    // distant headland
    S.ball([-6, -0.5, -11], [5, 2.2, 1.5], { r: [0, 1, 2] }, { res: 0.15 });
    // ---- the great stone arch over the market ----
    for (const sx of [-1, 1]) S.box([sx * 3.4, 1.6, -2.4], [0.45, 1.6, 0.45], STONE, { res: 0.07 });
    const arch = [];
    for (let i = 0; i <= 16; i++) { const a = Math.PI * (i / 16); arch.push([Math.cos(a) * 3.85, 3.2 + Math.sin(a) * 1.1]); }
    for (let i = 16; i >= 0; i--) { const a = Math.PI * (i / 16); arch.push([Math.cos(a) * 2.95, 3.2 + Math.sin(a) * 0.7]); }
    S.extrude([arch], [0, 0, -2.4], 0.9, STONE, { res: 0.07 });
    S.bake();
    // ---- the counter with a striped awning ----
    S.box([0, 0.38, -1.0], [2.2, 0.36, 0.35], WOOD, { res: 0.05, rd: 0.03 });
    S.box([0, 0.78, -1.0], [2.3, 0.05, 0.42], WOOD, { res: 0.04 });
    for (const sx of [-2.1, 2.1]) S.box([sx, 1.05, -1.3], [0.06, 1.05, 0.06], WOOD, { res: 0.03 });
    for (let i = 0; i < 9; i++) S.box([-2.2 + i * 0.55, 2.05, -0.95], [0.27, 0.04, 0.75], { r: i % 2 ? [0, 25, 26] : [0, 26, 27] }, { res: 0.04, ax: [[1, 0, 0], [0, 0.94, 0.34], [0, -0.34, 0.94]] });
    // crates, sacks, a weighing scale and a barrel of fish
    for (const [x, z, s] of [[-3.0, -1.6, 0.35], [-2.6, -0.4, 0.28], [2.9, -1.5, 0.3], [3.0, -0.9, 0.25]]) S.box([x, s, z], [s, s, s], WOOD, { res: 0.04, rd: 0.02 });
    S.ball([-3.0, 0.9, -1.6], [0.25, 0.2, 0.25], { r: [0, 35, 36] }, { res: 0.04 });
    S.tube([[0.9, 0.82, -1.0], [0.9, 1.3, -1.0]], 0.02, 0.02, { r: [0, 28, 29] }, { res: 0.015 });
    S.tube([[0.6, 1.28, -1.0], [1.2, 1.28, -1.0]], 0.015, 0.015, { r: [0, 28, 29] }, { res: 0.015 });
    for (const x of [0.62, 1.18]) S.lathe([x, 1.08, -1.0], 0.04, 0.1, { r: [17, 18, 19] }, { res: 0.015 });
    S.lathe([-1.2, 0.82, -1.0], 0.25, 0.16, WOOD, { res: 0.03 });
    // the ship beyond the pier: a hull, a mast, a furled sail
    S.ball([4.8, -0.2, -6.5], [2.2, 0.6, 0.7], WOOD, { res: 0.08 });
    S.tube([[4.7, 0, -6.5], [4.7, 3.6, -6.5]], 0.07, 0.05, WOOD, { res: 0.03 });
    S.tube([[3.6, 3.0, -6.5], [5.8, 3.0, -6.5]], 0.05, 0.05, WOOD, { res: 0.03 });
    S.tube([[3.7, 2.9, -6.45], [5.7, 2.9, -6.45]], 0.12, 0.12, { r: [0, 26, 27] }, { res: 0.04 });
    // lanterns hanging from the awning posts
    for (const sx of [-2.1, 2.1]) { S.box([sx + 0.0, 1.62, -1.0], [0.07, 0.1, 0.07], SUN, { res: 0.015 }); S.box([sx, 1.74, -1.0], [0.09, 0.02, 0.09], { r: [0, 28] }, { res: 0.012 }); }

    // ---- customers waiting in front of the counter (one prop each) ----
    const CUST = [[-1.0, 30, 31], [0.6, 32, 33], [-1.75, 34, 21], [1.4, 35, 36]];
    if (LAYER.prop) {
      const i = +LAYER.prop.slice(1), [x, a, b] = CUST[i];
      const z = 0.0, R = { r: [0, a, b] }, SKIN = { r: [0, 24] };
      for (const d of [-0.07, 0.07]) S.tube([[x + d, 0.05, z], [x + d, 0.5, z]], 0.045, 0.05, { r: [0, 22] }, { res: 0.012 });
      S.tube([[x, 0.45, z], [x, 0.95, z]], 0.13, 0.11, R, { res: 0.014 });
      S.ball([x, 1.1, z], 0.1, SKIN, { res: 0.012 });
      if (i === 0) S.lathe([x, 1.16, z], 0.12, t => 0.11 * (1 - t), R, { res: 0.01 }); // a pointed hood
      if (i === 1) S.lathe([x, 1.15, z], 0.02, 0.17, { r: [0, 6, 7] }, { res: 0.01 }); // wide hat brim
      if (i === 2) S.ball([x, 1.15, z], [0.11, 0.08, 0.11], { r: [0, 28, 29] }, { res: 0.01 }); // guard's helm
      if (i === 3) S.ball([x, 1.17, z], [0.12, 0.05, 0.12], { r: [0, 25, 26] }, { res: 0.01 }); // feathered cap
    }
    S.bake();

    // ---- the merchant behind the counter, facing the customers ----
    const hx = -0.2 + (LAYER.worker ? 0 : OFF), hz = -1.65;
    const P = (x, y, z) => [hx + x, y, hz + z];
    const APRON = { r: [0, 20, 21] }, SKIN = { r: [0, 24] };
    for (const d of [-0.07, 0.07]) S.tube([P(d, 0.05, 0), P(d, 0.55, 0)], 0.045, 0.05, { r: [0, 22] }, { tag: 'body', res: 0.012 });
    S.tube([P(0, 0.5, 0), P(0, 1.02, 0)], 0.12, 0.12, { r: [0, 27, 26] }, { tag: 'body', res: 0.014 }); // cream shirt
    S.box(P(0, 0.75, 0.1), [0.11, 0.28, 0.03], APRON, { tag: 'body', res: 0.012 });
    S.ball(P(0, 1.17, 0), 0.1, SKIN, { tag: 'body', res: 0.012 });
    S.ball(P(0, 1.22, -0.01), [0.105, 0.06, 0.1], { r: [0, 6, 7] }, { tag: 'body', res: 0.012 }); // hair
    S.tube([P(-0.15, 1.0, 0), P(-0.2, 0.75, 0.1)], 0.035, 0.035, { r: [0, 27, 26] }, { tag: 'body', res: 0.012 });
    // the arm holding the sold weapon (sculpted raised; posed down at rest)
    const SH = P(0.15, 1.0, 0);
    const HAND = P(0.3, 1.45, 0.2);
    S.tube([SH, HAND], 0.035, 0.032, { r: [0, 27, 26] }, { tag: 'arm', res: 0.012 });
    S.box([HAND[0], HAND[1] + 0.36, HAND[2]], [0.03, 0.38, 0.06], { r: [0, 28, 29] }, { tag: 'arm', res: 0.01 }); // blade
    S.box([HAND[0], HAND[1] - 0.02, HAND[2]], [0.03, 0.02, 0.1], { r: [0, 7, 8] }, { tag: 'arm', res: 0.01 }); // guard
    S.bake();

    const W = B.finish({ cam: { target: [0, 1.6, -1], dist: 16, pitch: 0.2, yaw: 0 }, detail: 26, dither: 0, radius: 7 });
    K.puppet(W, {
      parts: { body: { ids: tags.body, pivot: P(0, 0, 0), slices: 4 }, arm: { ids: tags.arm, pivot: SH, parent: 'body', slices: 2 } },
      pose(t, dt, pup) {
        const ease = x => x * x * (3 - 2 * x);
        let a = 1, breathe = 0; // 1 = arm resting on the counter, 0 = weapon held up high
        if (t < 1) breathe = Math.sin(t * Math.PI * 2);
        else if (t < 1.2) a = 1 - ease((t - 1) / 0.2);
        else if (t < 1.4) a = 0;
        else a = ease(Math.min(1, (t - 1.4) / 0.2));
        pup.pose.arm = { rot: [a * 80, 0, 0] };
        pup.pose.body = { rot: [-(1 - a) * 4, 0, 0], scale: [1, 1 + 0.012 * breathe, 1] };
      }
    });
    return W;
  }
  return { id: 'bb-orders', name: 'Harbour market', seed: 13, build };
};
