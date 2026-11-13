/* ============================================================
   UI / ULTIMATE XI — SBC, Transfers, Play hub & game modes, results
   ============================================================ */

/* ---------------- SBC ---------------- */
SCREENS.sbc = {
  hub: true, bg: 'hub', back: hubBack,
  render(params) {
    const { el, body } = hubShell('sbc');
    const cats = ['Foundations', 'Upgrades', 'Challenges', 'Players'];
    const cat = params.cat || 'Foundations';
    body.innerHTML = `<div class="row"><div class="page-title">Squad Building Challenges</div><div class="spacer"></div><div class="seg">${cats.map(c => `<button data-nav data-c="${c}" class="${c === cat ? 'on' : ''}">${c}</button>`).join('')}</div></div>
      <div class="tiles scroll" style="grid-template-columns:repeat(auto-fill,minmax(270px,1fr));flex:1;align-content:start;padding:4px">${SBCS.filter(s => s.cat === cat).map(s => {
      const n = SBC.count(s.id), av = SBC.available(s);
      const rp = s.reward.player ? P(s.reward.player) : null;
      return `<button class="tile" data-nav data-sbc="${s.id}" ${av ? '' : 'style="opacity:.5"'}><div class="tag pill ${av ? '' : 'good'}">${av ? (s.repeat > 1 ? `${n}/${s.repeat === 99 ? '∞' : s.repeat}` : 'NEW') : 'DONE'}</div>
        <h3 style="font-size:21px">${s.name}</h3><div class="sub">${s.desc}</div>
        <div class="art" style="min-height:150px">${rp ? `<div style="--cs:8px">${cardHTML(rp, { nav: false })}</div>` : `<div style="transform:scale(.8)">${packArtHTML(s.reward.pack)}</div>`}</div>
        <div style="font-size:12.5px;font-weight:700;color:var(--dim)">${s.size} players · ${s.reqs.length} requirement${s.reqs.length === 1 ? '' : 's'}</div>
        <div style="font-size:12.5px;font-weight:800;color:var(--teal);margin-top:2px">Reward: ${rewardText(s.reward)}</div></button>`;
    }).join('')}</div>`;
    $$('[data-c]', body).forEach(b => b.onclick = () => UI.go('sbc', { cat: b.dataset.c }, { replace: true, push: false }));
    $$('[data-sbc]', body).forEach(b => b.onclick = () => { const s = SBCS.find(x => x.id === b.dataset.sbc); if (!SBC.available(s)) return toast('Already completed'); UI.go('sbcbuild', { id: s.id, cat }); });
    return el;
  }
};
SCREENS.sbcbuild = {
  bg: 'hub',
  render(params) {
    const sbc = SBCS.find(x => x.id === params.id);
    const { el, body } = subShell(sbc.name, 'SBC · ' + sbc.cat);
    const st = Save.data.sbc.draft?.[sbc.id] || { formation: '4-3-3', uids: Array(sbc.size).fill(null) };
    st.uids = st.uids.filter(u => !u || Club.get(u)); while (st.uids.length < sbc.size) st.uids.push(null);
    const persist = () => { Save.data.sbc.draft = Save.data.sbc.draft || {}; Save.data.sbc.draft[sbc.id] = st; Save.dirty(); };
    const players = () => st.uids.map(u => u ? Club.player(u) : null);
    const draw = (focusIdx) => {
      const ps = players(), chk = sbcCheck(sbc, ps, st.formation);
      const grid = sbc.size === 11 ? pitchHTML(st.formation, ps, { chem: chk.chem, uids: st.uids }) :
        `<div class="row wrap" style="gap:16px;justify-content:center;align-content:center;height:100%">${ps.map((p, i) => `<div class="slot" data-slot="${i}">${p ? cardHTML(p, { uid: st.uids[i] }) : emptyCardHTML('ANY', false)}</div>`).join('')}</div>`;
      body.innerHTML = `<div class="row" style="gap:22px;flex:1;min-height:0;align-items:stretch">
        <div class="sb-side"><div class="panel col" style="padding:16px;gap:4px"><div class="h3" style="font-size:12px">Requirements</div>${chk.reqs.map(r => `<div class="req ${r.ok ? 'ok' : 'no'}"><i>${r.ok ? '✓' : '✕'}</i>${r.label}</div>`).join('')}</div>
          <div class="panel col" style="padding:16px;gap:6px"><div class="h3" style="font-size:12px">Reward</div><div style="font-weight:800;color:var(--teal)">${rewardText(sbc.reward)}</div></div>
          ${sbc.size === 11 ? `<label class="fld">Formation<select class="form" data-nav>${FORMATION_NAMES.map(f => `<option ${f === st.formation ? 'selected' : ''}>${f}</option>`).join('')}</select></label>` : ''}
          <div class="row wrap"><button class="btn small fill" data-nav>Auto-fill</button><button class="btn small clr" data-nav>Clear</button></div>
          <button class="btn ${chk.ok ? 'primary' : ''} sub" data-nav ${chk.ok ? '' : 'disabled'}>Submit squad</button>
          <div class="dim" style="font-size:12px">Submitted players are permanently removed from your club. Players in active market listings can't be used.</div></div>
        <div class="grow" style="min-width:0;display:flex;justify-content:center">${grid}</div></div>`;
      $$('.slot', body).forEach(s => { const i = +s.dataset.slot; $('.card', s).onclick = () => pickSlot(i); });
      const f = $('.form', body); if (f) f.onchange = e => { st.formation = e.target.value; persist(); draw(); };
      $('.clr', body).onclick = () => { st.uids = st.uids.map(() => null); persist(); draw(); };
      $('.fill', body).onclick = () => { autoFill(); persist(); draw(); };
      $('.sub', body).onclick = async () => {
        const vals = ps.filter(Boolean).reduce((s, p) => s + Market.value(p), 0);
        if (await modal({ title: 'Submit SBC?', body: `${sbc.size} players (est. value ${fmtFull(vals)} coins) will be exchanged for: <b>${rewardText(sbc.reward)}</b>`, buttons: [{ label: 'Cancel', value: false, cancel: true }, { label: 'Submit', value: true, primary: true }] })) {
          if (SBC.submit(sbc, st.uids, st.formation)) { Audio2.sfx('bigreveal'); if (Save.data.sbc.draft) delete Save.data.sbc.draft[sbc.id]; toast(`SBC complete! ${rewardText(sbc.reward)}`, 'good'); UI.go('sbc', { cat: params.cat }, { push: false }); UI.stack = []; }
        }
      };
      if (focusIdx != null) $(`.slot[data-slot="${focusIdx}"] .card`, body)?.focus();
    };
    const pickSlot = async (i) => {
      const used = new Set(st.uids.filter(Boolean));
      const usedPids = new Set([...used].map(u => Club.get(u).pid));
      if (st.uids[i]) {
        const v = await modal({ title: 'Slot', body: playerRowHTML(Club.player(st.uids[i])), buttons: [{ label: 'Replace', value: 'r', primary: true }, { label: 'Remove', value: 'x' }, { label: 'Cancel', value: null, cancel: true }] });
        if (v === 'x') { st.uids[i] = null; persist(); return draw(i); }
        if (v !== 'r') return draw(i);
      }
      const pos = sbc.size === 11 ? FORMATIONS[st.formation][i][0] : null;
      const u = await pickPlayer({ title: `Select player${pos ? ' · ' + pos : ''}`, pos, exclude: used, filter: it => !usedPids.has(it.pid) });
      if (u) { st.uids[i] = u; persist(); Audio2.sfx('select'); }
      draw(i);
    };
    // greedy auto-fill: lowest-value players that fit the requirements; prefers non-squad players
    const autoFill = () => {
      const allTier = sbc.reqs.find(r => r.t === 'tierAll');
      const minRat = sbc.reqs.find(r => r.t === 'rating')?.v || 0;
      const used = new Set(st.uids.filter(Boolean)), usedPids = new Set([...used].map(u => Club.get(u).pid));
      let pool = Save.data.club.items.filter(it => !used.has(it.uid) && !Club.inMarket(it.uid) && !usedPids.has(it.pid)).map(it => ({ it, p: P(it.pid) }));
      if (allTier) pool = pool.filter(x => tierOf(x.p.ovr) === allTier.v && x.p.type === 'base');
      const sameLg = sbc.reqs.find(r => r.t === 'sameLeague');
      if (sameLg) { const cnt = {}; pool.forEach(x => cnt[x.p.lg] = (cnt[x.p.lg] || 0) + 1); const best = Object.entries(cnt).sort((a, b) => b[1] - a[1])[0]?.[0]; pool = pool.filter(x => x.p.lg === best); }
      pool.sort((a, b) => (Club.inSquadAnywhere(a.it.uid) - Club.inSquadAnywhere(b.it.uid)) || (Math.abs(a.p.ovr - minRat) - Math.abs(b.p.ovr - minRat)));
      st.uids = st.uids.map((u, i) => {
        if (u) return u;
        const pos = sbc.size === 11 ? FORMATIONS[st.formation][i][0] : null;
        let k = pool.findIndex(x => (!pos || playerFitsPos(x.p, pos)) && !usedPids.has(x.p.id));
        if (k < 0) k = pool.findIndex(x => !usedPids.has(x.p.id) && (!pos || (pos === 'GK') === (x.p.pos === 'GK')));
        if (k < 0) return null;
        const x = pool.splice(k, 1)[0]; usedPids.add(x.p.id); return x.it.uid;
      });
      Audio2.sfx('select');
    };
    draw();
    return el;
  }
};

/* ---------------- TRANSFERS ---------------- */
SCREENS.transfers = {
  hub: true, bg: 'hub', back: hubBack,
  render(params) {
    const { el, body } = hubShell('transfers');
    const tab = params.tab || 'search';
    const mine = Save.data.market.mine;
    body.innerHTML = `<div class="row"><div class="page-title">Transfers</div><div class="spacer"></div><div class="seg">${[['search', 'Search Market'], ['list', `Transfer List (${mine.filter(l => l.status === 'active').length})`], ['bids', 'Transfer Targets'], ['history', 'History']].map(([k, l]) => `<button data-nav data-t="${k}" class="${k === tab ? 'on' : ''}">${l}</button>`).join('')}</div></div><div class="tb col" style="flex:1;min-height:0"></div>`;
    $$('[data-t]', body).forEach(b => b.onclick = () => UI.go('transfers', { tab: b.dataset.t }, { replace: true, push: false }));
    const tb = $('.tb', body);
    if (tab === 'search') renderMarketSearch(tb, params.f || Save.data.market.lastFilter || {});
    else if (tab === 'list') {
      const draw = () => {
        const now = Date.now();
        tb.innerHTML = `<div class="row" style="margin-bottom:10px"><div class="dim grow">Your listings. AI managers buy and bid in real time while the game is open. 5% tax on every sale.</div><button class="btn small add" data-nav>+ List a player</button><button class="btn small clr" data-nav>Clear sold/expired</button></div>
          <div class="scroll" style="flex:1"><table class="tbl"><tr><th>Player</th><th>Start</th><th>Buy Now</th><th>Current bid</th><th>Time left</th><th>Status</th><th></th></tr>
          ${mine.map(l => { const p = P(l.pid); return `<tr><td><span class="row" style="gap:8px"><span class="ovr ${ovrClass(p)}" style="font-family:var(--head);font-weight:900;padding:2px 6px;border-radius:5px">${p.ovr}</span>${esc(p.name)} <span class="dim">${p.pos}</span></span></td><td>${fmtFull(l.start)}</td><td>${fmtFull(l.bin)}</td><td>${l.bid ? fmtFull(l.bid) : '—'}</td><td>${l.status === 'active' ? fmtTime(l.ends - now) : '—'}</td>
            <td class="${l.status === 'sold' ? 'good' : l.status === 'expired' ? 'warn' : ''}">${l.status === 'sold' ? 'Sold ' + fmtFull(l.sold) : l.status}</td>
            <td>${l.status === 'active' && !l.bid ? `<button class="btn small" data-nav data-rm="${l.id}">Remove</button>` : l.status === 'expired' ? `<button class="btn small" data-nav data-re="${l.id}">Relist</button> <button class="btn small" data-nav data-rm="${l.id}">To club</button>` : ''}</td></tr>`; }).join('') || '<tr><td colspan=7 class="dim">No listings. List tradeable players from your Club or pack openings.</td></tr>'}</table></div>`;
        $$('[data-rm]', tb).forEach(b => b.onclick = () => { if (Market.removeListing(b.dataset.rm)) { toast('Returned to club'); draw(); } });
        $$('[data-re]', tb).forEach(b => b.onclick = async () => { const l = mine.find(x => x.id === b.dataset.re); Market.removeListing(l.id); if (await listDialog(l.uid)) draw(); else draw(); });
        $('.clr', tb).onclick = () => { Save.data.market.mine = mine.filter(l => l.status === 'active' || l.status === 'expired'); Save.dirty(); UI.rerender(); };
        $('.add', tb).onclick = async () => { const u = await pickPlayer({ title: 'List a player', allowUntr: false }); if (u && await listDialog(u)) UI.rerender(); };
      };
      draw(); UI.onMarketChange = () => UI.curName === 'transfers' && draw();
      UI.every(1000, () => { if (document.activeElement?.closest('.tb') && document.activeElement.tagName === 'BUTTON') return; const tds = $$('td', tb); if (tds.length) draw(); });
    } else if (tab === 'bids') {
      const draw = () => {
        const bids = Save.data.market.bids, now = Date.now();
        tb.innerHTML = `<div class="dim" style="margin-bottom:10px">Your active and recent bids. Coins are held while you are the highest bidder and refunded if you're outbid.</div><div class="scroll" style="flex:1"><table class="tbl"><tr><th>Player</th><th>Your bid</th><th>Current</th><th>Time left</th><th>Status</th><th></th></tr>
          ${bids.map((b, i) => { const p = P(b.pid); return `<tr><td>${p.ovr} ${esc(p.name)} <span class="dim">${p.pos}</span></td><td>${fmtFull(b.amt)}</td><td>${fmtFull(b.listing.bid)}</td><td>${b.status === 'winning' || b.status === 'outbid' ? fmtTime(b.listing.ends - now) : '—'}</td><td class="${b.status === 'won' ? 'good' : b.status === 'outbid' ? 'bad' : b.status === 'winning' ? 'good' : 'dim'}">${b.status}</td><td>${b.status === 'outbid' && b.listing.ends > now ? `<button class="btn small" data-nav data-rb="${i}">Bid again</button>` : ''}</td></tr>`; }).join('') || '<tr><td colspan=6 class="dim">No bids yet</td></tr>'}</table></div>`;
        $$('[data-rb]', tb).forEach(b => b.onclick = () => { const bd = Save.data.market.bids[+b.dataset.rb]; bidDialog(bd.listing).then(draw); });
      };
      draw(); UI.onMarketChange = () => UI.curName === 'transfers' && draw();
      UI.every(1000, () => { if (document.activeElement?.closest('.tb') && document.activeElement.tagName === 'BUTTON') return; draw(); });
    } else {
      tb.innerHTML = `<div class="scroll" style="flex:1"><table class="tbl"><tr><th>Date</th><th>Type</th><th>Player</th><th style="text-align:right">Price</th></tr>${Save.data.market.history.map(x => { const p = P(x.pid); return `<tr><td>${new Date(x.t).toLocaleString()}</td><td class="${x.kind === 'sell' ? 'good' : ''}">${x.kind === 'buy' ? 'Bought' : 'Sold'}</td><td>${p.ovr} ${esc(p.name)}</td><td style="text-align:right">${fmtFull(x.price)}</td></tr>`; }).join('') || '<tr><td colspan=4 class="dim">No transfers yet</td></tr>'}</table></div>`;
    }
    return el;
  }
};
function renderMarketSearch(tb, f) {
  tb.innerHTML = `<div class="filters" style="margin-bottom:10px">
    <label class="fld">Name<input type="text" class="fn" value="${esc(f.name || '')}" data-nav style="width:150px"></label>
    <label class="fld">Position<select class="fpos" data-nav><option value="">Any</option>${POSITIONS.map(p => `<option ${p === f.pos ? 'selected' : ''}>${p}</option>`).join('')}</select></label>
    <label class="fld">League<select class="flg" data-nav><option value="">Any</option>${Object.entries(LEAGUES).map(([k, L]) => `<option value="${k}" ${k === f.lg ? 'selected' : ''}>${L.name}</option>`).join('')}</select></label>
    <label class="fld">Nation<select class="fnat" data-nav><option value="">Any</option>${Object.entries(NATIONS).map(([k, N]) => `<option value="${k}" ${k === f.nat ? 'selected' : ''}>${N.name}</option>`).join('')}</select></label>
    <label class="fld">Club<select class="fclub" data-nav><option value="">Any</option>${Object.entries(CLUBS).map(([k, C]) => `<option value="${k}" ${k === f.club ? 'selected' : ''}>${C.name}</option>`).join('')}</select></label>
    <label class="fld">Rarity<select class="frar" data-nav><option value="">Any</option>${[['bronze', 'Bronze'], ['bronze-rare', 'Rare Bronze'], ['silver', 'Silver'], ['silver-rare', 'Rare Silver'], ['gold', 'Gold'], ['gold-rare', 'Rare Gold'], ['rare', 'Any rare'], ['special', 'Special']].map(([k, l]) => `<option value="${k}" ${k === f.rar ? 'selected' : ''}>${l}</option>`).join('')}</select></label>
    <label class="fld">Min OVR<input type="number" class="fmin" value="${f.minOvr || ''}" min="40" max="99" data-nav style="width:76px"></label>
    <label class="fld">Max OVR<input type="number" class="fmax" value="${f.maxOvr || ''}" min="40" max="99" data-nav style="width:76px"></label>
    <label class="fld">Max BIN<input type="number" class="fbin" value="${f.maxBin || ''}" step="500" data-nav style="width:100px"></label>
    <label class="fld">Sort<select class="fsort" data-nav>${[['ends', 'Time left'], ['bin-asc', 'Price ↑'], ['bin-desc', 'Price ↓'], ['ovr', 'Rating']].map(([k, l]) => `<option value="${k}" ${k === f.sort ? 'selected' : ''}>${l}</option>`).join('')}</select></label>
    <button class="btn primary go" data-nav>Search</button></div>
    <div class="res scroll col" style="flex:1;gap:6px"></div>`;
  const res = $('.res', tb);
  const doSearch = (useCache) => {
    const g = s => $(s, tb).value;
    const nf = { name: g('.fn').trim(), pos: g('.fpos'), lg: g('.flg'), nat: g('.fnat'), club: g('.fclub'), rar: g('.frar'), minOvr: +g('.fmin') || 0, maxOvr: +g('.fmax') || 0, maxBin: +g('.fbin') || 0, sort: g('.fsort') };
    Save.data.market.lastFilter = nf;
    const list = useCache && Save.data.market.listings.length ? Save.data.market.listings.filter(l => l.ends > Date.now()) : Market.search(nf);
    drawRes(list);
  };
  const drawRes = (list) => {
    const now = Date.now();
    res.innerHTML = list.length ? list.map((l, i) => { const p = P(l.pid); return playerRowHTML(p, `<span class="dim" style="width:80px;font-size:12px">${fmtTime(l.ends - now)}</span><span style="width:120px;font-size:12.5px">Bid ${l.bid ? `<b>${fmtFull(l.bid)}</b>${l.bidder === 'me' ? ' <span class="good">(you)</span>' : ''}` : `start ${fmtFull(l.start)}`}</span><span style="width:110px;font-weight:900"><i class="coin"></i> ${fmtFull(l.bin)}</span>`, `data-l="${i}"`); }).join('') : '<div class="dim" style="padding:20px">No results. Try widening your filters.</div>';
    $$('[data-l]', res).forEach(b => b.onclick = () => listingActions(list[+b.dataset.l]).then(() => drawRes(list.filter(l => Save.data.market.listings.includes(l) || l.bidder === 'me'))));
  };
  $('.go', tb).onclick = () => doSearch(false);
  $$('input', tb).forEach(i => i.addEventListener('keydown', e => { if (e.key === 'Enter') doSearch(false); }));
  doSearch(true);
}
async function listingActions(l) {
  const p = P(l.pid);
  const v = await inspectCard(p, { actions: [{ label: `Buy Now ${fmtFull(l.bin)}`, value: 'buy', primary: true }, { label: `Bid (min ${fmtFull(Market.minBid(l))})`, value: 'bid' }] });
  if (v === 'buy') {
    if (await modal({ title: 'Confirm purchase', body: `Buy <b>${esc(p.name)}</b> (${p.ovr}) for <b>${fmtFull(l.bin)}</b> coins?<div class="dim" style="margin-top:6px">Balance after: ${fmtFull(Save.data.coins - l.bin)}</div>`, buttons: [{ label: 'Cancel', value: false, cancel: true }, { label: 'Buy Now', value: true, primary: true }] })) {
      if (Market.buyNow(l)) { Audio2.sfx('bigreveal'); toast(`${p.name} added to your club!`, 'good'); }
    }
  } else if (v === 'bid') await bidDialog(l);
}
async function bidDialog(l) {
  const p = P(l.pid);
  const body = h(`<div class="col"><div>${playerRowHTML(p)}</div><div class="dim">Current: ${l.bid ? fmtFull(l.bid) : 'no bids'} · Buy Now ${fmtFull(l.bin)} · ends in ${fmtTime(l.ends - Date.now())}</div><label class="fld">Your bid<input type="number" class="amt" step="50" value="${Market.minBid(l)}" data-nav></label></div>`);
  if (await modal({ title: 'Place bid', body, buttons: [{ label: 'Cancel', value: false, cancel: true }, { label: 'Place bid', value: true, primary: true }] })) {
    if (Market.placeBid(l, +$('.amt', body).value)) toast('Bid placed — check Transfer Targets', 'good');
  }
}

/* ---------------- PLAY hub ---------------- */
SCREENS.play = {
  hub: true, bg: 'hub', back: hubBack,
  render() {
    const { el, body } = hubShell('play');
    const m = Save.data.modes, rv = m.rivals;
    if (m.sb.weekKey !== weekKey()) { m.sb.weekKey = weekKey(); m.sb.points = 0; m.sb.played = 0; }
    const sbRank = SB_RANKS.find(r => m.sb.points >= r.pts);
    const sq = Squads.active(), inf = Squads.info(sq);
    body.innerHTML = `<div class="row"><div class="page-title">Play</div><div class="spacer"></div><div class="dim" style="font-weight:700">Active squad: ${esc(sq.name)} · ${inf.rating} OVR · ${inf.chem.total} chem ${Squads.isComplete(sq) ? '' : '<span class="bad">· incomplete!</span>'}</div></div>
      <div class="tiles" style="grid-template-columns:1.2fr 1fr 1fr;grid-template-rows:1fr 1fr;flex:1;min-height:0">
        <button class="tile big" data-nav data-m="rivals" style="grid-row:span 2"><div class="glow"></div><h3>Division Rivals</h3><div class="sub">Climb from Division 10 to Elite. Promotion at 10 points (Win 3 · Draw 1 · Loss -1).</div>
          <div class="art"><div style="text-align:center"><div style="font-family:var(--head);font-weight:900;font-size:64px;color:var(--teal)">${rv.div === 1 ? 'ELITE' : rv.div}</div><div style="font-weight:800">${RIVALS_DIVS[rv.div].name}</div><div class="bar" style="width:240px;margin:12px auto"><i style="width:${rv.pts * 10}%"></i></div><div class="dim">${rv.pts}/10 points · ${rv.wins} career wins</div></div></div></button>
        <button class="tile" data-nav data-m="sb"><h3>Squad Battles</h3><div class="sub">Play AI squads. Earn points by difficulty & performance.</div><div class="art"><div style="text-align:center"><b style="font-size:28px">${fmtFull(m.sb.points)}</b><div class="dim">pts this week · ${sbRank.name}</div></div></div></button>
        <button class="tile" data-nav data-m="champs"><h3>Champions</h3><div class="sub">${Champions.maxMatches}-match elite tournament. Requires a ticket (Rivals).</div><div class="art"><div style="text-align:center">${m.champs.active ? `<b style="font-size:28px">${m.champs.active.w}-${m.champs.active.l}</b><div class="dim">${m.champs.active.played}/${Champions.maxMatches} played</div>` : `<b style="font-size:28px">${m.champs.tickets}</b><div class="dim">ticket(s)</div>`}</div></div></button>
        <button class="tile" data-nav data-m="draft"><h3>Draft</h3><div class="sub">Pick a formation and build a temporary squad from random choices. Win 4 straight.</div><div class="art"><div style="text-align:center">${m.draft.active ? `<b style="font-size:22px">In progress</b><div class="dim">${m.draft.active.wins} wins</div>` : `<div class="dim"><i class="coin"></i> ${fmtFull(DRAFT_COST.coins)} or <i class="pts"></i> ${DRAFT_COST.points}</div>`}</div></div></button>
        <button class="tile" data-nav data-m="friendly"><h3>Friendlies</h3><div class="sub">Casual matches with custom rules. No stakes.</div><div class="art" style="font-size:44px">⚽</div></button>
      </div>`;
    $$('[data-m]', body).forEach(b => b.onclick = () => { Audio2.sfx('select'); UI.go({ rivals: 'rivals', sb: 'squadbattles', champs: 'champions', draft: 'draft', friendly: 'friendlies' }[b.dataset.m]); });
    return el;
  }
};
function requireSquad() {
  const sq = Squads.active();
  if (!Squads.isComplete(sq)) { modal({ title: 'Squad incomplete', body: 'Your active squad needs 11 players before you can play. Use Auto-build in the Squad Builder.', buttons: [{ label: 'Open Squad Builder', value: true, primary: true }, { label: 'Cancel', value: false, cancel: true }] }).then(v => v && UI.go('squad')); return false; }
  return true;
}
function userTeam(useAway = false) {
  const sq = Squads.active(), pr = Save.data.profile;
  const players = Squads.players(sq), subs = sq.subs.map(u => u ? Club.player(u) : null).filter(Boolean);
  return { name: pr.clubName, short: pr.clubName.slice(0, 3).toUpperCase(), kit: useAway ? pr.kit.away : pr.kit.home, formation: sq.formation, players, subs, badge: pr.badge, chem: Squads.info(sq).chem, isUser: true };
}
function aiTeam(name, strength, kit) {
  const s = buildAISquad(strength);
  const k = kit || { c1: R.pick(['#c8102e', '#034694', '#ffffff', '#111111', '#00954c', '#6b2ea6', '#ff7f00', '#12a0d7']), c2: R.pick(['#ffffff', '#111111', '#ffd23f']) };
  return { name, short: name.replace(/[^A-Z]/g, '').slice(0, 3) || name.slice(0, 3).toUpperCase(), kit: k, formation: s.formation, players: s.players, subs: s.subs };
}
function kitClash(a, b) { const hex = c => [1, 3, 5].map(i => parseInt(c.slice(i, i + 2), 16)); const x = hex(a), y = hex(b); return Math.hypot(x[0] - y[0], x[1] - y[1], x[2] - y[2]) < 120; }

/* match result bookkeeping for UT modes */
function recordUTMatch(res, mode) {
  const st = Save.data.stats, u = res.userSide === 'away' ? 'away' : 'home';
  const gf = u === 'home' ? res.hg : res.ag, ga = u === 'home' ? res.ag : res.hg;
  const r = gf > ga ? 'W' : gf < ga ? 'L' : (res.pens ? (res.winner === u ? 'W' : 'L') : 'D');
  st.played++; st.gf += gf; st.ga += ga; if (r === 'W') st.wins++; else if (r === 'L') st.losses++; else st.draws++;
  Objectives.track('match');
  if (gf) Objectives.track('goal', gf);
  if (r === 'W') Objectives.track('win');
  if (ga === 0) Objectives.track('cleansheet');
  const myGoals = res.goals.filter(g => g.side === u && !g.og);
  const assists = myGoals.filter(g => g.assist).length; if (assists) { Objectives.track('assist', assists); st.assists += assists; }
  if (myGoals.some(g => POS_GROUP[g.pos] === 'MID')) Objectives.track('goal_mid');
  XP.add(r === 'W' ? 300 : r === 'D' ? 180 : 120);
  return r;
}
function logMatch(res, mode, r) {
  Save.data.matches.unshift({ t: Date.now(), mode, home: res.home.name, away: res.away.name, hg: res.hg, ag: res.ag, res: r });
  if (Save.data.matches.length > 100) Save.data.matches.length = 100;
  Save.dirty();
}
function league3Check(team) {
  const c = {}; team.players.forEach(p => { if (p) c[p.lg] = (c[p.lg] || 0) + 1; });
  if (Object.values(c).some(n => n >= 3)) Objectives.track('league3');
}

/* ---------------- Squad Battles ---------------- */
SCREENS.squadbattles = {
  bg: 'hub',
  render() {
    const { el, body } = subShell('Squad Battles', 'Play');
    const sb = Save.data.modes.sb;
    if (!sb.opps || sb.oppsWeek !== weekKey()) {
      sb.oppsWeek = weekKey();
      sb.opps = R.shuffle(AI_SQUAD_NAMES).slice(0, 8).map((n, i) => ({ name: n, str: 66 + i * 3 + R.int(0, 2), done: [] }));
      Save.dirty();
    }
    const rank = SB_RANKS.find(r => sb.points >= r.pts);
    const nextRank = SB_RANKS.slice().reverse().find(r => r.pts > sb.points);
    // weekly leaderboard: simulated rivals + you
    const lb = AI_SQUAD_NAMES.slice(0, 9).map((n, i) => ({ n: `${n.split(' ')[0]}Mgr${(hashStr(n + weekKey()) % 900) + 100}`, p: Math.round((hashStr(n + weekKey()) % 3800) * Math.min(1, (Date.now() % 604800000) / 604800000 + 0.15)) }));
    lb.push({ n: Save.data.profile.name + ' (you)', p: sb.points, me: true }); lb.sort((a, b) => b.p - a.p);
    body.innerHTML = `<div class="row" style="gap:20px;flex:1;min-height:0;align-items:stretch">
      <div class="col grow" style="min-width:0"><div class="dim" style="margin-bottom:10px">Choose an opponent and difficulty. Higher difficulty = more points. Points also scale with goals scored and clean sheets. Rank rewards are granted when you claim at week end.</div>
        <div class="tiles scroll" style="grid-template-columns:repeat(auto-fill,minmax(230px,1fr));align-content:start;flex:1">${sb.opps.map((o, i) => `<button class="tile" data-nav data-o="${i}"><h3 style="font-size:19px">${o.name}</h3><div class="sub">Squad rating ~${o.str}</div><div class="dim" style="margin-top:8px;font-size:12.5px">Beaten on: ${o.done.length ? o.done.map(d => DIFFICULTIES[d].name).join(', ') : '—'}</div></button>`).join('')}</div></div>
      <div class="col" style="width:330px;gap:14px">
        <div class="panel" style="padding:18px"><div class="h3">This week</div><div style="font-family:var(--head);font-weight:900;font-size:34px;margin:6px 0">${fmtFull(sb.points)}</div><div style="font-weight:800">${rank.name}</div>${nextRank ? `<div class="dim" style="font-size:12.5px">${fmtFull(nextRank.pts - sb.points)} pts to ${nextRank.name}</div>` : ''}
          ${rank.reward ? `<div style="font-size:12.5px;color:var(--teal);margin-top:6px">Current reward: ${rewardText(rank.reward)}</div><button class="btn small primary cl" data-nav style="margin-top:8px" ${sb.claimedWeek === weekKey() ? 'disabled' : ''}>${sb.claimedWeek === weekKey() ? 'Claimed this week' : 'Claim rank reward'}</button>` : ''}</div>
        <div class="panel col scroll" style="padding:14px;flex:1;min-height:0"><div class="h3">Weekly leaderboard</div><table class="tbl">${lb.map((r, i) => `<tr class="${r.me ? 'me' : ''}"><td>${i + 1}</td><td>${esc(r.n)}</td><td style="text-align:right"><b>${fmtFull(r.p)}</b></td></tr>`).join('')}</table></div></div></div>`;
    const cl = $('.cl', body); if (cl) cl.onclick = async () => { if (await modal({ title: 'Claim rank reward?', body: `Claiming locks in <b>${rank.name}</b> for this week: ${rewardText(rank.reward)}. You can keep playing to earn objective progress.`, buttons: [{ label: 'Cancel', value: false, cancel: true }, { label: 'Claim', value: true, primary: true }] })) { sb.claimedWeek = weekKey(); grantReward(rank.reward, `Squad Battles ${rank.name}`); UI.rerender(); } };
    $$('[data-o]', body).forEach(b => b.onclick = async () => {
      if (!requireSquad()) return;
      const o = sb.opps[+b.dataset.o];
      const d = await chooseDifficulty(o.name);
      if (!d) return;
      const D = DIFFICULTIES[d];
      const ut = userTeam(), opp = aiTeam(o.name, Math.round((o.str + D.ovr) / 2));
      league3Check(ut);
      runMatch({ home: ut, away: opp, userSide: 'home', difficulty: d, halfLen: Save.data.settings.halfLen, mode: 'sb', title: 'Squad Battles' }, res => {
        const r = recordUTMatch(res, 'sb');
        let pts = D.sbPts * (r === 'W' ? 1 : r === 'D' ? 0.5 : 0.2) + res.hg * 10 + (res.ag === 0 ? 20 : 0);
        pts = Math.round(pts);
        sb.points += pts; sb.played++;
        if (r === 'W') { Objectives.track('sb_win'); if (!o.done.includes(d)) o.done.push(d); }
        const coins = D.coins * (r === 'W' ? 2 : 1);
        Wallet.add('coins', coins, `Squad Battles vs ${o.name}`);
        logMatch(res, 'Squad Battles', r);
        showResults(res, { title: 'Squad Battles', rewards: `+${pts} SB points · +${fmtFull(coins)} coins`, onContinue: () => UI.go('squadbattles', {}, { push: false }) });
      });
    });
    return el;
  }
};
async function chooseDifficulty(name) {
  const body = h(`<div class="col" style="gap:8px">${Object.entries(DIFFICULTIES).map(([k, d]) => `<button class="prow" data-nav data-d="${k}"><b class="grow">${d.name}</b><span class="dim">${d.sbPts} pts · ${fmtFull(d.coins)} coins</span></button>`).join('')}</div>`);
  return new Promise(res => {
    modal({ title: `vs ${name} — choose difficulty`, body, buttons: [{ label: 'Cancel', value: null, cancel: true }], onOpen: (el, close) => $$('[data-d]', el).forEach(b => b.onclick = () => close(b.dataset.d)) }).then(res);
  });
}

/* ---------------- Division Rivals ---------------- */
SCREENS.rivals = {
  bg: 'hub',
  render() {
    const { el, body } = subShell('Division Rivals', 'Play');
    const rv = Save.data.modes.rivals;
    body.innerHTML = `<div class="row" style="gap:24px;flex:1;align-items:stretch">
      <div class="panel col" style="padding:26px;flex:1;gap:16px;align-items:center;justify-content:center">
        <div style="font-family:var(--head);font-weight:900;font-size:90px;color:var(--teal);line-height:1">${rv.div === 1 ? 'ELITE' : rv.div}</div><div class="h2">${RIVALS_DIVS[rv.div].name}</div>
        <div class="row" style="gap:8px">${Array.from({ length: 10 }, (_, i) => `<i style="width:28px;height:10px;border-radius:4px;background:${i < rv.pts ? 'var(--teal)' : 'rgba(255,255,255,.12)'}"></i>`).join('')}</div>
        <div class="dim">${rv.pts}/10 points to promotion · falling below 0 relegates</div>
        <div class="dim">Opponent strength ~${Math.round(Rivals.oppStrength(rv.div))} · Difficulty ${DIFFICULTIES[Rivals.difficulty(rv.div)].name}</div>
        <button class="btn primary go" data-nav data-autofocus style="font-size:16px"><span class="key">A</span> Find match</button></div>
      <div class="panel col" style="padding:20px;width:360px;gap:8px"><div class="h3">Rewards</div>
        <div class="kv"><span>Win</span><span>${fmtFull(900 + (11 - rv.div) * 60)} coins · +3 pts</span><span>Draw</span><span>${fmtFull(450 + (11 - rv.div) * 60)} coins · +1 pt</span><span>Loss</span><span>${fmtFull(200 + (11 - rv.div) * 60)} coins · -1 pt</span><span>Promotion</span><span>Premium/Jumbo pack + 50 Prime Points</span><span>Champions ticket</span><span>Every 3 weekly wins in Div 5 or better</span></div>
        <div class="h3" style="margin-top:14px">Record</div><div class="kv"><span>Played</span><span>${rv.played}</span><span>Wins</span><span>${rv.wins}</span><span>Best division</span><span>${RIVALS_DIVS[rv.best].name}</span><span>Champions tickets</span><span>${Save.data.modes.champs.tickets}</span></div></div></div>`;
    $('.go', body).onclick = () => {
      if (!requireSquad()) return;
      const ut = userTeam();
      const oppName = `${R.pick(['Ace', 'Pro', 'King', 'Volt', 'Nova', 'Zed', 'Kai', 'Rex'])}${R.pick(['_FC', 'Gaming', '99', 'Utd', 'XI', '_27'])}`;
      const opp = aiTeam(oppName, Math.round(Rivals.oppStrength(rv.div)));
      league3Check(ut);
      runMatch({ home: ut, away: opp, userSide: 'home', difficulty: Rivals.difficulty(rv.div), halfLen: Save.data.settings.halfLen, mode: 'rivals', title: 'Division Rivals' }, res => {
        const r = recordUTMatch(res, 'rivals'), out = Rivals.record(r);
        logMatch(res, 'Rivals', r);
        showResults(res, { title: 'Division Rivals', rewards: `+${fmtFull(out.coins)} coins${out.msg ? ' · ' + out.msg : ''}`, onContinue: () => UI.go('rivals', {}, { push: false }) });
      });
    };
    return el;
  }
};

/* ---------------- Champions ---------------- */
SCREENS.champions = {
  bg: 'hub',
  render() {
    const { el, body } = subShell('Champions', 'Play');
    const c = Save.data.modes.champs, a = c.active;
    body.innerHTML = `<div class="row" style="gap:24px;flex:1;align-items:stretch">
      <div class="panel col" style="padding:26px;flex:1;gap:16px;align-items:center;justify-content:center">
        ${a ? `<div class="h3">Champions · in progress</div><div style="font-family:var(--head);font-weight:900;font-size:90px">${a.w}<span class="dim">-</span>${a.l}</div>
          <div class="row" style="gap:6px">${Array.from({ length: Champions.maxMatches }, (_, i) => `<i style="width:22px;height:22px;border-radius:50%;background:${i < a.played ? 'rgba(63,224,197,.8)' : 'rgba(255,255,255,.1)'}"></i>`).join('')}</div>
          <div class="dim">Next reward tier: ${rewardText(Champions.rewardFor(a.w + 1))}</div>
          ${a.played < Champions.maxMatches ? '<button class="btn primary go" data-nav data-autofocus><span class="key">A</span> Play next match</button>' : '<button class="btn primary fin" data-nav data-autofocus>Claim rewards</button>'}
          <button class="btn small danger quit" data-nav>Finish early & claim</button>` :
        `<div style="font-size:90px">🏆</div><div class="h2">Champions</div><div class="dim" style="max-width:460px;text-align:center">A ${Champions.maxMatches}-match tournament against elite opposition (~88 OVR, Legendary). Rewards scale with wins. Earn tickets in Division Rivals.</div>
          <div style="font-weight:800">Tickets: ${c.tickets}</div>
          <div class="row"><button class="btn primary start" data-nav data-autofocus ${c.tickets ? '' : 'disabled'}><span class="key">A</span> Use ticket & start</button><button class="btn buy" data-nav>Buy ticket (<i class="pts"></i> 600)</button></div>`}
      </div>
      <div class="panel col" style="padding:20px;width:360px;gap:8px"><div class="h3">Reward tiers</div><div class="kv">${[9, 7, 5, 3, 0].map(w => `<span>${w}+ wins</span><span style="font-size:13px">${rewardText(Champions.rewardFor(w))}</span>`).join('')}</div>
        <div class="h3" style="margin-top:14px">History</div>${c.history.slice(0, 8).map(x => `<div class="dim" style="font-size:13px">${new Date(x.t).toLocaleDateString()} · ${x.w}-${x.l}</div>`).join('') || '<div class="dim">None yet</div>'}</div></div>`;
    const st = $('.start', body); if (st) st.onclick = () => { if (Champions.start()) UI.rerender(); };
    const by = $('.buy', body); if (by) by.onclick = () => { if (Wallet.spend('points', 600, 'Champions ticket')) { c.tickets++; Save.dirty(); UI.rerender(); } };
    const fin = () => { const rw = Champions.finish(); Audio2.sfx('bigreveal'); modal({ title: 'Champions rewards', body: rewardText(rw) }).then(() => UI.rerender()); };
    const fb = $('.fin', body); if (fb) fb.onclick = fin;
    const qb = $('.quit', body); if (qb) qb.onclick = async () => { if (await modal({ title: 'Finish now?', body: `You'll receive the ${a.w}-win rewards.`, buttons: [{ label: 'Cancel', value: false, cancel: true }, { label: 'Finish', value: true, primary: true }] })) fin(); };
    const go = $('.go', body); if (go) go.onclick = () => {
      if (!requireSquad()) return;
      const ut = userTeam(), opp = aiTeam(`${R.pick(['Elite', 'Prime', 'Apex', 'Legend'])} ${R.pick(['Gamer', 'Squad', 'FC', 'XI'])} ${R.int(1, 99)}`, R.int(85, 90));
      league3Check(ut);
      runMatch({ home: ut, away: opp, userSide: 'home', difficulty: 'legendary', halfLen: Save.data.settings.halfLen, mode: 'champs', title: `Champions · Match ${a.played + 1}`, knockout: true }, res => {
        const r0 = recordUTMatch(res, 'champs'); const r = r0 === 'D' ? (res.winner === 'home' ? 'W' : 'L') : r0;
        Champions.record(r); logMatch(res, 'Champions', r);
        showResults(res, { title: 'Champions', rewards: r === 'W' ? '+1,500 coins' : '+400 coins', onContinue: () => UI.go('champions', {}, { push: false }) });
      });
    };
    return el;
  }
};

/* ---------------- Draft ---------------- */
SCREENS.draft = {
  bg: 'hub',
  render() {
    const { el, body } = subShell('Draft', 'Play');
    const d = Save.data.modes.draft;
    if (!d.active) {
      body.innerHTML = `<div class="panel col" style="padding:28px;max-width:640px;gap:14px;margin:auto"><div class="h2">Start a Draft</div>
        <div class="dim">Choose a formation, then pick a captain and one player for each position from five random choices — including Team of the Week, Nightfall, Heroes and Icons. Your draft squad is temporary. Win up to 4 knockout matches for rewards.</div>
        <div class="kv">${[0, 1, 2, 3, 4].map(w => `<span>${w} wins</span><span style="font-size:13px">${rewardText(Draft.rewardFor(w))}</span>`).join('')}</div>
        <div class="row"><button class="btn primary c" data-nav data-autofocus>Enter (<i class="coin"></i> ${fmtFull(DRAFT_COST.coins)})</button><button class="btn p" data-nav>Enter (<i class="pts"></i> ${DRAFT_COST.points})</button></div></div>`;
      const start = (cur) => { if (!Wallet.spend(cur, DRAFT_COST[cur], 'Draft entry')) return; d.active = { formation: null, slots: Array(11).fill(null), captain: null, wins: 0, stage: 'formation' }; Save.dirty(); UI.rerender(); };
      $('.c', body).onclick = () => start('coins'); $('.p', body).onclick = () => start('points');
      return el;
    }
    const A = d.active;
    if (A.stage === 'formation') {
      const opts = R.shuffle(FORMATION_NAMES).slice(0, 5);
      body.innerHTML = `<div class="page-title" style="font-size:28px">Choose your formation</div><div class="row wrap" style="gap:16px">${opts.map(f => `<button class="tile" data-nav data-f="${f}" style="width:200px;height:260px"><h3>${f}</h3><div class="art">${miniPitchSVG(f, [])}</div></button>`).join('')}</div>`;
      $$('[data-f]', body).forEach(b => b.onclick = () => { A.formation = b.dataset.f; A.stage = 'pick'; Save.dirty(); UI.rerender(); });
      return el;
    }
    const players = A.slots.map(id => id ? P(id) : null);
    const chem = computeChemistry(A.formation, players);
    if (A.stage === 'pick') {
      body.innerHTML = `<div class="row" style="gap:22px;flex:1;min-height:0;align-items:stretch"><div class="sb-side"><div class="statbig"><div><b>${squadRating(players)}</b><span>Rating</span></div><div><b>${chem.total}</b><span>Chem</span></div></div><div class="dim">Select each position on the pitch to pick from 5 players. ${A.captain ? '' : 'Start with your captain (any position).'}</div>
        ${A.slots.every(Boolean) ? '<button class="btn primary done" data-nav data-autofocus>Start tournament</button>' : ''}<button class="btn small danger ab" data-nav>Abandon draft</button></div>
        <div class="grow" style="display:flex;justify-content:center">${pitchHTML(A.formation, players, { chem, captainIdx: A.slots.indexOf(A.captain) })}</div></div>`;
      $$('.pitch .slot', body).forEach(s => $('.card', s).onclick = () => draftPick(+s.dataset.slot));
      const dn = $('.done', body); if (dn) dn.onclick = () => { A.stage = 'play'; Save.dirty(); UI.rerender(); };
      $('.ab', body).onclick = async () => { if (await modal({ title: 'Abandon draft?', body: 'Your entry fee is not refunded.', buttons: [{ label: 'Cancel', value: false, cancel: true }, { label: 'Abandon', value: true, danger: true }] })) { d.active = null; Save.dirty(); UI.rerender(); } };
      async function draftPick(i) {
        if (A.slots[i]) return toast('Already picked');
        const pos = FORMATIONS[A.formation][i][0];
        const exclude = new Set(A.slots.filter(Boolean));
        const ch = !A.captain ? R.shuffle(DB.players.filter(p => p.ovr >= 86 && !exclude.has(p.id) && playerFitsPos(p, pos))).slice(0, 5) : Draft.choices(pos, exclude);
        const bodyEl = h(`<div class="row wrap" style="gap:12px;justify-content:center">${ch.map(p => `<div class="col" style="align-items:center">${cardHTML(p)}<div style="font-size:11px;font-weight:800" class="dim">${rarityName(p)}</div></div>`).join('')}</div>`);
        const pick = await new Promise(res => modal({ title: `${!A.captain ? 'Pick your captain' : 'Pick'} · ${pos}`, body: bodyEl, wide: true, buttons: [{ label: 'Cancel', value: null, cancel: true }], onOpen: (m, close) => $$('.card', m).forEach(c => c.onclick = () => close(c.dataset.pid)) }).then(res));
        if (pick) { A.slots[i] = pick; if (!A.captain) A.captain = pick; Audio2.sfx('reveal'); Save.dirty(); UI.rerender(); }
      }
      return el;
    }
    // play stage
    const opp = A.opp || (A.opp = { name: R.pick(AI_SQUAD_NAMES), str: 80 + A.wins * 2.5 });
    body.innerHTML = `<div class="row" style="gap:22px;flex:1;min-height:0;align-items:stretch"><div class="sb-side">
        <div class="h2">${Draft.rounds[A.wins]}</div><div class="dim">vs ${opp.name} (~${Math.round(opp.str)} OVR)</div>
        <div class="row" style="gap:6px">${Draft.rounds.map((r, i) => `<span class="pill ${i < A.wins ? 'good' : ''}">${r.split('-')[0].replace('Round of 16', 'R16')}</span>`).join('')}</div>
        <div class="dim" style="font-size:13px">Current reward: ${rewardText(Draft.rewardFor(A.wins))}</div>
        <button class="btn primary go" data-nav data-autofocus><span class="key">A</span> Play ${Draft.rounds[A.wins]}</button><button class="btn small qt" data-nav>Quit & claim rewards</button></div>
      <div class="grow" style="display:flex;justify-content:center">${pitchHTML(A.formation, players, { chem, captainIdx: A.slots.indexOf(A.captain) })}</div></div>`;
    const end = () => { const rw = Draft.rewardFor(A.wins); grantReward(rw, `Draft: ${A.wins} wins`); d.history.unshift({ t: Date.now(), w: A.wins }); d.active = null; Save.dirty(); Audio2.sfx('bigreveal'); modal({ title: `Draft over — ${A.wins} win${A.wins === 1 ? '' : 's'}`, body: `Rewards: <b>${rewardText(rw)}</b>` }).then(() => UI.rerender()); };
    $('.qt', body).onclick = end;
    $('.go', body).onclick = () => {
      const pr = Save.data.profile;
      const team = { name: pr.clubName + ' Draft', short: 'DRF', kit: pr.kit.home, formation: A.formation, players, subs: [], badge: pr.badge, chem, isUser: true };
      const o = aiTeam(opp.name, Math.round(opp.str));
      runMatch({ home: team, away: o, userSide: 'home', difficulty: A.wins >= 2 ? 'worldclass' : 'professional', halfLen: Save.data.settings.halfLen, mode: 'draft', title: `Draft · ${Draft.rounds[A.wins]}`, knockout: true }, res => {
        const r0 = recordUTMatch(res, 'draft'); const won = res.winner === 'home';
        logMatch(res, 'Draft', won ? 'W' : 'L');
        if (won) { A.wins++; A.opp = null; Objectives.track('draft_win'); }
        Save.dirty();
        showResults(res, { title: 'Draft', rewards: won ? (A.wins >= 4 ? 'Draft champion!' : 'Through to the next round') : 'Eliminated', onContinue: () => { if (!won || A.wins >= 4) end(); UI.go('draft', {}, { push: false }); } });
      });
    };
    return el;
  }
};

/* ---------------- Friendlies ---------------- */
const FRIENDLY_RULES = {
  classic: { name: 'Classic Match', desc: 'Standard rules.' },
  golden: { name: 'Golden Goal', desc: 'First goal wins — no time limit after 90 minutes reached in a draw.' },
  longshot: { name: 'Long Shots', desc: 'Goals from outside the box count double.' },
  headers: { name: 'Headers & Volleys', desc: 'Only goals from headers or volleys (ball in the air) count.' },
  nofouls: { name: 'No Rules', desc: 'No fouls, no offsides, no cards. Anything goes.' }
};
SCREENS.friendlies = {
  bg: 'hub',
  render() {
    const { el, body } = subShell('Friendlies', 'Play');
    body.innerHTML = `<div class="row" style="gap:22px;flex:1;align-items:stretch">
      <div class="col grow" style="gap:10px">${Object.entries(FRIENDLY_RULES).map(([k, r], i) => `<button class="tile" data-nav data-r="${k}" ${i === 0 ? 'data-autofocus' : ''} style="flex-direction:row;align-items:center;gap:16px;padding:16px 20px"><div class="grow"><h3 style="font-size:20px">${r.name}</h3><div class="sub">${r.desc}</div></div><span class="pill">Play</span></button>`).join('')}</div>
      <div class="panel col" style="padding:20px;width:320px;gap:12px"><div class="h3">Opponent</div>
        <label class="fld">Opponent strength<select class="os" data-nav>${[70, 75, 80, 84, 88].map(v => `<option value="${v}" ${v === 80 ? 'selected' : ''}>~${v} OVR</option>`).join('')}</select></label>
        <label class="fld">Difficulty<select class="df" data-nav>${Object.entries(DIFFICULTIES).map(([k, d]) => `<option value="${k}" ${k === Save.data.settings.difficulty ? 'selected' : ''}>${d.name}</option>`).join('')}</select></label>
        <div class="dim" style="font-size:12.5px">Friendlies count toward objectives but give no coins.</div></div></div>`;
    $$('[data-r]', body).forEach(b => b.onclick = () => {
      if (!requireSquad()) return;
      const rule = b.dataset.r;
      const ut = userTeam(), opp = aiTeam(R.pick(AI_SQUAD_NAMES), +$('.os', body).value);
      runMatch({ home: ut, away: opp, userSide: 'home', difficulty: $('.df', body).value, halfLen: Save.data.settings.halfLen, mode: 'friendly', rules: rule, title: FRIENDLY_RULES[rule].name }, res => {
        const r = recordUTMatch(res, 'friendly'); logMatch(res, 'Friendly', r);
        showResults(res, { title: `Friendly · ${FRIENDLY_RULES[rule].name}`, onContinue: () => UI.go('friendlies', {}, { push: false }) });
      });
    });
    return el;
  }
};

/* ---------------- match glue & results ---------------- */
function runMatch(cfg, onDone) {
  cfg.userSide = cfg.userSide === undefined ? 'home' : cfg.userSide;
  // avoid kit clashes: swap away team to alternate colours
  if (kitClash(cfg.home.kit.c1, cfg.away.kit.c1)) {
    const k = cfg.away;
    if (k.isUser) k.kit = Save.data.profile.kit.away; else k.kit = { c1: k.kit.c2 === '#ffffff' || kitClash(k.kit.c2, cfg.home.kit.c1) ? (kitClash('#ffffff', cfg.home.kit.c1) ? '#111111' : '#ffffff') : k.kit.c2, c2: k.kit.c1 };
  }
  const sim = cfg.sim;
  const start = sim => {
    if (sim) { const res = simulateMatch(cfg); onDone(res); }
    else Match.start(cfg, res => onDone(res));
  };
  if (sim !== undefined) return start(sim);
  modal({
    title: cfg.title || 'Match', body: `<div class="row" style="gap:20px;justify-content:center;align-items:center;padding:10px 0">
      <div class="col" style="align-items:center">${cfg.home.badge ? badgeSVG(cfg.home.badge, 70) : crestSVG(cfg.home.crest || cfg.home.short, 70)}<b>${esc(cfg.home.name)}</b><span class="dim">${squadRating(cfg.home.players)} OVR</span></div>
      <b style="font-family:var(--head);font-weight:900;font-size:30px">VS</b>
      <div class="col" style="align-items:center">${cfg.away.badge ? badgeSVG(cfg.away.badge, 70) : cfg.away.crest ? crestSVG(cfg.away.crest, 70) : badgeSVG({ shape: 'round', c1: cfg.away.kit.c2, c2: cfg.away.kit.c1, icon: 'ball' }, 70)}<b>${esc(cfg.away.name)}</b><span class="dim">${squadRating(cfg.away.players)} OVR</span></div></div>
      <div class="dim" style="text-align:center">${DIFFICULTIES[cfg.difficulty]?.name || ''} · ${cfg.halfLen}-minute halves${cfg.rules && cfg.rules !== 'classic' ? ' · ' + FRIENDLY_RULES[cfg.rules].name : ''}</div>`,
    buttons: [{ label: 'Cancel', value: null, cancel: true }, { label: 'Simulate', value: 'sim' }, { label: 'Play Match', value: 'play', primary: true }]
  }).then(v => { if (v) start(v === 'sim'); });
}
/* fast statistical simulation using team strengths */
function simulateMatch(cfg) {
  const H = teamStrength(cfg.home.formation, cfg.home.players, cfg.home.chem), A = teamStrength(cfg.away.formation, cfg.away.players, cfg.away.chem);
  const hs = (H.att * 0.4 + H.mid * 0.35 + H.def * 0.25), as = (A.att * 0.4 + A.mid * 0.35 + A.def * 0.25);
  let [hg, ag] = simScore(hs, as, cfg.userSide ? 1 : 1.5);
  const goals = [];
  const pickScorer = (team) => { const w = team.players.map((p, i) => ({ w: { ATT: 6, MID: 3, DEF: 1, GK: 0.02 }[POS_GROUP[FORMATIONS[team.formation][i][0]]] * (p.stats[1] / 60), v: p })); return R.weighted(w); };
  const add = (side, n) => { for (let i = 0; i < n; i++) { const t = side === 'home' ? cfg.home : cfg.away; const p = pickScorer(t), as2 = R.chance(0.7) ? R.pick(t.players.filter(x => x !== p)) : null; goals.push({ side, pid: p.id, name: p.name, pos: p.pos, min: R.int(1, 90), assist: as2 ? as2.name : null }); } };
  add('home', hg); add('away', ag); goals.sort((a, b) => a.min - b.min);
  let winner = hg > ag ? 'home' : ag > hg ? 'away' : null, pens = null;
  if (!winner && cfg.knockout) { const a = R.int(3, 5), b = a === 5 ? 4 : R.int(2, 5); pens = R.chance(0.5 + (hs - as) / 60) ? [Math.max(a, b + 1), b] : [b, Math.max(a, b + 1)]; winner = pens[0] > pens[1] ? 'home' : 'away'; }
  const poss = clamp(Math.round(50 + (H.mid - A.mid) * 1.2 + R.range(-5, 5)), 30, 70);
  const shotsH = R.int(4, 9) + hg * 2, shotsA = R.int(4, 9) + ag * 2;
  const stats = { poss: [poss, 100 - poss], shots: [shotsH, shotsA], sot: [hg + R.int(1, 3), ag + R.int(1, 3)], passes: [R.int(300, 520), R.int(300, 520)], tackles: [R.int(8, 20), R.int(8, 20)], fouls: [R.int(4, 12), R.int(4, 12)], corners: [R.int(1, 8), R.int(1, 8)] };
  return { home: cfg.home, away: cfg.away, hg, ag, goals, stats, winner, pens, userSide: cfg.userSide, simulated: true, mode: cfg.mode };
}
function showResults(res, { title, rewards = '', onContinue }) {
  Input.mode = 'menu';
  const { el, body } = subShell('Full Time', title);
  const S = res.stats, rows = [['Possession %', 'poss'], ['Shots', 'shots'], ['Shots on target', 'sot'], ['Passes', 'passes'], ['Tackles', 'tackles'], ['Fouls', 'fouls'], ['Corners', 'corners']];
  body.innerHTML = `<div class="row" style="gap:24px;flex:1;min-height:0;align-items:stretch">
    <div class="panel col" style="padding:26px;flex:1;align-items:center;gap:14px">
      <div class="row" style="gap:30px;align-items:center"><div style="text-align:center;font-weight:900;font-size:18px;width:200px">${esc(res.home.name)}</div>
        <div style="font-family:var(--head);font-weight:900;font-size:76px;line-height:1">${res.hg}<span class="dim"> - </span>${res.ag}</div><div style="text-align:center;font-weight:900;font-size:18px;width:200px">${esc(res.away.name)}</div></div>
      ${res.pens ? `<div style="font-weight:800">Penalties ${res.pens[0]} - ${res.pens[1]}</div>` : ''}${res.simulated ? '<span class="pill">Simulated</span>' : ''}
      <div class="row" style="gap:40px;align-items:flex-start;width:100%;justify-content:center;font-size:14px">
        <div class="col" style="gap:4px;align-items:flex-end;width:260px">${res.goals.filter(g => g.side === 'home').map(g => `<div>⚽ ${esc(shortName(g.name))} ${g.min}'${g.og ? ' (OG)' : ''}${g.assist ? ` <span class="dim">(${esc(shortName(g.assist))})</span>` : ''}</div>`).join('')}</div>
        <div class="col" style="gap:4px;width:260px">${res.goals.filter(g => g.side === 'away').map(g => `<div>⚽ ${esc(shortName(g.name))} ${g.min}'${g.og ? ' (OG)' : ''}${g.assist ? ` <span class="dim">(${esc(shortName(g.assist))})</span>` : ''}</div>`).join('')}</div></div>
      ${rewards ? `<div class="pill good" style="font-size:14px;padding:8px 16px">${rewards}</div>` : ''}
      <button class="btn primary cont" data-nav data-autofocus><span class="key">A</span> Continue</button></div>
    <div class="panel col" style="padding:22px;width:420px;gap:10px"><div class="h3">Match stats</div>
      <div class="stats-grid">${rows.map(([l, k]) => { const a = S[k][0], b = S[k][1], t = (a + b) || 1; return `<b style="text-align:left">${a}</b><span class="lab">${l}</span><b style="text-align:right">${b}</b><div class="sbar"><i style="width:${a / t * 100}%;background:var(--teal)"></i><i style="width:${b / t * 100}%;background:#ff6a8a"></i></div>`; }).join('')}</div></div></div>`;
  UI.cur && UI.cur.remove(); UI.cur = null;
  BG.set('hub');
  el.classList.add('screen'); $('#screen').appendChild(el); UI.cur = el; UI.curName = 'results';
  Input.setBase(el, () => cont());
  const cont = () => { Audio2.sfx('select'); onContinue && onContinue(); };
  $('.cont', el).onclick = cont;
  setTimeout(() => Input.focusFirst(el), 50);
  if (!Audio2.musicOn) Audio2.musicStart();
}
