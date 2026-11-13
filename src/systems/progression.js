/* ============================================================
   SYSTEMS / OBJECTIVES, SBC, COMPETITIONS (rewards & progression)
   ============================================================ */
function dayKey(t = Date.now()) { const d = new Date(t); return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`; }
function weekKey(t = Date.now()) { const d = new Date(t); const onejan = new Date(d.getFullYear(), 0, 1); return `${d.getFullYear()}-W${Math.ceil(((d - onejan) / 86400000 + onejan.getDay() + 1) / 7)}`; }
function msToReset(kind) {
  const now = new Date();
  if (kind === 'daily') { const t = new Date(now); t.setHours(24, 0, 0, 0); return t - now; }
  const t = new Date(now); t.setDate(t.getDate() + ((8 - t.getDay()) % 7 || 7)); t.setHours(0, 0, 0, 0); return t - now;
}

const OBJECTIVES = [
  // daily
  { id: 'd_play', cat: 'daily', title: 'Get Your Boots On', desc: 'Play 1 match in any Ultimate XI mode', ev: 'match', target: 1, reward: { coins: 500, xp: 150 } },
  { id: 'd_goals', cat: 'daily', title: 'Daily Finisher', desc: 'Score 3 goals in any mode', ev: 'goal', target: 3, reward: { coins: 750, xp: 200 } },
  { id: 'd_win', cat: 'daily', title: 'Daily Winner', desc: 'Win 1 match', ev: 'win', target: 1, reward: { pack: 'gold', xp: 200 } },
  { id: 'd_pack', cat: 'daily', title: 'Pack Opener', desc: 'Open 1 pack', ev: 'pack', target: 1, reward: { coins: 300, xp: 100 } },
  // weekly
  { id: 'w_goals', cat: 'weekly', title: 'Score 10 Goals', desc: 'Score 10 goals in Ultimate XI matches', ev: 'goal', target: 10, reward: { pack: 'premium', xp: 600 } },
  { id: 'w_wins', cat: 'weekly', title: 'Win 5 Matches', desc: 'Win 5 matches in any mode', ev: 'win', target: 5, reward: { coins: 5000, xp: 800 } },
  { id: 'w_assists', cat: 'weekly', title: 'Playmaker', desc: 'Assist 5 goals', ev: 'assist', target: 5, reward: { coins: 3000, xp: 500 } },
  { id: 'w_league3', cat: 'weekly', title: 'League Loyalty', desc: 'Play a match using 3+ players from the same league', ev: 'league3', target: 1, reward: { coins: 2000, xp: 300 } },
  { id: 'w_mid', cat: 'weekly', title: 'Midfield Maestro', desc: 'Score with a midfielder', ev: 'goal_mid', target: 1, reward: { coins: 1500, xp: 300 } },
  { id: 'w_sb', cat: 'weekly', title: 'Battle Ready', desc: 'Win 3 Squad Battles matches', ev: 'sb_win', target: 3, reward: { pack: 'jumbo', xp: 800 } },
  { id: 'w_market', cat: 'weekly', title: 'Market Mover', desc: 'Buy 3 players on the Transfer Market', ev: 'buy', target: 3, reward: { coins: 1500, xp: 300 } },
  // season (rewards Foundations players)
  { id: 's_wins', cat: 'season', title: 'Season Grind', desc: 'Win 15 matches this season', ev: 'win', target: 15, reward: { pack: 'found', xp: 2000 } },
  { id: 's_goals', cat: 'season', title: 'Goal Machine', desc: 'Score 40 goals', ev: 'goal', target: 40, reward: { player: 'f0', xp: 1500 } },
  { id: 's_sbc', cat: 'season', title: 'Squad Architect', desc: 'Complete 5 SBCs', ev: 'sbc', target: 5, reward: { player: 'f1', xp: 1500 } },
  { id: 's_rivals', cat: 'season', title: 'Rival Hunter', desc: 'Win 10 Division Rivals matches', ev: 'rivals_win', target: 10, reward: { pack: 'rare', xp: 2000 } },
  { id: 's_draft', cat: 'season', title: 'Draft Day', desc: 'Win 4 Draft matches', ev: 'draft_win', target: 4, reward: { player: 'f2', xp: 1500 } },
  { id: 's_clean', cat: 'season', title: 'Brick Wall', desc: 'Keep 5 clean sheets', ev: 'cleansheet', target: 5, reward: { player: 'f3', xp: 1500 } },
  // milestones (permanent)
  { id: 'm_matches', cat: 'milestone', title: 'Veteran', desc: 'Play 25 matches', ev: 'match', target: 25, reward: { pack: 'mega', xp: 2500 } },
  { id: 'm_goals', cat: 'milestone', title: 'Century', desc: 'Score 100 goals', ev: 'goal', target: 100, reward: { coins: 25000, xp: 4000 } },
  { id: 'm_packs', cat: 'milestone', title: 'Collector', desc: 'Open 25 packs', ev: 'pack', target: 25, reward: { pack: 'rare', xp: 1500 } },
  { id: 'm_sells', cat: 'milestone', title: 'Trader', desc: 'Sell 10 players on the market', ev: 'sell', target: 10, reward: { coins: 10000, xp: 1500 } },
  { id: 'm_champs', cat: 'milestone', title: 'Champion', desc: 'Win 10 Champions matches', ev: 'champs_win', target: 10, reward: { pack: 'legends', xp: 5000 } }
];

const Objectives = {
  periodKey(o) { return o.cat === 'daily' ? dayKey() : o.cat === 'weekly' ? weekKey() : o.cat === 'season' ? 'S1' : 'M'; },
  key(o) { return o.id + '@' + this.periodKey(o); },
  progress(o) { return Math.min(o.target, Save.data.objectives.progress[this.key(o)] || 0); },
  claimed(o) { return !!Save.data.objectives.claimed[this.key(o)]; },
  done(o) { return this.progress(o) >= o.target; },
  claimable() { return OBJECTIVES.filter(o => this.done(o) && !this.claimed(o)).length; },
  track(ev, n = 1) {
    if (!Save.data) return;
    let completed = [];
    for (const o of OBJECTIVES) {
      if (o.ev !== ev) continue;
      const k = this.key(o), before = Save.data.objectives.progress[k] || 0;
      if (before >= o.target) continue;
      Save.data.objectives.progress[k] = Math.min(o.target, before + n);
      if (Save.data.objectives.progress[k] >= o.target) completed.push(o);
    }
    completed.forEach(o => toast(`Objective complete: <b>${o.title}</b> — claim your reward`, 'good'));
    Save.dirty(); UI.refreshBadges?.();
  },
  claim(o) {
    if (!this.done(o) || this.claimed(o)) return false;
    Save.data.objectives.claimed[this.key(o)] = true;
    grantReward(o.reward, `Objective: ${o.title}`);
    Save.dirty(); return true;
  }
};

function rewardText(r) {
  const parts = [];
  if (r.coins) parts.push(`${fmtFull(r.coins)} Coins`);
  if (r.points) parts.push(`${fmtFull(r.points)} Prime Points`);
  if (r.pack) parts.push(PACKS[r.pack].name);
  if (r.player) { const p = P(r.player); parts.push(`${p.ovr} ${p.name}`); }
  if (r.tickets) parts.push(`${r.tickets} Champions Ticket`);
  if (r.xp) parts.push(`${fmtFull(r.xp)} XP`);
  return parts.join(' + ');
}
function grantReward(r, src) {
  if (r.coins) Wallet.add('coins', r.coins, src);
  if (r.points) Wallet.add('points', r.points, src);
  if (r.pack) { Save.data.unopened.push(r.pack); toast(`${PACKS[r.pack].name} added to My Packs`, 'good'); }
  if (r.player) { Club.add(r.player, true, 'reward'); const p = P(r.player); toast(`${p.ovr} ${p.name} sent to your club`, 'good'); }
  if (r.tickets) Save.data.modes.champs.tickets += r.tickets;
  if (r.xp) XP.add(r.xp);
  Save.dirty();
}

/* ---------------- SBC ---------------- */
const SBCS = [
  { id: 'up_bronze', cat: 'Upgrades', name: 'Bronze Upgrade', desc: 'Swap 5 bronze players for a Silver Pack.', size: 5, repeat: 99, reqs: [{ t: 'tierAll', v: 'bronze' }], reward: { pack: 'silver' } },
  { id: 'up_silver', cat: 'Upgrades', name: 'Silver Upgrade', desc: 'Swap 5 silver players for a Gold Pack.', size: 5, repeat: 99, reqs: [{ t: 'tierAll', v: 'silver' }], reward: { pack: 'gold' } },
  { id: 'up_gold', cat: 'Upgrades', name: 'Gold Upgrade', desc: '7 gold players for a Premium Gold Pack.', size: 7, repeat: 99, reqs: [{ t: 'tierMin', v: 'gold', n: 7 }], reward: { pack: 'premium' } },
  { id: 'up_rare', cat: 'Upgrades', name: 'Rare Mix', desc: 'Submit rare players for a Rare Players Pack.', size: 11, repeat: 10, reqs: [{ t: 'rare', n: 6 }, { t: 'rating', v: 72 }], reward: { pack: 'rare' } },
  { id: 'ch_league', cat: 'Challenges', name: 'League Lovers', desc: 'Build a squad from one league.', size: 11, repeat: 3, reqs: [{ t: 'sameLeague', n: 11 }, { t: 'chem', v: 18 }], reward: { pack: 'jumbo' } },
  { id: 'ch_nations', cat: 'Challenges', name: 'Around the World', desc: 'Use at least 5 nations.', size: 11, repeat: 3, reqs: [{ t: 'nations', n: 5 }, { t: 'rating', v: 70 }], reward: { pack: 'premium' } },
  { id: 'ch_hybrid', cat: 'Challenges', name: 'Hybrid Leagues', desc: 'Min. 3 leagues, decent chemistry.', size: 11, repeat: 3, reqs: [{ t: 'leagues', n: 3 }, { t: 'chem', v: 15 }, { t: 'tierMin', v: 'gold', n: 5 }], reward: { coins: 8000, pack: 'gold' } },
  { id: 'ch_top', cat: 'Challenges', name: 'Top Form', desc: 'High-rated squad required.', size: 11, repeat: 2, reqs: [{ t: 'rating', v: 79 }, { t: 'chem', v: 20 }], reward: { pack: 'mega' } },
  { id: 'pl_found1', cat: 'Players', name: 'Foundations: Winger', desc: 'Earn a Foundations upgrade.', size: 11, repeat: 1, reqs: [{ t: 'rating', v: 74 }, { t: 'chem', v: 15 }], reward: { player: 'f4' } },
  { id: 'pl_found2', cat: 'Players', name: 'Foundations: Defender', desc: 'Earn a Foundations upgrade.', size: 11, repeat: 1, reqs: [{ t: 'rating', v: 76 }, { t: 'nat', n: 2, any: true }], reward: { player: 'f5' } },
  { id: 'pl_totw', cat: 'Players', name: 'TOTW Spotlight', desc: 'Earn a Team of the Week card.', size: 11, repeat: 1, reqs: [{ t: 'rating', v: 80 }, { t: 'chem', v: 22 }], reward: { player: 't0' } },
  { id: 'pl_hero', cat: 'Players', name: 'Hero Moment', desc: 'Earn a Hero.', size: 11, repeat: 1, reqs: [{ t: 'rating', v: 83 }, { t: 'chem', v: 24 }, { t: 'special', n: 1 }], reward: { player: 'h0' } },
  { id: 'pl_icon', cat: 'Players', name: 'Icon Legacy', desc: 'Earn an Icon.', size: 11, repeat: 1, reqs: [{ t: 'rating', v: 85 }, { t: 'chem', v: 26 }, { t: 'special', n: 2 }], reward: { player: 'i0' } },
  { id: 'fd_intro', cat: 'Foundations', name: 'First XI', desc: 'Submit any complete squad of 11.', size: 11, repeat: 1, reqs: [], reward: { pack: 'premium', coins: 2500 } },
  { id: 'fd_chem', cat: 'Foundations', name: 'Chemistry Basics', desc: 'Learn chemistry: reach 10 chem.', size: 11, repeat: 1, reqs: [{ t: 'chem', v: 10 }], reward: { pack: 'gold', coins: 3000 } }
];

function sbcCheck(sbc, players /* array of P|null, length = size */, formation) {
  const ps = players.filter(Boolean);
  const chem = sbc.size === 11 ? computeChemistry(formation, players) : null;
  const rating = sbc.size === 11 ? squadRating(players) : (ps.length ? Math.floor(ps.reduce((a, p) => a + p.ovr, 0) / ps.length) : 0);
  const cnt = (f) => ps.filter(f).length;
  const maxBy = (key) => { const m = {}; ps.forEach(p => m[p[key]] = (m[p[key]] || 0) + 1); return Math.max(0, ...Object.values(m)); };
  const distinct = (key) => new Set(ps.map(p => p[key])).size;
  const res = [{ label: `Players: ${ps.length}/${sbc.size}`, ok: ps.length === sbc.size }];
  for (const r of sbc.reqs) {
    let label, ok;
    switch (r.t) {
      case 'tierAll': label = `All players: ${r.v[0].toUpperCase() + r.v.slice(1)}`; ok = ps.length > 0 && ps.every(p => tierOf(p.ovr) === r.v && p.type === 'base'); break;
      case 'tierMin': label = `Min. ${r.n} ${r.v[0].toUpperCase() + r.v.slice(1)} players`; ok = cnt(p => tierOf(p.ovr) === r.v) >= r.n; break;
      case 'rare': label = `Min. ${r.n} Rare players`; ok = cnt(p => p.rare) >= r.n; break;
      case 'rating': label = `Squad Rating: Min. ${r.v} (now ${rating})`; ok = rating >= r.v; break;
      case 'chem': label = `Total Chemistry: Min. ${r.v} (now ${chem ? chem.total : 0})`; ok = chem && chem.total >= r.v; break;
      case 'sameLeague': label = `Same League: ${r.n} players`; ok = maxBy('lg') >= r.n; break;
      case 'leagues': label = `Leagues: Min. ${r.n}`; ok = distinct('lg') >= r.n; break;
      case 'nations': label = `Nations: Min. ${r.n}`; ok = distinct('nat') >= r.n; break;
      case 'nat': label = `Same Nation: Min. ${r.n} players`; ok = maxBy('nat') >= r.n; break;
      case 'special': label = `Special cards (TOTW/Promo/Foundations): Min. ${r.n}`; ok = cnt(p => p.type !== 'base') >= r.n; break;
    }
    res.push({ label, ok });
  }
  return { reqs: res, ok: res.every(r => r.ok), rating, chem };
}
const SBC = {
  count(id) { return Save.data.sbc.done[id] || 0; },
  available(s) { return this.count(s.id) < s.repeat; },
  submit(sbc, uids, formation) {
    const players = uids.map(u => u ? Club.player(u) : null);
    const chk = sbcCheck(sbc, players, formation);
    if (!chk.ok) { Audio2.sfx('error'); toast('Requirements not met', 'bad'); return false; }
    uids.filter(Boolean).forEach(u => Club.remove(u));
    Save.data.sbc.done[sbc.id] = this.count(sbc.id) + 1;
    Save.data.stats.sbcs++;
    grantReward(sbc.reward, `SBC: ${sbc.name}`);
    Objectives.track('sbc');
    Save.data.profile.history.unshift({ t: Date.now(), text: `Completed SBC "${sbc.name}"` });
    Save.dirty(); return true;
  }
};

/* ---------------- COMPETITIONS ---------------- */
const DIFFICULTIES = {
  beginner: { name: 'Beginner', ai: 0.25, ovr: 64, sbPts: 30, coins: 200 },
  amateur: { name: 'Amateur', ai: 0.4, ovr: 70, sbPts: 50, coins: 300 },
  semipro: { name: 'Semi-Pro', ai: 0.55, ovr: 74, sbPts: 70, coins: 400 },
  professional: { name: 'Professional', ai: 0.7, ovr: 78, sbPts: 100, coins: 550 },
  worldclass: { name: 'World Class', ai: 0.82, ovr: 82, sbPts: 140, coins: 700 },
  legendary: { name: 'Legendary', ai: 0.92, ovr: 85, sbPts: 180, coins: 850 },
  ultimate: { name: 'Ultimate', ai: 1.0, ovr: 88, sbPts: 220, coins: 1000 }
};
const SB_RANKS = [
  { name: 'Elite 1', pts: 4000, reward: { pack: 'mega', coins: 20000, points: 150 } },
  { name: 'Gold 1', pts: 2500, reward: { pack: 'rare', coins: 10000 } },
  { name: 'Gold 3', pts: 1600, reward: { pack: 'jumbo', coins: 6000 } },
  { name: 'Silver 1', pts: 900, reward: { pack: 'premium', coins: 3000 } },
  { name: 'Bronze 1', pts: 300, reward: { pack: 'gold', coins: 1000 } },
  { name: 'Unranked', pts: 0, reward: null }
];
const AI_SQUAD_NAMES = ['Night Owls XI', 'Coastline FC', 'Desert Hawks', 'Iron Lions', 'Midnight Rovers', 'Silver Arrows', 'Thunder Bay', 'Red Comets', 'Golden Era', 'Northern Lights', 'Volcano United', 'Blue Harbour', 'Kings of the Park', 'Sunday League Stars', 'Ember City', 'Glacier FC', 'Neon Wolves', 'Sandstorm XI', 'Atlas Athletic', 'Polar Express'];

const RIVALS_DIVS = [null,
  { name: 'Elite Division', win: 4 }, { name: 'Division 2', win: 4 }, { name: 'Division 3', win: 3 }, { name: 'Division 4', win: 3 }, { name: 'Division 5', win: 3 },
  { name: 'Division 6', win: 3 }, { name: 'Division 7', win: 3 }, { name: 'Division 8', win: 3 }, { name: 'Division 9', win: 3 }, { name: 'Division 10', win: 3 }];
// points per division: promote at 10 pts (win 3/draw 1/loss -1), relegate below 0 (except div 10)
const Rivals = {
  oppStrength(div) { return 88 - (div - 1) * 2.4; },
  difficulty(div) { const map = ['', 'legendary', 'legendary', 'worldclass', 'worldclass', 'professional', 'professional', 'semipro', 'semipro', 'amateur', 'amateur']; return map[div]; },
  record(result) {
    const r = Save.data.modes.rivals;
    if (r.weekKey !== weekKey()) { r.weekKey = weekKey(); r.weekWins = 0; }
    r.played++;
    let msg = '';
    if (result === 'W') { r.pts += 3; r.wins++; r.weekWins++; Objectives.track('rivals_win'); }
    else if (result === 'D') r.pts += 1;
    else r.pts -= 1;
    const coins = { W: 900, D: 450, L: 200 }[result] + (11 - r.div) * 60;
    Wallet.add('coins', coins, `Division Rivals ${result === 'W' ? 'win' : result === 'D' ? 'draw' : 'match'}`);
    if (r.pts >= 10) {
      if (r.div > 1) { r.div--; msg = `Promoted to ${RIVALS_DIVS[r.div].name}!`; grantReward({ pack: r.div <= 3 ? 'jumbo' : 'premium', points: 50 }, 'Rivals promotion'); r.best = Math.min(r.best, r.div); Save.data.profile.history.unshift({ t: Date.now(), text: `Promoted to ${RIVALS_DIVS[r.div].name}` }); }
      else { msg = 'Elite title! Champions ticket earned'; Save.data.modes.champs.tickets++; }
      r.pts = 0;
    } else if (r.pts < 0) {
      if (r.div < 10) { r.div++; msg = `Relegated to ${RIVALS_DIVS[r.div].name}`; r.pts = 5; } else r.pts = 0;
    }
    // Champions qualification: 3 wins in a week in div 5 or better
    if (result === 'W' && r.div <= 5 && r.weekWins % 3 === 0) { Save.data.modes.champs.tickets++; msg += (msg ? ' · ' : '') + 'Champions ticket earned!'; }
    Save.dirty();
    return { coins, msg };
  }
};
const Champions = {
  maxMatches: 10,
  rewardFor(w) {
    if (w >= 9) return { pack: 'ultimate', coins: 50000, points: 400 };
    if (w >= 7) return { pack: 'mega', coins: 25000, points: 200 };
    if (w >= 5) return { pack: 'rare', coins: 12000, points: 100 };
    if (w >= 3) return { pack: 'jumbo', coins: 6000 };
    return { pack: 'premium', coins: 2000 };
  },
  start() { const c = Save.data.modes.champs; if (c.tickets < 1) return false; c.tickets--; c.active = { w: 0, l: 0, played: 0, started: Date.now() }; Save.dirty(); return true; },
  record(result) {
    const c = Save.data.modes.champs, a = c.active; if (!a) return;
    a.played++; if (result === 'W') { a.w++; Objectives.track('champs_win'); } else a.l++;
    Wallet.add('coins', result === 'W' ? 1500 : 400, 'Champions match');
    Save.dirty();
  },
  finish() {
    const c = Save.data.modes.champs, a = c.active; if (!a) return null;
    const rw = this.rewardFor(a.w);
    grantReward(rw, `Champions: ${a.w}-${a.l}`);
    c.history.unshift({ t: Date.now(), w: a.w, l: a.l });
    Save.data.profile.history.unshift({ t: Date.now(), text: `Champions finished ${a.w}-${a.l}` });
    c.active = null; Save.dirty(); return rw;
  }
};
const DRAFT_COST = { coins: 15000, points: 300 };
const Draft = {
  rewardFor(w) {
    return [{ coins: 1000, pack: 'gold' }, { coins: 3000, pack: 'premium' }, { coins: 8000, pack: 'draftreward', points: 50 }, { coins: 15000, pack: 'jumbo', points: 100 }, { coins: 30000, pack: 'mega', points: 200 }][w];
  },
  rounds: ['Round of 16', 'Quarter-Final', 'Semi-Final', 'Final'],
  choices(pos, exclude) {
    const pool = DB.players.filter(p => playerFitsPos(p, pos) && p.ovr >= 76 && !exclude.has(p.id));
    const out = []; const seen = new Set(exclude);
    for (let i = 0; i < 200 && out.length < 5; i++) {
      const tier = R.weighted([{ w: 70, v: 'base' }, { w: 14, v: 'totw' }, { w: 8, v: 'promo' }, { w: 5, v: 'hero' }, { w: 3, v: 'icon' }]);
      const sub = pool.filter(p => (tier === 'base' ? p.type === 'base' : p.type === tier) && !seen.has(p.id));
      const pick = sub.length ? R.pick(sub) : R.pick(pool.filter(p => !seen.has(p.id)));
      if (pick && !seen.has(pick.id)) { out.push(pick); seen.add(pick.id); }
    }
    return out;
  }
};
