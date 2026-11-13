/* ============================================================
   MATCH / VIEW — broadcast-camera renderer + HUD, pause & subs
   ============================================================ */
const MatchView = {
  cv: null, c: null, W: 0, H: 0, cam: { x: PW / 2, y: PH / 2 }, crowd: null, hud: {}, helpOn: true, radar: null,
  init(root, s) {
    root.innerHTML = `<canvas class="mc"></canvas>
      <div class="m-hud"><div class="clock">00:00</div><div class="kit" style="background:${s.teams.home.kit.c1}"></div><div class="tm">${esc(s.teams.home.short)}</div><div class="sc">0 - 0</div><div class="tm">${esc(s.teams.away.short)}</div><div class="kit" style="background:${s.teams.away.kit.c1}"></div></div>
      <div class="m-msg hidden"></div><div class="m-banner-host"></div>
      <div class="m-player hidden"><div class="nm"></div><div class="stam"><i></i></div></div>
      <div class="m-power hidden"><i></i></div>
      <canvas class="m-radar" width="168" height="110"></canvas>
      <div class="m-ctrl">${[['WASD', 'Move'], ['Shift', 'Sprint'], ['J', 'Pass / Tackle'], ['I', 'Through ball'], ['K', 'Shoot (hold) / Slide'], ['O', 'Finesse shot'], ['L', 'Lob / Cross'], ['E', 'Skill move'], ['Q', 'Switch player'], ['Esc', 'Pause · H hide']].map(([k, v]) => `<div><b>${k}</b>${v}</div>`).join('')}</div>`;
    this.cv = $('.mc', root); this.c = this.cv.getContext('2d');
    this.hud = { clock: $('.clock', root), sc: $('.sc', root), msg: $('.m-msg', root), bh: $('.m-banner-host', root), pl: $('.m-player', root), pw: $('.m-power', root), ctrl: $('.m-ctrl', root) };
    this.radar = $('.m-radar', root).getContext('2d');
    this.root = root;
    this.crowd = null;
    const rs = () => { const d = Math.min(1.5, devicePixelRatio || 1); this.W = innerWidth; this.H = innerHeight; this.cv.width = this.W * d; this.cv.height = this.H * d; this.c.setTransform(d, 0, 0, d, 0, 0); };
    this._rs = rs; addEventListener('resize', rs); rs();
    this.cam = { x: PW / 2, y: PH / 2 };
    this.hud.ctrl.classList.toggle('hidden', !this.helpOn);
    this._lastBanner = null;
    const pr = Save.data.profile;
    this.stadium = (s.teams.home.user || s.teams.away.user) ? pr.stadium : { seats: '#2a2f3a', tifo: 'none', theme: 'classic' };
    this.tifoColors = [pr.badge.c1, pr.badge.c2];
    if (!s.userSide) this.hud.ctrl.classList.add('hidden');
  },
  toggleHelp() { this.helpOn = !this.helpOn; this.hud.ctrl.classList.toggle('hidden', !this.helpOn); },
  camCfg() {
    const m = Save.data.settings.camera, W = this.W;
    return m === 'tele' ? { dist: 46, h: 26, f: W * 1.05 } : m === 'wide' ? { dist: 78, h: 46, f: W * 0.98 } : { dist: 60, h: 34, f: W * 1.0 };
  },
  proj(x, y, z = 0) {
    const C = this._cc;
    const d = y - (this.cam.y - C.dist);
    const s = C.f / Math.max(d, 1);
    return { x: this.W / 2 + (x - this.cam.x) * s, y: C.hz + (C.h - z) * s, s };
  },
  draw(s) {
    const c = this.c, W = this.W, H = this.H, b = s.ball;
    const C = this._cc = this.camCfg();
    // camera follow with look-ahead
    const tx = clamp(b.x + b.vx * 0.35, 18, PW - 18), ty = clamp(b.y * 0.85 + PH / 2 * 0.15, 14, 54);
    this.cam.x = lerp(this.cam.x, tx, 0.06); this.cam.y = lerp(this.cam.y, ty, 0.04);
    C.hz = H * 0.6 - C.h * C.f / C.dist;
    // sky
    const g = c.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, '#04060a'); g.addColorStop(0.4, '#0b1119'); g.addColorStop(1, '#0a1a10');
    c.fillStyle = g; c.fillRect(0, 0, W, H);
    this.drawStands(s);
    this.drawPitch(s);
    this.drawGoal(0, true); this.drawGoal(PW, true);
    // entities sorted far→near
    const ents = s.all.map(m => ({ t: 'p', m, y: m.y })); ents.push({ t: 'r', y: s.ref.y }); ents.push({ t: 'b', y: b.y });
    ents.sort((a, b) => b.y - a.y);
    for (const e of ents) { if (e.t === 'p') this.drawPlayer(s, e.m); else if (e.t === 'r') this.drawRef(s); else this.drawBall(s); }
    this.drawGoal(0, false); this.drawGoal(PW, false);
    this.drawFX(s);
    // floodlight glow
    c.globalCompositeOperation = 'lighter';
    [[-10, 80, 34], [PW + 10, 80, 34]].forEach(([x, y, z]) => { const q = this.proj(x, y, z); const rg = c.createRadialGradient(q.x, q.y, 0, q.x, q.y, 220); rg.addColorStop(0, 'rgba(255,255,235,.55)'); rg.addColorStop(0.15, 'rgba(255,250,220,.15)'); rg.addColorStop(1, 'rgba(0,0,0,0)'); c.fillStyle = rg; c.fillRect(q.x - 230, q.y - 230, 460, 460); });
    c.globalCompositeOperation = 'source-over';
    const vg = c.createRadialGradient(W / 2, H / 2, H * 0.45, W / 2, H / 2, H * 1.0); vg.addColorStop(0, 'rgba(0,0,0,0)'); vg.addColorStop(1, 'rgba(0,0,0,.45)'); c.fillStyle = vg; c.fillRect(0, 0, W, H);
    this.drawHUD(s);
  },
  drawStands(s) {
    const c = this.c;
    const poly = (pts, fill) => { c.fillStyle = fill; c.beginPath(); pts.forEach((p, i) => { const q = this.proj(...p); i ? c.lineTo(q.x, q.y) : c.moveTo(q.x, q.y); }); c.closePath(); c.fill(); };
    // far stand
    poly([[-30, 72, 0], [PW + 30, 72, 0], [PW + 30, 96, 28], [-30, 96, 28]], '#10141c');
    // behind-goal stands
    poly([[-5, -20, 0], [-5, PH + 6, 0], [-30, PH + 6, 22], [-30, -20, 22]], '#0d1118');
    poly([[PW + 5, -20, 0], [PW + 5, PH + 6, 0], [PW + 30, PH + 6, 22], [PW + 30, -20, 22]], '#0d1118');
    if (!this.crowd) {
      this.crowd = [];
      const seat = this.stadium.seats;
      const kitA = s.teams.home.kit.c1, kitB = s.teams.away.kit.c1;
      for (let i = 0; i < 2600; i++) {
        const u = Math.random(), v = Math.random();
        const col = Math.random() < 0.18 ? seat : Math.random() < 0.62 ? kitA : Math.random() < 0.5 ? kitB : R.pick(['#ddd', '#888', '#c9b28a']);
        this.crowd.push({ k: 0, u, v, col, ph: Math.random() * 6 });
      }
      for (let i = 0; i < 1400; i++) { const side = i % 2; this.crowd.push({ k: side ? 2 : 1, u: Math.random(), v: Math.random(), col: Math.random() < 0.7 ? (side ? s.teams.away.kit.c1 : s.teams.home.kit.c1) : '#aaa', ph: Math.random() * 6 }); }
    }
    const exc = s.state === 'goal' ? 1 : crowdExcitement(s);
    const tifo = this.stadium.tifo !== 'none' && (s.teams.home.user);
    for (const p of this.crowd) {
      let q;
      if (p.k === 0) {
        const x = -30 + p.u * (PW + 60), y = 72 + p.v * 24, z = p.v * 28;
        q = this.proj(x, y, z + 0.4);
        if (tifo && Math.abs(x - PW / 2) < 22 && p.v > 0.3) {
          const tc = this.tifoColors;
          const pat = this.stadium.tifo === 'stripes' ? (Math.floor((x - PW / 2 + 22) / 4) % 2) : this.stadium.tifo === 'flames' ? ((p.v * 10 + Math.sin(x * 0.4) * 2) % 3 < 1.5 ? 0 : 1) : (Math.hypot(x - PW / 2, (p.v - 0.65) * 50) < 9 ? 0 : 1);
          c.fillStyle = tc[pat];
        } else c.fillStyle = p.col;
      } else {
        const gx = p.k === 1 ? -5 - p.v * 25 : PW + 5 + p.v * 25;
        q = this.proj(gx, -20 + p.u * (PH + 26), p.v * 22 + 0.4); c.fillStyle = p.col;
      }
      if (q.x < -10 || q.x > this.W + 10 || q.y < -10) continue;
      const jump = Math.max(0, Math.sin(s.t * (3 + exc * 5) + p.ph)) * exc * q.s * 0.12;
      const sz = Math.max(1.2, q.s * 0.36);
      c.globalAlpha = 0.55 + p.v * 0.35;
      c.fillRect(q.x, q.y - jump, sz, sz * 1.25);
    }
    c.globalAlpha = 1;
    // LED boards (animated)
    const boards = [[[-4, 71, 0], [PW + 4, 71, 0], [PW + 4, 71, 1], [-4, 71, 1]], [[-3, -2, 0], [-3, PH + 2, 0], [-3, PH + 2, 1], [-3, -2, 1]], [[PW + 3, -2, 0], [PW + 3, PH + 2, 0], [PW + 3, PH + 2, 1], [PW + 3, -2, 1]]];
    boards.forEach((bd, i) => {
      const q = bd.map(p => this.proj(...p));
      const lg = c.createLinearGradient(q[0].x, 0, q[1].x, 0);
      const ph = (s.t * 0.12 + i * 0.3) % 1;
      lg.addColorStop(0, '#0c2733'); lg.addColorStop(Math.max(0, ph - 0.04), '#0c2733'); lg.addColorStop(ph, s.state === 'goal' ? '#ffd23f' : '#3fe0c5'); lg.addColorStop(Math.min(1, ph + 0.04), '#0c2733'); lg.addColorStop(1, '#0c2733');
      c.fillStyle = lg; c.beginPath(); q.forEach((p, k) => k ? c.lineTo(p.x, p.y) : c.moveTo(p.x, p.y)); c.fill();
    });
    // stadium name on far board
    const nq = this.proj(PW / 2, 71, 0.5);
    c.fillStyle = 'rgba(255,255,255,.85)'; c.font = `900 ${Math.max(8, nq.s * 0.8)}px Arial`; c.textAlign = 'center';
    c.fillText((s.teams.home.user ? this.stadium.name : 'PRIME FOOTBALL 27').toUpperCase(), nq.x, nq.y + nq.s * 0.3);
  },
  drawPitch(s) {
    const c = this.c, theme = s.teams.home.user ? this.stadium.theme : 'classic';
    const N = 18;
    for (let i = 0; i < N; i++) {
      const x0 = -4 + i * (PW + 8) / N, x1 = x0 + (PW + 8) / N;
      if (theme === 'checker') {
        for (let j = 0; j < 6; j++) { const y0 = -4 + j * (PH + 8) / 6, y1 = y0 + (PH + 8) / 6; this.quad([[x0, y0], [x1, y0], [x1, y1], [x0, y1]], (i + j) % 2 ? '#1f7a3c' : '#1b6d35'); }
      } else this.quad([[x0, -4], [x1, -4], [x1, PH + 4], [x0, PH + 4]], i % 2 ? (theme === 'gold' ? '#1f7a3c' : '#1e753a') : (theme === 'gold' ? '#1a6833' : '#1b6b35'));
    }
    c.strokeStyle = 'rgba(255,255,255,.75)'; c.lineWidth = 1.6;
    const L = pts => { c.beginPath(); pts.forEach((p, i) => { const q = this.proj(p[0], p[1]); i ? c.lineTo(q.x, q.y) : c.moveTo(q.x, q.y); }); c.stroke(); };
    L([[0, 0], [PW, 0], [PW, PH], [0, PH], [0, 0]]); L([[PW / 2, 0], [PW / 2, PH]]);
    const arc = (cx, cy, r, a0, a1) => { const pts = []; for (let a = a0; a <= a1 + 1e-6; a += (a1 - a0) / 28) pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); L(pts); };
    arc(PW / 2, PH / 2, 9.15, 0, Math.PI * 2);
    for (const gx of [0, PW]) {
      const d = gx === 0 ? 1 : -1;
      L([[gx, PH / 2 - 20.16], [gx + d * 16.5, PH / 2 - 20.16], [gx + d * 16.5, PH / 2 + 20.16], [gx, PH / 2 + 20.16]]);
      L([[gx, PH / 2 - 9.16], [gx + d * 5.5, PH / 2 - 9.16], [gx + d * 5.5, PH / 2 + 9.16], [gx, PH / 2 + 9.16]]);
      const a = Math.acos(5.5 / 9.15);
      gx === 0 ? arc(11, PH / 2, 9.15, -a, a) : arc(PW - 11, PH / 2, 9.15, Math.PI - a, Math.PI + a);
      const sp = this.proj(gx + d * 11, PH / 2); c.fillStyle = '#fff'; c.beginPath(); c.arc(sp.x, sp.y, 2, 0, 7); c.fill();
    }
    [[0, 0, 0], [PW, 0, Math.PI / 2], [PW, PH, Math.PI], [0, PH, -Math.PI / 2]].forEach(([x, y, a]) => arc(x, y, 1, a, a + Math.PI / 2));
    // center spot
    const cs = this.proj(PW / 2, PH / 2); c.fillStyle = '#fff'; c.beginPath(); c.arc(cs.x, cs.y, 2, 0, 7); c.fill();
    // corner flags
    for (const [x, y] of [[0, 0], [PW, 0], [0, PH], [PW, PH]]) { const a = this.proj(x, y, 0), t = this.proj(x, y, 1.6); c.strokeStyle = '#ddd'; c.lineWidth = 1.5; c.beginPath(); c.moveTo(a.x, a.y); c.lineTo(t.x, t.y); c.stroke(); c.fillStyle = '#ffd23f'; c.fillRect(t.x, t.y, Math.max(3, t.s * 0.5), Math.max(2, t.s * 0.35)); }
  },
  quad(pts, fill) { const c = this.c; c.fillStyle = fill; c.beginPath(); pts.forEach((p, i) => { const q = this.proj(p[0], p[1], p[2] || 0); i ? c.lineTo(q.x, q.y) : c.moveTo(q.x, q.y); }); c.closePath(); c.fill(); },
  drawGoal(gx, back) {
    const c = this.c, d = gx === 0 ? -1 : 1, depth = 2;
    if (back) {
      // net (drawn behind players)
      c.strokeStyle = 'rgba(255,255,255,.28)'; c.lineWidth = 0.8;
      for (let i = 0; i <= 10; i++) { const y = GY0 + i * GOAL_W / 10; const a = this.proj(gx, y, GOAL_H), b2 = this.proj(gx + d * depth, y, GOAL_H * 0.8), e = this.proj(gx + d * depth, y, 0); c.beginPath(); c.moveTo(a.x, a.y); c.lineTo(b2.x, b2.y); c.lineTo(e.x, e.y); c.stroke(); }
      for (let j = 0; j <= 5; j++) { const z = j * GOAL_H * 0.8 / 5; const a = this.proj(gx + d * depth, GY0, z), b2 = this.proj(gx + d * depth, GY1, z); c.beginPath(); c.moveTo(a.x, a.y); c.lineTo(b2.x, b2.y); c.stroke(); }
      this.quad([[gx, GY0, 0], [gx + d * depth, GY0, 0], [gx + d * depth, GY1, 0], [gx, GY1, 0]], 'rgba(0,0,0,.18)');
      // far post (behind players)
      this.post(gx, GY1);
    } else {
      this.post(gx, GY0);
      const a = this.proj(gx, GY0, GOAL_H), b2 = this.proj(gx, GY1, GOAL_H);
      c.strokeStyle = '#f5f5f5'; c.lineWidth = Math.max(2, a.s * 0.13); c.beginPath(); c.moveTo(a.x, a.y); c.lineTo(b2.x, b2.y); c.stroke();
    }
  },
  post(x, y) { const c = this.c, a = this.proj(x, y, 0), t = this.proj(x, y, GOAL_H); c.strokeStyle = '#f5f5f5'; c.lineWidth = Math.max(2, a.s * 0.13); c.beginPath(); c.moveTo(a.x, a.y); c.lineTo(t.x, t.y); c.stroke(); },
  drawPlayer(s, m) {
    const c = this.c;
    const base = this.proj(m.x, m.y, 0);
    const scale = base.s;
    if (base.x < -60 || base.x > this.W + 60) return;
    const hgt = scale * (m.p.height / 100), w = hgt * 0.27;
    const kit = m.gk ? (m.side === 'home' ? { c1: '#2bd96b', c2: '#0d3b1f' } : { c1: '#ffcc00', c2: '#3a2c00' }) : m.team.kit;
    // shadow
    c.fillStyle = 'rgba(0,0,0,.32)'; c.beginPath(); c.ellipse(base.x + w * 0.3, base.y, w * 1.05, w * 0.3, 0, 0, 7); c.fill();
    // controlled indicator
    if (s.ctrl === m && s.userSide) {
      c.strokeStyle = m.team.kit.c1 === '#ffffff' ? '#3fe0c5' : '#fff'; c.lineWidth = 2.2; c.beginPath(); c.ellipse(base.x, base.y, w * 1.5, w * 0.48, 0, 0, 7); c.stroke();
      c.fillStyle = '#3fe0c5'; c.beginPath(); c.moveTo(base.x, base.y - hgt - 5); c.lineTo(base.x - 6, base.y - hgt - 14); c.lineTo(base.x + 6, base.y - hgt - 14); c.fill();
      c.font = `800 ${Math.max(11, scale * 0.42)}px Segoe UI, Arial`; c.textAlign = 'center'; c.fillStyle = '#fff'; c.strokeStyle = 'rgba(0,0,0,.7)'; c.lineWidth = 3;
      const nm = shortName(m.p.name); c.strokeText(nm, base.x, base.y - hgt - 18); c.fillText(nm, base.x, base.y - hgt - 18);
    }
    c.save(); c.translate(base.x, base.y);
    const lying = m.sliding > 0 || (m.dive && Math.abs(m.dive.vy) > 1);
    if (lying) {
      const dirx = m.dive ? Math.sign(m.dive.vy) * (m.side === 'home' ? 1 : 1) : Math.sign(Math.cos(m.face)) || 1;
      c.rotate(dirx * (m.dive ? 1.25 : 1.1));
      c.translate(0, m.dive ? -hgt * 0.25 : 0);
    }
    const sw = Math.sin(m.ph * 2.3) * Math.min(1, Math.hypot(m.vx, m.vy) / 3);
    // legs
    c.strokeStyle = '#141414'; c.lineCap = 'round'; c.lineWidth = Math.max(1.4, w * 0.3);
    c.beginPath(); c.moveTo(-w * 0.18, -hgt * 0.47); c.lineTo(-w * 0.18 + sw * w * 0.75, 0); c.moveTo(w * 0.18, -hgt * 0.47); c.lineTo(w * 0.18 - sw * w * 0.75, 0); c.stroke();
    // socks
    c.strokeStyle = kit.c2; c.lineWidth = Math.max(1.4, w * 0.32);
    c.beginPath(); c.moveTo(-w * 0.18 + sw * w * 0.45, -hgt * 0.2); c.lineTo(-w * 0.18 + sw * w * 0.7, -hgt * 0.04); c.moveTo(w * 0.18 - sw * w * 0.45, -hgt * 0.2); c.lineTo(w * 0.18 - sw * w * 0.7, -hgt * 0.04); c.stroke();
    // shorts
    c.fillStyle = kit.c2; c.fillRect(-w * 0.52, -hgt * 0.56, w * 1.04, hgt * 0.13);
    // shirt
    c.fillStyle = kit.c1; c.beginPath();
    if (c.roundRect) c.roundRect(-w * 0.56, -hgt * 0.86, w * 1.12, hgt * 0.33, w * 0.22); else c.rect(-w * 0.56, -hgt * 0.86, w * 1.12, hgt * 0.33);
    c.fill();
    c.strokeStyle = 'rgba(0,0,0,.25)'; c.lineWidth = 1; c.stroke();
    // number
    if (hgt > 26) { c.fillStyle = kit.c2; c.font = `900 ${hgt * 0.16}px Arial`; c.textAlign = 'center'; c.fillText(String(m.slot + 1), 0, -hgt * 0.64); }
    // arms
    c.strokeStyle = kit.c1; c.lineWidth = Math.max(1.3, w * 0.25);
    const armUp = m.gk && m.dive ? -0.5 : 0;
    c.beginPath(); c.moveTo(-w * 0.5, -hgt * 0.82); c.lineTo(-w * 0.62 - sw * w * 0.35, -hgt * (0.6 + armUp)); c.moveTo(w * 0.5, -hgt * 0.82); c.lineTo(w * 0.62 + sw * w * 0.35, -hgt * (0.6 + armUp)); c.stroke();
    // head
    c.fillStyle = SKINS[m.p.face.skin]; c.beginPath(); c.arc(0, -hgt * 0.93, w * 0.33, 0, 7); c.fill();
    c.fillStyle = HAIRC[m.p.face.hairC]; if (m.p.face.hair !== 5) { c.beginPath(); c.arc(0, -hgt * 0.96, w * 0.33, Math.PI, 0); c.fill(); }
    c.restore();
    if (m.labelT > 0 && m.label) { c.font = `800 ${Math.max(10, scale * 0.38)}px Segoe UI`; c.fillStyle = `rgba(255,210,63,${Math.min(1, m.labelT * 2)})`; c.textAlign = 'center'; c.fillText(m.label, base.x, base.y - hgt - (s.ctrl === m ? 32 : 8)); }
  },
  drawRef(s) {
    const r = s.ref, c = this.c, base = this.proj(r.x, r.y, 0), hgt = base.s * 1.8, w = hgt * 0.27;
    c.fillStyle = 'rgba(0,0,0,.3)'; c.beginPath(); c.ellipse(base.x, base.y, w, w * 0.3, 0, 0, 7); c.fill();
    const sw = Math.sin(r.ph * 2.3) * Math.min(1, Math.hypot(r.vx, r.vy) / 3);
    c.strokeStyle = '#111'; c.lineWidth = Math.max(1.4, w * 0.3); c.lineCap = 'round';
    c.beginPath(); c.moveTo(base.x - w * 0.18, base.y - hgt * 0.47); c.lineTo(base.x - w * 0.18 + sw * w * 0.7, base.y); c.moveTo(base.x + w * 0.18, base.y - hgt * 0.47); c.lineTo(base.x + w * 0.18 - sw * w * 0.7, base.y); c.stroke();
    c.fillStyle = '#111'; c.fillRect(base.x - w * 0.5, base.y - hgt * 0.56, w, hgt * 0.13);
    c.fillStyle = '#e6ff3f'; c.fillRect(base.x - w * 0.55, base.y - hgt * 0.86, w * 1.1, hgt * 0.33);
    c.fillStyle = '#b07a52'; c.beginPath(); c.arc(base.x, base.y - hgt * 0.93, w * 0.32, 0, 7); c.fill();
  },
  drawBall(s) {
    const b = s.ball, c = this.c;
    const g = this.proj(b.x, b.y, 0), q = this.proj(b.x, b.y, b.z + 0.11);
    const r = Math.max(2.2, q.s * 0.17);
    c.fillStyle = `rgba(0,0,0,${0.4 - Math.min(0.3, b.z * 0.05)})`; c.beginPath(); c.ellipse(g.x, g.y, r * 1.1, r * 0.4, 0, 0, 7); c.fill();
    c.fillStyle = '#fff'; c.beginPath(); c.arc(q.x, q.y, r, 0, 7); c.fill();
    const rot = (b.x + b.y) * 1.3;
    c.fillStyle = '#222'; c.beginPath(); c.arc(q.x + Math.cos(rot) * r * 0.4, q.y + Math.sin(rot) * r * 0.4, r * 0.35, 0, 7); c.fill();
    c.strokeStyle = 'rgba(0,0,0,.35)'; c.lineWidth = 1; c.beginPath(); c.arc(q.x, q.y, r, 0, 7); c.stroke();
    // trail for shots
    if (b.shot && Math.hypot(b.vx, b.vy) > 15) { c.strokeStyle = 'rgba(255,255,255,.35)'; c.lineWidth = r; c.beginPath(); const t = this.proj(b.x - b.vx * 0.05, b.y - b.vy * 0.05, b.z); c.moveTo(t.x, t.y); c.lineTo(q.x, q.y); c.stroke(); }
    // set-piece aim arrow
    if (s.state === 'setpiece' && s.sp && s.sp.aim && s.teams[s.sp.side].user) {
      const a = this.proj(b.x + s.sp.aim.x * 6, b.y + s.sp.aim.y * 6, 0);
      c.strokeStyle = 'rgba(63,224,197,.9)'; c.lineWidth = 3; c.setLineDash([6, 5]); c.beginPath(); c.moveTo(g.x, g.y); c.lineTo(a.x, a.y); c.stroke(); c.setLineDash([]);
    }
  },
  drawFX(s) {
    const c = this.c;
    for (const f of s.fx) {
      if (f.type === 'confetti') {
        if (!f.p) f.p = Array.from({ length: 160 }, () => ({ x: Math.random() * this.W, y: -Math.random() * this.H * 0.5, vy: R.range(60, 180), vx: R.range(-40, 40), c: R.pick(['#ffd23f', '#3fe0c5', '#ff4fa3', '#fff', '#3ea6ff']), r: Math.random() * 6 }));
        for (const p of f.p) { p.y += p.vy / 60; p.x += p.vx / 60; p.r += 0.1; c.fillStyle = p.c; c.save(); c.translate(p.x, p.y); c.rotate(p.r); c.fillRect(-4, -2, 8, 4); c.restore(); }
      }
    }
  },
  drawHUD(s) {
    const H = this.hud;
    const half = s.half, mins = Math.min(45, s.clock / s.halfSecs * 45) + (half - 1) * 45;
    const mm = Math.floor(mins), ss = Math.floor((mins - mm) * 60);
    H.clock.textContent = s.goldenGoal ? 'GG' : `${String(mm).padStart(2, '0')}:${String(ss).padStart(2, '0')}`;
    H.sc.textContent = `${s.score.home} - ${s.score.away}`;
    const m = s.msgs[s.msgs.length - 1];
    H.msg.classList.toggle('hidden', !m); if (m) H.msg.textContent = m.text;
    if (s.banner !== this._lastBanner) {
      this._lastBanner = s.banner;
      H.bh.innerHTML = s.banner ? `<div class="m-banner">${esc(s.banner.big)}<small>${esc(s.banner.small)}</small></div>` : '';
    }
    if (s.ctrl && s.userSide) {
      H.pl.classList.remove('hidden');
      const p = s.ctrl.p;
      H.pl.querySelector('.nm').innerHTML = `<span class="ovr ${ovrClass(p)}" style="padding:1px 6px;border-radius:4px;font-family:var(--head);font-weight:900">${p.ovr}</span> ${s.ctrl.slotPos} · ${esc(p.name)}`;
      const st = H.pl.querySelector('.stam i'); st.style.width = (s.ctrl.stamina * 100) + '%'; st.style.background = s.ctrl.stamina > 0.6 ? 'var(--green)' : s.ctrl.stamina > 0.3 ? 'var(--yellow)' : 'var(--red)';
    } else H.pl.classList.add('hidden');
    H.pw.classList.toggle('hidden', !(s.charge > 0));
    if (s.charge > 0) H.pw.firstElementChild.style.width = (s.charge * 100) + '%';
    // radar
    const r = this.radar, RW = 168, RH = 110;
    r.clearRect(0, 0, RW, RH);
    r.strokeStyle = 'rgba(255,255,255,.45)'; r.strokeRect(4, 4, RW - 8, RH - 8); r.beginPath(); r.moveTo(RW / 2, 4); r.lineTo(RW / 2, RH - 4); r.stroke();
    const sx = x => 4 + x / PW * (RW - 8), sy = y => RH - 4 - y / PH * (RH - 8);
    for (const p of s.all) { r.fillStyle = p === s.ctrl ? '#3fe0c5' : p.team.kit.c1; r.beginPath(); r.arc(sx(p.x), sy(p.y), p === s.ctrl ? 3.6 : 2.6, 0, 7); r.fill(); r.strokeStyle = 'rgba(0,0,0,.6)'; r.lineWidth = 0.8; r.stroke(); }
    r.fillStyle = '#fff'; r.beginPath(); r.arc(sx(s.ball.x), sy(s.ball.y), 2.4, 0, 7); r.fill();
  },

  /* ---------- pause menu / substitutions ---------- */
  togglePause(s) {
    if (s.state === 'fulltime') return;
    s.paused = !s.paused;
    const host = this.root;
    $('.m-pause', host)?.remove();
    if (!s.paused) { Input.mode = 'game'; Input.popLayer(this._pl); Audio2.crowdLevel(0.3); return; }
    Input.mode = 'menu'; Audio2.crowdLevel(0.08);
    const el = h(`<div class="m-pause"><div class="panel col" style="padding:28px 32px;min-width:360px;gap:10px">
      <div class="h2">Paused</div><div class="dim" style="margin-bottom:6px">${esc(s.teams.home.name)} ${s.score.home} - ${s.score.away} ${esc(s.teams.away.name)}</div>
      <button class="btn primary" data-nav data-a="resume" data-autofocus>Resume</button>
      ${s.userSide ? '<button class="btn" data-nav data-a="subs">Substitutions</button>' : ''}
      <button class="btn" data-nav data-a="camera">Camera: ${Save.data.settings.camera}</button>
      <button class="btn" data-nav data-a="sim">Simulate rest of match</button>
      ${s.userSide ? '<button class="btn danger" data-nav data-a="forfeit">Forfeit (0-3 loss)</button>' : '<button class="btn danger" data-nav data-a="forfeit">Quit match</button>'}</div></div>`);
    host.appendChild(el);
    this._pl = Input.pushLayer(el, () => this.togglePause(s));
    Input.focusFirst(el);
    $$('[data-a]', el).forEach(b => b.onclick = () => {
      const a = b.dataset.a;
      if (a === 'resume') this.togglePause(s);
      else if (a === 'camera') { const cams = ['broadcast', 'tele', 'wide']; Save.data.settings.camera = cams[(cams.indexOf(Save.data.settings.camera) + 1) % 3]; Save.dirty(); b.textContent = 'Camera: ' + Save.data.settings.camera; }
      else if (a === 'subs') this.subsMenu(s);
      else if (a === 'sim') { this.closePause(s); simulateRest(s); }
      else if (a === 'forfeit') {
        this.closePause(s);
        if (s.userSide) { const u = s.userSide; s.score[u] = 0; s.score[other(u)] = Math.max(3, s.score[other(u)]); s.goals = s.goals.filter(g => g.side !== u); }
        Match.end();
      }
    });
  },
  closePause(s) { s.paused = false; $('.m-pause', this.root)?.remove(); Input.popLayer(this._pl); },
  subsMenu(s) {
    const team = s.teams[s.userSide];
    let selOn = null;
    const body = h('<div></div>');
    const draw = () => {
      body.innerHTML = `<div class="dim" style="margin-bottom:8px">Substitutions used: ${s.subsUsed[s.userSide]}/5. Select a player on the pitch, then a substitute.</div>
        <div class="row" style="gap:20px;align-items:flex-start"><div class="col" style="gap:4px;flex:1">${team.players.map((m, i) => `<button class="prow" data-nav data-on="${i}" style="${selOn === i ? 'border-color:var(--teal)' : ''}"><span style="width:38px;font-weight:900">${m.slotPos}</span><span class="grow">${esc(m.p.name)} (${m.p.ovr})</span><span style="width:60px"><span class="bar" style="display:block"><i style="width:${m.stamina * 100}%;background:${m.stamina > 0.6 ? 'var(--green)' : m.stamina > 0.3 ? 'var(--yellow)' : 'var(--red)'}"></i></span></span></button>`).join('')}</div>
        <div class="col" style="gap:4px;flex:1">${team.bench.map((p, i) => `<button class="prow" data-nav data-b="${i}" ${selOn === null || s.subsUsed[s.userSide] >= 5 ? 'disabled style="opacity:.5"' : ''}><span style="width:38px;font-weight:900">${p.pos}</span><span class="grow">${esc(p.name)} (${p.ovr})</span></button>`).join('') || '<div class="dim">No substitutes available</div>'}</div></div>`;
      $$('[data-on]', body).forEach(b => b.onclick = () => { selOn = +b.dataset.on; draw(); $(`[data-b]`, body)?.focus(); });
      $$('[data-b]', body).forEach(b => b.onclick = () => {
        if (selOn === null || s.subsUsed[s.userSide] >= 5) return;
        const old = team.players[selOn], np = team.bench[+b.dataset.b];
        const nm = makeMP(np, old.side, old.slot, team, team.chem ? team.chem.per[old.slot] : 2);
        Object.assign(nm, { x: old.x, y: old.y, face: old.face });
        team.players[selOn] = nm; s.all = [...s.teams.home.players, ...s.teams.away.players];
        team.bench.splice(+b.dataset.b, 1, old.p);
        if (s.ball.owner === old) s.ball.owner = nm;
        if (s.ctrl === old) s.ctrl = nm;
        s.subsUsed[s.userSide]++; msg(s, `🔁 ${shortName(np.name)} on for ${shortName(old.p.name)}`, 2.5);
        selOn = null; draw();
      });
    };
    draw();
    modal({ title: 'Substitutions', body, wide: true, buttons: [{ label: 'Done', value: true, primary: true, cancel: true }] });
  }
};
function simulateRest(s) {
  const remain = s.half === 1 ? 1 + (1 - s.clock / s.halfSecs) : Math.max(0, 1 - s.clock / s.halfSecs);
  const frac = remain / 2;
  const H = teamStrength(s.teams.home.formation, s.teams.home.players.map(m => m.p)), A = teamStrength(s.teams.away.formation, s.teams.away.players.map(m => m.p));
  const hs = H.att * 0.4 + H.mid * 0.35 + H.def * 0.25, as = A.att * 0.4 + A.mid * 0.35 + A.def * 0.25;
  const pois = l => { let L = Math.exp(-l), k = 0, p = 1; do { k++; p *= Math.random(); } while (p > L); return k - 1; };
  const diff = (hs - as) / 10;
  const hg = pois(clamp(1.35 + diff * 0.9, 0.2, 4) * frac), ag = pois(clamp(1.15 - diff * 0.9, 0.2, 4) * frac);
  const baseMin = Math.floor((s.half - 1) * 45 + s.clock / s.halfSecs * 45);
  const add = (side, n) => { const t = s.teams[side]; for (let i = 0; i < n; i++) { const m = R.weighted(t.players.map(x => ({ w: { ATT: 6, MID: 3, DEF: 1, GK: 0.01 }[POS_GROUP[x.slotPos]], v: x }))); s.goals.push({ side, pid: m.p.id, name: m.p.name, pos: m.slotPos, min: R.int(baseMin + 1, 90), assist: null }); s.score[side]++; } };
  add('home', hg); add('away', ag);
  s.goals.sort((a, b) => a.min - b.min);
  s.stats.shots[0] += hg * 2 + R.int(0, 3); s.stats.shots[1] += ag * 2 + R.int(0, 3); s.stats.sot[0] += hg; s.stats.sot[1] += ag;
  Match.end();
}
