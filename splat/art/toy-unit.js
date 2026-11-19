// Blacksmith Battles: one fighter for the Fight field, seen side on and facing right (the toy flips foes to face left).
// Rendered alone against a flat backdrop, so tools/pack.py keeps just the figure as a cut-out.
// Environment variables: UNIT_ARCH = Sword | Axe | Spear | Bow | Staff | Shield | Warhammer | Grimoire (what they carry),
// UNIT_SIDE = hero | foe (bright steel and blue, or dark iron, red and horns), UNIT_NONE=1 draws only the backdrop. Each weapon has its own outfit:
// knight (Sword), berserker (Axe), pikeman (Spear), ranger (Bow), healer (Staff), guard (Shield), forge brute (Warhammer), wizard (Grimoire).
// The clip: idle 0-1 s (breathing), walk 1-2 (one full stride), attack 2-2.6 (the weapon's own move), hurt 3-3.3, down 4-4.5 (falls back).
module.exports = ({ makeBuilder, makeSculpt, KIT: K }) => {
  const PAL = [
    0x08080c, 0x16141c, // 0-1 deep shade
    0x2a1e18, 0x4a3628, 0xd8a07a, 0xa87458, // 2-5 trousers, boots, skin, skin shade
    0x3a4250, 0x5a6070, 0x9aa2b0, 0xd0d8e0, // 6-9 steel
    0x22242c, 0x34343e, 0x50505c, // 10-12 dark iron
    0x1e2a4a, 0x2a4a8a, 0x4a72c0, // 13-15 hero blue
    0x4a1414, 0x8a2420, 0xc0402e, // 16-18 foe red
    0x4a2e1a, 0x6e4628, 0x946238, // 19-21 wood
    0xc8a040, 0xf0d070, // 22-23 gold
    0x2a5a3a, 0x7ae0b0, 0xd8fff0, // 24-26 staff gem
    0x4a2a6a, 0x8a5ac0, 0xd0b0ff, // 27-29 grimoire
    0xe8dcc0, 0xa89878, // 30-31 parchment, bowstring
    0xff00ff, // 32 backdrop (never in a figure)
    0x3a2a1a, 0x6a4a2a, 0x8a6a44, // 33-35 leather
    0x5a4a38, 0x8a7a60, 0xb0a080, // 36-38 fur
    0x1e3a22, 0x2e5a30, 0x4a7a40, // 39-41 ranger green
    0x8a8a90, 0xc8c8c0, 0xeeeee4, // 42-44 white robe
    0x2a1a40, 0x4a2a7a, 0x6a4aa8, // 45-47 wizard violet
    0x3a2010, 0x7a3a1a, 0xb86a3a, // 48-50 hair, dark to ginger
    0x6a6a6a, 0xb0b0b0, // 51-52 grey beard
    0x2a1612, 0x4a2a20, // 53-54 brigand brown
    0x1a1014, 0x3a1a20, 0x5a2028 // 55-57 cultist black-red
  ];
  function build(seed) {
    const env = (typeof process !== 'undefined' && process.env) || {};
    const ARCH = env.UNIT_ARCH || 'Sword', FOE = env.UNIT_SIDE === 'foe', NONE = env.UNIT_NONE === '1';
    const B = makeBuilder(seed, PAL);
    const S = K.sculpt(makeSculpt(B));
    const tags = K.deform.tags(S);
    S.sun = B.norm([0.35, 0.8, 0.6]);
    S.res = 0.05;
    S.amb = 0.3;
    S.sky = 0.2;
    S.box([0, 1, -6], [12, 6, 0.1], { r: [32], em: true }, { res: 0.2 });
    S.bake();
    const SKIN = { r: [0, 5, 4] }, TROUS = { r: [0, 2] }, BOOT = { r: [0, 1, 3] };
    const ARM = FOE ? { r: [0, 10, 11, 12] } : { r: [0, 6, 7, 8, 9] };
    const CLOTH = FOE ? { r: [0, 16, 17, 18] } : { r: [0, 13, 14, 15] };
    const WOOD = { r: [0, 19, 20, 21] }, STEEL = { r: [0, 7, 8, 9] }, GOLD = { r: [0, 22, 23] };
    let SLEEVE = ARM;
    if (!NONE) {
      // legs: near (z+) and far (z-), each hangs from the hip
      for (const [tag, z] of [['legF', 0.07], ['legB', -0.07]]) {
        S.tube([[0, 0.62, z], [0, 0.08, z]], 0.06, 0.055, TROUS, { tag, res: 0.012 });
        S.box([0.04, 0.05, z], [0.09, 0.05, 0.05], BOOT, { tag, res: 0.012 });
      }
      // the body, dressed for the weapon they carry: every weapon is its own kind of fighter
      const LEATHER = { r: [0, 33, 34, 35] }, FUR = { r: [0, 36, 37, 38] };
      const HOOD = FOE ? { r: [0, 53, 54, 34] } : { r: [0, 39, 40, 41] };
      const ROBE = FOE ? { r: [0, 55, 56, 57] } : { r: [0, 42, 43, 44] };
      const WIZ = FOE ? { r: [0, 55, 16, 17] } : { r: [0, 45, 46, 47] };
      const HAIR = FOE ? { r: [0, 1, 48] } : { r: [0, 48, 49, 50] }, GREY = { r: [0, 51, 52] };
      const b = { tag: 'body', res: 0.012 }, f = { tag: 'body', res: 0.008 };
      const horns = (y, wide) => { if (FOE) for (const sz of [-1, 1]) S.tube([[-0.02, y, sz * 0.09], [-0.1, y + 0.15, sz * (wide || 0.15)]], 0.025, 0.006, { r: [0, 30, 31] }, f); };
      const robe = (m, top) => { S.lathe([0, 0.1, 0], top - 0.1, t => 0.25 - 0.12 * t, m, b); };
      SLEEVE = ARM;
      S.ball([0.02, 1.24, 0], 0.11, SKIN, b); // the head
      if (ARCH === 'Sword') { // knight: mail, tabard, round helm with a crest
        S.tube([[0, 0.58, 0], [0, 1.1, 0]], 0.15, 0.14, ARM, { tag: 'body', res: 0.014 });
        S.box([0.05, 0.78, 0], [0.12, 0.27, 0.15], CLOTH, b);
        S.box([0.0, 0.62, 0], [0.155, 0.03, 0.155], { r: [0, 3, 22] }, { tag: 'body', res: 0.01 });
        S.ball([0.0, 1.29, 0], [0.125, 0.09, 0.125], ARM, { tag: 'body', res: 0.01 });
        S.box([0.1, 1.24, 0], [0.02, 0.06, 0.01], ARM, f); // nose guard
        if (FOE) horns(1.33); else S.box([-0.02, 1.4, 0], [0.09, 0.03, 0.015], CLOTH, f); // crest
      } else if (ARCH === 'Axe') { // berserker: bare arms, leather, a fur mantle, wild hair and beard
        SLEEVE = SKIN;
        S.tube([[0, 0.58, 0], [0, 1.1, 0]], 0.15, 0.15, LEATHER, { tag: 'body', res: 0.014 });
        S.ball([-0.01, 1.07, 0], [0.21, 0.09, 0.21], FUR, b);
        S.box([0.0, 0.62, 0], [0.16, 0.035, 0.16], { r: [0, 3, 22] }, f);
        S.ball([-0.02, 1.3, 0], [0.12, 0.08, 0.12], HAIR, f);
        S.ball([-0.08, 1.22, 0], [0.07, 0.1, 0.1], HAIR, f); // hair down the back
        S.ball([0.1, 1.16, 0], [0.05, 0.08, 0.07], HAIR, f); // beard
        if (FOE) { S.ball([0.0, 1.31, 0], [0.12, 0.07, 0.12], ARM, f); horns(1.33, 0.2); }
      } else if (ARCH === 'Spear') { // pikeman: long quartered tabard and a broad-brimmed kettle hat
        S.tube([[0, 0.58, 0], [0, 1.1, 0]], 0.15, 0.14, ARM, { tag: 'body', res: 0.014 });
        S.box([0.05, 0.72, 0], [0.12, 0.33, 0.155], CLOTH, b);
        S.box([0.06, 0.72, 0], [0.12, 0.33, 0.02], GOLD, f); // a stripe down the middle
        S.ball([0.0, 1.31, 0], [0.115, 0.08, 0.115], ARM, f);
        S.ball([0.0, 1.28, 0], [0.21, 0.018, 0.21], ARM, f); // brim
        horns(1.34);
      } else if (ARCH === 'Bow') { // ranger: leather jerkin, a hood and cloak, a quiver on the back
        SLEEVE = LEATHER;
        S.tube([[0, 0.58, 0], [0, 1.1, 0]], 0.14, 0.13, LEATHER, { tag: 'body', res: 0.014 });
        S.box([0.04, 0.82, 0], [0.11, 0.22, 0.14], HOOD, b);
        S.box([-0.13, 0.82, 0], [0.03, 0.34, 0.15], HOOD, b); // cloak
        S.ball([-0.03, 1.27, 0], [0.13, 0.135, 0.13], HOOD, f); // hood, the face showing in front
        S.tube([[-0.16, 0.72, 0.06], [-0.22, 1.18, 0.06]], 0.045, 0.045, LEATHER, f);
        for (const dz of [-0.02, 0.02]) S.tube([[-0.22, 1.18, 0.06 + dz], [-0.24, 1.26, 0.06 + dz]], 0.012, 0.004, { r: [30, 44] }, f);
      } else if (ARCH === 'Staff') { // healer: a long robe with a rope belt, a hood and a grey beard
        SLEEVE = ROBE;
        robe(ROBE, 1.12);
        S.box([0.0, 0.66, 0], [0.2, 0.025, 0.2], GOLD, f);
        S.ball([-0.03, 1.27, 0], [0.13, 0.13, 0.13], ROBE, f);
        S.ball([0.1, 1.15, 0], [0.04, 0.09, 0.06], FOE ? HAIR : GREY, f);
      } else if (ARCH === 'Shield') { // guard: heavy plate, big pauldrons, a flat-topped great helm with a plume
        S.tube([[0, 0.58, 0], [0, 1.1, 0]], 0.17, 0.16, ARM, { tag: 'body', res: 0.014 });
        S.box([0.06, 0.74, 0], [0.12, 0.3, 0.16], CLOTH, b);
        for (const z of [-0.18, 0.18]) S.ball([0, 1.08, z], [0.1, 0.07, 0.09], ARM, f);
        S.box([0.01, 1.27, 0], [0.12, 0.13, 0.12], ARM, f);
        S.box([0.13, 1.28, 0], [0.006, 0.012, 0.08], { r: [0] }, f); // visor slit
        if (FOE) horns(1.38); else S.ball([-0.03, 1.45, 0], [0.12, 0.05, 0.03], CLOTH, f); // plume
      } else if (ARCH === 'Warhammer') { // forge brute: stocky, leather apron, bald with a great beard, iron bracers
        SLEEVE = SKIN;
        S.tube([[0, 0.58, 0], [0, 1.1, 0]], 0.18, 0.18, LEATHER, { tag: 'body', res: 0.014 });
        S.box([0.13, 0.7, 0], [0.05, 0.33, 0.15], { r: [0, 33, 34] }, b); // apron
        S.box([0.0, 0.62, 0], [0.19, 0.035, 0.19], { r: [0, 3, 22] }, f);
        S.ball([0.11, 1.14, 0], [0.07, 0.12, 0.09], HAIR, f); // the great beard
        if (FOE) { S.ball([0.0, 1.31, 0], [0.12, 0.07, 0.12], ARM, f); horns(1.33, 0.2); }
      } else if (ARCH === 'Grimoire') { // wizard: a robe with gold trim, a tall pointed hat, a long beard
        SLEEVE = WIZ;
        robe(WIZ, 1.12);
        S.box([0.0, 0.18, 0], [0.24, 0.03, 0.24], GOLD, f);
        S.ball([0.0, 1.32, 0], [0.2, 0.02, 0.2], WIZ, f); // brim
        S.lathe([0, 1.32, 0], 0.36, t => 0.115 * (1 - t), WIZ, f);
        S.ball([0.1, 1.11, 0], [0.04, 0.13, 0.06], FOE ? HAIR : GREY, f);
      }
      // the off arm (far side): holds the bow; otherwise swings while walking
      const SHO = [0.0, 1.05, -0.17], HO = [0.02, 0.66, -0.2];
      S.tube([SHO, HO], 0.045, 0.04, SLEEVE, { tag: 'armO', res: 0.012 });
      // the weapon arm (near side) and the weapon in its hand, sculpted hanging straight down
      const SH = [0.0, 1.05, 0.17], H = [0.02, 0.66, 0.2];
      S.tube([SH, H], 0.045, 0.04, SLEEVE, { tag: 'armW', res: 0.012 });
      if (SLEEVE === SKIN && ARCH === 'Warhammer') S.tube([[0.0, 0.8, 0.19], [0.015, 0.7, 0.2]], 0.052, 0.05, ARM, { tag: 'armW', res: 0.01 }); // bracer
      S.ball(H, 0.045, SKIN, { tag: 'armW', res: 0.01 });
      const [hx, hy, hz] = H, w = { tag: 'armW', res: 0.01 };
      if (ARCH === 'Sword') {
        S.box([hx, hy, hz + 0.02], [0.02, 0.02, 0.07], GOLD, w); // crossguard
        S.box([hx + 0.33, hy, hz + 0.02], [0.3, 0.03, 0.012], STEEL, w); // blade, pointing forward
      } else if (ARCH === 'Axe') {
        S.tube([[hx - 0.08, hy, hz + 0.02], [hx + 0.55, hy, hz + 0.02]], 0.02, 0.02, WOOD, w);
        S.extrude([[[0, 0], [0.14, 0.12], [0.16, -0.18], [0, -0.06]]], [hx + 0.48, hy + 0.04, hz + 0.02], 0.025, STEEL, w);
      } else if (ARCH === 'Warhammer') {
        S.tube([[hx - 0.08, hy, hz + 0.02], [hx + 0.6, hy, hz + 0.02]], 0.02, 0.02, WOOD, w);
        S.box([hx + 0.6, hy, hz + 0.02], [0.07, 0.1, 0.07], ARM, w);
      } else if (ARCH === 'Spear') {
        S.tube([[hx - 0.3, hy, hz + 0.02], [hx + 0.75, hy, hz + 0.02]], 0.016, 0.016, WOOD, w);
        S.lathe([hx + 0.75, hy, hz + 0.02], 0.18, t => 0.04 * (1 - t), STEEL, { ...w, ax: [[0, -1, 0], [1, 0, 0], [0, 0, 1]] });
      } else if (ARCH === 'Staff') {
        S.tube([[hx, hy - 0.6, hz + 0.02], [hx, hy + 0.75, hz + 0.02]], 0.022, 0.02, WOOD, w);
        S.ball([hx, hy + 0.82, hz + 0.02], 0.065, { r: [24, 25, 26], em: true }, w);
      } else if (ARCH === 'Shield') {
        S.ball([hx + 0.08, hy + 0.14, hz + 0.1], [0.17, 0.24, 0.04], FOE ? { r: [0, 16, 17] } : { r: [0, 13, 14] }, { ...w, res: 0.01 });
        S.ball([hx + 0.08, hy + 0.14, hz + 0.15], [0.045, 0.045, 0.02], GOLD, w); // boss
      } else if (ARCH === 'Grimoire') {
        S.box([hx + 0.12, hy + 0.05, hz + 0.02], [0.1, 0.13, 0.03], { r: [0, 27, 28] }, w);
        S.box([hx + 0.14, hy + 0.05, hz + 0.06], [0.08, 0.11, 0.008], { r: [30, 31] }, w);
      }
      if (ARCH === 'Bow') { // the bow in the off hand, the near hand draws the string
        const [ox, oy, oz] = HO;
        const arc = []; for (let i = 0; i <= 10; i++) { const a = -0.9 + 1.8 * i / 10; arc.push([ox + 0.05 + Math.cos(a) * 0.12, oy + Math.sin(a) * 0.42, oz]); }
        for (let i = 0; i < 10; i++) S.tube([arc[i], arc[i + 1]], 0.017, 0.017, WOOD, { tag: 'armO', res: 0.008 });
        S.tube([arc[0], arc[10]], 0.005, 0.005, { r: [31, 30] }, { tag: 'armO', res: 0.006 });
      }
    }
    S.bake();
    const W = B.finish({ cam: { target: [0, 0.75, 0], dist: 9, pitch: 0.08, yaw: 0 }, detail: 26, dither: 0, radius: 4 });
    if (NONE) return W;
    const HIP = [0, 0.62, 0];
    K.puppet(W, {
      parts: {
        body: { ids: tags.body, pivot: HIP, slices: 3 },
        legF: { ids: tags.legF, pivot: [0, 0.62, 0.07], parent: 'body', slices: 2 },
        legB: { ids: tags.legB, pivot: [0, 0.62, -0.07], parent: 'body', slices: 2 },
        armW: { ids: tags.armW, pivot: SH0, parent: 'body', slices: 2 },
        armO: { ids: tags.armO, pivot: SO0, parent: 'body', slices: 2 }
      },
      pose(t, dt, pup) { pose(t, pup) }
    });
    return W;
  }
  const SH0 = [0.0, 1.05, 0.17], SO0 = [0.0, 1.05, -0.17];
  const ease = x => x * x * (3 - 2 * x);
  // what each weapon's arms do over the attack (u 0..1): [weapon arm angle, weapon arm reach, off arm angle, lean]
  const READY = { Sword: [25, 0, 10, 0], Axe: [20, 0, 10, 0], Warhammer: [15, 0, 10, 0], Spear: [8, 0, 40, 0], Bow: [80, 0, 90, 0], Staff: [10, 0, 15, 0], Shield: [35, 0, 20, 0], Grimoire: [55, 0, 20, 0] };
  function attack(arch, u) {
    const r = READY[arch] || READY.Sword, up = ease(Math.min(1, u / 0.45)), dn = ease(Math.max(0, Math.min(1, (u - 0.45) / 0.2))), back = ease(Math.max(0, (u - 0.75) / 0.25));
    if (arch === 'Spear') { const k = u < 0.4 ? -ease(u / 0.4) : u < 0.6 ? -1 + 2.2 * ease((u - 0.4) / 0.2) : 1.2 * (1 - back); return [r[0], k * 0.2, r[2], k * 6]; }
    if (arch === 'Bow') { const draw = u < 0.55 ? ease(u / 0.55) : 1 - ease(Math.min(1, (u - 0.55) / 0.08)); return [r[0], -0.22 * draw, r[2], 0]; }
    if (arch === 'Shield') { const k = u < 0.35 ? -ease(u / 0.35) * 0.4 : u < 0.55 ? -0.4 + 1.6 * ease((u - 0.35) / 0.2) : 1.2 * (1 - back); return [r[0] + 20 * Math.max(0, k), 0.12 * k, r[2], 8 * k]; }
    if (arch === 'Staff' || arch === 'Grimoire') { const k = u < 0.4 ? ease(u / 0.4) : 1 - back; return [r[0] + 110 * k, 0, r[2] + 30 * k, -4 * k]; }
    // swung weapons: raise overhead behind, then chop forward and down
    const a = r[0] + (150 - r[0]) * up * (1 - dn) + (-35 - r[0]) * dn * (1 - back) + 0 * back;
    return [up < 1 ? r[0] + (150 - r[0]) * up : dn < 1 || back === 0 ? 150 + (-35 - 150) * dn : -35 + (r[0] + 35) * back, 0, r[2], -6 * up * (1 - dn) + 10 * dn * (1 - back)];
  }
  function pose(t, pup) {
    const env = (typeof process !== 'undefined' && process.env) || {};
    const arch = env.UNIT_ARCH || 'Sword', r = READY[arch] || READY.Sword;
    let wA = r[0], wR = 0, oA = r[2], lean = 0, legA = 0, bob = 0, breathe = 0, fall = 0, drop = 0;
    if (t < 1) breathe = Math.sin(t * Math.PI * 2);
    else if (t < 2) { const p = (t - 1) * Math.PI * 2; legA = 28 * Math.sin(p); bob = 0.025 * Math.abs(Math.cos(p)); oA = r[2] + (arch === 'Bow' ? 0 : -18 * Math.sin(p)); lean = 4; }
    else if (t < 2.6) { [wA, wR, oA, lean] = attack(arch, (t - 2) / 0.6); }
    else if (t < 3.5) { const k = Math.sin(Math.min(1, (t - 3) / 0.3) * Math.PI); lean = -14 * k; wA = r[0] - 20 * k; drop = 0; }
    else { const k = ease(Math.min(1, (t - 4) / 0.5)); fall = 82 * k; drop = 0.5 * k; wA = r[0] - 40 * k; oA = r[2] - 40 * k; legA = 10 * k; }
    pup.pose.body = { rot: [0, 0, -lean + fall], pos: [-0.25 * drop, bob - drop * 0.95, 0], scale: [1, 1 + 0.012 * breathe, 1] };
    pup.pose.legF = { rot: [0, 0, legA - fall] };
    pup.pose.legB = { rot: [0, 0, -legA - fall] };
    pup.pose.armW = { rot: [0, 0, wA], pos: [wR, 0, 0] };
    pup.pose.armO = { rot: [0, 0, oA] };
  }
  return { id: 'bb-unit', name: 'Fighter', seed: 31, build };
};
