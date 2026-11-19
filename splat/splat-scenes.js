// Splat scenes for the toy's world strip: the Mine and the Forge, drawn from sprite layers that were
// pre-rendered with ink-studio (see splat/tools). One background picture, small cut-outs for the worker's
// frames and the fire, and pixel sparks, chips and lantern flicker drawn here. Plain canvas 2D, no WebGL,
// so it runs on any tablet; it only draws while its spot in the strip is on screen.
//
//   const s = SplatScenes.mount(el, 'forge');  s.start('Axe'); s.hit('P'); s.finish();
//   const m = SplatScenes.mount(el, 'mine');   m.swing('+55 ore');
//   const j = SplatScenes.mount(el, 'jobs');   j.act('+1 Miner'); j.count(5);   (most other spots work like this)
//   const f = SplatScenes.mount(el, 'fight');  f.army(['Sword','Bow']); f.begin(A, B, 2); f.ev(e); f.end(true);   (the battlefield, below)
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
      dur: { idle: 1, strike: 0.12, recover: 0.38 },
      loops: {},
      hit: [266, 124],
      popArea: [236, 300, 96, 112], // x0, x1, y0, y1: where the ore popups appear, above the boulder
      glows: [{ x: 97, y: 48, r: 26, c: '255,190,90', a: 0.16 }, { x: 193, y: 50, r: 22, c: '255,190,90', a: 0.14 },
        { x: 309, y: 46, r: 26, c: '255,190,90', a: 0.16 }, { x: 357, y: 62, r: 28, c: '255,190,90', a: 0.18 }]
    },
    // the generic spots: an idle loop, one act, props shown by count; landAt = seconds into the act when the pop and burst happen
    jobs: {
      dur: { idle: 1, act: 0.6 }, loops: {}, landAt: 0.25,
      hit: [262, 62], burst: ['#f0e6c8', '#c8b890', '#d84a30'],
      popArea: [200, 280, 30, 52],
      glows: [{ x: 123, y: 74, r: 30, c: '255,190,90', a: 0.2 }, { x: 368, y: 76, r: 30, c: '255,190,90', a: 0.2 }]
    },
    orders: {
      dur: { idle: 1, act: 0.6 }, loops: {}, landAt: 0.3,
      hit: [240, 88], burst: ['#ffe08a', '#f0b840', '#fff4c0'],
      popArea: [196, 284, 40, 66],
      glows: [{ x: 149, y: 91, r: 24, c: '255,190,90', a: 0.22 }, { x: 330, y: 91, r: 24, c: '255,190,90', a: 0.22 }]
    },
    armory: {
      dur: { idle: 1, act: 0.6 }, loops: {}, landAt: 0.15,
      hit: [330, 141], burst: ['#ffd070', '#ff9a40', '#fff4c0'],
      popArea: [268, 326, 84, 104],
      glows: [{ x: 115, y: 75, r: 30, c: '255,170,80', a: 0.24 }, { x: 367, y: 75, r: 30, c: '255,170,80', a: 0.24 }]
    },
    barracks: {
      dur: { idle: 1, act: 0.6 }, loops: {}, landAt: 0.15,
      hit: [343, 64], burst: ['#fff4c0', '#ffe08a', '#d8e4f0'],
      popArea: [272, 334, 44, 62],
      glows: []
    },
    library: {
      dur: { idle: 1, act: 0.6 }, loops: {}, landAt: 0.25,
      hit: [310, 128], burst: ['#fff4c0', '#c8ecff', '#e8dcb8'],
      popArea: [278, 336, 96, 114],
      glows: [{ x: 321, y: 148, r: 16, c: '255,200,110', a: 0.26 }, { x: 240, y: 48, r: 36, c: '150,210,255', a: 0.12 }]
    },
    sanctum: {
      dur: { idle: 1, act: 0.6 }, loops: {}, landAt: 0.12,
      hit: [266, 96], burst: ['#f4eeff', '#b69cff', '#8affe0'],
      popArea: [190, 246, 82, 102],
      glows: [{ x: 240, y: 172, r: 54, c: '182,156,255', a: 0.14 }, { x: 266, y: 96, r: 14, c: '200,255,240', a: 0.2 }]
    },
    upg: {
      dur: { idle: 1, act: 0.6 }, loops: {}, landAt: 0.12,
      hit: [186, 99], burst: ['#ffffff', '#d9e6ff', '#f0d070'],
      popArea: [150, 214, 52, 72],
      glows: [{ x: 222, y: 108, r: 20, c: '255,220,140', a: 0.24 }, { x: 360, y: 116, r: 18, c: '255,220,140', a: 0.22 }]
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
      for (let i = 0; i < Math.min(this.nProps || 0, (this.meta.props || []).length); i++) this.sprite(this.meta.props[i]);
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

  // a short text that floats up from a random spot in the scene's pop area (the +ore over the boulder, and so on)
  Scene.prototype.pop = function (text) {
    if (!this.meta || !this.cv.width || !this.cfg.popArea) return;
    const [x0, x1, y0, y1] = this.cfg.popArea, x = x0 + Math.random() * (x1 - x0), y = y0 + Math.random() * (y1 - y0);
    const e = document.createElement('span');
    e.textContent = text;
    e.style.cssText = `position:absolute;left:${(((x - this.ox) / this.cv.width) * 100).toFixed(1)}%;top:${(((y - this.oy) / this.cv.height) * 100).toFixed(1)}%;` +
      'transform:translate(-50%,-50%);z-index:3;pointer-events:none;white-space:nowrap;font-weight:800;font-size:15px;color:#f3cf6a;' +
      'text-shadow:0 1px 0 #2a1608,0 0 6px rgba(0,0,0,.8)';
    this.el.appendChild(e);
    if (e.animate) e.animate([{ transform: 'translate(-50%,-50%)', opacity: 1 }, { transform: 'translate(-50%,-50%) translateY(-6px)', opacity: 1, offset: 0.35 }, { transform: 'translate(-50%,-50%) translateY(-26px)', opacity: 0 }], { duration: 850, easing: 'ease-out' });
    setTimeout(() => e.remove(), 860);
  };
  // the other spots: act(label) plays the worker's one move and pops the label; count(n) shows the first n props
  class Generic extends Scene {
    act(label) {
      if (this.seg === 'act' && !this.landed) this.land();
      this.label = label; this.landed = false; this.play('act', ['idle']);
    }
    land() { this.landed = true; if (this.cfg.burst) this.burst(this.cfg.hit, 8, this.cfg.burst, 0.8); if (this.label) this.pop(this.label); this.label = null; }
    step(dt) { super.step(dt); if (this.seg === 'act' && !this.landed && this.segT >= this.cfg.landAt) this.land(); }
    count(n) { if (n !== this.nProps) { this.nProps = n; this.draw(); } }
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
    constructor(el) { super(el, 'mine'); this.onEnd = seg => { if (seg === 'strike') this.landed(); }; }
    // he waits with the pick up; a tap is an instant strike, chips fly and the ore count pops up over the boulder
    swing(label) {
      if (this.seg === 'strike') this.landed(); // tapping faster than the swing: count the blow that was under way
      this.label = label; this.play('strike', ['recover', 'idle']);
    }
    landed() {
      this.burst(this.cfg.hit, 8, ['#d88038', '#f0b070', '#9a4a22', '#584738'], 0.9);
      if (this.label) this.pop(this.label);
      this.label = null;
    }
  }

  // ---- the Fight spot: an open field where the army waits in single file, marches out and fights it out ----
  // Fighters are pre-rendered cut-outs (units.png, from art/toy-unit.js via tools/units.py), one set per weapon and side;
  // foes are the same frames mirrored. Bars, arrows, bolts, sparks and the line closing up are drawn here.
  //   f.army(['Sword','Bow'])            the heroes waiting at the left (Hero 1 first, nearest the fight)
  //   f.begin(A, B, spd) -> ms           the march out; A and B are the battle's units ({id, arch, hp, max})
  //   f.ev(e)  f.meters(ids, m)          a battle event as it plays, and the attack meters for this tick
  //   f.skip(A, B)  f.end(win)           jump to the result; the battle is over (the army walks back after a moment)
  const FOOT_Y = 158; // where feet meet the track, in field.png pixels
  const RANGED = { Bow: 1, Staff: 1, Grimoire: 1 };
  function loadImg(src) { return new Promise((ok, bad) => { const i = new Image(); i.onload = () => ok(i); i.onerror = bad; i.src = src; }); }
  class Field {
    constructor(el) {
      this.el = el; this.name = 'fight';
      this.cv = document.createElement('canvas');
      this.cv.className = 'splat-cv';
      this.cv.style.cssText = 'position:absolute;inset:0;width:100%;height:100%;image-rendering:pixelated;image-rendering:crisp-edges;pointer-events:none';
      el.prepend(this.cv);
      this.ctx = this.cv.getContext('2d');
      this.units = []; this.parts = []; this.shots = []; this.later = []; this.pops = 0;
      this.mode = 'idle'; this.archs = []; this.time = 0; this.last = 0; this.visible = true; this.shake = 0;
      this.spd = () => 2;
      this.ready = Promise.all([fetch(BASE + 'units.json').then(r => r.json()), loadImg(BASE + 'units.png'), loadImg(BASE + 'field.png')])
        .then(([meta, img, bg]) => { this.meta = meta; this.img = img; this.bg = bg; el.classList.add('splat-on'); this.fit(); this.camp(true); this.tick(); });
      if ('IntersectionObserver' in window) new IntersectionObserver(es => { this.visible = es[es.length - 1].isIntersecting; if (this.visible) this.tick(); }).observe(el);
      if ('ResizeObserver' in window) new ResizeObserver(() => this.fit()).observe(el);
    }
    get live() { return this.mode === 'march' || this.mode === 'fight' || this.mode === 'over'; }
    fit() {
      if (!this.bg) return;
      const r = this.el.getBoundingClientRect(), W = this.bg.width, H = this.bg.height;
      if (!r.width || !r.height) return;
      const s = Math.max(r.width / W, r.height / H);
      const w = Math.min(W, Math.round(r.width / s)), h = Math.min(H, Math.round(r.height / s));
      if (this.cv.width !== w || this.cv.height !== h) { this.cv.width = w; this.cv.height = h; }
      this.ox = Math.round((W - w) / 2); this.oy = Math.round((H - h) / 2);
      this.place(false); this.draw();
    }
    // ---- where everyone stands (x is measured from the middle of the view; heroes left, foes right) ----
    gap(n, room) { return n > 1 ? Math.max(6, Math.min(19, room / (n - 1))) : 0; }
    place(snap) {
      const half = (this.cv.width || 300) / 2;
      if (this.mode === 'idle' || this.mode === 'home') {
        const hs = this.units.filter(u => u.side === 0), sp = this.gap(hs.length, half * 0.62);
        hs.forEach((u, k) => { u.tx = -half * 0.3 - k * sp; if (snap) u.x = u.tx; });
        return;
      }
      for (const side of [0, 1]) {
        const alive = this.units.filter(u => u.side === side && !u.dead), sp = this.gap(alive.length, half - 30);
        alive.forEach((u, k) => { u.tx = (side ? 1 : -1) * (13 + k * sp); if (snap) u.x = u.tx; });
      }
    }
    unit(arch, side, id, hp, max, k) {
      return { id, arch: this.meta && this.meta.archs.includes(arch) ? arch : 'Sword', side, hp, max, ghost: hp, x: 0, tx: 0, m: 0, dead: false, deadAt: 0,
        atkAt: -9, hurtAt: -9, ph: (k * 0.37) % 1, alpha: 1, pend: 0, dy: k % 2 ? -3 : 0 }; // every other fighter a step further back, so a long file reads as people
    }
    // the army at rest: the equipped heroes in single file on the left
    army(archs) {
      this.archs = archs.slice();
      if (this.mode === 'idle') this.camp(true);
    }
    camp(snap, from) {
      this.mode = 'idle';
      this.units = this.archs.map((a, k) => this.unit(a, 0, 'h' + k, 1, 1, k));
      this.place(true);
      if (from) for (const u of this.units) u.x = u.tx - from; // they walk back in from the left
      this.draw();
    }
    begin(A, B, spd) {
      if (!this.meta) return 0;
      const half = (this.cv.width || 300) / 2, olds = this.units.filter(u => u.side === 0);
      this.mode = 'march'; this.later = []; this.shots = []; this.parts = [];
      this.units = [...A.map((u, k) => this.unit(u.arch, 0, u.id, u.hp, u.max, k)), ...B.map((u, k) => this.unit(u.arch, 1, u.id, u.hp, u.max, k))];
      this.units.forEach(u => (u.m = 0));
      // heroes start where they stood in camp; foes come in from beyond the right edge
      const sp = this.gap(olds.length, half * 0.62);
      this.units.filter(u => u.side === 0).forEach((u, k) => { u.x = olds[k] ? olds[k].x : -half * 0.3 - k * sp; });
      this.place(false);
      this.units.filter(u => u.side === 1).forEach((u, k) => { u.x = half + 16 + (u.tx - 13); });
      const k = this.k(spd), far = Math.max(...this.units.map(u => Math.abs(u.tx - u.x)), 1);
      this.walkV = far / (1.5 / k); // everyone arrives together
      this.fightAt = this.time + 1.5 / k;
      this.tick();
      return Math.round((1.5 / k) * 1000) + 60;
    }
    k(spd) { spd = spd === undefined ? this.spd() : spd; return Math.max(0.75, Math.min(2.6, (spd || 2) / 1.5)); }
    byId(id) { return this.units.find(u => u.id === id); }
    meters(ids, m) { ids.forEach((id, i) => { const u = this.byId(id); if (u) u.m = m[i]; }); }
    at(dt, fn) { this.later.push({ t: this.time + dt, fn }); }
    // ---- one battle event ----
    ev(e) {
      if (!this.meta || this.mode === 'idle') return;
      this.mode = 'fight';
      const k = this.k(), d = this.byId(e.d), a = e.a ? this.byId(e.a) : null, land = 0.2 / k;
      if (!d) return;
      if (e.k === 'hit') {
        let t = 0;
        if (a && !e.thorns && !e.cover && !e.cleave && !e.bleed) { a.atkAt = this.time; }
        if (a && !e.thorns && !e.bleed) {
          if (RANGED[a.arch] && Math.abs(a.x - d.x) > 24) {
            const fly = Math.abs(a.x - d.x) / (a.arch === 'Bow' ? 260 : 190) / k;
            t = land + fly; this.at(land, () => this.shot(a, d, a.arch === 'Bow' ? 'arrow' : a.arch === 'Staff' ? 'bolt' : 'orb', fly));
          } else t = land;
        }
        d.pend = Math.max(d.pend, this.time + t);
        this.at(t, () => this.impact(d, e));
      } else if (e.k === 'heal') {
        let t = 0;
        if (a && a !== d) { a.atkAt = this.time; t = land + 0.1 / k; }
        d.pend = Math.max(d.pend, this.time + t);
        this.at(t, () => { d.hp = e.hp; d.ghost = Math.max(d.ghost, d.hp); this.sparkle(d); this.pop(d, '+' + e.amt, '#8af08a'); });
      } else if (e.k === 'down') {
        const t = Math.max(0, d.pend - this.time) + 0.02;
        d.pend = this.time + t;
        this.at(t, () => { d.hp = 0; d.dead = true; d.deadAt = this.time; this.place(false); });
      } else if (e.k === 'buff' && /spell/.test(e.txt || '')) {
        this.at(land, () => this.flashLine(1 - d.side));
      }
    }
    impact(d, e) {
      d.hp = e.hp; d.hurtAt = this.time;
      const c = this.chest(d);
      if (e.bleed) this.burst(c, 4, ['#a01818', '#d83030'], 0.5);
      else this.burst(c, e.crit || e.fury ? 12 : 6, e.spell ? ['#d0b0ff', '#8a5ac0', '#ffffff'] : e.crit ? ['#fff4b0', '#ffd060', '#ffffff'] : ['#ffe8c0', '#ffb060', '#c8c8d0'], e.crit ? 1.2 : 0.8);
      if (e.crit || e.fury) this.shake = 0.12;
      this.pop(d, '-' + e.dmg + (e.crit ? '!' : ''), e.crit || e.fury ? '#ffd24a' : e.bleed ? '#e05050' : '#ffffff', e.crit || e.fury);
    }
    shot(a, d, kind, dur) {
      const fy = FOOT_Y - this.oy, dir = a.side ? -1 : 1;
      this.shots.push({ x0: a.x + dir * 8, y0: fy - 27, x1: d.x, y1: fy - 24, t0: this.time, dur, kind, arc: kind === 'arrow' ? Math.min(26, Math.abs(d.x - a.x) * 0.22) : 0 });
    }
    chest(u) { return [u.x + this.cv.width / 2, FOOT_Y - this.oy - 24 + (u.dy || 0)]; }
    sparkle(u) {
      const [x, y] = this.chest(u);
      for (let i = 0; i < 8; i++) this.parts.push({ x: x + (Math.random() - 0.5) * 12, y: y + 8 - Math.random() * 16, vx: 0, vy: -14 - Math.random() * 10, g: -6, life: 0.5 + Math.random() * 0.3, c: i % 2 ? '#8af08a' : '#e8ffe0', s: 1 });
    }
    flashLine(side) { for (const u of this.units) if (u.side === side && !u.dead) this.burst(this.chest(u), 5, ['#d0b0ff', '#8a5ac0'], 0.7); }
    burst([x, y], n, colours, speed = 1) {
      for (let i = 0; i < n; i++) {
        const a = -Math.PI * (0.05 + 0.9 * Math.random()), v = (40 + Math.random() * 60) * speed;
        this.parts.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: 0.2 + Math.random() * 0.25, c: colours[i % colours.length], g: 220 });
      }
    }
    // numbers float up over the fighter, as page text so they stay crisp
    pop(u, text, colour, big) {
      if (this.pops > 9 || !this.cv.width) return;
      const [x, y] = this.chest(u), e = document.createElement('span');
      e.textContent = text;
      e.style.cssText = `position:absolute;left:${((x / this.cv.width) * 100).toFixed(1)}%;top:${(((y - 16) / this.cv.height) * 100).toFixed(1)}%;` +
        `transform:translate(-50%,-50%);z-index:3;pointer-events:none;white-space:nowrap;font-weight:900;font-size:${big ? 14 : 11}px;color:${colour};` +
        'text-shadow:0 1px 0 #1a0e06,1px 0 0 #1a0e06,-1px 0 0 #1a0e06,0 -1px 0 #1a0e06,0 0 6px rgba(0,0,0,.7)';
      this.el.appendChild(e); this.pops++;
      const dx = (Math.random() - 0.5) * 14, dur = Math.round(900 / Math.sqrt(this.k()));
      if (e.animate) e.animate([{ transform: 'translate(-50%,-50%) scale(.6)', opacity: 1 }, { transform: `translate(calc(-50% + ${dx / 2}px),-50%) translateY(-8px) scale(${big ? 1.25 : 1})`, opacity: 1, offset: 0.25 },
        { transform: `translate(calc(-50% + ${dx}px),-50%) translateY(-24px) scale(1)`, opacity: 0 }], { duration: dur, easing: 'ease-out' });
      setTimeout(() => { e.remove(); this.pops--; }, dur);
    }
    // the result: every remaining event is applied, nobody animates
    skip(A, B) {
      if (!this.meta) return;
      if (this.mode === 'idle') this.begin(A, B, 2);
      this.later = []; this.shots = [];
      for (const s of [...A, ...B]) { const u = this.byId(s.id); if (u) { u.hp = s.hp; u.ghost = s.hp; u.m = 0; if (s.hp <= 0 && !u.dead) { u.dead = true; u.deadAt = this.time - 5; } } }
      this.mode = 'fight'; this.place(true);
    }
    end(win) {
      if (!this.meta) return;
      this.mode = 'over'; this.win = win; this.overAt = this.time + Math.max(0.3, ...this.later.map(l => l.t - this.time));
      this.units.forEach(u => (u.m = 0));
      clearTimeout(this.homeT);
      this.homeT = setTimeout(() => { if (this.mode === 'over') this.goHome(); }, 3200);
      setTimeout(() => this.banner(win ? 'Victory!' : 'Defeat', win ? '#ffd24a' : '#ff7a6a'), Math.max(0, this.overAt - this.time) * 1000 + 250);
      this.tick();
    }
    banner(text, colour) {
      const e = document.createElement('div');
      e.textContent = text;
      e.style.cssText = 'position:absolute;left:50%;top:30%;transform:translate(-50%,-50%);z-index:4;pointer-events:none;white-space:nowrap;' +
        `font:900 30px var(--display,serif);letter-spacing:.06em;color:${colour};text-shadow:0 2px 0 #1a0e06,2px 0 0 #1a0e06,-2px 0 0 #1a0e06,0 -2px 0 #1a0e06,0 0 14px rgba(0,0,0,.6)`;
      this.el.appendChild(e);
      if (e.animate) e.animate([{ transform: 'translate(-50%,-50%) scale(.4)', opacity: 0 }, { transform: 'translate(-50%,-50%) scale(1.15)', opacity: 1, offset: 0.12 },
        { transform: 'translate(-50%,-50%) scale(1)', opacity: 1, offset: 0.2 }, { transform: 'translate(-50%,-50%) scale(1)', opacity: 1, offset: 0.85 }, { transform: 'translate(-50%,-60%) scale(1)', opacity: 0 }], { duration: 2600, easing: 'ease-out' });
      setTimeout(() => e.remove(), 2600);
    }
    goHome() {
      // the field clears and the army walks back in to camp, everyone on their feet again
      // survivors walk back from where they stand, the fallen rejoin from the left, foes still standing leave to the right
      const half = (this.cv.width || 300) / 2, was = this.units.filter(u => u.side === 0), foes = this.units.filter(u => u.side === 1 && !u.dead);
      this.later = []; this.shots = [];
      this.camp(true);
      this.units.forEach((u, k) => { const o = was[k]; u.x = o && !o.dead ? o.x : -half - 14 - k * 8; });
      foes.forEach((u, k) => { u.tx = half + 30 + k * 10; u.leaving = true; this.units.push(u); });
      this.mode = 'home'; this.walkV = 60; this.tick();
    }
    // ---- the frame loop ----
    tick() {
      if (this.raf || !this.meta) return;
      this.raf = requestAnimationFrame(now => {
        this.raf = 0;
        if (!this.visible || document.hidden) { this.last = 0; return; }
        const dt = this.last ? Math.min(0.1, (now - this.last) / 1000) : 0;
        this.last = now; this.time += dt;
        this.step(dt); this.draw(); this.tick();
      });
    }
    step(dt) {
      const due = this.later.filter(l => l.t <= this.time);
      this.later = this.later.filter(l => l.t > this.time);
      due.sort((a, b) => a.t - b.t).forEach(l => l.fn());
      const v = this.mode === 'march' || this.mode === 'home' ? this.walkV : 34 * this.k();
      for (const u of this.units) {
        if (u.dead) { u.alpha = Math.max(0.55, 1 - (this.time - u.deadAt - 1.2) * 0.5); continue; }
        const d = u.tx - u.x;
        u.moving = Math.abs(d) > 0.4;
        u.x += Math.sign(d) * Math.min(Math.abs(d), v * dt);
        u.ghost = Math.max(u.hp, u.ghost - Math.max(1, u.max * 0.6) * dt);
      }
      if (this.mode === 'march' && this.time >= this.fightAt) this.mode = 'fight';
      this.units = this.units.filter(u => !(u.leaving && !u.moving));
      if (this.mode === 'home' && !this.units.some(u => u.moving)) this.mode = 'idle';
      for (const p of this.parts) { p.vy += (p.g || 220) * dt; p.x += p.vx * dt; p.y += p.vy * dt; p.life -= dt; }
      this.parts = this.parts.filter(p => p.life > 0);
      this.shots = this.shots.filter(s => this.time - s.t0 < s.dur);
      this.shake = Math.max(0, this.shake - dt);
    }
    frame(u) {
      const S = this.meta.seg, t = this.time, k = this.k();
      let seg = 'idle', i;
      if (u.dead) { seg = 'down'; i = Math.min(2, Math.floor(((t - u.deadAt) / 0.4) * 3)); }
      else if (t - u.atkAt < 0.45 / k) { seg = 'atk'; i = Math.min(5, Math.floor(((t - u.atkAt) / (0.45 / k)) * 6)); }
      else if (t - u.hurtAt < 0.16) { seg = 'hurt'; i = 0; }
      else if (u.moving) { seg = 'walk'; i = Math.floor(((t * (this.mode === 'march' ? k : 1)) / 0.62 + u.ph) * 6) % 6; }
      else { i = Math.floor((t / 1.1 + u.ph) * 4) % 4; }
      if (this.mode === 'over' && this.win !== undefined && !u.dead && (u.side === 0) === !!this.win && seg === 'idle') return { name: `${u.arch}-${u.side ? 'foe' : 'hero'}-${S.idle[0]}`, hop: Math.max(0, Math.sin((t * 1.6 + u.ph) * Math.PI * 2)) * 3 };
      return { name: `${u.arch}-${u.side ? 'foe' : 'hero'}-${S[seg][i]}`, hop: 0, lunge: seg === 'atk' && !RANGED[u.arch] ? Math.sin((i / 5) * Math.PI) * 4 : 0 };
    }
    draw() {
      if (!this.meta || !this.cv.width) return;
      const c = this.ctx, W = this.cv.width, cx = Math.round(W / 2), fy = FOOT_Y - this.oy;
      const sx = this.shake > 0 ? Math.round((Math.random() - 0.5) * 2) : 0;
      c.globalAlpha = 1;
      c.drawImage(this.bg, this.ox - sx, this.oy, W, this.cv.height, 0, 0, W, this.cv.height);
      const [fx, fyy] = this.meta.foot;
      // back of each file first, so the fighter nearer the clash overlaps the one behind; the fallen lie underneath
      const order = this.units.slice().sort((a, b) => (b.dead - a.dead) || (a.dy - b.dy) || (Math.abs(b.x) - Math.abs(a.x)));
      for (const u of order) {
        const f = this.frame(u), s = this.meta.sprites[f.name];
        if (!s) continue;
        const dir = u.side ? -1 : 1, x = Math.round(cx + u.x + dir * (f.lunge || 0)) + sx, y = fy + u.dy - Math.round(f.hop || 0);
        // a soft shadow on the track
        c.globalAlpha = 0.28 * u.alpha; c.fillStyle = '#2a2010';
        c.fillRect(x - 6, fy + u.dy - 1, 13, 2); c.fillRect(x - 4, fy + u.dy - 2, 9, 1);
        c.globalAlpha = u.alpha;
        if (u.side) { c.save(); c.translate(x, 0); c.scale(-1, 1); c.drawImage(this.img, s[0], s[1], s[2], s[3], s[4] - fx, y + s[5] - fyy, s[2], s[3]); c.restore(); }
        else c.drawImage(this.img, s[0], s[1], s[2], s[3], x + s[4] - fx, y + s[5] - fyy, s[2], s[3]);
        // a white flash on the frame they are struck
        if (this.time - u.hurtAt < 0.07 && !u.dead) {
          c.globalCompositeOperation = 'lighter'; c.globalAlpha = 0.5;
          if (u.side) { c.save(); c.translate(x, 0); c.scale(-1, 1); c.drawImage(this.img, s[0], s[1], s[2], s[3], s[4] - fx, y + s[5] - fyy, s[2], s[3]); c.restore(); }
          else c.drawImage(this.img, s[0], s[1], s[2], s[3], x + s[4] - fx, y + s[5] - fyy, s[2], s[3]);
          c.globalCompositeOperation = 'source-over';
        }
      }
      c.globalAlpha = 1;
      // arrows, bolts and orbs in flight
      for (const s of this.shots) {
        const p = Math.min(1, (this.time - s.t0) / s.dur), x = cx + s.x0 + (s.x1 - s.x0) * p, y = s.y0 + (s.y1 - s.y0) * p - s.arc * 4 * p * (1 - p);
        if (s.kind === 'arrow') {
          const vx = s.x1 - s.x0, vy = (s.y1 - s.y0) - s.arc * 4 * (1 - 2 * p), l = Math.hypot(vx, vy) || 1, ux = vx / l, uy = vy / l;
          c.fillStyle = '#6e4628'; for (let i = 1; i < 6; i++) c.fillRect(Math.round(x - ux * i), Math.round(y - uy * i), 1, 1);
          c.fillStyle = '#e8ecf0'; c.fillRect(Math.round(x), Math.round(y), 1, 1);
          c.fillStyle = '#f4f4f0'; c.fillRect(Math.round(x - ux * 6), Math.round(y - uy * 6) - 1, 1, 2);
        } else {
          const col = s.kind === 'bolt' ? ['#7ae0b0', '#d8fff0'] : ['#8a5ac0', '#e0c8ff'], dir = Math.sign(s.x1 - s.x0);
          c.globalAlpha = 0.5; c.fillStyle = col[0]; c.fillRect(Math.round(x - dir * 4), Math.round(y), 3, 1);
          c.globalAlpha = 1; c.fillRect(Math.round(x) - 1, Math.round(y) - 1, 3, 3); c.fillStyle = col[1]; c.fillRect(Math.round(x), Math.round(y), 1, 1);
        }
      }
      // health and attack meters over every fighter still standing
      if (this.live) {
        const near = {}; for (const side of [0, 1]) { const a = this.units.filter(u => u.side === side && !u.dead); near[side] = a.length > 1 ? Math.abs(a[1].tx - a[0].tx) : 19; }
        for (const u of this.units) {
          if (u.dead) continue;
          const bw = Math.max(5, Math.min(14, Math.round(near[u.side]) - 3)), x = Math.round(cx + u.x - bw / 2) + sx, y = fy + u.dy - 49;
          c.fillStyle = 'rgba(14,10,8,.85)'; c.fillRect(x - 1, y - 1, bw + 2, 5);
          const hp = Math.max(0, Math.round((u.hp / u.max) * bw)), gh = Math.max(0, Math.round((u.ghost / u.max) * bw));
          c.fillStyle = '#f4e8d0'; c.fillRect(x, y, gh, 2);
          c.fillStyle = u.side ? (u.hp / u.max < 0.3 ? '#ff7050' : '#e04a3a') : u.hp / u.max < 0.3 ? '#e8c040' : '#5ad45a'; c.fillRect(x, y, hp, 2);
          const m = Math.round((Math.min(100, u.m) / 100) * bw);
          c.fillStyle = u.m >= 100 ? (Math.floor(this.time * 10) % 2 ? '#fff4b0' : '#f0c040') : '#d8a030'; c.fillRect(x, y + 3, m, 1);
        }
      }
      for (const p of this.parts) { c.globalAlpha = Math.min(1, p.life * 4); c.fillStyle = p.c; c.fillRect(Math.round(p.x) + sx, Math.round(p.y), 1, 1); }
      c.globalAlpha = 1;
    }
  }

  window.SplatScenes = {
    mount(el, name) { return name === 'fight' ? new Field(el) : name === 'forge' ? new Forge(el) : name === 'mine' ? new Mine(el) : SCENES[name] ? new Generic(el, name) : null; },
    names: () => [...Object.keys(SCENES), 'fight'],
    supported: !!(window.fetch && window.requestAnimationFrame && document.createElement('canvas').getContext)
  };
})();
