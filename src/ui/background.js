/* ============================================================
   UI / BACKGROUND — animated 3D-ish stadium (menu) & clubhouse (hub)
   Dynamic camera, floodlights, haze particles, running players.
   ============================================================ */
const BG = {
  cv: null, ctx: null, mode: 'menu', t: 0, running: false, players: [], ball: null, parts: [], crowd: null, w: 0, h: 0,
  init() {
    this.cv = $('#bg'); this.ctx = this.cv.getContext('2d');
    const rs = () => { const d = Math.min(1.5, window.devicePixelRatio || 1); this.w = innerWidth; this.h = innerHeight; this.cv.width = this.w * d; this.cv.height = this.h * d; this.ctx.setTransform(d, 0, 0, d, 0, 0); this.crowd = null; };
    addEventListener('resize', rs); rs();
    // background players
    const kits = [['#e8b631', '#14161c'], ['#f2f2f2', '#2a6fdb']];
    for (let i = 0; i < 12; i++) this.players.push({ x: R.range(20, 85), z: R.range(8, 60), vx: 0, vz: 0, team: i % 2, kit: kits[i % 2], ph: R.range(0, 6), tx: 0, tz: 0, retarget: 0 });
    this.ball = { x: 52, z: 34, vx: 0, vz: 0, owner: 0 };
    for (let i = 0; i < 70; i++) this.parts.push({ x: Math.random(), y: Math.random(), s: R.range(.5, 2.2), v: R.range(.002, .01), a: R.range(.1, .5) });
    this.running = true;
    let last = performance.now();
    const loop = (now) => {
      const dt = clamp((now - last) / 1000, 0, 0.05); last = now;
      if (this.mode !== 'off') { this.t += dt; this.update(dt); this.draw(); }
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  },
  set(mode) { this.mode = mode; this.cv.style.display = mode === 'off' ? 'none' : 'block'; },
  update(dt) {
    const b = this.ball, ps = this.players;
    const owner = ps[b.owner];
    if (owner) { b.x = lerp(b.x, owner.x + 0.9, 0.3); b.z = lerp(b.z, owner.z, 0.3); }
    else { b.x += b.vx * dt; b.z += b.vz * dt; b.vx *= 0.985; b.vz *= 0.985; }
    if (owner && Math.random() < dt * 0.6) { // pass
      const mates = ps.filter((p, i) => p.team === owner.team && p !== owner);
      const tgt = R.pick(mates); const d = Math.hypot(tgt.x - b.x, tgt.z - b.z) || 1;
      b.vx = (tgt.x - b.x) / d * 22; b.vz = (tgt.z - b.z) / d * 22; b.owner = -1;
    }
    ps.forEach((p, i) => {
      p.retarget -= dt;
      if (b.owner === -1) { // chase ball
        const d = Math.hypot(b.x - p.x, b.z - p.z);
        if (d < 1.4) { b.owner = i; }
      }
      if (p.retarget <= 0) { p.tx = clamp(b.x + R.range(-22, 22), 6, 99); p.tz = clamp(b.z + R.range(-16, 16), 4, 64); p.retarget = R.range(1, 3); }
      const tx = (b.owner === -1 && Math.hypot(b.x - p.x, b.z - p.z) < 12) ? b.x : (i === b.owner ? p.x + (p.team ? -6 : 6) : p.tx);
      const tz = (b.owner === -1 && Math.hypot(b.x - p.x, b.z - p.z) < 12) ? b.z : (i === b.owner ? p.z + Math.sin(this.t + i) * 4 : p.tz);
      const dx = tx - p.x, dz = tz - p.z, d = Math.hypot(dx, dz) || 1;
      const sp = Math.min(d, i === b.owner ? 6 : 5.5);
      p.vx = lerp(p.vx, dx / d * sp, 0.08); p.vz = lerp(p.vz, dz / d * sp, 0.08);
      p.x = clamp(p.x + p.vx * dt, 2, 103); p.z = clamp(p.z + p.vz * dt, 2, 66);
      p.ph += Math.hypot(p.vx, p.vz) * dt * 1.6;
    });
    if (b.x < 2 || b.x > 103 || b.z < 2 || b.z > 66) { b.x = clamp(b.x, 3, 102); b.z = clamp(b.z, 3, 65); b.vx = -b.vx; b.vz = -b.vz; }
  },
  proj(x, z, y = 0) {
    const W = this.w, H = this.h;
    const camX = 52 + Math.sin(this.t * 0.07) * 18, camZ = -26 + Math.sin(this.t * 0.05) * 4, camY = 17 + Math.sin(this.t * 0.09) * 3;
    const f = W * 0.9;
    const dz = z - camZ;
    const s = f / dz;
    return { x: W / 2 + (x - camX) * s, y: H * 0.36 + (camY - y) * s, s };
  },
  draw() {
    const c = this.ctx, W = this.w, H = this.h;
    if (this.mode === 'hub') return this.drawHub();
    // sky
    const g = c.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, '#05070c'); g.addColorStop(0.5, '#0d1520'); g.addColorStop(1, '#030405');
    c.fillStyle = g; c.fillRect(0, 0, W, H);
    // stands (back + sides) with crowd
    const p0 = this.proj(-10, 72), p1 = this.proj(115, 72), q0 = this.proj(-10, 72, 22), q1 = this.proj(115, 72, 22);
    c.fillStyle = '#0c1018';
    c.beginPath(); c.moveTo(p0.x, p0.y); c.lineTo(p1.x, p1.y); c.lineTo(q1.x, q1.y); c.lineTo(q0.x, q0.y); c.fill();
    // crowd specks
    if (!this.crowd) { this.crowd = []; for (let i = 0; i < 1400; i++) this.crowd.push({ u: Math.random(), v: Math.random(), c: R.pick(['#e8b631', '#ffffff', '#2a6fdb', '#cf3b3b', '#8aa', '#ddd']), ph: Math.random() * 6 }); }
    for (const s of this.crowd) {
      const x = lerp(-10, 115, s.u), y = 1 + s.v * 20;
      const pp = this.proj(x, 72 + s.v * 6, y);
      const jump = Math.max(0, Math.sin(this.t * 3 + s.ph)) * 1.2 * pp.s * 0.05;
      c.fillStyle = s.c; c.globalAlpha = 0.35 + s.v * 0.25;
      c.fillRect(pp.x, pp.y - jump, Math.max(1, pp.s * 0.35), Math.max(1, pp.s * 0.5));
    }
    c.globalAlpha = 1;
    // ad boards
    const a0 = this.proj(-2, 70), a1 = this.proj(107, 70), a2 = this.proj(107, 70, 1.2), a3 = this.proj(-2, 70, 1.2);
    const ag = c.createLinearGradient(a0.x, 0, a1.x, 0);
    const sh = (this.t * 0.15) % 1;
    ag.addColorStop(0, '#0f2b3d'); ag.addColorStop(sh, '#e8b631'); ag.addColorStop(Math.min(1, sh + 0.05), '#0f2b3d'); ag.addColorStop(1, '#0f2b3d');
    c.fillStyle = ag; c.beginPath(); c.moveTo(a0.x, a0.y); c.lineTo(a1.x, a1.y); c.lineTo(a2.x, a2.y); c.lineTo(a3.x, a3.y); c.fill();
    // pitch with stripes
    for (let i = 0; i < 14; i++) {
      const x0 = i * 105 / 14, x1 = (i + 1) * 105 / 14;
      const A = this.proj(x0, 0), B = this.proj(x1, 0), C = this.proj(x1, 68), D = this.proj(x0, 68);
      c.fillStyle = i % 2 ? '#1d6b37' : '#1a6232';
      c.beginPath(); c.moveTo(A.x, A.y); c.lineTo(B.x, B.y); c.lineTo(C.x, C.y); c.lineTo(D.x, D.y); c.fill();
    }
    // lines
    c.strokeStyle = 'rgba(255,255,255,.55)'; c.lineWidth = 1.4;
    const line = (pts) => { c.beginPath(); pts.forEach((p, i) => { const q = this.proj(p[0], p[1]); i ? c.lineTo(q.x, q.y) : c.moveTo(q.x, q.y); }); c.stroke(); };
    line([[0, 0], [105, 0], [105, 68], [0, 68], [0, 0]]); line([[52.5, 0], [52.5, 68]]);
    line([[0, 13.8], [16.5, 13.8], [16.5, 54.2], [0, 54.2]]); line([[105, 13.8], [88.5, 13.8], [88.5, 54.2], [105, 54.2]]);
    const circ = []; for (let a = 0; a <= 6.3; a += 0.2) circ.push([52.5 + Math.cos(a) * 9.15, 34 + Math.sin(a) * 9.15]); line(circ);
    // goals
    [0, 105].forEach(gx => {
      const a = this.proj(gx, 30.3), b = this.proj(gx, 37.7), at = this.proj(gx, 30.3, 2.44), bt = this.proj(gx, 37.7, 2.44);
      c.strokeStyle = '#fff'; c.lineWidth = 2; c.beginPath(); c.moveTo(a.x, a.y); c.lineTo(at.x, at.y); c.lineTo(bt.x, bt.y); c.lineTo(b.x, b.y); c.stroke();
    });
    // players (sorted by depth)
    const ents = this.players.map((p, i) => ({ p, i, z: p.z })).sort((a, b) => b.z - a.z);
    for (const { p } of ents) this.drawRunner(p);
    const bp = this.proj(this.ball.x, this.ball.z, 0.3);
    c.fillStyle = '#fff'; c.beginPath(); c.arc(bp.x, bp.y, Math.max(1.5, bp.s * 0.22), 0, 7); c.fill();
    // floodlights + glare
    [[-8, 74, 30], [113, 74, 30], [20, 76, 34], [85, 76, 34]].forEach(([x, z, y], i) => {
      const q = this.proj(x, z, y);
      const fl = 0.85 + Math.sin(this.t * 2 + i) * 0.05;
      const rg = c.createRadialGradient(q.x, q.y, 0, q.x, q.y, 260 * fl);
      rg.addColorStop(0, 'rgba(255,255,240,.9)'); rg.addColorStop(0.05, 'rgba(255,250,220,.45)'); rg.addColorStop(0.3, 'rgba(255,240,200,.08)'); rg.addColorStop(1, 'rgba(0,0,0,0)');
      c.globalCompositeOperation = 'lighter'; c.fillStyle = rg; c.fillRect(q.x - 270, q.y - 270, 540, 540);
      c.globalCompositeOperation = 'source-over';
    });
    // light beams / haze particles
    c.globalCompositeOperation = 'lighter';
    for (const pt of this.parts) {
      pt.y -= pt.v * 0.3; pt.x += Math.sin(this.t + pt.y * 10) * 0.0004; if (pt.y < 0) { pt.y = 1; pt.x = Math.random(); }
      c.fillStyle = `rgba(255,230,170,${pt.a * 0.5})`; c.beginPath(); c.arc(pt.x * W, pt.y * H, pt.s, 0, 7); c.fill();
    }
    c.globalCompositeOperation = 'source-over';
    // vignette
    const vg = c.createRadialGradient(W / 2, H / 2, H * 0.3, W / 2, H / 2, H * 0.95);
    vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(0,0,0,.65)');
    c.fillStyle = vg; c.fillRect(0, 0, W, H);
  },
  drawRunner(p) {
    const c = this.ctx;
    const base = this.proj(p.x, p.z, 0), top = this.proj(p.x, p.z, 1.8);
    const hgt = base.y - top.y, w = hgt * 0.28;
    // shadow
    c.fillStyle = 'rgba(0,0,0,.35)'; c.beginPath(); c.ellipse(base.x, base.y, w * 0.9, w * 0.25, 0, 0, 7); c.fill();
    const sw = Math.sin(p.ph * 2.2);
    c.strokeStyle = '#111'; c.lineWidth = Math.max(1, w * 0.32); c.lineCap = 'round';
    // legs
    c.beginPath(); c.moveTo(base.x, base.y - hgt * 0.48); c.lineTo(base.x + sw * w * 0.7, base.y); c.moveTo(base.x, base.y - hgt * 0.48); c.lineTo(base.x - sw * w * 0.7, base.y); c.stroke();
    // shorts + shirt
    c.fillStyle = p.kit[1]; c.fillRect(base.x - w * 0.5, base.y - hgt * 0.55, w, hgt * 0.14);
    c.fillStyle = p.kit[0]; c.beginPath(); c.roundRect ? c.roundRect(base.x - w * 0.55, base.y - hgt * 0.86, w * 1.1, hgt * 0.34, w * 0.2) : c.rect(base.x - w * 0.55, base.y - hgt * 0.86, w * 1.1, hgt * 0.34); c.fill();
    // arms
    c.strokeStyle = p.kit[0]; c.lineWidth = Math.max(1, w * 0.26);
    c.beginPath(); c.moveTo(base.x - w * 0.5, base.y - hgt * 0.8); c.lineTo(base.x - w * 0.6 - sw * w * 0.3, base.y - hgt * 0.6); c.moveTo(base.x + w * 0.5, base.y - hgt * 0.8); c.lineTo(base.x + w * 0.6 + sw * w * 0.3, base.y - hgt * 0.6); c.stroke();
    // head
    c.fillStyle = '#c48a5c'; c.beginPath(); c.arc(base.x, base.y - hgt * 0.93, w * 0.32, 0, 7); c.fill();
  },
  drawHub() {
    const c = this.ctx, W = this.w, H = this.h, t = this.t;
    const g = c.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, '#0c1116'); g.addColorStop(0.55, '#121a20'); g.addColorStop(1, '#06090c');
    c.fillStyle = g; c.fillRect(0, 0, W, H);
    // ceiling slats in perspective
    const vpX = W * 0.55 + Math.sin(t * 0.08) * 40, vpY = H * 0.42;
    c.strokeStyle = 'rgba(255,255,255,.05)'; c.lineWidth = 2;
    for (let i = -20; i <= 20; i++) { c.beginPath(); c.moveTo(vpX + i * 8, vpY - 70); c.lineTo(vpX + i * 160, -20); c.stroke(); }
    // light strips
    for (let i = 0; i < 5; i++) {
      const y = H * 0.08 + i * 26, w = W * (0.5 - i * 0.06);
      const lg = c.createLinearGradient(vpX - w / 2, 0, vpX + w / 2, 0);
      lg.addColorStop(0, 'rgba(160,255,236,0)'); lg.addColorStop(0.5, `rgba(200,255,245,${0.18 - i * 0.025})`); lg.addColorStop(1, 'rgba(160,255,236,0)');
      c.fillStyle = lg; c.fillRect(vpX - w / 2, y, w, 3);
    }
    // lockers silhouettes
    c.fillStyle = 'rgba(255,255,255,.025)';
    for (let i = 0; i < 9; i++) { const x = vpX - 380 + i * 95; c.fillRect(x, vpY - 40, 70, 210); }
    // floor reflection
    const fg = c.createLinearGradient(0, vpY + 170, 0, H);
    fg.addColorStop(0, 'rgba(63,224,197,.06)'); fg.addColorStop(1, 'rgba(0,0,0,0)');
    c.fillStyle = fg; c.fillRect(0, vpY + 170, W, H);
    // dotted side panels like broadcast set
    c.fillStyle = 'rgba(63,224,197,.12)';
    for (let y = 0; y < H; y += 12) for (let x = 0; x < 70; x += 12) { if ((x + y) % 24 === 0) { c.beginPath(); c.arc(x + 6, y + 6, 1.8, 0, 7); c.fill(); c.beginPath(); c.arc(W - x - 6, y + 6, 1.8, 0, 7); c.fill(); } }
    // drifting particles
    c.globalCompositeOperation = 'lighter';
    for (const pt of this.parts) { pt.y -= pt.v * 0.15; if (pt.y < 0) { pt.y = 1; pt.x = Math.random(); } c.fillStyle = `rgba(120,255,230,${pt.a * 0.25})`; c.beginPath(); c.arc(pt.x * W, pt.y * H, pt.s, 0, 7); c.fill(); }
    c.globalCompositeOperation = 'source-over';
  }
};
