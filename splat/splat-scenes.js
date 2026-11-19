// Splat scenes for the toy's world strip: the Mine and the Forge, drawn from sprite layers that were
// pre-rendered with ink-studio (see splat/tools). One background picture, small cut-outs for the worker's
// frames and the fire, and pixel sparks, chips and lantern flicker drawn here. Plain canvas 2D, no WebGL,
// so it runs on any tablet; it only draws while its spot in the strip is on screen.
//
//   const s = SplatScenes.mount(el, 'forge');  s.start('Axe'); s.hit('P'); s.finish();
//   const m = SplatScenes.mount(el, 'mine');   m.swing();
(function () {
  const BASE = (document.currentScript && document.currentScript.src.replace(/[^/]*$/, '')) || 'splat/';
  const cache = {};
  function load(name) {
    if (!cache[name])
      cache[name] = Promise.all([
        fetch(BASE + name + '.json').then(r => r.json()),
        new Promise((ok, bad) => { const i = new Image(); i.onload = () => ok(i); i.onerror = bad; i.src = BASE + name + '.png'; })
      ]);
    return cache[name];
  }

  // seconds each segment lasts in the clip (the clip times of its frames are in the json)
  const SCENES = {
    forge: {
      dur: { idle: 1, raise: 0.5, ready: 0.5, slam: 0.25, recover: 0.25, lower: 0.5 },
      loops: { fire: 2 },
      hit: [236, 123],
      glows: [{ x: 240, y: 76, r: 46, c: '255,140,50', a: 0.22 }],
      embersFrom: [240, 60]
    },
    mine: {
      dur: { idle: 1, swing: 0.6 },
      loops: {},
      hit: [266, 124],
      glows: [{ x: 97, y: 48, r: 26, c: '255,190,90', a: 0.16 }, { x: 193, y: 50, r: 22, c: '255,190,90', a: 0.14 },
        { x: 309, y: 46, r: 26, c: '255,190,90', a: 0.16 }, { x: 357, y: 62, r: 28, c: '255,190,90', a: 0.18 }]
    }
  };
  const PIECE = { Sword: 'sword', Axe: 'axe', Spear: 'spear', Shield: 'shield', Warhammer: 'hammer' };

  class Scene {
    constructor(el, name) {
      this.el = el; this.name = name; this.cfg = SCENES[name];
      this.cv = document.createElement('canvas');
      this.cv.className = 'splat-cv';
      this.cv.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;image-rendering:pixelated;image-rendering:crisp-edges;pointer-events:none';
      el.prepend(this.cv);
      this.ctx = this.cv.getContext('2d');
      this.parts = []; // sparks and chips: {x, y, vx, vy, life, c, g}
      this.seg = 'idle'; this.segT = 0; this.variant = ''; this.queue = []; this.visible = true; this.last = 0;
      this.ready = load(name).then(([meta, img]) => { this.meta = meta; this.img = img; el.classList.add('splat-on'); this.fit(); this.tick(); });
      if ('IntersectionObserver' in window) {
        new IntersectionObserver(es => { this.visible = es[es.length - 1].isIntersecting; if (this.visible) this.tick(); }).observe(el);
      }
      if ('ResizeObserver' in window) new ResizeObserver(() => this.fit()).observe(el);
    }
    // the canvas holds just the art pixels that show: the art fills the spot (cover), centred
    fit() {
      if (!this.meta) return;
      const r = this.el.getBoundingClientRect(), W = this.meta.w, H = this.meta.h;
      if (!r.width || !r.height) return;
      const s = Math.max(r.width / W, r.height / H);
      const w = Math.min(W, Math.round(r.width / s)), h = Math.min(H, Math.round(r.height / s));
      if (this.cv.width !== w || this.cv.height !== h) { this.cv.width = w; this.cv.height = h; }
      this.ox = Math.round((W - w) / 2); this.oy = Math.round((H - h) / 2);
      this.draw();
    }
    // play a segment now, then the queued ones; a looping segment (idle, ready) holds until replaced
    play(seg, then = []) { this.seg = seg; this.segT = 0; this.queue = then.slice(); this.tick(); }
    after(seg) { const q = this.queue; if (q.length) { this.seg = q.shift(); this.segT = 0; } else this.seg = this.seg === 'idle' || this.seg === 'ready' ? this.seg : this.restSeg(); }
    restSeg() { return this.name === 'forge' && this.variant ? 'ready' : 'idle'; }
    frameName() {
      const seg = this.meta.seg[this.seg], n = seg.t.length, d = this.cfg.dur[this.seg];
      let k = Math.min(n - 1, Math.floor((this.segT / d) * n));
      if (this.seg === 'lower') k = n - 1 - k; // the arm comes down the way it went up
      return (seg.shared ? '' : this.variant + '-') + this.seg + '-' + k;
    }
    tick() {
      if (this.raf || !this.meta) return;
      this.raf = requestAnimationFrame(now => {
        this.raf = 0;
        if (!this.visible || document.hidden) { this.last = 0; return; }
        const dt = this.last ? Math.min(0.1, (now - this.last) / 1000) : 0;
        this.last = now; this.time = now / 1000;
        this.segT += dt;
        const d = this.cfg.dur[this.seg];
        if (this.segT >= d) {
          const ended = this.seg;
          if (ended === 'idle' || ended === 'ready') this.segT %= d;
          else { this.after(ended); if (this.onEnd) this.onEnd(ended); }
        }
        if (this.seg === 'swing' && !this.chipped && this.segT >= 0.27) { this.chipped = true; this.burst(this.cfg.hit, 8, ['#d88038', '#f0b070', '#9a4a22', '#584738'], 0.9); }
        this.step(dt);
        this.draw();
        this.tick();
      });
    }
    step(dt) {
      for (const p of this.parts) { p.vy += (p.g || 260) * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt; }
      this.parts = this.parts.filter(p => p.life > 0);
      const e = this.cfg.embersFrom;
      if (e && Math.random() < dt * 3) this.parts.push({ x: e[0] + (Math.random() - 0.5) * 30, y: e[1], vx: (Math.random() - 0.5) * 6, vy: -8 - Math.random() * 8, g: -4, life: 1.6 + Math.random(), c: Math.random() < 0.5 ? '#ffb838' : '#ff6a20' });
    }
    burst([x, y], n, colours, speed = 1) {
      for (let i = 0; i < n; i++) {
        const a = -Math.PI * (0.1 + 0.8 * Math.random());
        const v = (50 + Math.random() * 70) * speed;
        this.parts.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: 0.25 + Math.random() * 0.3, c: colours[i % colours.length] });
      }
    }
    sprite(name) {
      const s = this.meta.sprites[name];
      if (s) this.ctx.drawImage(this.img, s[0], s[1], s[2], s[3], s[4] - this.ox, s[5] - this.oy, s[2], s[3]);
    }
    draw() {
      if (!this.meta || !this.cv.width) return;
      const c = this.ctx, t = this.time || 0;
      c.globalCompositeOperation = 'source-over';
      this.sprite('bg');
      for (const [k, names] of Object.entries(this.meta.loops)) {
        const secs = this.cfg.loops[k] || 1;
        this.sprite(names[Math.floor(((t % secs) / secs) * names.length) % names.length]);
      }
      this.sprite(this.frameName());
      // flickering light: soft additive glows over the lanterns and the furnace mouth
      c.globalCompositeOperation = 'lighter';
      this.cfg.glows.forEach((g, i) => {
        const f = 0.75 + 0.15 * Math.sin(t * 9.3 + i * 2) + 0.1 * Math.sin(t * 23.7 + i);
        const x = g.x - this.ox, y = g.y - this.oy;
        const gr = c.createRadialGradient(x, y, 0, x, y, g.r);
        gr.addColorStop(0, `rgba(${g.c},${(g.a * f).toFixed(3)})`);
        gr.addColorStop(1, `rgba(${g.c},0)`);
        c.fillStyle = gr;
        c.fillRect(x - g.r, y - g.r, g.r * 2, g.r * 2);
      });
      c.globalCompositeOperation = 'source-over';
      for (const p of this.parts) { c.fillStyle = p.c; c.fillRect(Math.round(p.x - this.ox), Math.round(p.y - this.oy), 1, 1); }
    }
  }

  class Forge extends Scene {
    constructor(el) { super(el, 'forge'); this.onEnd = seg => this.ended(seg); }
    // a new blank goes on the anvil and the hammer comes up
    start(arch) { this.variant = PIECE[arch] || 'bar'; this.finishing = false; this.play('raise', ['ready']); }
    // a tap: slam, sparks on contact (more for a Perfect), then back up
    hit(kind) {
      if (!this.variant) return;
      this.kind = kind; this.play('slam', ['recover', 'ready']);
    }
    ended(seg) {
      if (seg === 'slam') {
        const k = this.kind, h = this.meta ? this.cfg.hit : [0, 0];
        if (k === 'P') this.burst(h, 16, ['#fff0a0', '#ffb838', '#ff6a20'], 1.2);
        else if (k === 'G') this.burst(h, 8, ['#ffb838', '#ff6a20']);
        else this.burst(h, 4, ['#7a1810', '#5e5560'], 0.6);
      }
      if (this.finishing && (seg === 'recover' || seg === 'raise')) this.lowerNow();
    }
    // the piece is done: lower the hammer once the current blow is over, and clear the anvil
    finish() {
      if (!this.variant) return;
      if (this.seg === 'slam' || this.seg === 'recover' || this.seg === 'raise') { this.finishing = true; return; }
      this.lowerNow();
    }
    lowerNow() { this.finishing = false; this.variant = ''; this.play('lower', ['idle']); }
  }
  class Mine extends Scene {
    constructor(el) { super(el, 'mine'); }
    swing() { this.chipped = false; this.play('swing', ['idle']); }
  }

  window.SplatScenes = {
    mount(el, name) { return name === 'forge' ? new Forge(el) : name === 'mine' ? new Mine(el) : null; },
    supported: !!(window.fetch && window.requestAnimationFrame && document.createElement('canvas').getContext)
  };
})();
