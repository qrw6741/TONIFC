/* ============================================================
   SYSTEMS / FORMATIONS, CHEMISTRY, SQUADS, CLUB
   Coordinates: x 0..100 (left→right), y 0..100 (own goal=100 → attack=0)
   ============================================================ */
const FORMATIONS = {
  '4-3-3': [['GK', 50, 92], ['LB', 14, 72], ['CB', 37, 76], ['CB', 63, 76], ['RB', 86, 72], ['CM', 30, 52], ['CM', 50, 56], ['CM', 70, 52], ['LW', 18, 24], ['ST', 50, 18], ['RW', 82, 24]],
  '4-2-3-1': [['GK', 50, 92], ['LB', 14, 72], ['CB', 37, 76], ['CB', 63, 76], ['RB', 86, 72], ['CDM', 37, 58], ['CDM', 63, 58], ['LM', 16, 38], ['CAM', 50, 38], ['RM', 84, 38], ['ST', 50, 16]],
  '4-4-2': [['GK', 50, 92], ['LB', 14, 72], ['CB', 37, 76], ['CB', 63, 76], ['RB', 86, 72], ['LM', 14, 46], ['CM', 38, 50], ['CM', 62, 50], ['RM', 86, 46], ['ST', 38, 18], ['ST', 62, 18]],
  '4-1-2-1-2': [['GK', 50, 92], ['LB', 14, 72], ['CB', 37, 76], ['CB', 63, 76], ['RB', 86, 72], ['CDM', 50, 60], ['CM', 28, 48], ['CM', 72, 48], ['CAM', 50, 36], ['ST', 38, 17], ['ST', 62, 17]],
  '3-5-2': [['GK', 50, 92], ['CB', 28, 75], ['CB', 50, 78], ['CB', 72, 75], ['CDM', 38, 58], ['CDM', 62, 58], ['LM', 12, 44], ['CAM', 50, 38], ['RM', 88, 44], ['ST', 38, 17], ['ST', 62, 17]],
  '4-2-2-2': [['GK', 50, 92], ['LB', 14, 72], ['CB', 37, 76], ['CB', 63, 76], ['RB', 86, 72], ['CDM', 37, 58], ['CDM', 63, 58], ['CAM', 24, 36], ['CAM', 76, 36], ['ST', 38, 17], ['ST', 62, 17]],
  '5-3-2': [['GK', 50, 92], ['LWB', 10, 64], ['CB', 30, 76], ['CB', 50, 78], ['CB', 70, 76], ['RWB', 90, 64], ['CM', 30, 50], ['CM', 50, 54], ['CM', 70, 50], ['ST', 38, 18], ['ST', 62, 18]],
  '3-4-3': [['GK', 50, 92], ['CB', 28, 75], ['CB', 50, 78], ['CB', 72, 75], ['LM', 12, 50], ['CM', 38, 54], ['CM', 62, 54], ['RM', 88, 50], ['LW', 20, 24], ['ST', 50, 17], ['RW', 80, 24]]
};
const FORMATION_NAMES = Object.keys(FORMATIONS);

/* chemistry links between adjacent slots (nearest neighbours) */
const _linkCache = {};
function formationLinks(f) {
  if (_linkCache[f]) return _linkCache[f];
  const pos = FORMATIONS[f], links = new Set();
  pos.forEach((a, i) => {
    const near = pos.map((b, j) => ({ j, d: j === i ? 1e9 : Math.hypot(a[1] - b[1], (a[2] - b[2]) * 1.25) })).sort((x, y) => x.d - y.d);
    const k = a[0] === 'GK' ? 2 : 3;
    near.slice(0, k).forEach(nb => { if (nb.d < 45) links.add(i < nb.j ? `${i}-${nb.j}` : `${nb.j}-${i}`); });
  });
  return (_linkCache[f] = [...links].map(s => s.split('-').map(Number)));
}

function playerFitsPos(p, pos) { return p.pos === pos || (p.alt || []).includes(pos); }

/* Chemistry (0-3 per player, 33 max). Club/nation/league counts across the XI.
   Icons: +1 extra nation weight and count for every league. Heroes: double league weight.
   A player out of position gets 0 chemistry (but still contributes to others). */
function computeChemistry(formation, players /* array[11] of P or null */) {
  const club = {}, nat = {}, lg = {};
  const valid = players.map((p, i) => p ? { p, i } : null).filter(Boolean);
  valid.forEach(({ p }) => {
    if (p.club !== 'ICN' && p.club !== 'HER') club[p.club] = (club[p.club] || 0) + 1;
    nat[p.nat] = (nat[p.nat] || 0) + (p.type === 'icon' ? 2 : 1);
    if (p.type === 'hero') lg[p.lg] = (lg[p.lg] || 0) + 2;
    else if (p.type !== 'icon') lg[p.lg] = (lg[p.lg] || 0) + 1;
  });
  const iconCount = valid.filter(v => v.p.type === 'icon').length;
  const thr = (n, t) => n >= t[2] ? 3 : n >= t[1] ? 2 : n >= t[0] ? 1 : 0;
  const per = players.map((p, i) => {
    if (!p) return 0;
    const slotPos = FORMATIONS[formation][i][0];
    if (!playerFitsPos(p, slotPos)) return 0;
    if (p.type === 'icon' || p.type === 'hero') return 3;
    let c = 0;
    c += thr(club[p.club] || 0, [2, 5, 7]);
    c += thr(nat[p.nat] || 0, [2, 5, 8]);
    c += thr((lg[p.lg] || 0) + iconCount, [3, 5, 8]);
    return Math.min(3, c);
  });
  const links = formationLinks(formation).map(([a, b]) => {
    const A = players[a], B = players[b];
    if (!A || !B) return { a, b, q: 'none' };
    let s = 0;
    if (A.club === B.club && A.club !== 'ICN' && A.club !== 'HER') s += 2;
    if (A.nat === B.nat) s += 1;
    if (A.lg === B.lg || A.type === 'icon' || B.type === 'icon') s += 1;
    return { a, b, q: s >= 2 ? 'green' : s === 1 ? 'yellow' : 'red' };
  });
  return { per, total: per.reduce((x, y) => x + y, 0), links };
}

function squadRating(players) {
  const r = players.filter(Boolean).map(p => p.ovr);
  while (r.length < 11) r.push(0);
  const avg = r.reduce((a, b) => a + b, 0) / 11;
  const corr = r.reduce((s, x) => s + (x > avg ? x - avg : 0), 0);
  return Math.min(99, Math.floor((r.reduce((a, b) => a + b, 0) + corr) / 11));
}

/* team strength used by the match engine/simulation: attack/mid/def from slot positions */
function teamStrength(formation, players, chem) {
  const g = { ATT: [], MID: [], DEF: [], GK: [] };
  players.forEach((p, i) => {
    if (!p) return;
    const pos = FORMATIONS[formation][i][0];
    const c = chem ? chem.per[i] : 3;
    const eff = p.ovr - (playerFitsPos(p, pos) ? 0 : 6) + (c - 1.5) * 1.2;
    g[POS_GROUP[pos]].push(eff);
  });
  const av = a => a.length ? a.reduce((x, y) => x + y, 0) / a.length : 40;
  return { att: av(g.ATT), mid: av(g.MID), def: av(g.DEF), gk: av(g.GK) };
}

/* ---------------- Club (owned items) ---------------- */
const Club = {
  items() { return Save.data.club.items; },
  get(uid) { return Save.data.club.items.find(i => i.uid === uid); },
  player(uid) { const it = this.get(uid); return it ? P(it.pid) : null; },
  add(pid, untr = true, source = '') {
    const it = { uid: uid(), pid, untr, at: Date.now(), src: source };
    Save.data.club.items.push(it); Save.dirty(); return it;
  },
  remove(uidv) {
    const d = Save.data;
    d.club.items = d.club.items.filter(i => i.uid !== uidv);
    // remove from all squads
    d.squads.forEach(s => {
      s.slots = s.slots.map(u => u === uidv ? null : u);
      s.subs = s.subs.map(u => u === uidv ? null : u);
      if (s.captain === uidv) s.captain = null;
    });
    Save.dirty();
  },
  ownsPid(pid) { return Save.data.club.items.some(i => i.pid === pid); },
  inSquadAnywhere(uidv) { return Save.data.squads.some(s => s.slots.includes(uidv) || s.subs.includes(uidv)); },
  inActiveSquad(uidv) { const s = Squads.active(); return s && (s.slots.includes(uidv) || s.subs.includes(uidv)); },
  duplicates() {
    const seen = {}, dups = [];
    for (const it of Save.data.club.items) { (seen[it.pid] = seen[it.pid] || []).push(it); }
    for (const k in seen) if (seen[k].length > 1) dups.push(...seen[k].slice(1));
    return dups;
  },
  inMarket(uidv) { return Save.data.market.mine.some(l => l.uid === uidv && l.status === 'active'); }
};

const Squads = {
  active() { return Save.data.squads[Save.data.activeSquad] || Save.data.squads[0]; },
  players(s) { return s.slots.map(u => u ? Club.player(u) : null); },
  create(name, formation = '4-3-3') {
    const s = { id: uid(), name, formation, slots: Array(11).fill(null), subs: Array(7).fill(null), captain: null };
    Save.data.squads.push(s); Save.dirty(); return s;
  },
  info(s) {
    const ps = this.players(s);
    const chem = computeChemistry(s.formation, ps);
    return { players: ps, chem, rating: squadRating(ps), filled: ps.filter(Boolean).length };
  },
  /* auto-build the best XI for formation from club (greedy by fit+rating, chem-aware second pass) */
  autoBuild(s, pool) {
    const items = (pool || Save.data.club.items).filter(it => !Club.inMarket(it.uid));
    const used = new Set(), usedPids = new Set();
    const slots = FORMATIONS[s.formation].map(f => f[0]);
    const order = slots.map((pos, i) => i).sort((a, b) => (slots[a] === 'GK' ? -1 : 0) - (slots[b] === 'GK' ? -1 : 0));
    const res = Array(11).fill(null);
    for (const i of order) {
      const pos = slots[i];
      let best = null, bs = -1;
      for (const it of items) {
        if (used.has(it.uid)) continue;
        const p = P(it.pid);
        if (usedPids.has(p.id)) continue;
        const sc = p.ovr + (p.pos === pos ? 12 : playerFitsPos(p, pos) ? 8 : (pos === 'GK' || p.pos === 'GK') ? -99 : -10);
        if (sc > bs) { bs = sc; best = it; }
      }
      if (best) { res[i] = best.uid; used.add(best.uid); usedPids.add(best.pid); }
    }
    s.slots = res;
    // subs: best remaining
    const rem = items.filter(it => !used.has(it.uid)).sort((a, b) => P(b.pid).ovr - P(a.pid).ovr);
    const subs = [];
    const gk = rem.find(it => P(it.pid).pos === 'GK');
    if (gk) subs.push(gk.uid);
    for (const it of rem) { if (subs.length >= 7) break; if (!subs.includes(it.uid)) subs.push(it.uid); }
    while (subs.length < 7) subs.push(null);
    s.subs = subs;
    // captain: highest rated
    const ps = s.slots.filter(Boolean);
    s.captain = ps.sort((a, b) => (Club.player(b)?.ovr || 0) - (Club.player(a)?.ovr || 0))[0] || null;
    Save.dirty();
  },
  isComplete(s) { return s.slots.every(Boolean); }
};

/* Build an AI opponent squad from the database. strength = target overall */
function buildAISquad(strength, opts = {}) {
  const formation = opts.formation || R.pick(FORMATION_NAMES);
  const slots = FORMATIONS[formation].map(f => f[0]);
  let pool = DB.players.filter(p => p.type === 'base' || (strength >= 84 && R.chance(0.3)));
  if (opts.league) pool = pool.filter(p => p.lg === opts.league);
  if (opts.club) pool = DB.byClub[opts.club].filter(p => p.type === 'base');
  const used = new Set();
  const players = slots.map(pos => {
    const cands = pool.filter(p => !used.has(p.id) && playerFitsPos(p, pos));
    let best = null, bd = 1e9;
    for (const c of R.shuffle(cands).slice(0, 220)) {
      const d = Math.abs(c.ovr - (strength + R.range(-3, 3)));
      if (d < bd) { bd = d; best = c; }
    }
    if (!best) best = R.pick(pool.filter(p => !used.has(p.id)));
    used.add(best.id); return best;
  });
  const subs = R.shuffle(pool.filter(p => !used.has(p.id) && Math.abs(p.ovr - strength) < 6)).slice(0, 7);
  return { formation, players, subs };
}
