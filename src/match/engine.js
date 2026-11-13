/* ============================================================
   MATCH / ENGINE — 11v11 football simulation
   Pitch 105×68 m. Ball physics with height, possession & dribbling,
   passes/through/lobs/crosses/shots/finesse/headers/volleys, tackles,
   slides, fouls, set pieces (kick-off, throw-in, corner, goal kick,
   free kick, penalty), goalkeeping, stamina, subs, team & player AI.
   ============================================================ */
const PW = 105, PH = 68, GOAL_W = 7.32, GOAL_H = 2.44, G = 9.81;
const GY0 = PH / 2 - GOAL_W / 2, GY1 = PH / 2 + GOAL_W / 2;

const Match = {
  active: false, s: null,
  start(cfg, onEnd) {
    Audio2.musicStop(); Audio2.crowdStart();
    const root = $('#match'); root.classList.remove('hidden'); root.innerHTML = '';
    BG.set('off'); $('#screen').style.visibility = 'hidden';
    const s = this.s = newMatchState(cfg);
    s.onEnd = onEnd;
    MatchView.init(root, s);
    Input.mode = 'game'; Input.clearPressed();
    this.active = true;
    this.layer = Input.pushLayer(root, () => { });
    let last = performance.now(), acc = 0;
    const step = 1 / 60;
    const loop = (now) => {
      if (!this.active) return;
      acc += clamp((now - last) / 1000, 0, 0.1); last = now;
      readGameInput(s);
      while (acc >= step) { if (!s.paused) update(s, step); acc -= step; }
      MatchView.draw(s);
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
    beginKickoff(s, 'home');
    banner(s, `${s.teams.home.short} vs ${s.teams.away.short}`, cfg.title || 'Kick-off', 1.8);
  },
  end() {
    const s = this.s; this.active = false;
    Audio2.crowdStop(); Input.popLayer(this.layer);
    $('#match').classList.add('hidden'); $('#match').innerHTML = ''; $('#screen').style.visibility = '';
    Input.mode = 'menu';
    const res = buildResult(s);
    s.onEnd(res);
  }
};

function newMatchState(cfg) {
  const ai = DIFFICULTIES[cfg.difficulty || 'professional'].ai;
  const s = {
    cfg, t: 0, clock: 0, half: 1, halfSecs: (cfg.halfLen || 3) * 60, state: 'kickoff', stateT: 0, paused: false,
    rules: cfg.rules || 'classic', ai, userSide: cfg.userSide, msgs: [], banner: null,
    ball: { x: PW / 2, y: PH / 2, z: 0, vx: 0, vy: 0, vz: 0, spin: 0, owner: null, last: null, prev: null, shot: null, shotEval: false, kickType: '' },
    stats: { poss: [0, 0], shots: [0, 0], sot: [0, 0], passes: [0, 0], tackles: [0, 0], fouls: [0, 0], corners: [0, 0] },
    goals: [], score: { home: 0, away: 0 }, subsUsed: { home: 0, away: 0 }, sp: null, cam: { x: PW / 2, y: PH / 2, zoom: 1 },
    ctrl: null, charge: 0, chargeKind: null, fx: [], ref: { x: PW / 2, y: PH / 2 + 8, vx: 0, vy: 0, ph: 0 }, goldenGoal: false, extra: false
  };
  s.teams = {};
  for (const side of ['home', 'away']) {
    const T = cfg[side];
    const team = s.teams[side] = { side, name: T.name, short: T.short, kit: T.kit, formation: T.formation, dir: side === 'home' ? 1 : -1, players: [], bench: (T.subs || []).slice(0, 7), user: s.userSide === side, chem: T.chem };
    T.players.forEach((p, i) => team.players.push(makeMP(p, side, i, team, T.chem ? T.chem.per[i] : 3)));
  }
  s.all = [...s.teams.home.players, ...s.teams.away.players];
  if (s.userSide) s.ctrl = s.teams[s.userSide].players.find(p => p.slotPos === 'ST' || p.slotPos === 'CF') || s.teams[s.userSide].players[10];
  return s;
}
function makeMP(p, side, slot, team, chem) {
  const pos = FORMATIONS[team.formation][slot];
  const st = p.stats, gk = pos[0] === 'GK';
  const fit = playerFitsPos(p, pos[0]) ? 0 : -6;
  const cb = (chem - 1.5) * 1.5 + fit; // chemistry & position fit tweak effective attributes
  const a = i => clamp(st[i] + cb, 20, 99);
  return {
    p, side, slot, team, slotPos: pos[0], fx: pos[1], fy: pos[2], gk,
    x: 0, y: 0, vx: 0, vy: 0, face: side === 'home' ? 0 : Math.PI,
    pac: gk ? 55 : a(0), sho: gk ? 30 : a(1), pas: gk ? Math.max(50, st[2]) : a(2), dri: gk ? 40 : a(3), def: gk ? 40 : a(4), phy: gk ? 60 : a(5),
    gkr: gk ? clamp(p.ovr + cb, 30, 99) : 0,
    stamina: 1, cool: 0, tackleCool: 0, stun: 0, dive: null, decideT: Math.random() * 0.5, run: null, ph: Math.random() * 6, skillT: 0, yellow: 0, label: null, labelT: 0, goalT: 0
  };
}
function enemy(s, side) { return s.teams[side === 'home' ? 'away' : 'home']; }
function other(side) { return side === 'home' ? 'away' : 'home'; }
function goalX(team) { return team.dir > 0 ? PW : 0; }   // goal this team attacks
function ownGoalX(team) { return team.dir > 0 ? 0 : PW; }
function sideIdx(side) { return side === 'home' ? 0 : 1; }
function msg(s, text, dur = 2) { s.msgs.push({ text, t: dur }); }
function banner(s, big, small = '', dur = 2.2) { s.banner = { big, small, t: dur }; }
function maxSpeed(m, sprint) {
  const base = 5.2 + m.pac / 100 * 3.6;
  let v = sprint ? base : base * 0.66;
  v *= 0.72 + 0.28 * m.stamina;
  if (m.side !== m.team.side) v *= 1;
  if (!m.team.user) v *= 0.93 + m.team._ai * 0.09;
  return v;
}

/* ------------------------- positioning ------------------------- */
function homeSpot(s, m) {
  const t = m.team, b = s.ball;
  const inPoss = b.owner && b.owner.side === m.side;
  const depth = (100 - m.fy) / 100;
  const span = inPoss ? 70 : 52;
  // block shift: how far up the pitch the ball is, from this team's perspective
  const prog = t.dir > 0 ? b.x : PW - b.x;
  const shift = clamp((prog - 52.5) * 0.45 + (inPoss ? 10 : -2), -14, 28);
  let along = 4 + depth * span + (m.gk ? -shift : shift);
  if (!m.gk && !inPoss) along = Math.max(along, POS_GROUP[m.slotPos] === 'DEF' ? 7 : 11);
  if (m.gk) along = clamp(3 + Math.max(0, prog - 60) * 0.06, 2, 9);
  along = clamp(along, 2, 100);
  const width = (inPoss ? 30 : 23);
  let y = PH / 2 + (t.dir > 0 ? 1 : -1) * ((m.fx - 50) / 50) * width;
  y += (b.y - PH / 2) * (m.gk ? 0.08 : 0.22);
  const x = t.dir > 0 ? along : PW - along;
  return { x: clamp(x, 1, PW - 1), y: clamp(y, 2, PH - 2) };
}
function nearestTo(list, x, y, excl) {
  let best = null, bd = 1e9;
  for (const m of list) { if (m === excl || m.stun > 0) continue; const d = (m.x - x) ** 2 + (m.y - y) ** 2; if (d < bd) { bd = d; best = m; } }
  return best;
}
function placeFormation(s, kickSide) {
  for (const side of ['home', 'away']) {
    const t = s.teams[side];
    for (const m of t.players) {
      const depth = (100 - m.fy) / 100;
      let along = 3 + depth * 46; along = Math.min(along, 50.5);
      if (m.gk) along = 3;
      m.x = t.dir > 0 ? along : PW - along;
      m.y = clamp(PH / 2 + (t.dir > 0 ? 1 : -1) * ((m.fx - 50) / 50) * 26, 3, PH - 3);
      m.vx = m.vy = 0; m.dive = null; m.stun = 0; m.run = null;
      m.face = t.dir > 0 ? 0 : Math.PI;
    }
  }
  // kicker + partner at centre
  const t = s.teams[kickSide];
  const fwds = t.players.filter(m => !m.gk).sort((a, b) => Math.abs(b.x - PW / 2) - Math.abs(a.x - PW / 2)).reverse();
  const k = fwds[0], p2 = fwds[1];
  k.x = PW / 2 - t.dir * 0.4; k.y = PH / 2;
  p2.x = PW / 2 - t.dir * 2.5; p2.y = PH / 2 + 6;
  // defenders out of circle
  for (const m of enemy(s, kickSide).players) { const d = Math.hypot(m.x - PW / 2, m.y - PH / 2); if (d < 9.5) { m.x = PW / 2 + enemy(s, kickSide).dir * -10; } }
  return { k, p2 };
}
function beginKickoff(s, side) {
  const { k, p2 } = placeFormation(s, side);
  const b = s.ball; Object.assign(b, { x: PW / 2, y: PH / 2, z: 0, vx: 0, vy: 0, vz: 0, owner: null, shot: null, spin: 0 });
  s.state = 'setpiece'; s.stateT = 0;
  s.sp = { type: 'kickoff', side, taker: k, target: p2, x: PW / 2, y: PH / 2 };
  giveBall(s, k);
  if (s.teams[side].user) switchTo(s, k);
}

/* ------------------------- ball control ------------------------- */
function giveBall(s, m) {
  const b = s.ball;
  if (b.owner === m) return;
  if (b.last && b.last !== m) b.prev = b.last;
  b.owner = m; b.last = m; b.shot = null; m.recvT = s.t; b.shotEval = false; b.z = 0; b.vz = 0; b.spin = 0; b.kickType = '';
  m.run = null;
  // user auto-switch to receiver
  if (m.team.user) switchTo(s, m);
}
function switchTo(s, m) { if (s.ctrl !== m) { s.ctrl = m; s.charge = 0; s.chargeKind = null; } }
function kick(s, m, vx, vy, vz, type, spin = 0) {
  const b = s.ball;
  b.owner = null; b.vx = vx; b.vy = vy; b.vz = vz; b.spin = spin; b.last = m; b.kickType = type;
  b.z = Math.max(b.z, 0.11);
  m.cool = 0.35;
  b.shot = type === 'shot' ? { side: m.side, m, t: s.t, fromX: m.x, fromY: m.y, air: b.z > 0.5 || type === 'header' } : null;
  if (type === 'shot') { s.stats.shots[sideIdx(m.side)]++; b.shotEval = false; }
  if (type === 'pass') { b.passFrom = m; b.passT = s.t; }
  Audio2.sfx('kick');
}
function passTo(s, m, target, kind) {
  const b = s.ball;
  let tx = target.x, ty = target.y;
  const errScale = (1 - m.pas / 100) * 0.16 + (m.team.user ? 0 : (1 - m.team._ai) * 0.08) + (m.stun > 0 ? 0.1 : 0);
  if (kind === 'through') {
    const t = m.team, gx = goalX(t);
    const ahead = 9 + m.pas / 20;
    tx = target.x + t.dir * ahead; ty = target.y + (PH / 2 - target.y) * 0.15;
    tx = clamp(tx, 2, PW - 2); target.run = { x: tx, y: ty, t: 2.6 };
  } else {
    // lead the receiver
    tx += target.vx * 0.45; ty += target.vy * 0.45;
  }
  const dx = tx - b.x, dy = ty - b.y, d = Math.hypot(dx, dy) || 1;
  let ang = Math.atan2(dy, dx) + (Math.random() - 0.5) * 2 * errScale * (0.6 + d / 40);
  if (kind === 'lob' || kind === 'cross') {
    const vh = clamp(9 + d * 0.42, 11, 25);
    const T = d / vh;
    const vz = G * T / 2 * (kind === 'cross' ? 0.92 : 1);
    kick(s, m, Math.cos(ang) * vh, Math.sin(ang) * vh, vz, 'pass');
  } else {
    const v = clamp(6 + d * 0.5, 8, kind === 'through' ? 22 : 20);
    kick(s, m, Math.cos(ang) * v, Math.sin(ang) * v, kind === 'through' ? 0.4 : 0.2, 'pass');
  }
  target._expect = s.t; b.target = target;
  s.stats.passes[sideIdx(m.side)]++;
}
function shoot(s, m, power, aimY, finesse = false, kind = 'shot') {
  const t = m.team, b = s.ball, gx = goalX(t);
  const d = Math.hypot(gx - b.x, PH / 2 - b.y);
  // target point inside the goal
  let ty = aimY !== null ? aimY : (Math.random() < 0.5 ? GY0 + 0.9 : GY1 - 0.9);
  const quality = (m.sho / 100) * (finesse ? 1.08 : 1) * (m.stun > 0 ? 0.7 : 1);
  const errBase = (1.1 - quality) * (0.35 + d / 30) * (m.team.user ? 1 : 1.25 - m.team._ai * 0.4);
  const pressure = enemy(s, m.side).players.some(o => Math.hypot(o.x - m.x, o.y - m.y) < 2.2) ? 1.35 : 1;
  ty += (Math.random() - 0.5) * 2 * errBase * 2.2 * pressure;
  const spd = finesse ? 15 + power * 9 : 17 + power * 15 + m.sho / 25;
  let tz = 0.3 + power * 1.4 + (Math.random() - 0.3) * errBase * 1.6 * pressure;
  if (power > 0.85) tz += (power - 0.85) * 10 * (1.05 - quality); // over-hit
  if (finesse) tz = Math.min(tz, 1.9);
  const dx = gx - b.x, dy = ty - b.y, dd = Math.hypot(dx, dy) || 1;
  const T = dd / spd;
  const vz = (tz - b.z + 0.5 * G * T * T) / T;
  const spin = finesse ? (dy > 0 ? -1 : 1) * 5.5 : 0;
  // finesse curls: aim slightly wide so curve brings it back
  let ang = Math.atan2(dy, dx); if (finesse) ang -= spin * 0.018;
  kick(s, m, Math.cos(ang) * spd, Math.sin(ang) * spd, Math.min(vz, 9), kind === 'header' ? 'shot' : 'shot', spin);
  s.ball.shot.air = kind === 'header' || kind === 'volley' || s.ball.shot.air;
  s.ball.shot.outside = d > 17.5;
  m.label = finesse ? 'Finesse' : kind === 'header' ? 'Header' : kind === 'volley' ? 'Volley' : null; m.labelT = 1.2;
}

/* ------------------------- input ------------------------- */
function readGameInput(s) {
  const k = Input.keys, pad = Input.pad;
  let x = 0, y = 0;
  if (k['a'] || k['arrowleft']) x -= 1; if (k['d'] || k['arrowright']) x += 1;
  if (k['w'] || k['arrowup']) y -= 1; if (k['s'] || k['arrowdown']) y += 1;
  let ax = 0, ay = 0, rsx = 0, rsy = 0;
  const btn = i => !!(pad && pad.buttons[i] && pad.buttons[i].pressed);
  if (pad) { ax = pad.axes[0] || 0; ay = pad.axes[1] || 0; rsx = pad.axes[2] || 0; rsy = pad.axes[3] || 0; if (btn(14)) ax = -1; if (btn(15)) ax = 1; if (btn(12)) ay = -1; if (btn(13)) ay = 1; }
  if (Math.hypot(ax, ay) > 0.25) { x = ax; y = ay; }
  const l = Math.hypot(x, y); if (l > 1) { x /= l; y /= l; }
  const prev = s._in || {};
  // taps shorter than a frame are buffered in Input.pressed so no press is ever lost
  const P2 = Input.pressed, tap = key => { const v = !!P2[key]; P2[key] = false; return v; };
  const tp = { j: tap('j'), i: tap('i'), k: tap('k'), l: tap('l'), o: tap('o'), e: tap('e'), q: tap('q'), esc: tap('escape'), p: tap('p'), h: tap('h') };
  const cur = {
    x, y, sprint: !!(k['shift'] || btn(7)),
    pass: !!(k['j'] || tp.j || btn(0)), through: !!(k['i'] || tp.i || btn(3)), shoot: !!(k['k'] || btn(2)), lob: !!(k['l'] || tp.l || btn(1)),
    finesse: !!(k['o'] || (btn(5) && btn(2))), skill: !!(k['e'] || tp.e || Math.hypot(rsx, rsy) > 0.7), sw: !!(k['q'] || tp.q || btn(4)), pause: !!(k['escape'] || tp.esc || k['p'] || tp.p || btn(9)), help: !!(k['h'] || tp.h)
  };
  // a quick tap of shoot/finesse (press+release within a frame) still fires a low-power shot
  if ((tp.k && !k['k']) || (tp.o && !k['o'])) { s._tapShot = tp.o ? 'finesse' : 'shot'; }
  if (cur.finesse && btn(5)) cur.shoot = false;
  const ed = {}; for (const kk in cur) if (typeof cur[kk] === 'boolean') ed[kk] = cur[kk] && !prev[kk];
  const rel = {}; for (const kk of ['shoot', 'finesse']) rel[kk] = !cur[kk] && prev[kk];
  if (s._tapShot) { ed.shoot = true; rel[s._tapShot] = true; if (!s.chargeKind) { s.charge = 0.45; s.chargeKind = s._tapShot; } s._tapShot = null; }
  s._in = cur; s.inp = cur; s.edge = ed; s.rel = rel;
  if (ed.pause) MatchView.togglePause(s);
  if (ed.help) MatchView.toggleHelp();
}

/* ------------------------- main update ------------------------- */
function update(s, dt) {
  s.t += dt; s.stateT += dt;
  for (const side of ['home', 'away']) s.teams[side]._ai = s.teams[side].user ? 0.75 : s.ai;
  s.msgs.forEach(m => m.t -= dt); s.msgs = s.msgs.filter(m => m.t > 0);
  if (s.banner) { s.banner.t -= dt; if (s.banner.t <= 0) s.banner = null; }
  s.fx.forEach(f => f.t -= dt); s.fx = s.fx.filter(f => f.t > 0);

  if (s.state === 'play') {
    s.clock += dt;
    const b = s.ball;
    if (b.owner) s.stats.poss[sideIdx(b.owner.side)] += dt;
    // half/full time
    if (s.clock >= s.halfSecs && !s.goldenGoal && s.state === 'play') {
      if (s.half === 1) { s.state = 'halftime'; s.stateT = 0; Audio2.sfx('whistle3'); banner(s, 'Half Time', `${s.teams.home.short} ${s.score.home} - ${s.score.away} ${s.teams.away.short}`, 3); return; }
      else {
        if (s.rules === 'golden' && s.score.home === s.score.away) { s.goldenGoal = true; banner(s, 'Golden Goal', 'Next goal wins', 2.2); msg(s, 'Golden goal — next goal wins!', 3); }
        else { s.state = 'fulltime'; s.stateT = 0; Audio2.sfx('whistle3'); banner(s, 'Full Time', `${s.teams.home.short} ${s.score.home} - ${s.score.away} ${s.teams.away.short}`, 3.2); return; }
      }
    }
    if (s.goldenGoal && s.clock > s.halfSecs * 1.67) { s.state = 'fulltime'; s.stateT = 0; Audio2.sfx('whistle3'); banner(s, 'Full Time', '', 3); return; }
  }
  if (s.state === 'halftime') {
    if (s.stateT > 3.2) { s.half = 2; s.clock = 0; for (const side of ['home', 'away']) { s.teams[side].dir *= -1; s.teams[side].players.forEach(m => m.stamina = Math.min(1, m.stamina + 0.25)); } beginKickoff(s, 'away'); Audio2.sfx('whistle'); }
    simPlayers(s, dt, true); return;
  }
  if (s.state === 'fulltime') {
    simPlayers(s, dt, true);
    if (s.stateT > 3.4) Match.end();
    return;
  }
  if (s.state === 'goal') {
    celebrate(s, dt);
    physicsBall(s, dt, true);
    if (s.stateT > 4.2) {
      if (s.goldenGoal) { s.state = 'fulltime'; s.stateT = 0; Audio2.sfx('whistle3'); banner(s, 'Full Time', 'Golden goal!', 3); return; }
      beginKickoff(s, other(s.lastGoalSide)); Audio2.sfx('whistle');
    }
    return;
  }
  if (s.state === 'setpiece') { updateSetPiece(s, dt); simPlayers(s, dt, true); return; }
  if (s.state === 'out') { physicsBall(s, dt, true); simPlayers(s, dt, true); if (s.stateT > 1.0) startSetPiece(s, s.pendingSP); return; }

  // ---- open play
  userControl(s, dt);
  teamAI(s, dt);
  simPlayers(s, dt, false);
  physicsBall(s, dt, false);
  handleContacts(s, dt);
  checkGoalAndOut(s);
  updateRef(s, dt);
  Audio2.crowdLevel(crowdExcitement(s));
}
function crowdExcitement(s) {
  const b = s.ball; const nearGoal = Math.min(b.x, PW - b.x);
  return clamp(0.25 + (nearGoal < 25 ? (25 - nearGoal) / 25 * 0.55 : 0) + (b.shot ? 0.3 : 0), 0.2, 1);
}

/* ------------------------- user control ------------------------- */
function userControl(s, dt) {
  if (!s.userSide) return;
  const team = s.teams[s.userSide], b = s.ball, m = s.ctrl, I = s.inp, E = s.edge;
  if (!m) return;
  // switching
  if (E.sw) {
    const cands = team.players.filter(x => x !== m && !x.gk);
    const best = nearestTo(cands, b.x + b.vx * 0.3, b.y + b.vy * 0.3);
    if (best) { switchTo(s, best); Audio2.sfx('move'); }
  }
  // auto-switch when defending and far away
  if (b.owner && b.owner.side !== s.userSide && Math.hypot(m.x - b.x, m.y - b.y) > 16 && !E.sw && s.t - (s._lastAutoSw || 0) > 1.2) {
    const best = nearestTo(team.players.filter(x => !x.gk), b.x, b.y);
    if (best && best !== m) { switchTo(s, best); s._lastAutoSw = s.t; }
  }
  if (!b.owner && b.last && b.last.side === s.userSide && b.kickType === 'pass') { /* follow pass: receiver gets control on reception (giveBall) */ }
  else if (!b.owner && Math.hypot(m.x - b.x, m.y - b.y) > 14 && s.t - (s._lastAutoSw || 0) > 1.5) {
    const best = nearestTo(team.players.filter(x => !x.gk), b.x, b.y);
    if (best && best !== s.ctrl && Math.hypot(best.x - b.x, best.y - b.y) < Math.hypot(m.x - b.x, m.y - b.y) - 4) { switchTo(s, best); s._lastAutoSw = s.t; }
  }
  const has = b.owner === m;
  // movement
  const mag = Math.hypot(I.x, I.y);
  m._userMove = true;
  if (mag > 0.1) {
    const v = maxSpeed(m, I.sprint) * Math.min(1, mag) * (has ? 0.94 - (1 - m.dri / 100) * 0.12 : 1);
    const turn = has ? 6 + m.dri / 14 : 12;
    m.vx = lerp(m.vx, I.x / Math.max(mag, 1) * v, Math.min(1, turn * dt));
    m.vy = lerp(m.vy, I.y / Math.max(mag, 1) * v, Math.min(1, turn * dt));
  } else { m.vx = lerp(m.vx, 0, Math.min(1, 8 * dt)); m.vy = lerp(m.vy, 0, Math.min(1, 8 * dt)); }
  m.sprinting = I.sprint && mag > 0.1;
  const aimX = mag > 0.1 ? I.x / mag : Math.cos(m.face), aimY = mag > 0.1 ? I.y / mag : Math.sin(m.face);

  if (has) {
    // charge shots
    if (I.shoot || I.finesse) { s.charge = Math.min(1, s.charge + dt * 1.15); s.chargeKind = I.finesse ? 'finesse' : 'shot'; }
    if ((s.rel.shoot || s.rel.finesse) && s.chargeKind) {
      const t = team, gx = goalX(t);
      // aim: vertical input picks a side of the goal (from the attacker's view)
      let aim = null;
      if (Math.abs(I.y) > 0.3) aim = I.y < 0 ? GY0 + 0.8 : GY1 - 0.8;
      else aim = (m.y < PH / 2 ? GY1 - 1 : GY0 + 1);
      if (Math.abs(gx - m.x) > 40) { // long-range: treat as a long pass/clearance toward aim direction
        shoot(s, m, s.charge, aim, s.chargeKind === 'finesse');
      } else shoot(s, m, s.charge, aim, s.chargeKind === 'finesse');
      s.charge = 0; s.chargeKind = null; return;
    }
    if (E.pass || E.through || E.lob) {
      const kind = E.through ? 'through' : E.lob ? (inCrossZone(s, m) ? 'cross' : 'lob') : 'ground';
      const tgt = pickPassTarget(s, m, aimX, aimY, kind);
      if (tgt) passTo(s, m, tgt, kind);
      else { const v = kind === 'lob' ? 18 : 14; kick(s, m, aimX * v, aimY * v, kind === 'lob' ? 6 : 0.2, 'pass'); }
      return;
    }
    if (E.skill) doSkill(s, m, aimX, aimY);
  } else {
    // defending / off the ball
    const opp = b.owner && b.owner.side !== m.side ? b.owner : null;
    const d = Math.hypot(b.x - m.x, b.y - m.y);
    const firstTime = !b.owner && d < 1.6 && m.cool <= 0 && b.z > 0.35 && b.z < 2.7;
    if (E.pass && opp) tryTackle(s, m, opp, false);
    if (E.shoot && !firstTime && (opp || !b.owner)) trySlide(s, m, aimX, aimY);
    // first-time actions on a loose ball near the player: volley / header / first-time pass
    if (firstTime) {
      if (b.z > 0.35 && b.z < 2.7 && (E.shoot || E.pass)) {
        const inRange = Math.abs(goalX(team) - m.x) < 30;
        if (E.shoot && inRange) { shoot(s, m, 0.6, null, false, b.z > 1.3 ? 'header' : 'volley'); }
        else { const tgt = pickPassTarget(s, m, aimX, aimY, 'ground'); if (tgt) passTo(s, m, tgt, 'ground'); else kick(s, m, aimX * 15, aimY * 15, 2, 'pass'); }
      }
    }
  }
}
function inCrossZone(s, m) { const gx = goalX(m.team); return Math.abs(gx - m.x) < 30 && (m.y < 18 || m.y > PH - 18); }
function pickPassTarget(s, m, ax, ay, kind) {
  let best = null, bs = -1e9;
  for (const t of m.team.players) {
    if (t === m) continue;
    const dx = t.x - m.x, dy = t.y - m.y, d = Math.hypot(dx, dy);
    if (d < 3 || d > (kind === 'lob' || kind === 'cross' ? 55 : 42)) continue;
    const cos = (dx * ax + dy * ay) / d;
    if (cos < 0.35) continue;
    let sc = cos * 30 - d * 0.35;
    if (kind === 'cross') sc += (Math.abs(goalX(m.team) - t.x) < 16 && Math.abs(t.y - PH / 2) < 12) ? 25 : -10;
    if (kind === 'through') sc += (t.x - m.x) * m.team.dir * 0.3;
    if (t.gk) sc -= 12;
    if (sc > bs) { bs = sc; best = t; }
  }
  return best;
}
function doSkill(s, m, ax, ay) {
  if (m.skillT > 0) return;
  const stars = m.p.sm;
  const names = ['Ball Roll', 'Step Over', 'Roulette', 'Elastico', 'Rainbow Flick'];
  m.label = names[Math.min(stars, 5) - 1] || 'Feint'; m.labelT = 1;
  // sidestep perpendicular to movement + short burst; success fools nearby defenders
  const px = -ay, py = ax, sgn = Math.random() < 0.5 ? 1 : -1;
  m.vx += px * sgn * (3 + stars) + ax * stars * 0.9; m.vy += py * sgn * (3 + stars) + ay * stars * 0.9;
  m.skillT = 1.1 - stars * 0.08;
  const success = Math.random() < 0.25 + stars * 0.13 + m.dri / 400;
  for (const o of enemy(s, m.side).players) if (Math.hypot(o.x - m.x, o.y - m.y) < 4) { if (success) { o.tackleCool = 0.9; o.stun = 0.35; } }
  if (!success && Math.random() < 0.35) { // lose control
    const b = s.ball; b.owner = null; b.vx = m.vx * 1.3 + ax * 3; b.vy = m.vy * 1.3 + ay * 3; m.cool = 0.4;
  }
}
function tryTackle(s, m, opp, ai) {
  if (m.tackleCool > 0) return false;
  m.tackleCool = 0.7;
  const d = Math.hypot(opp.x - m.x, opp.y - m.y);
  if (d > 2.0) { m.vx += (opp.x - m.x) / d * 2; m.vy += (opp.y - m.y) / d * 2; return false; }
  s.stats.tackles[sideIdx(m.side)]++;
  Audio2.sfx('tackle');
  let p = clamp(0.3 + (m.def - opp.dri) / 100 + (ai ? (m.team._ai - 0.6) * 0.25 : 0.12) - (d - 1) * 0.15, 0.08, 0.8);
  if (s.t - (opp.recvT || 0) < 0.5) p *= 0.5;
  if (Math.random() < p) {
    if (Math.random() < 0.55) { giveBall(s, m); } else { const b = s.ball; b.owner = null; b.vx = (Math.random() - 0.5) * 8; b.vy = (Math.random() - 0.5) * 8; opp.cool = 0.4; }
    opp.stun = 0.3; return true;
  }
  if (Math.random() < 0.12 && s.rules !== 'nofouls') { foul(s, m, opp, false); return false; }
  m.stun = 0.45; return false;
}
function trySlide(s, m, ax, ay) {
  if (m.tackleCool > 0 || m.sliding) return;
  m.sliding = 0.6; m.tackleCool = 1.4; m.vx = ax * (maxSpeed(m, true) + 2.5); m.vy = ay * (maxSpeed(m, true) + 2.5);
  m.label = 'Slide'; m.labelT = 0.6;
}
function foul(s, m, victim, slide) {
  if (s.rules === 'nofouls') return;
  s.stats.fouls[sideIdx(m.side)]++;
  Audio2.sfx('whistle');
  const card = slide && Math.random() < 0.35 || Math.random() < 0.08;
  if (card) { m.yellow++; msg(s, `🟨 Yellow card — ${shortName(m.p.name)}`, 2.6); }
  else msg(s, `Foul by ${shortName(m.p.name)}`, 2);
  const defT = m.team, gxOwn = ownGoalX(defT);
  const inBox = Math.abs(victim.x - gxOwn) < 16.5 && Math.abs(victim.y - PH / 2) < 20.16;
  s.ball.owner = null; s.ball.vx = s.ball.vy = s.ball.vz = 0;
  s.pendingSP = inBox ? { type: 'penalty', side: victim.side, x: defT.dir > 0 ? 11 : PW - 11, y: PH / 2 } : { type: 'freekick', side: victim.side, x: victim.x, y: victim.y };
  s.state = 'out'; s.stateT = 0.4;
  if (inBox) banner(s, 'Penalty!', '', 1.6);
}

/* ------------------------- team AI ------------------------- */
function teamAI(s, dt) {
  const b = s.ball;
  for (const side of ['home', 'away']) {
    const team = s.teams[side], foe = enemy(s, side);
    const inPoss = b.owner && b.owner.side === side;
    const loose = !b.owner;
    // who chases a loose ball / presses the carrier
    let chaser = null, chaser2 = null;
    const recv = loose && b.target && b.target.side === side && b.last && b.last.side === side && s.t - (b.passT || 0) < 3 ? b.target : null;
    if (recv && !(team.user && recv === s.ctrl)) {
      // move to where the ball will be when it slows / reaches the receiver line
      const sp = Math.hypot(b.vx, b.vy) || 1;
      let best = { x: b.x, y: b.y }, bt = 1e9;
      for (let k = 0.15; k < 2.6; k += 0.15) {
        const f = (1 - Math.exp(-0.6 * k)) / 0.6;
        const px = b.x + b.vx * f, py = b.y + b.vy * f;
        const need = Math.hypot(px - recv.x, py - recv.y) / maxSpeed(recv, true);
        if (need <= k && k < bt) { bt = k; best = { x: px, y: py }; break; }
        best = { x: px, y: py };
      }
      steer(recv, best.x, best.y, true, dt); recv._recv = true;
    }
    if (!inPoss) {
      const tx = b.x + b.vx * 0.35, ty = b.y + b.vy * 0.35;
      const outfield = team.players.filter(m => !m.gk && !(team.user && m === s.ctrl) && m !== recv);
      chaser = nearestTo(outfield, tx, ty);
      if (!loose) chaser2 = nearestTo(outfield.filter(m => m !== chaser), tx, ty);
    }
    for (const m of team.players) {
      m._userMove = false;
      if (team.user && m === s.ctrl) continue;
      if (m.stun > 0 || m.sliding) continue;
      let tx, ty, sprint = false;
      if (m.gk) { gkAI(s, m, dt); continue; }
      if (b.owner === m) { carrierAI(s, m, dt); continue; }
      if (m === recv) continue;
      const home = homeSpot(s, m);
      tx = home.x; ty = home.y;
      if (m === chaser) {
        const d = Math.hypot(b.x - m.x, b.y - m.y);
        if (loose) { const lead = Math.min(0.8, d / 14); tx = b.x + b.vx * lead; ty = b.y + b.vy * lead; sprint = d > 2; }
        else {
          // jockey: stay goal-side of the carrier, then step in
          const og = ownGoalX(team), gx2 = og - b.x, gy2 = PH / 2 - b.y, gl = Math.hypot(gx2, gy2) || 1;
          const close = d < 3.2;
          tx = b.x + gx2 / gl * (close ? 0.9 : 1.6); ty = b.y + gy2 / gl * (close ? 0.9 : 1.6); sprint = d > 6;
          if (d < 1.7 && b.owner) {
            const agg = team.user ? 0.7 : 0.35 + team._ai * 0.9;
            if (Math.random() < agg * dt) tryTackle(s, m, b.owner, true);
            else if (!team.user && Math.random() < dt * 0.04 * team._ai && Math.abs(b.owner.x - og) > 25) trySlide(s, m, (b.x - m.x) / (d || 1), (b.y - m.y) / (d || 1));
          }
        }
      } else if (m === chaser2) {
        // cover: between ball and own goal
        const og = ownGoalX(team);
        tx = lerp(b.x, og, 0.4); ty = lerp(b.y, PH / 2, 0.35);
      } else if (!inPoss) {
        // mark nearest attacker near my zone
        const mk = nearestTo(foe.players.filter(o => !o.gk), home.x, home.y);
        if (mk && Math.hypot(mk.x - home.x, mk.y - home.y) < 14) { const og = ownGoalX(team); tx = lerp(mk.x, og, 0.12); ty = lerp(mk.y, PH / 2, 0.08); tx = lerp(tx, home.x, 0.35); ty = lerp(ty, home.y, 0.35); }
      } else if (inPoss) {
        // supporting runs
        if (m.run && m.run.t > 0) { m.run.t -= dt; tx = m.run.x; ty = m.run.y; sprint = true; }
        else if (POS_GROUP[m.slotPos] === 'ATT' && Math.random() < dt * 0.35) {
          const gx = goalX(team); m.run = { x: clamp(m.x + team.dir * R.range(8, 18), 3, PW - 3), y: clamp(lerp(m.y, PH / 2, 0.3) + R.range(-6, 6), 4, PH - 4), t: R.range(1, 2.2) };
          if (Math.abs(gx - m.run.x) < 3) m.run.x = gx - team.dir * 6;
        }
        // find space: move away from nearest marker
        const mk = nearestTo(foe.players, m.x, m.y);
        if (mk) { const d = Math.hypot(mk.x - m.x, mk.y - m.y); if (d < 4) { ty += (m.y - mk.y) / (d || 1) * 3; } }
      }
      steer(m, tx, ty, sprint, dt);
    }
  }
}
function steer(m, tx, ty, sprint, dt) {
  const dx = tx - m.x, dy = ty - m.y, d = Math.hypot(dx, dy);
  const max = maxSpeed(m, sprint);
  const want = d < 0.4 ? 0 : Math.min(max, d * 1.8);
  const vx = d > 0.01 ? dx / d * want : 0, vy = d > 0.01 ? dy / d * want : 0;
  m.vx = lerp(m.vx, vx, Math.min(1, 6 * dt)); m.vy = lerp(m.vy, vy, Math.min(1, 6 * dt));
  m.sprinting = sprint && want > max * 0.8;
}
function carrierAI(s, m, dt) {
  const team = m.team, foe = enemy(s, m.side), b = s.ball, ai = team._ai;
  const gx = goalX(team), distGoal = Math.hypot(gx - m.x, PH / 2 - m.y);
  const nearest = nearestTo(foe.players, m.x, m.y);
  const press = nearest ? Math.hypot(nearest.x - m.x, nearest.y - m.y) : 99;
  m.decideT -= dt;
  // dribble direction: toward goal, steering away from the nearest defender
  let dx = gx - m.x, dy = (PH / 2 - m.y) * 0.6;
  const dl = Math.hypot(dx, dy) || 1; dx /= dl; dy /= dl;
  if (nearest && press < 6) { const ox = m.x - nearest.x, oy = m.y - nearest.y, ol = Math.hypot(ox, oy) || 1; dx += ox / ol * 0.9 * (6 - press) / 6; dy += oy / ol * 1.2 * (6 - press) / 6; }
  const l2 = Math.hypot(dx, dy) || 1; dx /= l2; dy /= l2;
  const sprint = press > 3.2 || (press > 2 && (nearest.x - m.x) * team.dir < 0);
  steer(m, m.x + dx * 6, m.y + dy * 6, sprint, dt);
  if (m.decideT > 0 || m.cool > 0) return;
  m.decideT = 0.55 - ai * 0.3 + Math.random() * 0.25;
  if (s.state !== 'play') return;
  // shooting decision
  const angleOK = Math.abs(m.y - PH / 2) < 16 + (30 - Math.min(30, distGoal)) * 0.2;
  if (distGoal < 27 && angleOK && (press > 2.2 || distGoal < 16 || Math.random() < 0.5)) {
    const pShoot = distGoal < 12 ? 0.95 : distGoal < 17 ? 0.6 + ai * 0.2 : distGoal < 22 ? 0.25 + ai * 0.15 : 0.08 + ai * 0.08;
    if (Math.random() < pShoot) {
      const aim = R.chance(0.5) ? GY0 + R.range(0.5, 1.6) : GY1 - R.range(0.5, 1.6);
      const fin = distGoal > 15 && distGoal < 22 && Math.random() < 0.35;
      shoot(s, m, R.range(0.45, 0.82), aim, fin); return;
    }
  }
  // passing options
  let best = null, bs = -1e9;
  for (const t of team.players) {
    if (t === m) continue;
    const d = Math.hypot(t.x - m.x, t.y - m.y);
    if (d < 5 || d > 40) continue;
    const open = Math.min(...foe.players.map(o => Math.hypot(o.x - t.x, o.y - t.y)));
    // interception risk along the line
    let risk = 0;
    for (const o of foe.players) {
      const t2 = clamp(((o.x - m.x) * (t.x - m.x) + (o.y - m.y) * (t.y - m.y)) / (d * d), 0, 1);
      const px = m.x + (t.x - m.x) * t2, py = m.y + (t.y - m.y) * t2;
      const od = Math.hypot(o.x - px, o.y - py);
      if (od < 2.2 && t2 > 0.1) risk += (2.2 - od) * 6;
    }
    const prog = (t.x - m.x) * team.dir;
    let sc = prog * 0.9 + Math.min(open, 8) * 2.2 - risk - d * 0.15 - (t.gk ? 30 : 0);
    if (Math.abs(gx - t.x) < 20 && Math.abs(t.y - PH / 2) < 15 && open > 2.5) sc += 14;
    if (sc > bs) { bs = sc; best = t; }
  }
  const dribbleScore = (press > 5 ? 14 : press > 3 ? 6 : press > 2 ? -2 : -10) + (distGoal < 32 ? 5 : 0) + (m.dri - 70) * 0.2;
  if (best && (bs > dribbleScore || press < 1.8)) {
    const crossZone = inCrossZone(s, m) && Math.abs(gx - best.x) < 16;
    const through = best.run && Math.random() < 0.6;
    passTo(s, m, best, crossZone ? 'cross' : through ? 'through' : (Math.hypot(best.x - m.x, best.y - m.y) > 30 && Math.random() < 0.5 ? 'lob' : 'ground'));
  }
}
function gkAI(s, m, dt) {
  const team = m.team, b = s.ball, og = ownGoalX(team);
  if (m.dive) { // diving animation/motion
    m.dive.t -= dt; m.x += m.dive.vx * dt; m.y += m.dive.vy * dt; m.vx = m.dive.vx; m.vy = m.dive.vy;
    if (m.dive.t <= 0) { m.dive = null; m.stun = 0.5; }
    return;
  }
  if (b.owner === m) { // distribute
    m.decideT -= dt;
    steer(m, og + team.dir * 6, PH / 2, false, dt);
    if (m.decideT <= 0 && m.holdT === undefined) m.holdT = 0;
    m.holdT = (m.holdT || 0) + dt;
    if (m.holdT > 1.3 && !(team.user && s.ctrl === m)) {
      m.holdT = 0;
      const mates = team.players.filter(t => !t.gk);
      const open = mates.map(t => ({ t, o: Math.min(...enemy(s, m.side).players.map(o => Math.hypot(o.x - t.x, o.y - t.y))) })).sort((a, b) => b.o - a.o);
      const tgt = open[0].o > 6 ? open[0].t : R.pick(mates.filter(t => POS_GROUP[t.slotPos] !== 'DEF')) || open[0].t;
      passTo(s, m, tgt, Math.hypot(tgt.x - m.x, tgt.y - m.y) > 28 ? 'lob' : 'ground');
    }
    return;
  }
  m.holdT = 0;
  // position on line between ball and goal centre
  const bx = b.x, by = b.y;
  const dGoal = Math.hypot(bx - og, by - PH / 2);
  const off = clamp(1 + (40 - Math.min(40, dGoal)) * 0.07, 1, 4.5);
  let tx = og + team.dir * off, ty = PH / 2 + (by - PH / 2) * clamp(off / Math.max(dGoal, 1), 0, 0.5) * 2.2;
  ty = clamp(ty, GY0 + 0.4, GY1 - 0.4);
  // rush out on loose balls / 1v1 in the box
  const inBox = Math.abs(bx - og) < 16.5 && Math.abs(by - PH / 2) < 20;
  if (inBox && (!b.owner || b.owner.side !== m.side) && dGoal < 13 && !b.shot) {
    const carrier = b.owner; const myD = Math.hypot(bx - m.x, by - m.y);
    if (!carrier || myD < 6) { tx = bx; ty = by; }
  }
  steer(m, tx, ty, inBox, dt);
  // claim loose balls / crosses
  if (!b.owner && Math.hypot(bx - m.x, by - m.y) < 1.8 && b.z < 2.6 && m.cool <= 0 && !b.shot) { giveBall(s, m); b.vx = b.vy = 0; }
}

/* ------------------------- players & physics ------------------------- */
function simPlayers(s, dt, frozen) {
  for (const m of s.all) {
    m.cool = Math.max(0, m.cool - dt); m.tackleCool = Math.max(0, m.tackleCool - dt); m.stun = Math.max(0, m.stun - dt); m.skillT = Math.max(0, m.skillT - dt); m.labelT = Math.max(0, m.labelT - dt);
    if (m.sliding) { m.sliding -= dt; m.vx *= 0.94; m.vy *= 0.94; if (m.sliding <= 0) { m.sliding = 0; m.stun = 0.35; } }
    if (frozen && !m._spMove) { // set-piece / stoppage: walk toward target
      if (m._target) steer(m, m._target.x, m._target.y, false, dt); else { m.vx *= 0.9; m.vy *= 0.9; }
    }
    m.x = clamp(m.x + m.vx * dt, -3, PW + 3); m.y = clamp(m.y + m.vy * dt, -3, PH + 3);
    const sp = Math.hypot(m.vx, m.vy);
    if (sp > 0.3) m.face = Math.atan2(m.vy, m.vx);
    m.ph += sp * dt * 1.7;
    // stamina
    if (m.sprinting && sp > 4) m.stamina = Math.max(0, m.stamina - dt * (0.012 - m.phy / 100 * 0.006) * 1.6);
    else m.stamina = Math.min(1, m.stamina + dt * 0.003);
  }
  // separation
  for (let i = 0; i < s.all.length; i++) for (let j = i + 1; j < s.all.length; j++) {
    const a = s.all[i], c = s.all[j], dx = c.x - a.x, dy = c.y - a.y, d = Math.hypot(dx, dy);
    if (d < 0.85 && d > 0.001) { const push = (0.85 - d) / 2; a.x -= dx / d * push; a.y -= dy / d * push; c.x += dx / d * push; c.y += dy / d * push; }
  }
}
function physicsBall(s, dt, frozen) {
  const b = s.ball;
  if (b.owner) {
    const m = b.owner;
    const sp = Math.hypot(m.vx, m.vy);
    const lead = 0.55 + Math.min(0.5, sp * 0.05);
    b.x = m.x + Math.cos(m.face) * lead; b.y = m.y + Math.sin(m.face) * lead; b.z = 0;
    b.vx = m.vx; b.vy = m.vy; b.vz = 0;
    return;
  }
  // air or ground
  if (b.z > 0.02 || b.vz > 0) {
    b.vz -= G * dt; b.z += b.vz * dt;
    b.vx *= Math.exp(-0.12 * dt); b.vy *= Math.exp(-0.12 * dt);
    if (b.z <= 0) { b.z = 0; if (b.vz < -2) { b.vz = -b.vz * 0.48; b.vx *= 0.82; b.vy *= 0.82; } else b.vz = 0; }
  } else {
    const k = 0.6; b.vx *= Math.exp(-k * dt); b.vy *= Math.exp(-k * dt);
    if (Math.hypot(b.vx, b.vy) < 0.15) { b.vx = b.vy = 0; }
  }
  // curl (finesse)
  if (b.spin) { const v = Math.hypot(b.vx, b.vy) || 1; const px = -b.vy / v, py = b.vx / v; b.vx += px * b.spin * dt; b.vy += py * b.spin * dt; b.spin *= Math.exp(-0.6 * dt); }
  b.x += b.vx * dt; b.y += b.vy * dt;
}
function handleContacts(s, dt) {
  const b = s.ball;
  if (b.owner) {
    // slide tackles hitting the carrier
    for (const m of s.all) {
      if (!m.sliding || m.side === b.owner.side) continue;
      const d = Math.hypot(m.x - b.x, m.y - b.y), dc = Math.hypot(m.x - b.owner.x, m.y - b.owner.y);
      if (d < 1.4 || dc < 1.0) {
        const carrier = b.owner;
        // from behind? (slider moving roughly the same way as the carrier faces)
        const behind = (m.vx * Math.cos(carrier.face) + m.vy * Math.sin(carrier.face)) / (Math.hypot(m.vx, m.vy) || 1) > 0.5;
        const clean = d < 1.2 && Math.random() < 0.45 + (m.def - carrier.dri) / 120 + (behind ? -0.3 : 0);
        s.stats.tackles[sideIdx(m.side)]++; Audio2.sfx('tackle');
        m.sliding = 0;
        if (clean) { b.owner = null; b.vx = m.vx * 0.9; b.vy = m.vy * 0.9; carrier.stun = 0.6; carrier.cool = 0.5; }
        else if (s.rules !== 'nofouls' && (behind || Math.random() < 0.5)) { carrier.stun = 0.8; foul(s, m, carrier, true); }
        break;
      }
    }
    return;
  }
  // headers & volleys for AI, ball pick-up
  let best = null, bd = 1e9;
  for (const m of s.all) {
    if (m.cool > 0 || m.stun > 0 || m.dive) continue;
    if (b.shot && m.gk) continue;
    const d = Math.hypot(m.x - b.x, m.y - b.y);
    const reach = m.gk ? 1.4 : 0.95 + m.dri / 500;
    if (b.z < 1.0 && d < reach) {
      const spd = Math.hypot(b.vx, b.vy);
      // fast balls are harder to control
      const ctrl = spd < 13 ? 1 : clamp(1 - (spd - 13) / 22 + m.dri / 250, 0.15, 1);
      if (Math.random() < ctrl * (m.side === b.last?.side ? 1 : 0.7) * Math.min(1, dt * 60)) { if (d < bd) { bd = d; best = m; } }
    } else if (b.z >= 1.0 && b.z < 2.7 && d < 1.15 && !m.gk && !(m.team.user && m === s.ctrl && (s.inp.shoot || s.inp.pass))) {
      aiHeader(s, m); return;
    }
  }
  if (best) {
    // track reception: counts as completed pass if from teammate
    if (b.last && b.last.side !== best.side) { b.prev = null; }
    giveBall(s, best);
    if (best.gk && b.shot === null) { }
  }
  // shot evaluation for goalkeeper saves
  if (b.shot && !b.shotEval) gkSaveCheck(s);
}
function aiHeader(s, m) {
  const b = s.ball, team = m.team, gx = goalX(team);
  const d = Math.abs(gx - m.x);
  if (d < 16 && Math.abs(m.y - PH / 2) < 14) { shoot(s, m, 0.5, null, false, 'header'); m.label = 'Header'; m.labelT = 1; }
  else {
    // defensive header / header pass forward
    const ang = Math.atan2((PH / 2 - m.y) * 0.3, team.dir) + R.range(-0.6, 0.6);
    kick(s, m, Math.cos(ang) * 13, Math.sin(ang) * 13, 4.5, 'pass');
  }
}
function gkSaveCheck(s) {
  const b = s.ball, sh = b.shot;
  const defT = enemy(s, sh.side), gk = defT.players.find(m => m.gk);
  const gl = ownGoalX(defT);
  if (!gk || Math.sign(b.vx) !== (gl > PW / 2 ? 1 : -1) || Math.abs(b.vx) < 1) { if (Math.abs(b.vx) < 1) b.shotEval = true; return; }
  const t = (gl - b.x) / b.vx;
  if (t > 0.75 || t < 0) return;
  b.shotEval = true;
  // predict crossing point
  const cy = b.y + b.vy * t + (b.spin ? 0 : 0), cz = Math.max(0, b.z + b.vz * t - 0.5 * G * t * t);
  const onTarget = cy > GY0 && cy < GY1 && cz < GOAL_H;
  if (onTarget) s.stats.sot[sideIdx(sh.side)]++;
  else { if (Math.random() < 0.6) Audio2.sfx('ooh'); return; }
  // reach: distance the keeper must cover to the crossing point (at his depth)
  const committed = gk.dive && s.sp === null && s._penKick;
  const gkY = committed ? gk.y + gk.dive.vy * Math.min(t, gk.dive.t) : gk.y;
  const reachY = Math.abs(cy - gkY), reachZ = Math.max(0, cz - 1.6);
  const reach = Math.hypot(reachY, reachZ);
  const time = Math.max(0.12, t);
  const gkr = gk.gkr * (defT.user ? 1 : 0.92 + s.ai * 0.1);
  const speed = Math.hypot(b.vx, b.vy);
  let p = gkr / 100 * 1.15 - reach * 0.17 - (speed - 18) * 0.012 + time * 0.35 - (sh.outside ? -0.08 : 0);
  if (reach < 0.8) p += 0.25;
  p = clamp(p, 0.04, 0.95);
  const save = Math.random() < p;
  // dive animation toward crossing point
  const dy = cy - gk.y;
  if (committed) { s._penKick = false; }
  else if (Math.abs(dy) > 0.6) gk.dive = { vx: (gl > PW / 2 ? -0.5 : 0.5), vy: clamp(dy / time, -9, 9) * (save ? 1 : 0.7), t: Math.min(0.55, time + 0.15), dir: Math.sign(dy), hi: cz > 1.3 };
  else if (!committed) gk.dive = { vx: 0, vy: 0, t: 0.35, dir: 0, hi: cz > 1.3 };
  if (save) {
    const catchIt = speed < 21 && Math.random() < 0.5 + gkr / 300;
    s._pendingSave = { gk, t: time, catchIt };
  }
}
function resolvePendingSave(s, dt) {
  const ps = s._pendingSave; if (!ps) return;
  ps.t -= dt;
  if (ps.t > 0.02) return;
  s._pendingSave = null;
  const b = s.ball, gk = ps.gk;
  if (b.owner || !b.shot) return;
  if (ps.catchIt) { gk.dive = null; giveBall(s, gk); msg(s, `Save! ${shortName(gk.p.name)}`, 1.6); }
  else {
    // parry: deflect away from goal, possibly out for a corner
    const dir = gk.team.dir;
    b.vx = dir * R.range(4, 10); b.vy = (b.y < PH / 2 ? -1 : 1) * R.range(4, 11); b.vz = R.range(1, 4); b.last = gk; b.shot = null; b.spin = 0;
    msg(s, `Great save by ${shortName(gk.p.name)}!`, 1.8);
  }
  Audio2.sfx('ooh');
}
function checkGoalAndOut(s) {
  resolvePendingSave(s, 1 / 60);
  const b = s.ball;
  // posts & crossbar
  for (const gx of [0, PW]) {
    if ((gx === 0 && b.x < 0.3 && b.vx < 0) || (gx === PW && b.x > PW - 0.3 && b.vx > 0)) {
      const nearPost = Math.min(Math.abs(b.y - GY0), Math.abs(b.y - GY1)) < 0.18 && b.z < GOAL_H;
      const bar = b.y > GY0 && b.y < GY1 && Math.abs(b.z - GOAL_H) < 0.14;
      if (nearPost || bar) { b.vx = -b.vx * 0.6; if (bar) b.vz = -Math.abs(b.vz) * 0.5; b.x = gx === 0 ? 0.35 : PW - 0.35; Audio2.sfx('post'); msg(s, bar ? 'Off the crossbar!' : 'Off the post!', 1.6); b.shot = null; return; }
    }
  }
  if (b.x < 0 || b.x > PW) {
    const gx = b.x < 0 ? 0 : PW;
    if (b.y > GY0 && b.y < GY1 && b.z < GOAL_H) return scoreGoal(s, gx);
    // out over the goal line
    const defT = ownGoalX(s.teams.home) === gx ? s.teams.home : s.teams.away;
    const lastSide = b.last ? b.last.side : null;
    if (lastSide === defT.side) { s.pendingSP = { type: 'corner', side: other(defT.side), x: gx === 0 ? 0.5 : PW - 0.5, y: b.y < PH / 2 ? 0.5 : PH - 0.5 }; s.stats.corners[sideIdx(other(defT.side))]++; }
    else s.pendingSP = { type: 'goalkick', side: defT.side, x: gx === 0 ? 5.5 : PW - 5.5, y: b.y < PH / 2 ? PH / 2 - 9 : PH / 2 + 9 };
    b.shot = null; s.state = 'out'; s.stateT = 0; b.owner = null;
    if (s.pendingSP.type === 'corner') msg(s, 'Corner', 1.2); else msg(s, 'Goal kick', 1.2);
    return;
  }
  if (b.y < 0 || b.y > PH) {
    const side = b.last ? other(b.last.side) : 'home';
    s.pendingSP = { type: 'throwin', side, x: clamp(b.x, 1, PW - 1), y: b.y < 0 ? 0 : PH };
    b.shot = null; s.state = 'out'; s.stateT = 0.3; b.owner = null; msg(s, 'Throw-in', 1.1);
  }
}
function scoreGoal(s, gx) {
  const b = s.ball;
  const scoringTeam = goalX(s.teams.home) === gx ? s.teams.home : s.teams.away;
  const scorer = b.last;
  const og = scorer && scorer.side !== scoringTeam.side;
  // friendly rule variants
  if (s.rules === 'headers' && !(b.shot && b.shot.air) && !og) {
    msg(s, 'Goal disallowed — headers & volleys only!', 2.4); Audio2.sfx('whistle');
    s.pendingSP = { type: 'goalkick', side: other(scoringTeam.side), x: gx === 0 ? 5.5 : PW - 5.5, y: PH / 2 }; s.state = 'out'; s.stateT = 0; b.owner = null; return;
  }
  let value = 1;
  if (s.rules === 'longshot' && b.shot && b.shot.outside && !og) value = 2;
  s.score[scoringTeam.side] += value;
  const assist = !og && b.prev && b.prev.side === scoringTeam.side && b.prev !== scorer ? b.prev : null;
  const min = Math.min(45, Math.floor(s.clock / s.halfSecs * 45)) + (s.half - 1) * 45 + 1;
  for (let i = 0; i < value; i++) s.goals.push({ side: scoringTeam.side, pid: scorer?.p.id, name: scorer ? scorer.p.name : 'Unknown', pos: scorer?.slotPos, min, assist: assist ? assist.p.name : null, og });
  s.lastGoalSide = scoringTeam.side; s.state = 'goal'; s.stateT = 0; s.celebrant = og ? null : scorer;
  b.vx *= 0.15; b.vy *= 0.15; b.shot = null;
  Audio2.sfx('net'); Audio2.sfx('goalcrowd'); Audio2.sfx('whistle'); Audio2.crowdLevel(1);
  banner(s, value === 2 ? 'Double!' : 'Goal!', `${scorer ? shortName(scorer.p.name) : ''} ${min}'${og ? ' (OG)' : ''}${assist ? ' · assist ' + shortName(assist.p.name) : ''}`, 3.6);
  s.fx.push({ type: 'confetti', t: 3.5, x: gx, y: PH / 2 });
}
function celebrate(s, dt) {
  const c = s.celebrant;
  const corner = { x: c ? (c.team.dir > 0 ? PW - 2 : 2) : PW / 2, y: c && c.y < PH / 2 ? 3 : PH - 3 };
  for (const m of s.all) {
    m.stun = 0;
    if (c && m === c) steer(m, corner.x, corner.y, true, dt);
    else if (c && m.side === c.side && !m.gk) steer(m, corner.x - c.team.dir * (2 + (m.slot % 4)), corner.y + ((m.slot % 3) - 1) * 2, s.stateT > 0.6, dt);
    else steer(m, m.x, m.y, false, dt);
  }
  simPlayers(s, dt, false);
}
function updateRef(s, dt) {
  const r = s.ref, b = s.ball;
  const tx = b.x - 6, ty = b.y + (b.y < PH / 2 ? 9 : -9);
  const dx = tx - r.x, dy = ty - r.y, d = Math.hypot(dx, dy);
  const v = Math.min(6, d * 0.9);
  r.vx = lerp(r.vx, d > 0.1 ? dx / d * v : 0, 0.05); r.vy = lerp(r.vy, d > 0.1 ? dy / d * v : 0, 0.05);
  r.x += r.vx * dt; r.y += r.vy * dt; r.ph += Math.hypot(r.vx, r.vy) * dt * 1.7;
}

/* ------------------------- set pieces ------------------------- */
function startSetPiece(s, sp) {
  const b = s.ball, team = s.teams[sp.side], foe = enemy(s, sp.side);
  s.state = 'setpiece'; s.stateT = 0; s.sp = sp;
  Object.assign(b, { x: sp.x, y: sp.y, z: 0, vx: 0, vy: 0, vz: 0, owner: null, shot: null, spin: 0 });
  // reset intents
  for (const m of s.all) { m._target = null; m.run = null; m.dive = null; m.sliding = 0; }
  let taker;
  if (sp.type === 'goalkick') taker = team.players.find(m => m.gk);
  else if (sp.type === 'penalty') taker = team.players.slice().sort((a, b) => b.sho - a.sho)[0];
  else taker = nearestTo(team.players.filter(m => !m.gk), sp.x, sp.y);
  sp.taker = taker;
  taker.x = sp.x - (sp.type === 'throwin' ? 0 : team.dir * 0.6); taker.y = sp.y + (sp.type === 'throwin' ? (sp.y < 1 ? -0.4 : 0.4) : 0); taker.vx = taker.vy = 0;
  // arrange players
  const gx = goalX(team), og = ownGoalX(team);
  const boxSpots = (n, attX, spread) => Array.from({ length: n }, (_, i) => ({ x: attX - team.dir * R.range(4, 12), y: PH / 2 + (i - (n - 1) / 2) * spread + R.range(-1, 1) }));
  if (sp.type === 'corner' || (sp.type === 'freekick' && Math.abs(gx - sp.x) < 35)) {
    const atk = team.players.filter(m => m !== taker && !m.gk).sort((a, b) => b.p.height - a.p.height);
    const spots = boxSpots(5, gx, 3.2);
    atk.forEach((m, i) => { m._target = spots[i] || homeSpot(s, m); if (i < 5) { m.x = m._target.x; m.y = m._target.y; } });
    const def = foe.players.filter(m => !m.gk);
    def.forEach((m, i) => { const mk = atk[i % 5]; m._target = mk ? { x: mk.x + team.dir * 0.8, y: mk.y + 0.6 } : homeSpot(s, m); m.x = m._target.x; m.y = m._target.y; });
    if (sp.type === 'freekick') { // wall
      const dx = gx - sp.x, dy = PH / 2 - sp.y, dl = Math.hypot(dx, dy) || 1;
      def.slice(0, 3).forEach((m, i) => { m.x = sp.x + dx / dl * 9.15 + (-dy / dl) * (i - 1) * 0.8; m.y = sp.y + dy / dl * 9.15 + (dx / dl) * (i - 1) * 0.8; m._target = { x: m.x, y: m.y }; });
    }
  } else if (sp.type === 'penalty') {
    for (const m of s.all) { if (m === taker || m.gk) continue; m.x = clamp(gx - team.dir * R.range(18, 24), 1, PW - 1); m.y = PH / 2 + R.range(-18, 18); m._target = { x: m.x, y: m.y }; }
    const k = foe.players.find(m => m.gk); k.x = gx - team.dir * 0.3; k.y = PH / 2;
    taker.x = sp.x - team.dir * 1.2; taker.y = PH / 2;
  } else {
    for (const m of s.all) if (m !== taker) { const h2 = homeSpot(s, m); m._target = h2; }
    if (sp.type === 'throwin' || sp.type === 'freekick') {
      const near = team.players.filter(m => m !== taker && !m.gk).sort((a, b) => Math.hypot(a.x - sp.x, a.y - sp.y) - Math.hypot(b.x - sp.x, b.y - sp.y)).slice(0, 2);
      near.forEach((m, i) => { m._target = { x: clamp(sp.x + (i ? -1 : 1) * 7 + team.dir * 3, 2, PW - 2), y: clamp(sp.y + (sp.y < PH / 2 ? 1 : -1) * (6 + i * 5), 2, PH - 2) }; });
    }
  }
  b.x = sp.x; b.y = sp.y;
  if (team.user) switchTo(s, taker);
  sp.ready = 0;
  if (sp.type === 'goalkick') giveBall(s, taker);
  const names = { corner: 'Corner kick', throwin: 'Throw-in', goalkick: 'Goal kick', freekick: 'Free kick', penalty: 'Penalty kick' };
  if (team.user && sp.type !== 'goalkick') msg(s, `${names[sp.type]} — ${sp.type === 'penalty' ? 'aim with ↑/↓, hold K to shoot' : sp.type === 'freekick' && Math.abs(gx - sp.x) < 32 ? 'J pass · L cross · K shoot' : sp.type === 'corner' ? 'aim, then L to cross or J short' : 'aim and press J / L'}`, 3.2);
  else if (foe.user && sp.type === 'penalty') msg(s, 'Penalty against you — hold ↑ or ↓ to choose your dive', 3);
}
function updateSetPiece(s, dt) {
  const sp = s.sp, b = s.ball, team = s.teams[sp.side], taker = sp.taker;
  // hold ball at spot with taker
  if (sp.type !== 'goalkick') { b.owner = null; b.x = sp.x; b.y = sp.y; b.z = 0; b.vx = b.vy = 0; }
  taker.vx = taker.vy = 0; taker._spMove = true;
  // face toward attack/goal
  const gx = goalX(team);
  taker.face = Math.atan2(PH / 2 - taker.y, gx - taker.x);
  if (sp.type === 'throwin') taker.face = Math.atan2((PH / 2 - sp.y), team.dir * 2);
  s.ref.x = lerp(s.ref.x, sp.x - 8, 0.02); s.ref.y = lerp(s.ref.y, clamp(sp.y, 8, PH - 8), 0.02);
  const userTaking = team.user && s.ctrl === taker;
  const userDefPen = sp.type === 'penalty' && enemy(s, sp.side).user;
  if (sp.type === 'kickoff') { if (s.stateT < 0.6) return; }
  if (s.stateT < 0.8) return;
  const I = s.inp || {}, E = s.edge || {};
  const finishSP = () => { taker._spMove = false; for (const m of s.all) m._target = null; s.state = 'play'; s.stateT = 0; s.sp = null; };
  const doIt = (fn) => { fn(); finishSP(); };
  if (userTaking) {
    const mag = Math.hypot(I.x || 0, I.y || 0);
    const ax = mag > 0.2 ? I.x / mag : Math.cos(taker.face), ay = mag > 0.2 ? I.y / mag : Math.sin(taker.face);
    sp.aim = { x: ax, y: ay };
    const kickTake = () => { b.owner = taker; };
    if (sp.type === 'penalty' || (sp.type === 'freekick' && Math.abs(gx - sp.x) < 32)) {
      if (I.shoot || I.finesse) { s.charge = Math.min(1, s.charge + dt * 1.1); s.chargeKind = I.finesse ? 'finesse' : 'shot'; }
      if (s.rel.shoot || s.rel.finesse) {
        const aim = Math.abs(I.y || 0) > 0.3 ? ((I.y < 0) ? GY0 + 0.7 : GY1 - 0.7) : (sp.type === 'penalty' ? PH / 2 + R.range(-0.8, 0.8) : (sp.y < PH / 2 ? GY0 + 1 : GY1 - 1));
        const pw = s.charge, fin = s.chargeKind === 'finesse';
        s.charge = 0; s.chargeKind = null;
        return doIt(() => { kickTake(); shoot(s, taker, sp.type === 'penalty' ? Math.min(pw, 0.85) : pw, aim, fin); if (sp.type === 'penalty') penaltyKeeper(s, sp); });
      }
    }
    if (E.pass || E.lob || E.through) {
      const kind = E.lob ? (sp.type === 'corner' || inCrossZone(s, taker) ? 'cross' : 'lob') : E.through ? 'through' : 'ground';
      const tgt = pickPassTarget(s, taker, ax, ay, kind) || nearestTo(team.players.filter(m => m !== taker && !m.gk), sp.x, sp.y);
      return doIt(() => { kickTake(); if (sp.type === 'throwin') throwIn(s, taker, tgt, kind); else passTo(s, taker, tgt, kind); if (sp.type === 'corner') s.stats.passes[sideIdx(taker.side)]; });
    }
    if (sp.type === 'goalkick' && s.stateT > 6) return doIt(() => { const tgt = nearestTo(team.players.filter(m => !m.gk), taker.x + team.dir * 30, PH / 2); passTo(s, taker, tgt, 'lob'); });
    return;
  }
  // penalty vs user keeper: dive choice
  if (userDefPen) { const y = I.y || 0; sp.userDive = Math.abs(y) > 0.3 ? Math.sign(y) : 0; }
  // AI taker
  if (s.stateT < (sp.type === 'penalty' ? 2.2 : 1.4)) return;
  doIt(() => {
    if (sp.type === 'goalkick') { const mates = team.players.filter(m => !m.gk); const tgt = R.chance(0.5) ? nearestTo(mates, taker.x + team.dir * 18, R.pick([12, PH - 12])) : nearestTo(mates, taker.x + team.dir * 40, PH / 2); passTo(s, taker, tgt, Math.hypot(tgt.x - taker.x, tgt.y - taker.y) > 26 ? 'lob' : 'ground'); return; }
    b.owner = taker;
    if (sp.type === 'penalty') { const side = R.pick([-1, 0, 1]); const aim = side === 0 ? PH / 2 + R.range(-0.6, 0.6) : side < 0 ? GY0 + R.range(0.5, 1.2) : GY1 - R.range(0.5, 1.2); shoot(s, taker, R.range(0.5, 0.78), aim, false); penaltyKeeper(s, sp); return; }
    if (sp.type === 'freekick' && Math.abs(gx - sp.x) < 28 && Math.random() < 0.6) { shoot(s, taker, R.range(0.55, 0.8), R.chance(0.5) ? GY0 + 0.8 : GY1 - 0.8, true); return; }
    if (sp.type === 'corner') { const tgt = team.players.filter(m => m !== taker && !m.gk).sort((a, b) => Math.hypot(a.x - gx, a.y - PH / 2) - Math.hypot(b.x - gx, b.y - PH / 2))[R.int(0, 2)]; passTo(s, taker, tgt, Math.random() < 0.85 ? 'cross' : 'ground'); return; }
    const tgt = nearestTo(team.players.filter(m => m !== taker && !m.gk), sp.x + team.dir * 8, sp.y);
    if (sp.type === 'throwin') throwIn(s, taker, tgt, 'ground'); else passTo(s, taker, tgt, Math.hypot(tgt.x - taker.x, tgt.y - taker.y) > 26 ? 'lob' : 'ground');
  });
}
function throwIn(s, m, tgt, kind) {
  const b = s.ball, dx = tgt.x - b.x, dy = tgt.y - b.y, d = Math.hypot(dx, dy) || 1;
  const v = clamp(6 + d * 0.5, 7, kind === 'lob' ? 17 : 13);
  b.z = 1.8; kick(s, m, dx / d * v, dy / d * v, 2.5, 'pass'); s.stats.passes[sideIdx(m.side)]++;
}
function penaltyKeeper(s, sp) {
  // keeper commits to a side at the moment of the kick
  const defT = enemy(s, sp.side), gk = defT.players.find(m => m.gk); if (!gk) return;
  const dir = defT.user ? (sp.userDive ?? 0) : R.weighted([{ w: 4, v: -1 }, { w: 2, v: 0 }, { w: 4, v: 1 }]);
  gk.dive = { vx: 0, vy: dir * 7.5, t: 0.42, dir, hi: false };
  s._penKick = true;
  s.ball.shotEval = false;
}

/* ------------------------- results ------------------------- */
function buildResult(s) {
  const tot = s.stats.poss[0] + s.stats.poss[1] || 1;
  const st = JSON.parse(JSON.stringify(s.stats));
  st.poss = [Math.round(s.stats.poss[0] / tot * 100), 100 - Math.round(s.stats.poss[0] / tot * 100)];
  let winner = s.score.home > s.score.away ? 'home' : s.score.away > s.score.home ? 'away' : null, pens = null;
  if (!winner && s.cfg.knockout) {
    // penalty shootout (resolved from shooter/keeper ratings)
    const take = (shooters, gk) => { const sh = shooters[Math.floor(Math.random() * shooters.length)]; return Math.random() < clamp(0.72 + (sh.sho - gk.gkr) / 200, 0.5, 0.92); };
    const H = s.teams.home.players.filter(m => !m.gk).sort((a, b) => b.sho - a.sho).slice(0, 5), A = s.teams.away.players.filter(m => !m.gk).sort((a, b) => b.sho - a.sho).slice(0, 5);
    const gh = s.teams.home.players.find(m => m.gk) || H[0], ga = s.teams.away.players.find(m => m.gk) || A[0];
    let h = 0, a = 0, i = 0;
    for (; i < 5; i++) { if (take(H, ga)) h++; if (take(A, gh)) a++; }
    while (h === a && i < 20) { if (take(H, ga)) h++; if (take(A, gh)) a++; i++; }
    if (h === a) h++;
    pens = [h, a]; winner = h > a ? 'home' : 'away';
  }
  return { home: s.cfg.home, away: s.cfg.away, hg: s.score.home, ag: s.score.away, goals: s.goals, stats: st, winner, pens, userSide: s.userSide, mode: s.cfg.mode };
}
