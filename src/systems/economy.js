/* ============================================================
   SYSTEMS / ECONOMY — wallet, XP, packs, transfer market
   Prime Points are a fictional in-game currency; there are
   no real-money transactions anywhere in the game.
   ============================================================ */
const Wallet = {
  get coins() { return Save.data.coins; },
  get points() { return Save.data.points; },
  can(cur, amt) { return (cur === 'coins' ? Save.data.coins : Save.data.points) >= amt; },
  add(cur, amt, desc, kind = 'reward') {
    if (!amt) return;
    if (cur === 'coins') Save.data.coins += amt; else Save.data.points += amt;
    this.log(kind, amt, cur, desc); UI.refreshCurrency(); if (amt > 0 && cur === 'coins') Audio2.sfx('coin');
  },
  spend(cur, amt, desc, kind = 'purchase') {
    amt = Math.round(amt);
    if (amt < 0 || !this.can(cur, amt)) { Audio2.sfx('error'); toast(`Not enough ${cur === 'coins' ? 'coins' : 'Prime Points'}`, 'bad'); return false; }
    if (cur === 'coins') Save.data.coins -= amt; else Save.data.points -= amt;
    this.log(kind, -amt, cur, desc); UI.refreshCurrency(); return true;
  },
  log(kind, amount, cur, desc) {
    Save.data.tx.unshift({ t: Date.now(), kind, amount, cur, desc });
    if (Save.data.tx.length > 300) Save.data.tx.length = 300;
    Save.dirty();
  }
};

const XP = {
  need(level) { return 800 + level * 350; },
  add(n) {
    const pr = Save.data.profile; pr.xp += n;
    let ups = 0;
    while (pr.xp >= this.need(pr.level)) { pr.xp -= this.need(pr.level); pr.level++; ups++; }
    if (ups) {
      const lvl = pr.level;
      Wallet.add('coins', 500 * lvl, `Club Level ${lvl} reward`);
      if (lvl % 5 === 0) { Save.data.unopened.push('premium'); toast(`Level ${lvl}! Premium Gold Pack added to My Packs`, 'good'); }
      else toast(`Club Level ${lvl}! +${fmtFull(500 * lvl)} coins`, 'good');
      pr.history.unshift({ t: Date.now(), text: `Reached Club Level ${lvl}` });
    }
    Save.dirty(); UI.refreshCurrency();
  }
};

/* ---------------- PACKS ---------------- */
// tier keys: bronze, bronze-rare, silver, silver-rare, gold, gold-rare, totw, promo, found, hero, icon
const PACKS = {
  bronze: { name: 'Bronze Pack', items: 12, coins: 400, points: 0, art: 'bronze', guar: [['bronze-rare', 1]], w: { bronze: 70, 'bronze-rare': 24, silver: 6 }, desc: '12 items. 1 Rare Bronze guaranteed.' },
  silver: { name: 'Silver Pack', items: 12, coins: 2500, points: 0, art: 'silver', guar: [['silver-rare', 1]], w: { silver: 68, 'silver-rare': 24, gold: 7, 'bronze-rare': 1 }, desc: '12 items. 1 Rare Silver guaranteed.' },
  gold: { name: 'Gold Pack', items: 12, coins: 5000, points: 50, art: 'gold', guar: [['gold', 3]], w: { gold: 52, 'gold-rare': 10, silver: 32, 'silver-rare': 4, totw: 1.4, promo: 0.4, hero: 0.15, icon: 0.05 }, desc: '12 items. 3 Gold guaranteed.' },
  premium: { name: 'Premium Gold Pack', items: 12, coins: 7500, points: 150, art: 'premium', guar: [['gold-rare', 2], ['gold', 4]], w: { gold: 55, 'gold-rare': 30, silver: 10, totw: 3, promo: 1.2, hero: 0.5, icon: 0.3 }, desc: '12 items. 2 Rare Gold + 4 Gold guaranteed.' },
  jumbo: { name: 'Jumbo Premium Gold Pack', items: 24, coins: 15000, points: 300, art: 'jumbo', guar: [['gold-rare', 4], ['gold', 10]], w: { gold: 52, 'gold-rare': 34, silver: 9, totw: 3.2, promo: 1.3, hero: 0.5, icon: 0.3 }, desc: '24 items. 4 Rare Gold + 10 Gold guaranteed.' },
  rare: { name: 'Rare Players Pack', items: 12, coins: 15000, points: 300, art: 'rare', guar: [['gold-rare', 4]], w: { 'gold-rare': 62, 'silver-rare': 26, totw: 7, promo: 3, hero: 1.2, icon: 0.8 }, desc: '12 rare players. 4 Rare Gold guaranteed.' },
  mega: { name: 'Mega Pack', items: 30, coins: 30000, points: 450, art: 'mega', guar: [['gold-rare', 6], ['gold', 14]], w: { gold: 48, 'gold-rare': 38, silver: 8, totw: 4, promo: 1.4, hero: 0.4, icon: 0.2 }, desc: '30 items. 6 Rare Gold + 14 Gold guaranteed.' },
  ultimate: { name: 'Ultimate Pack', items: 30, coins: 125000, points: 1500, art: 'ultimate', guar: [['special', 1], ['gold-rare', 29]], w: { 'gold-rare': 80, totw: 12, promo: 5, hero: 2, icon: 1 }, desc: '30 Rare Gold. 1 special card guaranteed.' },
  totwpack: { name: 'Team of the Week Pack', items: 3, coins: 60000, points: 750, art: 'totw', guar: [['totw', 1], ['gold-rare', 2]], w: { 'gold-rare': 100 }, desc: '3 Rare Gold. 1 TOTW guaranteed.', promo: true },
  nightfall: { name: 'Nightfall Promo Pack', items: 6, coins: 0, points: 900, art: 'promo', guar: [['promo', 1], ['gold-rare', 5]], w: { 'gold-rare': 100 }, desc: '6 Rare Gold. 1 Nightfall promo guaranteed.', promo: true },
  legends: { name: 'Heroes & Icons Pack', items: 3, coins: 0, points: 2500, art: 'icon', guar: [['legend', 1], ['gold-rare', 2]], w: { 'gold-rare': 100 }, desc: '1 Hero or Icon guaranteed (Icon 25%).', promo: true },
  found: { name: 'Foundations Pack', items: 5, coins: 0, points: 0, art: 'found', guar: [['found', 1], ['gold-rare', 4]], w: { 'gold-rare': 100 }, desc: 'Reward pack. 1 Foundations player guaranteed.', reward: true },
  draftreward: { name: 'Draft Reward Pack', items: 6, coins: 0, points: 0, art: 'premium', guar: [['gold-rare', 3]], w: { gold: 60, 'gold-rare': 35, totw: 4, promo: 1 }, desc: 'Draft reward.', reward: true }
};
const PACK_ORDER = ['bronze', 'silver', 'gold', 'premium', 'jumbo', 'rare', 'mega', 'ultimate', 'totwpack', 'nightfall', 'legends'];

const _tierPools = {};
function tierPool(tier) {
  if (_tierPools[tier]) return _tierPools[tier];
  let pool;
  if (tier === 'special') pool = DB.players.filter(p => ['totw', 'promo', 'hero', 'icon'].includes(p.type));
  else if (tier === 'legend') pool = DB.players.filter(p => p.type === 'hero' || p.type === 'icon');
  else if (['totw', 'promo', 'hero', 'icon', 'found'].includes(tier)) pool = DB.players.filter(p => p.type === tier);
  else if (tier === 'gold') pool = DB.players.filter(p => p.type === 'base' && tierOf(p.ovr) === 'gold'); // any gold (rare or not)
  else pool = DB.players.filter(p => p.type === 'base' && rarityKey(p) === tier);
  return (_tierPools[tier] = pool);
}
function rollFromTier(tier) {
  const pool = tierPool(tier);
  if (tier === 'legend') return R.chance(0.25) ? R.pick(pool.filter(p => p.type === 'icon')) : R.pick(pool.filter(p => p.type === 'hero'));
  // weight lower ratings more heavily (realistic pack odds)
  const min = Math.min(...pool.map(p => p.ovr));
  const k = tier.startsWith('gold') ? 3.2 : 6;
  return R.weighted(pool.map(p => ({ w: Math.exp(-(p.ovr - min) / k), v: p })));
}
/* odds table for transparency: probability per non-guaranteed slot + chance of ≥1 in pack */
function packOdds(id) {
  const pk = PACKS[id]; const tot = Object.values(pk.w).reduce((a, b) => a + b, 0);
  const free = pk.items - pk.guar.reduce((s, g) => s + g[1], 0);
  return Object.entries(pk.w).map(([t, w]) => {
    const p = w / tot;
    const guaranteed = pk.guar.filter(g => g[0] === t).reduce((s, g) => s + g[1], 0);
    const atLeast = guaranteed ? 1 : 1 - Math.pow(1 - p, free);
    return { tier: t, perSlot: p, atLeast };
  });
}
function generatePack(id) {
  const pk = PACKS[id], out = [];
  pk.guar.forEach(([t, n]) => { for (let i = 0; i < n; i++) out.push(rollFromTier(t)); });
  const ws = Object.entries(pk.w).map(([t, w]) => ({ w, v: t }));
  while (out.length < pk.items) out.push(rollFromTier(R.weighted(ws)));
  return out.sort((a, b) => cardValueScore(b) - cardValueScore(a));
}
function cardValueScore(p) { return p.ovr + (CARD_TYPES[p.type].order * 4) + (p.rare ? 1 : 0); }
const TIER_LABEL = { bronze: 'Bronze', 'bronze-rare': 'Rare Bronze', silver: 'Silver', 'silver-rare': 'Rare Silver', gold: 'Gold', 'gold-rare': 'Rare Gold', totw: 'Team of the Week', promo: 'Nightfall Promo', found: 'Foundations', hero: 'Hero', icon: 'Icon', special: 'Special card', legend: 'Hero/Icon' };

/* ---------------- TRANSFER MARKET ---------------- */
const MARKET_TAX = 0.05;
const Market = {
  demand(pid) { const d = Save.data.market.demand; return d[pid] ?? 1; },
  nudge(pid, f) { const d = Save.data.market.demand; d[pid] = clamp((d[pid] ?? 1) * f, 0.6, 1.8); },
  // global market cycle — prices oscillate slowly over real time (simulated "weekend league" demand etc.)
  cycle() { const t = Date.now() / 3.6e6; return 1 + 0.06 * Math.sin(t * 0.9) + 0.03 * Math.sin(t * 2.7); },
  value(p) { return Math.max(150, Math.round(baseValue(p) * this.demand(p.id) * this.cycle() / 50) * 50); },
  priceRange(p) { const v = this.value(p); return { min: Math.max(150, Math.round(v * 0.45 / 50) * 50), max: Math.round(v * 3 / 50) * 50 }; },
  makeListing(p) {
    const v = this.value(p), bin = Math.max(200, Math.round(v * R.range(0.92, 1.35) / 50) * 50);
    const start = Math.max(150, Math.round(bin * R.range(0.45, 0.8) / 50) * 50);
    const dur = R.pick([1, 2, 3, 5, 8, 15, 30, 60]) * 60000;
    const hasBid = R.chance(0.25);
    return { id: uid(), pid: p.id, start, bin, bid: hasBid ? start : 0, bidder: hasBid ? 'ai' : null, ends: Date.now() + dur * R.range(0.2, 1), seller: 'AI' };
  },
  search(f) {
    let pool = DB.players.filter(p => p.type !== 'found');
    if (f.name) { const q = f.name.toLowerCase(); pool = pool.filter(p => p.name.toLowerCase().includes(q)); }
    if (f.pos) pool = pool.filter(p => p.pos === f.pos);
    if (f.lg) pool = pool.filter(p => p.lg === f.lg);
    if (f.nat) pool = pool.filter(p => p.nat === f.nat);
    if (f.club) pool = pool.filter(p => p.club === f.club);
    if (f.rar) pool = pool.filter(p => f.rar === 'rare' ? p.rare : f.rar === 'special' ? p.type !== 'base' : rarityKey(p) === f.rar || (f.rar === 'gold' && tierOf(p.ovr) === 'gold' && p.type === 'base'));
    if (f.minOvr) pool = pool.filter(p => p.ovr >= f.minOvr);
    if (f.maxOvr) pool = pool.filter(p => p.ovr <= f.maxOvr);
    if (!pool.length) return [];
    // weighted toward common cards; specials are scarce
    const listings = [];
    const n = Math.min(24, Math.max(4, pool.length * 2));
    for (let i = 0; i < n; i++) {
      const p = R.pick(pool);
      if (p.type !== 'base' && R.chance(0.5) && pool.some(x => x.type === 'base')) continue;
      listings.push(this.makeListing(p));
    }
    let res = listings;
    if (f.maxBin) res = res.filter(l => l.bin <= f.maxBin);
    if (f.sort === 'bin-asc') res.sort((a, b) => a.bin - b.bin);
    else if (f.sort === 'bin-desc') res.sort((a, b) => b.bin - a.bin);
    else if (f.sort === 'ovr') res.sort((a, b) => P(b.pid).ovr - P(a.pid).ovr);
    else res.sort((a, b) => a.ends - b.ends);
    Save.data.market.listings = res; Save.dirty();
    return res;
  },
  buyNow(l) {
    const p = P(l.pid);
    if (l.ends < Date.now()) { toast('This auction has ended', 'bad'); return false; }
    if (!Wallet.spend('coins', l.bin, `Bought ${p.name} (${p.ovr})`, 'market')) return false;
    Club.add(p.id, false, 'market');
    this.nudge(p.id, 1.04);
    this.hist('buy', p, l.bin);
    Save.data.market.listings = Save.data.market.listings.filter(x => x.id !== l.id);
    Save.data.stats.bought++;
    Objectives.track('buy');
    return true;
  },
  minBid(l) { if (!l.bid) return l.start; return l.bid + (l.bid < 1000 ? 50 : l.bid < 10000 ? 100 : l.bid < 50000 ? 250 : 1000); },
  placeBid(l, amt) {
    const p = P(l.pid);
    if (l.ends < Date.now()) { toast('This auction has ended', 'bad'); return false; }
    if (amt < this.minBid(l)) { toast(`Minimum bid is ${fmtFull(this.minBid(l))}`, 'bad'); return false; }
    if (amt >= l.bin) return this.buyNow(l);
    // escrow coins
    if (!Wallet.spend('coins', amt, `Bid on ${p.name}`, 'bid')) return false;
    const prev = Save.data.market.bids.find(b => b.lid === l.id && b.status === 'winning');
    if (prev) { Wallet.add('coins', prev.amt, `Bid refund ${p.name}`, 'refund'); prev.status = 'replaced'; }
    l.bid = amt; l.bidder = 'me';
    Save.data.market.bids.unshift({ lid: l.id, pid: l.pid, amt, ends: l.ends, status: 'winning', listing: l });
    // a few seconds extension like real auctions
    if (l.ends - Date.now() < 30000) l.ends = Date.now() + 30000;
    Save.dirty(); return true;
  },
  listItem(uidv, start, bin, durMin) {
    const it = Club.get(uidv); if (!it) return false;
    const p = P(it.pid);
    if (it.untr) { toast('Untradeable items cannot be listed', 'bad'); return false; }
    if (Club.inMarket(uidv)) { toast('Already listed', 'bad'); return false; }
    const rg = this.priceRange(p);
    if (bin <= start) { toast('Buy Now must be higher than start price', 'bad'); return false; }
    if (start < rg.min || bin > rg.max) { toast(`Price range for this player: ${fmtFull(rg.min)} – ${fmtFull(rg.max)}`, 'bad'); return false; }
    // remove from squads while listed
    Save.data.squads.forEach(s => { s.slots = s.slots.map(u => u === uidv ? null : u); s.subs = s.subs.map(u => u === uidv ? null : u); });
    Save.data.market.mine.unshift({ id: uid(), uid: uidv, pid: p.id, start, bin, bid: 0, ends: Date.now() + durMin * 60000, status: 'active', listed: Date.now() });
    Save.dirty(); return true;
  },
  removeListing(id) {
    const l = Save.data.market.mine.find(x => x.id === id);
    if (!l) return;
    if (l.status === 'active' && l.bid) { toast('Cannot remove a listing that has bids', 'bad'); return false; }
    Save.data.market.mine = Save.data.market.mine.filter(x => x.id !== id);
    Save.dirty(); return true;
  },
  hist(kind, p, price) {
    Save.data.market.history.unshift({ t: Date.now(), kind, pid: p.id, price });
    if (Save.data.market.history.length > 150) Save.data.market.history.length = 150;
  },
  /* simulation tick — call regularly. Resolves auctions, simulates AI buyers/bidders */
  tick() {
    if (!Save.data) return;
    const now = Date.now(), m = Save.data.market;
    let changed = false;
    // my active listings: AI interest
    for (const l of m.mine) {
      if (l.status !== 'active') continue;
      const p = P(l.pid), v = this.value(p);
      const dt = Math.min(60, (now - (l._lt || l.listed)) / 1000); l._lt = now;
      // buy-now chance per second: higher when cheap
      const r = l.bin / v;
      const pBuy = r <= 0.95 ? 0.08 : r <= 1.1 ? 0.025 : r <= 1.3 ? 0.006 : 0.0008;
      if (Math.random() < 1 - Math.pow(1 - pBuy, dt)) { this.sell(l, l.bin); changed = true; continue; }
      // bidding
      const next = l.bid ? l.bid + Math.max(50, Math.round(l.bid * 0.05 / 50) * 50) : l.start;
      if (next < v * 0.98 && Math.random() < 1 - Math.pow(0.97, dt)) { l.bid = next; changed = true; }
      if (now >= l.ends) {
        if (l.bid) this.sell(l, l.bid); else { l.status = 'expired'; }
        changed = true;
      }
    }
    // my bids
    for (const b of m.bids) {
      if (b.status !== 'winning') continue;
      const l = b.listing, p = P(b.pid), v = this.value(p);
      const dt = Math.min(60, (now - (b._lt || now - 1000)) / 1000); b._lt = now;
      // AI outbid chance: high if our bid is well below value
      const r = b.amt / v, pOut = r < 0.7 ? 0.06 : r < 0.9 ? 0.025 : r < 1.0 ? 0.008 : 0.001;
      if (now < l.ends && Math.random() < 1 - Math.pow(1 - pOut, dt)) {
        b.status = 'outbid'; l.bid = this.minBid({ bid: b.amt }); l.bidder = 'ai';
        Wallet.add('coins', b.amt, `Outbid on ${p.name} — refund`, 'refund');
        toast(`Outbid on ${p.name}`, 'bad'); changed = true; continue;
      }
      if (now >= l.ends) {
        b.status = 'won'; Club.add(p.id, false, 'auction'); this.hist('buy', p, b.amt); this.nudge(p.id, 1.03);
        Save.data.stats.bought++; Objectives.track('buy');
        toast(`Won ${p.name} for ${fmtFull(b.amt)} coins!`, 'good'); changed = true;
      }
    }
    if (m.bids.length > 60) m.bids = m.bids.filter(b => b.status === 'winning').concat(m.bids.filter(b => b.status !== 'winning').slice(0, 40));
    if (changed) { Save.dirty(); UI.onMarketChange?.(); }
  },
  sell(l, price) {
    const p = P(l.pid);
    const net = Math.round(price * (1 - MARKET_TAX));
    l.status = 'sold'; l.sold = price;
    Club.remove(l.uid);
    Wallet.add('coins', net, `Sold ${p.name} for ${fmtFull(price)} (5% tax)`, 'sale');
    this.hist('sell', p, price); this.nudge(p.id, 0.97);
    Save.data.stats.sold++; Objectives.track('sell');
    toast(`${p.name} sold for ${fmtFull(price)}! +${fmtFull(net)} after tax`, 'good');
  }
};
