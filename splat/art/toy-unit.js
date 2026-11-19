// Blacksmith Battles: one fighter for the Fight field, seen side on and facing right (the toy flips foes to face left).
// Rendered alone against a flat backdrop, so tools/pack.py keeps just the figure as a cut-out.
// Environment variables: UNIT_ARCH = Sword | Axe | Spear | Bow | Staff | Shield | Warhammer | Grimoire (what they carry),
// UNIT_SIDE = hero | foe (blue tabard and bright steel, or a red tabard, dark iron and a horned helm), UNIT_NONE=1 draws only the backdrop.
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
    0xff00ff // 32 backdrop (never in a figure)
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
    if (!NONE) {
      // legs: near (z+) and far (z-), each hangs from the hip
      for (const [tag, z] of [['legF', 0.07], ['legB', -0.07]]) {
        S.tube([[0, 0.62, z], [0, 0.08, z]], 0.06, 0.055, TROUS, { tag, res: 0.012 });
        S.box([0.04, 0.05, z], [0.09, 0.05, 0.05], BOOT, { tag, res: 0.012 });
      }
      // body: mail shirt, tabard over it, belt, head and helm
      S.tube([[0, 0.58, 0], [0, 1.1, 0]], 0.15, 0.14, ARM, { tag: 'body', res: 0.014 });
      S.box([0.05, 0.78, 0], [0.12, 0.27, 0.15], CLOTH, { tag: 'body', res: 0.012 });
      S.box([0.0, 0.62, 0], [0.155, 0.03, 0.155], { r: [0, 3, 22] }, { tag: 'body', res: 0.01 });
      S.ball([0.02, 1.24, 0], 0.11, SKIN, { tag: 'body', res: 0.012 });
      S.ball([0.0, 1.29, 0], [0.125, 0.09, 0.125], ARM, { tag: 'body', res: 0.01 });
      S.box([0.1, 1.24, 0], [0.02, 0.06, 0.01], ARM, { tag: 'body', res: 0.008 }); // nose guard
      if (FOE) for (const sz of [-1, 1]) S.tube([[-0.02, 1.33, sz * 0.09], [-0.1, 1.48, sz * 0.15]], 0.025, 0.006, { r: [0, 30, 31] }, { tag: 'body', res: 0.008 });
      else S.box([-0.02, 1.4, 0], [0.09, 0.03, 0.015], CLOTH, { tag: 'body', res: 0.008 }); // crest
      // the off arm (far side): holds the bow; otherwise swings while walking
      const SHO = [0.0, 1.05, -0.17], HO = [0.02, 0.66, -0.2];
      S.tube([SHO, HO], 0.045, 0.04, ARM, { tag: 'armO', res: 0.012 });
      // the weapon arm (near side) and the weapon in its hand, sculpted hanging straight down
      const SH = [0.0, 1.05, 0.17], H = [0.02, 0.66, 0.2];
      S.tube([SH, H], 0.045, 0.04, ARM, { tag: 'armW', res: 0.012 });
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
