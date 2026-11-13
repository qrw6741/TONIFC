/* ============================================================
   UI / ULTIMATE XI — Home, Objectives, Club, Squad builder, Store, Packs
   ============================================================ */
const hubBack = () => { Audio2.sfx('back'); UI.reset('main'); };

/* ---------------- HOME ---------------- */
SCREENS.home = {
  hub: true, bg: 'hub', back: hubBack,
  render() {
    const { el, body } = hubShell('home');
    const sq = Squads.active(), info = Squads.info(sq);
    const pr = Save.data.profile;
    const objs = OBJECTIVES.filter(o => !Objectives.claimed(o)).sort((a, b) => (Objectives.done(b) - Objectives.done(a)) || (Objectives.progress(b) / b.target - Objectives.progress(a) / a.target)).slice(0, 3);
    const promo = DB.players.filter(p => p.type === 'promo').sort((a, b) => b.ovr - a.ovr).slice(0, 3);
    const rv = Save.data.modes.rivals, sb = Save.data.modes.sb;
    const unopened = Save.data.unopened.length + (Save.data.pending?.length ? 1 : 0);
    body.innerHTML = `
      <div class="row" style="align-items:flex-end;margin-bottom:14px"><div class="page-title" style="margin:0">Welcome back</div><div class="spacer"></div>
        <div style="min-width:280px"><div class="row" style="justify-content:space-between;font-weight:800;font-size:13px"><span>Club Level ${pr.level}</span><span class="dim">${fmtFull(pr.xp)} / ${fmtFull(XP.need(pr.level))} XP</span></div><div class="bar gold" style="margin-top:6px"><i style="width:${pr.xp / XP.need(pr.level) * 100}%"></i></div></div></div>
      <div class="row" style="gap:18px;flex:1;min-height:0;align-items:stretch">
        <div class="col" style="width:290px;gap:14px;min-height:0">
          <button class="tile" data-nav data-go="club" style="flex:none"><div class="h3">Club overview</div>
            <div class="row" style="margin-top:10px">${badgeSVG(pr.badge, 54)}<div><div style="font-weight:900;font-size:20px">${esc(pr.clubName)}</div><div class="dim" style="font-size:13px">${Save.data.club.items.length} players · ${Save.data.stats.wins} wins</div></div></div></button>
          <button class="tile" data-nav data-go="objectives" style="flex:1"><div class="h3">Active objectives</div>
            <div class="col" style="gap:10px;margin-top:12px;width:100%">${objs.map(o => `<div><div class="row" style="justify-content:space-between;font-size:13.5px;font-weight:700"><span>${o.title}</span><span class="${Objectives.done(o) ? 'good' : 'dim'}">${Objectives.done(o) ? 'CLAIM' : Objectives.progress(o) + '/' + o.target}</span></div><div class="bar" style="margin-top:4px"><i style="width:${Objectives.progress(o) / o.target * 100}%"></i></div></div>`).join('')}</div></button>
          <button class="tile" data-nav data-go="play" style="flex:none"><div class="h3">Competitions</div>
            <div class="kv" style="margin-top:10px;font-size:13.5px"><span>Division Rivals</span><span>${RIVALS_DIVS[rv.div].name} · ${rv.pts}/10</span><span>Squad Battles</span><span>${fmtFull(sb.weekKey === weekKey() ? sb.points : 0)} pts</span><span>Champions</span><span>${Save.data.modes.champs.active ? 'In progress' : Save.data.modes.champs.tickets + ' ticket(s)'}</span></div></button>
        </div>
        <button class="tile big" data-nav data-go="squad" data-autofocus style="flex:1.25;min-width:0"><div class="glow"></div><div class="row" style="width:100%"><div><h3>${esc(sq.name)}</h3><div class="sub">Manage your squad, formation & chemistry</div></div><div class="spacer"></div>
            <div class="statbig" style="width:220px"><div><b>${info.rating}</b><span>Rating</span></div><div><b>${info.chem.total}</b><span>Chem</span></div></div></div>
          <div class="art" style="min-height:0;overflow:hidden">${miniPitchSVG(sq.formation, info.players)}</div></button>
        <div class="col" style="flex:1;gap:14px;min-width:0">
          <button class="tile" data-nav data-go="store" style="flex:1"><h3>Nightfall Promo</h3><div class="sub">Latest promotional cards — in packs now</div>
            <div class="art"><div class="row" style="gap:6px">${promo.map(p => `<div style="--cs:7.6px">${cardHTML(p, { nav: false })}</div>`).join('')}</div></div></button>
          <button class="tile" data-nav data-go="store" data-tab="mine" style="flex:none"><div class="row"><div class="grow"><h3 style="font-size:22px">${unopened ? `${unopened} unopened` : 'Store'}</h3><div class="sub">${unopened ? 'Open your packs' : 'Available packs from 400 coins'}</div></div><div style="transform:scale(.55);margin:-40px -20px">${packArtHTML(unopened ? Save.data.unopened[0] || 'premium' : 'premium')}</div></div></button>
          <div class="tile" style="flex:none;cursor:default"><div class="h3">Balance</div><div class="row" style="gap:18px;margin-top:8px;font-weight:900;font-size:22px"><span><i class="coin"></i> ${fmtFull(Save.data.coins)}</span><span><i class="pts"></i> ${fmtFull(Save.data.points)}</span></div><div class="dim" style="font-size:12px;margin-top:4px">Prime Points are free in-game credits — no real money.</div></div>
        </div></div>`;
    $$('[data-go]', body).forEach(b => b.onclick = () => { Audio2.sfx('select'); const g = b.dataset.go; if (HUB_TABS.some(t => t[0] === g)) UI.go(g, { tab: b.dataset.tab }, { replace: true, push: false }); else UI.go(g); });
    return el;
  }
};
function miniPitchSVG(formation, players) {
  const F = FORMATIONS[formation];
  return `<svg viewBox="0 0 100 100" style="width:100%;height:100%;max-height:340px">
    <rect x="4" y="2" width="92" height="96" rx="3" fill="rgba(40,140,90,.18)" stroke="rgba(160,255,236,.35)" stroke-width=".5"/>
    <line x1="4" y1="50" x2="96" y2="50" stroke="rgba(160,255,236,.3)" stroke-width=".4"/><circle cx="50" cy="50" r="9" fill="none" stroke="rgba(160,255,236,.3)" stroke-width=".4"/>
    ${F.map((f, i) => { const p = players[i]; return `<g transform="translate(${f[1]},${f[2] * 0.92 + 4})"><circle r="5.2" fill="${p ? (p.type !== 'base' ? '#6b2ea6' : tierOf(p.ovr) === 'gold' ? '#d9b04a' : tierOf(p.ovr) === 'silver' ? '#b9c1cb' : '#b07a4f') : 'rgba(255,255,255,.15)'}" stroke="#fff" stroke-width=".5"/><text y="1.8" text-anchor="middle" font-size="4.6" font-weight="900" fill="#111">${p ? p.ovr : ''}</text><text y="10" text-anchor="middle" font-size="3.4" font-weight="700" fill="#fff">${p ? esc(shortName(p.name)).slice(0, 11) : f[0]}</text></g>`; }).join('')}</svg>`;
}

/* ---------------- OBJECTIVES ---------------- */
SCREENS.objectives = {
  hub: true, bg: 'hub', back: hubBack,
  render(params) {
    const { el, body } = hubShell('objectives');
    const cat = params.cat || 'daily';
    const cats = [['daily', 'Daily'], ['weekly', 'Weekly'], ['season', 'Season'], ['milestone', 'Milestones']];
    body.innerHTML = `<div class="row"><div class="page-title">Objectives</div><div class="spacer"></div><div class="seg">${cats.map(([k, l]) => `<button data-nav data-c="${k}" class="${k === cat ? 'on' : ''}">${l} ${OBJECTIVES.filter(o => o.cat === k && Objectives.done(o) && !Objectives.claimed(o)).length ? '•' : ''}</button>`).join('')}</div></div>
      <div class="dim" style="margin:-8px 0 14px;font-size:13px">${cat === 'daily' ? 'Resets in ' + fmtTime(msToReset('daily')) : cat === 'weekly' ? 'Resets in ' + fmtTime(msToReset('weekly')) : cat === 'season' ? 'Season 1 · rewards Foundations players' : 'Permanent milestones'}</div>
      <div class="col scroll" style="gap:10px;flex:1">${OBJECTIVES.filter(o => o.cat === cat).map(o => {
      const pr = Objectives.progress(o), done = Objectives.done(o), cl = Objectives.claimed(o);
      return `<div class="panel row" style="padding:16px 20px;gap:18px"><div style="width:44px;height:44px;border-radius:50%;display:grid;place-items:center;font-weight:900;background:${cl ? 'rgba(61,220,132,.2)' : done ? 'var(--teal)' : 'rgba(255,255,255,.08)'};color:${done && !cl ? '#062' : '#fff'}">${cl ? '✓' : done ? '!' : Math.round(pr / o.target * 100) + '%'}</div>
        <div class="grow"><div style="font-weight:800;font-size:16px">${o.title}</div><div class="dim" style="font-size:13px">${o.desc}</div><div class="bar" style="margin-top:8px;max-width:420px"><i style="width:${pr / o.target * 100}%"></i></div></div>
        <div style="text-align:right;min-width:220px"><div style="font-size:12.5px;color:var(--teal);font-weight:700;margin-bottom:6px">${rewardText(o.reward)}</div>
        ${cl ? '<span class="pill good">Claimed</span>' : `<button class="btn ${done ? 'primary' : ''} small" data-nav data-claim="${o.id}" ${done ? '' : 'disabled'}>${done ? 'Claim reward' : pr + ' / ' + o.target}</button>`}</div></div>`;
    }).join('')}</div>`;
    $$('[data-c]', body).forEach(b => b.onclick = () => UI.go('objectives', { cat: b.dataset.c }, { replace: true, push: false }));
    $$('[data-claim]', body).forEach(b => b.onclick = () => { const o = OBJECTIVES.find(x => x.id === b.dataset.claim); if (Objectives.claim(o)) { Audio2.sfx('reveal'); toast(`Claimed: ${rewardText(o.reward)}`, 'good'); UI.go('objectives', { cat }, { replace: true, push: false }); } });
    return el;
  }
};

/* ---------------- CLUB ---------------- */
SCREENS.club = {
  hub: true, bg: 'hub', back: hubBack,
  render(params) {
    const { el, body } = hubShell('club');
    const view = params.view || 'players';
    body.innerHTML = `<div class="row"><div class="page-title">Club</div><div class="spacer"></div>
      <div class="seg">${[['players', 'Players'], ['dupes', 'Duplicates'], ['squads', 'Squads'], ['stats', 'Club Stats'], ['custom', 'Customize']].map(([k, l]) => `<button data-nav data-v="${k}" class="${k === view ? 'on' : ''}">${l}</button>`).join('')}</div></div><div class="cb col" style="flex:1;min-height:0"></div>`;
    const cb = $('.cb', body);
    $$('[data-v]', body).forEach(b => b.onclick = () => { if (b.dataset.v === 'custom') return UI.go('customize'); UI.go('club', { view: b.dataset.v }, { replace: true, push: false }); });
    if (view === 'players' || view === 'dupes') {
      cb.innerHTML = `<div class="filters" style="margin-bottom:10px"><input type="text" class="q" placeholder="Search players" data-nav style="width:200px">
        <select class="fpos" data-nav><option value="">Position</option>${POSITIONS.map(p => `<option>${p}</option>`).join('')}</select>
        <select class="flg" data-nav><option value="">League</option>${Object.entries(LEAGUES).map(([k, L]) => `<option value="${k}">${L.name}</option>`).join('')}</select>
        <select class="frar" data-nav><option value="">Rarity</option><option value="bronze">Bronze</option><option value="silver">Silver</option><option value="gold">Gold</option><option value="rare">Rare</option><option value="special">Special</option></select>
        <select class="fsort" data-nav><option value="ovr">Sort: Rating</option><option value="new">Sort: Newest</option><option value="name">Sort: Name</option><option value="val">Sort: Value</option><option value="pace">Sort: Pace</option></select>
        <span class="spacer"></span><span class="cnt dim" style="font-weight:700"></span>
        ${view === 'dupes' ? '<button class="btn small qsall" data-nav>Quick sell all duplicates</button>' : ''}</div>
        <div class="plist scroll" style="flex:1"></div>`;
      const list = $('.plist', cb);
      const render = () => {
        const q = $('.q', cb).value.toLowerCase(), fp = $('.fpos', cb).value, fl = $('.flg', cb).value, fr = $('.frar', cb).value, so = $('.fsort', cb).value;
        let items = view === 'dupes' ? Club.duplicates() : Save.data.club.items.slice();
        let arr = items.map(it => ({ it, p: P(it.pid) })).filter(({ p }) => (!q || p.name.toLowerCase().includes(q)) && (!fp || p.pos === fp) && (!fl || p.lg === fl) &&
          (!fr || (fr === 'rare' ? p.rare : fr === 'special' ? p.type !== 'base' : (p.type === 'base' && tierOf(p.ovr) === fr))));
        const sorts = { ovr: (a, b) => b.p.ovr - a.p.ovr, new: (a, b) => b.it.at - a.it.at, name: (a, b) => shortName(a.p.name).localeCompare(shortName(b.p.name)), val: (a, b) => Market.value(b.p) - Market.value(a.p), pace: (a, b) => b.p.stats[0] - a.p.stats[0] };
        arr.sort(sorts[so]);
        $('.cnt', cb).textContent = `${arr.length} players`;
        list.innerHTML = arr.map(({ it, p }) => `<div class="col" style="align-items:center;gap:4px">${cardHTML(p, { uid: it.uid, untr: it.untr })}<div style="font-size:11px;font-weight:800" class="${Club.inMarket(it.uid) ? 'warn' : Club.inActiveSquad(it.uid) ? 'good' : 'dim'}">${Club.inMarket(it.uid) ? 'ON MARKET' : Club.inActiveSquad(it.uid) ? 'IN SQUAD' : it.untr ? 'UNTRADEABLE' : '&nbsp;'}</div></div>`).join('') || '<div class="dim" style="padding:30px">No players found.</div>';
        $$('.card', list).forEach(c => c.onclick = () => clubItemActions(c.dataset.uid, render));
      };
      $$('input,select', cb).forEach(i => i.oninput = render);
      if (view === 'dupes') $('.qsall', cb).onclick = async () => {
        const d = Club.duplicates().filter(it => !Club.inMarket(it.uid) && !Club.inSquadAnywhere(it.uid));
        if (!d.length) return toast('No duplicates to sell');
        const tot = d.reduce((s, it) => s + quickSellValue(P(it.pid)), 0);
        if (await modal({ title: 'Quick sell duplicates?', body: `Sell ${d.length} duplicate players for <b>${fmtFull(tot)}</b> coins.`, buttons: [{ label: 'Cancel', value: false, cancel: true }, { label: 'Quick sell', value: true, primary: true }] })) {
          d.forEach(it => Club.remove(it.uid)); Wallet.add('coins', tot, `Quick sold ${d.length} duplicates`, 'quicksell'); render();
        }
      };
      render();
    } else if (view === 'squads') {
      cb.innerHTML = `<div class="row" style="margin-bottom:12px"><button class="btn primary new" data-nav>+ New squad</button></div><div class="col scroll" style="gap:10px">${Save.data.squads.map((s, i) => {
        const inf = Squads.info(s); return `<div class="panel row" style="padding:14px 18px;gap:18px">${i === Save.data.activeSquad ? '<span class="pill good">ACTIVE</span>' : ''}<div class="grow"><div style="font-weight:800;font-size:17px">${esc(s.name)}</div><div class="dim" style="font-size:13px">${s.formation} · Rating ${inf.rating} · Chem ${inf.chem.total}/33 · ${inf.filled}/11</div></div>
        <button class="btn small" data-nav data-edit="${i}">Edit</button>${i !== Save.data.activeSquad ? `<button class="btn small" data-nav data-act="${i}">Set active</button>` : ''}<button class="btn small" data-nav data-ren="${i}">Rename</button>${Save.data.squads.length > 1 ? `<button class="btn small danger" data-nav data-del="${i}">Delete</button>` : ''}</div>`;
      }).join('')}</div>`;
      $('.new', cb).onclick = () => { const s = Squads.create(`Squad ${Save.data.squads.length + 1}`); Save.data.activeSquad = Save.data.squads.length - 1; UI.go('squad'); };
      $$('[data-edit]', cb).forEach(b => b.onclick = () => { Save.data.activeSquad = +b.dataset.edit; Save.dirty(); UI.go('squad'); });
      $$('[data-act]', cb).forEach(b => b.onclick = () => { Save.data.activeSquad = +b.dataset.act; Save.dirty(); UI.rerender(); });
      $$('[data-ren]', cb).forEach(b => b.onclick = () => renameSquad(Save.data.squads[+b.dataset.ren]).then(() => UI.rerender()));
      $$('[data-del]', cb).forEach(b => b.onclick = async () => { if (await modal({ title: 'Delete squad?', buttons: [{ label: 'Cancel', value: false, cancel: true }, { label: 'Delete', value: true, danger: true }] })) { Save.data.squads.splice(+b.dataset.del, 1); Save.data.activeSquad = 0; Save.dirty(); UI.rerender(); } });
    } else if (view === 'stats') {
      const items = Save.data.club.items.map(i => P(i.pid));
      const cnt = f => items.filter(f).length;
      const val = items.reduce((s, p) => s + Market.value(p), 0);
      const s = Save.data.stats;
      cb.innerHTML = `<div class="row" style="gap:18px;align-items:flex-start;flex-wrap:wrap">
        <div class="panel col" style="padding:20px;width:320px"><div class="h3">Collection</div><div class="kv" style="margin-top:10px"><span>Total players</span><span>${items.length}</span><span>Gold / Silver / Bronze</span><span>${cnt(p => tierOf(p.ovr) === 'gold')} / ${cnt(p => tierOf(p.ovr) === 'silver')} / ${cnt(p => tierOf(p.ovr) === 'bronze')}</span><span>Rare</span><span>${cnt(p => p.rare)}</span><span>Special cards</span><span>${cnt(p => p.type !== 'base')}</span><span>Icons / Heroes</span><span>${cnt(p => p.type === 'icon')} / ${cnt(p => p.type === 'hero')}</span><span>Duplicates</span><span>${Club.duplicates().length}</span><span>Est. club value</span><span><i class="coin"></i> ${fmtFull(val)}</span></div></div>
        <div class="panel col" style="padding:20px;width:320px"><div class="h3">Record</div><div class="kv" style="margin-top:10px"><span>Matches</span><span>${s.played}</span><span>Wins / Draws / Losses</span><span>${s.wins} / ${s.draws} / ${s.losses}</span><span>Goals scored</span><span>${s.gf}</span><span>Goals conceded</span><span>${s.ga}</span><span>Packs opened</span><span>${s.packs}</span><span>SBCs</span><span>${s.sbcs}</span></div></div>
        <div class="panel col scroll" style="padding:20px;width:380px;max-height:60vh"><div class="h3">Club history</div>${Save.data.profile.history.slice(0, 40).map(x => `<div style="padding:6px 0;border-bottom:1px solid var(--line);font-size:13.5px"><span class="dim">${new Date(x.t).toLocaleDateString()}</span> · ${esc(x.text)}</div>`).join('')}</div></div>`;
    }
    return el;
  }
};
async function renameSquad(s) {
  const body = h(`<div><input type="text" value="${esc(s.name)}" maxlength="24" data-nav style="width:100%"></div>`);
  const v = await modal({ title: 'Rename squad', body, buttons: [{ label: 'Cancel', value: null, cancel: true }, { label: 'Save', value: 'ok', primary: true }] });
  if (v) { s.name = $('input', body).value.trim() || s.name; Save.dirty(); }
}
async function clubItemActions(uidv, after) {
  const it = Club.get(uidv); if (!it) return;
  const p = P(it.pid);
  const inMk = Club.inMarket(uidv);
  const acts = [];
  if (!inMk && !it.untr) acts.push({ label: 'List on Transfer Market', value: 'list' });
  if (!inMk) acts.push({ label: `Quick sell (${fmtFull(quickSellValue(p))})`, value: 'qs', danger: true });
  const best = bestOwnedForPos(p.pos, uidv);
  if (best) acts.push({ label: 'Compare', value: 'cmp' });
  const v = await inspectCard(p, { item: it, actions: acts });
  if (v === 'qs') {
    if (Club.inSquadAnywhere(uidv) && !(await modal({ title: 'Player is in a squad', body: 'Quick selling removes him from your squads. Continue?', buttons: [{ label: 'Cancel', value: false, cancel: true }, { label: 'Quick sell', value: true, danger: true }] }))) return;
    Club.remove(uidv); Wallet.add('coins', quickSellValue(p), `Quick sold ${p.name}`, 'quicksell'); toast(`Quick sold ${p.name}`, 'good');
  } else if (v === 'list') await listDialog(uidv);
  else if (v === 'cmp') await modal({ title: 'Compare', body: compareHTML(p, best), wide: true });
  after && after();
}
async function listDialog(uidv) {
  const it = Club.get(uidv), p = P(it.pid), rg = Market.priceRange(p), v = Market.value(p);
  const body = h(`<div class="col" style="gap:12px"><div class="row">${playerRowHTML(p)}</div>
    <div class="dim" style="font-size:13px">Estimated market value <b class="good"><i class="coin"></i> ${fmtFull(v)}</b> · allowed range ${fmtFull(rg.min)}–${fmtFull(rg.max)} · 5% tax on sale</div>
    <div class="row"><label class="fld grow">Start price<input type="number" class="st" step="50" value="${Math.round(v * 0.75 / 50) * 50}" data-nav></label><label class="fld grow">Buy Now price<input type="number" class="bn" step="50" value="${Math.round(v * 1.05 / 50) * 50}" data-nav></label></div>
    <label class="fld">Duration<select class="du" data-nav><option value="2">2 minutes</option><option value="10" selected>10 minutes</option><option value="60">1 hour</option><option value="180">3 hours</option></select></label>
    <div class="dim net" style="font-size:13px"></div></div>`);
  const upd = () => $('.net', body).innerHTML = `If sold at Buy Now you receive <b>${fmtFull(Math.round(+$('.bn', body).value * (1 - MARKET_TAX)))}</b> coins.`;
  $('.bn', body).oninput = upd; upd();
  const r = await modal({ title: 'List on Transfer Market', body, buttons: [{ label: 'Cancel', value: null, cancel: true }, { label: 'List player', value: 'ok', primary: true }] });
  if (r && Market.listItem(uidv, +$('.st', body).value, +$('.bn', body).value, +$('.du', body).value)) { toast(`${p.name} listed`, 'good'); return true; }
  return false;
}

/* ---------------- SQUAD BUILDER ---------------- */
SCREENS.squad = {
  bg: 'hub',
  render() {
    const sq = Squads.active();
    const { el, body } = subShell(esc(sq.name), 'Squad Builder');
    let sel = -1; // selected slot (0-10 pitch, 11-17 bench)
    const draw = () => {
      const info = Squads.info(sq);
      const capIdx = sq.slots.indexOf(sq.captain);
      body.innerHTML = `<div class="row" style="gap:22px;flex:1;min-height:0;align-items:stretch">
        <div class="sb-side">
          <div class="statbig"><div><b>${info.rating}</b><span>Squad rating</span></div><div><b style="color:${info.chem.total >= 24 ? 'var(--green)' : info.chem.total >= 12 ? 'var(--yellow)' : 'var(--red)'}">${info.chem.total}</b><span>Chemistry /33</span></div></div>
          <label class="fld">Squad<select class="sqsel" data-nav>${Save.data.squads.map((s, i) => `<option value="${i}" ${i === Save.data.activeSquad ? 'selected' : ''}>${esc(s.name)}</option>`).join('')}</select></label>
          <label class="fld">Formation<select class="form" data-nav>${FORMATION_NAMES.map(f => `<option ${f === sq.formation ? 'selected' : ''}>${f}</option>`).join('')}</select></label>
          <div class="row wrap"><button class="btn small auto" data-nav>Auto-build best XI</button><button class="btn small ren" data-nav>Rename</button><button class="btn small nw" data-nav>New squad</button></div>
          <div class="panel col" style="padding:12px;gap:6px;font-size:12.5px"><div class="h3" style="font-size:12px">Chemistry links</div>
            <div class="row"><i style="width:22px;height:4px;background:var(--green);border-radius:2px"></i> Strong (club, or nation + league)</div>
            <div class="row"><i style="width:22px;height:4px;background:var(--yellow);border-radius:2px"></i> Partial (nation or league)</div>
            <div class="row"><i style="width:22px;height:4px;background:var(--red);border-radius:2px"></i> None</div>
            <div class="dim">Player chem (◆0–3) comes from how many teammates share his club, nation and league. Out-of-position players get 0.</div></div>
          <div class="panel col sel-info" style="padding:12px;gap:8px;font-size:13px"></div>
        </div>
        <div class="grow" style="min-width:0;display:flex;justify-content:center">${pitchHTML(sq.formation, info.players, { chem: info.chem, captainIdx: capIdx, selected: sel < 11 ? sel : -1, showLinks: Save.data.settings.showLinks, uids: sq.slots })}</div>
        <div class="col" style="width:250px;gap:10px;min-height:0"><div class="h3">Substitutes</div>
          <div class="bench">${sq.subs.map((u, i) => { const p = u ? Club.player(u) : null; return `<div class="slot ${sel === 11 + i ? 'sel' : ''}" data-bench="${i}" style="position:relative">${p ? cardHTML(p, { mini: true, uid: u }) : emptyCardHTML('SUB', true, 'data-uid=""')}</div>`; }).join('')}</div>
          <div class="dim" style="font-size:12px">Drag cards to swap, or select a card then choose an action. Changes save automatically.</div></div></div>`;
      // selection info
      const si = $('.sel-info', body);
      if (sel >= 0) {
        const u = sel < 11 ? sq.slots[sel] : sq.subs[sel - 11];
        const p = u ? Club.player(u) : null;
        const pos = sel < 11 ? FORMATIONS[sq.formation][sel][0] : 'SUB';
        si.innerHTML = `<div class="h3" style="font-size:12px">Selected: ${pos}</div>${p ? `<div style="font-weight:800">${esc(p.name)} (${p.ovr})</div>` : '<div class="dim">Empty slot</div>'}
          <div class="row wrap"><button class="btn small" data-nav data-a="replace">${p ? 'Replace' : 'Add player'}</button>${p ? `<button class="btn small" data-nav data-a="move">Swap with…</button><button class="btn small" data-nav data-a="view">View</button>${sel < 11 ? '<button class="btn small" data-nav data-a="cap">Make captain</button>' : ''}<button class="btn small" data-nav data-a="remove">Remove</button>` : ''}<button class="btn small" data-nav data-a="cancel">Cancel</button></div>`;
        $$('[data-a]', si).forEach(b => b.onclick = () => slotAction(b.dataset.a, u, pos));
      } else si.innerHTML = '<div class="dim">Select a player on the pitch or bench.</div>';
      // events
      $$('.pitch .slot', body).forEach(s => { const i = +s.dataset.slot; $('.card', s).onclick = () => clickSlot(i); dnd(s, i); });
      $$('.bench .slot', body).forEach(s => { const i = 11 + +s.dataset.bench; $('.card', s).onclick = () => clickSlot(i); dnd(s, i); });
      $('.form', body).onchange = e => { sq.formation = e.target.value; Save.dirty(); draw(); };
      $('.sqsel', body).onchange = e => { Save.data.activeSquad = +e.target.value; Save.dirty(); UI.go('squad', {}, { push: false }); };
      $('.auto', body).onclick = () => { Squads.autoBuild(sq); Audio2.sfx('reveal'); toast('Best XI auto-built', 'good'); draw(); };
      $('.ren', body).onclick = () => renameSquad(sq).then(() => UI.go('squad', {}, { push: false }));
      $('.nw', body).onclick = () => { Squads.create(`Squad ${Save.data.squads.length + 1}`); Save.data.activeSquad = Save.data.squads.length - 1; UI.go('squad', {}, { push: false }); };
      if (focusAfter != null) { const t = focusAfter < 11 ? $(`.pitch .slot[data-slot="${focusAfter}"] .card`, body) : $(`.bench .slot[data-bench="${focusAfter - 11}"] .card`, body); t && t.focus(); focusAfter = null; }
    };
    let moving = -1, focusAfter = null;
    const getU = i => i < 11 ? sq.slots[i] : sq.subs[i - 11];
    const setU = (i, u) => { if (i < 11) sq.slots[i] = u; else sq.subs[i - 11] = u; };
    const swap = (a, b) => { const ua = getU(a), ub = getU(b); setU(a, ub); setU(b, ua); Save.dirty(); Audio2.sfx('select'); };
    const clickSlot = i => {
      if (moving >= 0) { if (moving !== i) swap(moving, i); moving = -1; sel = -1; focusAfter = i; draw(); return; }
      sel = sel === i ? -1 : i; focusAfter = i; draw();
      if (sel >= 0 && !getU(i)) slotAction('replace', null, i < 11 ? FORMATIONS[sq.formation][i][0] : null);
      else if (sel >= 0) setTimeout(() => $('.sel-info [data-a]', body)?.focus(), 0);
    };
    const slotAction = async (a, u, pos) => {
      const i = sel;
      if (a === 'cancel') { sel = -1; focusAfter = i; draw(); return; }
      if (a === 'view') { await inspectCard(Club.player(u), { item: Club.get(u) }); focusAfter = i; draw(); return; }
      if (a === 'cap') { sq.captain = u; Save.dirty(); toast('Captain set', 'good'); sel = -1; focusAfter = i; draw(); return; }
      if (a === 'remove') { setU(i, null); if (sq.captain === u) sq.captain = null; Save.dirty(); sel = -1; focusAfter = i; draw(); return; }
      if (a === 'move') { moving = i; toast('Now select the slot to swap with'); return; }
      if (a === 'replace') {
        const cur = new Set([...sq.slots, ...sq.subs].filter(Boolean));
        const curPids = new Set([...cur].map(x => Club.get(x)?.pid));
        const pick = await pickPlayer({ title: `Select ${pos && pos !== 'SUB' ? pos : 'player'}`, pos: pos && pos !== 'SUB' ? pos : null, exclude: new Set(), filter: it => !curPids.has(it.pid) || cur.has(it.uid) });
        if (pick) {
          const other = [...sq.slots.map((x, k) => [x, k]), ...sq.subs.map((x, k) => [x, 11 + k])].find(([x]) => x === pick);
          if (other) swap(i, other[1]); else { setU(i, pick); Save.dirty(); Audio2.sfx('select'); }
        }
        sel = -1; focusAfter = i; draw();
      }
    };
    const dnd = (slotEl, i) => {
      const card = $('.card', slotEl);
      card.addEventListener('dragstart', e => { e.dataTransfer.setData('text/slot', String(i)); e.dataTransfer.effectAllowed = 'move'; });
      slotEl.addEventListener('dragover', e => { e.preventDefault(); slotEl.classList.add('drag-over'); });
      slotEl.addEventListener('dragleave', () => slotEl.classList.remove('drag-over'));
      slotEl.addEventListener('drop', e => { e.preventDefault(); slotEl.classList.remove('drag-over'); const from = +e.dataTransfer.getData('text/slot'); if (!isNaN(from) && from !== i) { swap(from, i); sel = -1; draw(); } });
    };
    draw();
    return el;
  }
};

/* ---------------- STORE ---------------- */
SCREENS.store = {
  hub: true, bg: 'hub', back: hubBack,
  render(params) {
    const { el, body } = hubShell('store');
    const tab = params.tab || (Save.data.unopened.length || Save.data.pending?.length ? 'mine' : 'packs');
    const today = dayKey();
    body.innerHTML = `<div class="row"><div class="page-title">Store</div><div class="spacer"></div>
      <div class="seg">${[['packs', 'Packs'], ['promo', 'Special Promos'], ['mine', `My Packs (${Save.data.unopened.length})`], ['odds', 'Pack Odds']].map(([k, l]) => `<button data-nav data-t="${k}" class="${k === tab ? 'on' : ''}">${l}</button>`).join('')}</div></div>
      <div class="sb scroll" style="flex:1"></div>`;
    const sb = $('.sb', body);
    $$('[data-t]', body).forEach(b => b.onclick = () => UI.go('store', { tab: b.dataset.t }, { replace: true, push: false }));
    const tile = (id, owned = false, idx = -1) => {
      const pk = PACKS[id];
      return `<button class="tile pack-tile" data-nav data-pack="${id}" data-idx="${idx}">${packArtHTML(id)}<div style="font-weight:900;font-size:16px;margin-top:6px">${pk.name}</div><div class="dim" style="font-size:12px;min-height:30px">${pk.desc}</div>
        ${owned ? '<span class="pill good">Open now</span>' : `<div class="price">${pk.coins ? `<span><i class="coin"></i> ${fmtFull(pk.coins)}</span>` : ''}${pk.points ? `<span><i class="pts"></i> ${fmtFull(pk.points)}</span>` : ''}</div>`}</button>`;
    };
    if (tab === 'packs' || tab === 'promo') {
      const ids = PACK_ORDER.filter(id => !!PACKS[id].promo === (tab === 'promo'));
      sb.innerHTML = `${tab === 'packs' ? `<div class="panel row" style="padding:14px 18px;margin-bottom:16px;gap:14px"><i class="pts" style="font-size:26px"></i><div class="grow"><b>Daily Prime Points</b><div class="dim" style="font-size:13px">Claim 100 free Prime Points every day. Prime Points are fictional credits — no real-money purchases exist in this game.</div></div><button class="btn ${Save.data.dailyPts === today ? '' : 'primary'} dp" data-nav ${Save.data.dailyPts === today ? 'disabled' : ''}>${Save.data.dailyPts === today ? 'Claimed today' : 'Claim 100'}</button></div>` : ''}
        <div class="packs">${ids.map(id => tile(id)).join('')}</div>`;
      const dp = $('.dp', sb); if (dp) dp.onclick = () => { Save.data.dailyPts = today; Wallet.add('points', 100, 'Daily Prime Points'); UI.rerender(); };
      $$('[data-pack]', sb).forEach(b => b.onclick = () => buyPack(b.dataset.pack));
    } else if (tab === 'mine') {
      const pend = Save.data.pending?.length;
      sb.innerHTML = `${pend ? `<div class="panel row" style="padding:14px 18px;margin-bottom:14px"><div class="grow"><b>${pend} unassigned items</b><div class="dim" style="font-size:13px">From your last pack — send them to your club or sell them.</div></div><button class="btn primary pend" data-nav>View items</button></div>` : ''}
        ${Save.data.unopened.length ? `<div class="packs">${Save.data.unopened.map((id, i) => tile(id, true, i)).join('')}</div>` : '<div class="dim" style="padding:30px">No unopened packs. Earn them from objectives, SBCs and competitions, or buy them in the Store.</div>'}`;
      if (pend) $('.pend', sb).onclick = () => UI.go('packresult');
      $$('[data-pack]', sb).forEach(b => b.onclick = () => { const i = +b.dataset.idx; const id = Save.data.unopened[i]; Save.data.unopened.splice(i, 1); Save.dirty(); openPack(id); });
    } else {
      sb.innerHTML = `<div class="dim" style="margin-bottom:12px">Every pack's contents are generated from these configurable odds (see <code>PACKS</code> in <code>systems/economy.js</code>). Guaranteed slots are filled first; remaining slots roll the per-slot odds below.</div>
        <div class="packs" style="grid-template-columns:repeat(auto-fill,minmax(320px,1fr))">${PACK_ORDER.map(id => {
        const pk = PACKS[id]; return `<div class="panel" style="padding:16px"><div style="font-weight:900">${pk.name}</div><div class="dim" style="font-size:12px;margin-bottom:8px">${pk.items} items · Guaranteed: ${pk.guar.map(g => `${g[1]}× ${TIER_LABEL[g[0]]}`).join(', ')}</div>
          <table class="tbl"><tr><th>Item</th><th>Per slot</th><th>≥1 in pack</th></tr>${packOdds(id).map(o => `<tr><td>${TIER_LABEL[o.tier]}</td><td>${(o.perSlot * 100).toFixed(o.perSlot < 0.01 ? 2 : 1)}%</td><td>${(o.atLeast * 100).toFixed(o.atLeast < 0.01 ? 2 : 1)}%</td></tr>`).join('')}</table></div>`;
      }).join('')}</div>`;
    }
    return el;
  }
};
async function buyPack(id) {
  const pk = PACKS[id];
  const opts = [];
  if (pk.coins) opts.push({ label: `${fmtFull(pk.coins)} Coins`, value: 'coins', primary: true });
  if (pk.points) opts.push({ label: `${fmtFull(pk.points)} Prime Points`, value: 'points', primary: !pk.coins });
  opts.push({ label: 'Cancel', value: null, cancel: true });
  const body = h(`<div class="row" style="gap:20px">${packArtHTML(id)}<div><div style="font-weight:800">${pk.desc}</div><div class="dim" style="font-size:13px;margin-top:6px">Odds: ${packOdds(id).slice(0, 4).map(o => `${TIER_LABEL[o.tier]} ${(o.perSlot * 100).toFixed(1)}%`).join(' · ')}…</div><div class="dim" style="font-size:13px;margin-top:6px">Balance: <i class="coin"></i> ${fmtFull(Save.data.coins)} · <i class="pts"></i> ${fmtFull(Save.data.points)}</div></div></div>`);
  const cur = await modal({ title: `Buy ${pk.name}?`, body, buttons: opts });
  if (!cur) return;
  if (Save.data.pending?.length) { toast('Assign your previous pack items first', 'bad'); return UI.go('packresult'); }
  if (!Wallet.spend(cur, cur === 'coins' ? pk.coins : pk.points, `Bought ${pk.name}`, 'store')) return;
  openPack(id, cur === 'coins' || cur === 'points');
}

/* ---------------- PACK OPENING (cinematic) ---------------- */
function openPack(id, tradeable = false) {
  if (Save.data.pending?.length) { // safety: auto-assign leftovers
    Save.data.pending.forEach(x => { if (!x.done) Club.add(x.pid, x.untr, 'pack'); }); Save.data.pending = [];
  }
  const items = generatePack(id);
  const untr = !tradeable || !!PACKS[id].reward;
  Save.data.pending = items.map(p => ({ pid: p.id, untr, done: null }));
  Save.data.stats.packs++; Objectives.track('pack'); XP.add(50);
  Save.now();
  const best = items[0];
  const isWalkout = best.ovr >= 84 || ['icon', 'hero', 'promo', 'totw'].includes(best.type);
  const lvl = best.type === 'icon' ? 4 : best.type === 'hero' || best.type === 'promo' ? 3 : best.ovr >= 86 || best.type === 'totw' ? 2 : best.ovr >= 80 ? 1 : 0;
  Audio2.musicStop();
  const el = h(`<div class="po"><canvas></canvas><div class="stage"></div><button class="btn skip" data-nav>Skip ▸▸</button></div>`);
  document.body.appendChild(el);
  const layer = Input.pushLayer(el, () => finish());
  const cv = $('canvas', el), cx = cv.getContext('2d');
  const W = cv.width = innerWidth, H = cv.height = innerHeight;
  const colors = { 0: ['#cfd6de', '#7f8a99'], 1: ['#ffd34a', '#c3901c'], 2: ['#ffd34a', '#ff8a00'], 3: ['#ff4fa3', '#7a2ff5'], 4: ['#fff3c4', '#e8b631'] }[lvl];
  let phase = 'pack', t0 = performance.now(), beams = 0, flash = 0, sparks = [], done = false;
  const fx = (now) => {
    if (done) return;
    const t = (now - t0) / 1000;
    cx.fillStyle = '#000'; cx.fillRect(0, 0, W, H);
    // stadium tunnel lights
    const g = cx.createRadialGradient(W / 2, H * 0.55, 10, W / 2, H * 0.55, H);
    g.addColorStop(0, `rgba(40,60,80,${0.5 + beams * 0.3})`); g.addColorStop(1, 'rgba(0,0,0,1)');
    cx.fillStyle = g; cx.fillRect(0, 0, W, H);
    cx.globalCompositeOperation = 'lighter';
    const nb = 6 + lvl * 3;
    for (let i = 0; i < nb; i++) {
      const a = -Math.PI / 2 + (i - nb / 2) * 0.16 + Math.sin(t * 0.8 + i) * 0.05;
      const len = H * 1.2;
      cx.save(); cx.translate(W / 2, H * 1.05); cx.rotate(a + Math.PI / 2);
      const lg = cx.createLinearGradient(0, 0, 0, -len);
      lg.addColorStop(0, colors[i % 2] + 'aa'); lg.addColorStop(1, 'rgba(0,0,0,0)');
      cx.globalAlpha = 0.25 * beams; cx.fillStyle = lg;
      cx.beginPath(); cx.moveTo(-8, 0); cx.lineTo(-90, -len); cx.lineTo(90, -len); cx.lineTo(8, 0); cx.fill(); cx.restore();
    }
    cx.globalAlpha = 1;
    // sparks
    for (const s of sparks) { s.x += s.vx; s.y += s.vy; s.vy += 0.06; s.l -= 0.012; if (s.l > 0) { cx.fillStyle = s.c; cx.globalAlpha = s.l; cx.fillRect(s.x, s.y, 3, 3); } }
    sparks = sparks.filter(s => s.l > 0); cx.globalAlpha = 1;
    if (flash > 0) { cx.fillStyle = `rgba(255,255,255,${flash})`; cx.fillRect(0, 0, W, H); flash -= 0.04; }
    cx.globalCompositeOperation = 'source-over';
    requestAnimationFrame(fx);
  };
  requestAnimationFrame(fx);
  const burst = (n = 160) => { for (let i = 0; i < n; i++) { const a = Math.random() * 6.28, v = R.range(2, 9); sparks.push({ x: W / 2, y: H * 0.45, vx: Math.cos(a) * v, vy: Math.sin(a) * v - 3, l: 1, c: R.pick(colors) }); } };
  const stage = $('.stage', el);
  const timers = [];
  const at = (ms, f) => timers.push(setTimeout(f, ms));
  stage.innerHTML = `<div class="bigpack">${packArtHTML(id)}</div><div class="dim press" style="font-weight:800">Opening ${PACKS[id].name}…</div>`;
  Audio2.sfx('riser');
  const tweenBeams = (to, ms) => { const from = beams, s = performance.now(); const st = () => { const k = Math.min(1, (performance.now() - s) / ms); beams = from + (to - from) * k; if (k < 1) requestAnimationFrame(st); }; st(); };
  tweenBeams(0.4 + lvl * 0.15, 1400);
  at(1500, () => { $('.bigpack', stage).style.setProperty('--s', '1.4'); $('.bigpack', stage).style.opacity = 0; $('.bigpack', stage).style.transition = 'all .35s'; flash = 0.9; Audio2.sfx('whoosh'); });
  if (isWalkout) {
    const seq = [
      () => `<div class="walk-el">${flagSVG(best.nat, 240, 160)}<div style="font-size:30px;margin-top:10px">${NATIONS[best.nat].name}</div></div>`,
      () => `<div class="walk-el">${best.pos}</div>`,
      () => `<div class="walk-el">${crestSVG(best.club, 200)}<div style="font-size:26px;margin-top:10px">${CLUBS[best.club].name}</div></div>`,
      () => `<div class="walk-el" style="font-size:140px;color:${colors[0]}">${best.ovr}</div>`
    ];
    seq.forEach((f, i) => at(2000 + i * 1300, () => { stage.innerHTML = f(); Audio2.sfx(i === 3 ? 'boom' : 'reveal'); tweenBeams(0.6 + lvl * 0.1 + i * 0.1, 400); if (i === 3) { burst(120); flash = 0.4; } }));
    at(2000 + 4 * 1300, () => reveal());
  } else at(2000, () => reveal());
  function reveal() {
    phase = 'reveal'; flash = 0.7; burst(lvl ? 220 : 60); tweenBeams(1, 300);
    Audio2.sfx(lvl >= 2 ? 'bigreveal' : 'reveal');
    stage.innerHTML = `<div class="reveal-card">${cardHTML(best, { nav: false, cls: 'shine' })}</div><div style="font-weight:900;font-size:20px;text-shadow:0 2px 10px #000">${esc(best.name)} · ${rarityName(best)}</div><button class="btn primary cont" data-nav><span class="key">A</span> Continue</button>`;
    $('.cont', stage).onclick = () => finish();
    setTimeout(() => $('.cont', stage)?.focus(), 400);
    $('.skip', el).classList.add('hidden');
  }
  $('.skip', el).onclick = () => { timers.forEach(clearTimeout); reveal(); };
  function finish() {
    if (done) return; done = true;
    timers.forEach(clearTimeout);
    Input.popLayer(layer); el.remove(); Audio2.musicStart();
    UI.go('packresult', { packId: id });
  }
}
SCREENS.packresult = {
  bg: 'hub',
  render(params) {
    const { el, body } = subShell('Pack Items', params.packId ? PACKS[params.packId].name : 'Unassigned');
    const pend = Save.data.pending || [];
    const draw = () => {
      const left = pend.filter(x => !x.done);
      body.innerHTML = `<div class="row" style="margin-bottom:10px;gap:10px"><div class="grow dim">${left.length} of ${pend.length} items to assign · Select an item for actions</div>
        <button class="btn small qsd" data-nav>Quick sell duplicates</button><button class="btn primary sall" data-nav ${left.length ? 'data-autofocus' : ''}>Send all to club</button></div>
        <div class="po-grid scroll" style="flex:1">${pend.map((x, i) => { const p = P(x.pid); const dupe = Club.ownsPid(p.id); return `<div class="po-item ${x.done ? 'done' : ''}">${cardHTML(p, { untr: x.untr, extra: dupe && !x.done ? '<div class="c-dupe">DUPLICATE</div>' : '' }).replace('data-pid', `data-i="${i}" data-pid`)}<div class="st ${x.done ? 'dim' : dupe ? 'warn' : 'good'}">${x.done || (dupe ? 'Duplicate' : 'New')}</div></div>`; }).join('')}</div>`;
      $$('.po-grid .card', body).forEach(c => c.onclick = () => itemAct(+c.dataset.i));
      $('.sall', body).onclick = () => { pend.forEach(x => { if (!x.done) { Club.add(x.pid, x.untr, 'pack'); x.done = 'Sent to club'; } }); finishAll(); };
      $('.qsd', body).onclick = () => { let tot = 0; pend.forEach(x => { if (!x.done && Club.ownsPid(x.pid)) { tot += quickSellValue(P(x.pid)); x.done = 'Quick sold'; } }); if (tot) Wallet.add('coins', tot, 'Quick sold pack duplicates', 'quicksell'); Save.dirty(); draw(); if (!pend.some(x => !x.done)) finishAll(); };
    };
    const finishAll = () => { Save.data.pending = []; Save.dirty(); toast('Items assigned', 'good'); UI.go('store', { tab: Save.data.unopened.length ? 'mine' : 'packs' }, { push: false }); };
    const itemAct = async (i) => {
      const x = pend[i]; if (x.done) return;
      const p = P(x.pid);
      const best = bestOwnedForPos(p.pos);
      const acts = [{ label: 'Send to Club', value: 'club', primary: true }, { label: `Quick sell (${fmtFull(quickSellValue(p))})`, value: 'qs', danger: true }];
      if (!x.untr) acts.splice(1, 0, { label: 'List on Transfer Market', value: 'list' });
      if (best) acts.push({ label: `Compare with ${best.ovr} ${shortName(best.name)}`, value: 'cmp' });
      const v = await inspectCard(p, { item: { untr: x.untr }, actions: acts });
      if (v === 'club') { Club.add(p.id, x.untr, 'pack'); x.done = 'Sent to club'; }
      else if (v === 'qs') { Wallet.add('coins', quickSellValue(p), `Quick sold ${p.name}`, 'quicksell'); x.done = 'Quick sold'; }
      else if (v === 'list') { const it = Club.add(p.id, x.untr, 'pack'); if (await listDialog(it.uid)) x.done = 'Listed'; else x.done = 'Sent to club'; }
      else if (v === 'cmp') { await modal({ title: 'Compare', body: compareHTML(p, best), wide: true }); }
      Save.dirty();
      if (!pend.some(y => !y.done)) return finishAll();
      draw();
    };
    if (!pend.length) body.innerHTML = '<div class="dim">No pending items.</div>';
    else draw();
    return el;
  },
  back() { const pend = Save.data.pending || []; pend.forEach(x => { if (!x.done) Club.add(x.pid, x.untr, 'pack'); }); Save.data.pending = []; Save.dirty(); UI.go('store', {}, { push: false }); }
};
