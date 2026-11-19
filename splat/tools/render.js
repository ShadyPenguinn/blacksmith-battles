// Renders every frame the toy's splat scenes need with ink-studio (the copy vendored in forge-splat-test),
// into splat/tools/frames/<scene>/ (not committed). Then tools/pack.py <scene> packs them into <scene>.png + <scene>.json.
// Usage: node splat/tools/render.js forge|mine
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const CLI = path.join(ROOT, '..', 'forge-splat-test', 'addons', 'splats', 'tools', 'ink-studio', 'cli', 'ink-studio.js');
const steps = (a, b, n) => [...Array(n)].map((_, i) => +(a + ((b - a) * i) / n).toFixed(4));
const SCENES = {
  // clip: idle 0-1 s, raise 1-1.5, ready 1.5-2, slam 2-2.25, recover 2.25-2.5 (art/toy-forge.js)
  forge: {
    file: 'toy-forge.js',
    view: ['--zoom', '2.9', '--target', '0,1.05,0.1'],
    bg: { TOY_SMITH: '0', TOY_FIRE: '0' },
    loops: { fire: { env: { TOY_SMITH: '0' }, t: steps(0, 2, 24) } },
    actor: { env: { TOY_FIRE: '0' }, variable: 'TOY_PIECE', variants: ['sword', 'axe', 'spear', 'shield', 'hammer', 'bar'] },
    seg: {
      idle: { t: steps(0, 1, 12), variants: false },
      lower: { t: steps(1, 1.5, 6), variants: false },
      raise: { t: steps(1, 1.5, 6) },
      ready: { t: steps(1.5, 2, 6) },
      slam: { t: [2.0, 2.08, 2.14, 2.19, 2.23, 2.25] },
      recover: { t: [2.29, 2.33, 2.38, 2.42, 2.46] }
    },
    hit: { a: { TOY_FIRE: '0', TOY_PIECE: 'bar' }, b: { TOY_FIRE: '0' }, t: 1 }
  },
  // clip: idle 0-1 s, swing 1-1.6 (raise 1-1.3, strike 1.3-1.45, recover 1.45-1.6) (art/toy-mine.js)
  mine: {
    file: 'toy-mine.js',
    view: ['--tone', 'off', '--zoom', '2.6', '--target', '0.7,0.95,0.3'],
    bg: { TOY_WORKER: '0' },
    loops: {},
    actor: { env: {}, variants: [''] },
    seg: {
      idle: { t: steps(0, 1, 12), variants: false },
      swing: { t: [1.0, 1.06, 1.12, 1.18, 1.24, 1.3, 1.34, 1.38, 1.42, 1.45, 1.5, 1.55], variants: false }
    }
  }
};
const name = process.argv[2];
const SC = SCENES[name];
if (!SC) throw new Error('usage: render.js ' + Object.keys(SCENES).join('|'));
const OUT = path.join(__dirname, 'frames', name);
fs.mkdirSync(OUT, { recursive: true });
const VIEW = ['--clean', '--px', '2', ...SC.view, '--w', '960', '--h', '420'];
const jobs = [{ name: 'bg', env: SC.bg, t: 0 }];
const layout = { loops: {}, seg: {}, variants: SC.actor.variants };
for (const [k, L] of Object.entries(SC.loops)) {
  layout.loops[k] = L.t.map((t, i) => `${k}-${i}`);
  L.t.forEach((t, i) => jobs.push({ name: `${k}-${i}`, env: L.env, t }));
}
for (const [k, G] of Object.entries(SC.seg)) {
  const vs = G.variants === false ? [''] : SC.actor.variants;
  layout.seg[k] = { t: G.t, shared: G.variants === false };
  for (const v of vs)
    G.t.forEach((t, i) => jobs.push({ name: `${v ? v + '-' : ''}${k}-${i}`, env: { ...SC.actor.env, ...(v ? { [SC.actor.variable]: v } : {}) }, t }));
}
if (SC.hit) {
  jobs.push({ name: 'hit-a', env: SC.hit.a, t: SC.hit.t }, { name: 'hit-b', env: SC.hit.b, t: SC.hit.t });
}
fs.writeFileSync(path.join(OUT, 'jobs.json'), JSON.stringify({ ...layout, jobs: jobs.map(j => j.name) }));
let next = 0, running = 0, done = 0;
const N = Math.max(2, require('os').cpus().length);
const SCENE = path.join(ROOT, 'art', SC.file);
(function run() {
  while (running < N && next < jobs.length) {
    const j = jobs[next++];
    running++;
    const p = spawn('node', [CLI, 'render', SCENE, '--t', String(j.t), ...VIEW, '--out', path.join(OUT, j.name + '.png')], { env: { ...process.env, ...j.env }, stdio: 'ignore' });
    p.on('exit', code => {
      running--; done++;
      if (code) console.error('failed', j.name);
      if (done === jobs.length) console.log(`${name}: ${done} frames`);
      run();
    });
  }
})();
