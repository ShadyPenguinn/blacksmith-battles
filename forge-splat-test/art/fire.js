// The forge's flames as their own clip, looping on the clock: three tongues that stretch, squash and sway.
// Same world space as forge-live.js (furnace at x -1.9, z -1.2); placed at the origin.
module.exports = ({ makeBuilder, makeSculpt, KIT: K }) => ({
  id: 'fire',
  name: 'Forge fire',
  seed: 5,
  build(seed) {
    const B = makeBuilder(seed, [0x07080b, 0x7a1810, 0xb02a18, 0xff6a20, 0xffb838, 0xfff0a0]);
    const S = K.sculpt(makeSculpt(B));
    S.res = 0.02;
    const tags = K.deform.tags(S);
    const FX = -1.9, FZ = -1.2;
    const tongues = [
      { x: FX - 0.12, z: FZ + 0.5, h: 0.5, w: 0.15 },
      { x: FX + 0.13, z: FZ + 0.55, h: 0.38, w: 0.12 },
      { x: FX - 0.3, z: FZ + 0.58, h: 0.27, w: 0.09 },
      { x: FX + 0.0, z: FZ + 0.62, h: 0.2, w: 0.08 }
    ];
    tongues.forEach((f, i) => {
      const o = { tag: 'f' + i, res: 0.02 };
      S.lathe([f.x, 0.26, f.z], f.h, t => f.w * Math.pow(1 - t, 0.8) * (0.6 + 0.4 * Math.sin(Math.min(1, t * 3) * 1.57)), { r: [2, 3], em: true }, o);
      S.lathe([f.x, 0.27, f.z + f.w * 0.45], f.h * 0.72, t => f.w * 0.66 * Math.pow(1 - t, 0.8), { r: [4], em: true }, o);
      S.lathe([f.x, 0.27, f.z + f.w * 0.75], f.h * 0.4, t => f.w * 0.36 * (1 - t), { r: [5], em: true }, o);
    });
    S.bake();
    const W = B.finish({ cam: { target: [FX, 0.5, FZ], dist: 3, pitch: 0.3, yaw: 0.32 }, detail: 26 });
    const parts = {};
    tongues.forEach((f, i) => (parts['f' + i] = { ids: tags['f' + i], pivot: [f.x, 0.26, f.z], slices: 4 }));
    // frequencies that are whole multiples of 0.5 Hz, so the 2 s clip loops without a seam
    const TAU = Math.PI * 2;
    K.puppet(W, {
      parts,
      pose(t, dt, pup) {
        tongues.forEach((f, i) => {
          const a = i * 1.7;
          const s = 1 + 0.18 * Math.sin(TAU * 2.5 * t + a) + 0.1 * Math.sin(TAU * 4.5 * t + a * 2) + 0.06 * Math.sin(TAU * 7.5 * t + a * 3);
          const w = 1 - 0.35 * (s - 1);
          const sway = 7 * Math.sin(TAU * 1.5 * t + a) + 4 * Math.sin(TAU * 3.5 * t + a * 1.3);
          pup.pose['f' + i] = { scale: [w, s, w], rot: [0, 0, sway] };
        });
      }
    });
    return W;
  }
});
