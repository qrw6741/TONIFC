/* ============================================================
   UI / MAIN MENU + boot + Kick Off, Career, Clubs, Tournaments,
   Settings, Customize, Profile
   ============================================================ */
SCREENS.title = {
  bg: 'menu', noMusic: true,
  render() {
    const el = h(`<div class="mm" style="align-items:center;justify-content:center">
      <div style="text-align:center;position:relative">
        <div class="logo27" style="font-size:110px;line-height:1">PRIME<b>27</b></div>
        <div style="font-family:var(--head);font-weight:900;letter-spacing:.5em;font-size:16px;color:var(--gold2);margin-top:6px">FOOTBALL</div>
        <div style="margin-top:60px"><button class="btn primary" data-nav data-autofocus style="font-size:16px"><span class="key">A</span> Press Start</button></div>
        <div class="dim press" style="margin-top:16px;font-size:13px">Keyboard, mouse or controller</div>
      </div></div>`);
    $('button', el).onclick = () => {
      Audio2.resume(); Audio2.sfx('boom'); Audio2.musicStart();
      if (!Save.data) UI.reset('onboard'); else UI.reset('main');
    };
    return el;
  },
  back() { }
};

SCREENS.onboard = {
  bg: 'menu',
  render() {
    const el = h(`<div class="mm" style="align-items:center;justify-content:center">
      <div class="panel" style="padding:34px 38px;width:min(620px,92vw)">
        <div class="h3" style="color:var(--gold2)">Welcome to Ultimate XI</div>
        <div class="h1" style="font-size:36px;margin:8px 0 20px">Create your club</div>
        <div class="col" style="gap:14px">
          <label class="fld">Manager name<input type="text" class="mn" maxlength="18" value="Manager" data-nav></label>
          <label class="fld">Club name<input type="text" class="cn" maxlength="22" value="Phoenix FC" data-nav></label>
          <div class="row" style="gap:18px"><div class="bprev"></div>
            <label class="fld grow">Badge colours<div class="row"><input type="color" class="c1" value="#e8b631" data-nav><input type="color" class="c2" value="#14161c" data-nav>
            <select class="ic" data-nav>${['star', 'ball', 'crown', 'bolt', 'bird', 'flame'].map(x => `<option>${x}</option>`).join('')}</select></div></label></div>
          <div class="dim" style="font-size:13px">You'll receive a starter squad, 5,000 coins, 500 Prime Points (fictional in-game credits) and a Premium Gold Pack.</div>
          <button class="btn primary go" data-nav style="align-self:flex-start"><span class="key">A</span> Start Ultimate XI</button>
        </div></div></div>`);
    const upd = () => $('.bprev', el).innerHTML = badgeSVG({ shape: 'shield', c1: $('.c1', el).value, c2: $('.c2', el).value, icon: $('.ic', el).value }, 64);
    $$('input,select', el).forEach(i => i.oninput = upd); upd();
    $('.go', el).onclick = () => {
      Save.create($('.mn', el).value.trim() || 'Manager');
      const pr = Save.data.profile;
      pr.clubName = $('.cn', el).value.trim() || 'Phoenix FC';
      pr.badge = { shape: 'shield', c1: $('.c1', el).value, c2: $('.c2', el).value, icon: $('.ic', el).value };
      pr.kit.home.c1 = pr.badge.c1; pr.kit.home.c2 = pr.badge.c2;
      grantStarter();
      Save.data.onboarded = true; Save.now();
      utTransition(() => UI.reset('home'));
    };
    return el;
  },
  back() { UI.reset('title'); }
};

function grantStarter() {
  // starter squad: a balanced mix of bronze/silver/gold (untradeable)
  const need = { GK: 2, CB: 4, LB: 2, RB: 2, CDM: 2, CM: 3, CAM: 1, LM: 1, RM: 1, LW: 1, RW: 1, ST: 3 };
  const base = DB.players.filter(p => p.type === 'base');
  const lg = R.pick(['PCL', 'LSO', 'SAU', 'BKL', 'LLU', 'APL']);
  for (const pos in need) {
    for (let i = 0; i < need[pos]; i++) {
      const target = i === 0 ? R.int(68, 75) : R.int(58, 68);
      const pool = base.filter(p => p.pos === pos && Math.abs(p.ovr - target) <= 2 && (i === 0 ? p.lg === lg : true) && !Club.ownsPid(p.id));
      const p = pool.length ? R.pick(pool) : R.pick(base.filter(x => x.pos === pos));
      Club.add(p.id, true, 'starter');
    }
  }
  const s = Squads.create('Starter XI', '4-3-3');
  Squads.autoBuild(s);
  Save.data.unopened.push('premium');
  Save.data.profile.history.unshift({ t: Date.now(), text: `${Save.data.profile.clubName} joined Ultimate XI` });
}

/* animated transition into Ultimate XI */
function utTransition(cb) {
  Audio2.sfx('whoosh');
  const el = h(`<div style="position:fixed;inset:0;z-index:500;pointer-events:none;overflow:hidden">
    <div class="wipe" style="position:absolute;inset:-20%;background:linear-gradient(110deg,#0a1a1d 0%,#0f3b3a 40%,#3fe0c5 50%,#0f3b3a 60%,#05090c 100%);transform:translateX(-120%) skewX(-12deg);transition:transform .55s cubic-bezier(.7,0,.3,1)"></div>
    <div class="lg" style="position:absolute;inset:0;display:grid;place-items:center;opacity:0;transition:all .35s"><div style="text-align:center"><div style="font-family:var(--head);font-weight:900;font-size:84px;letter-spacing:.02em;font-style:italic">ULTIMATE <span style="color:var(--teal)">XI</span></div><div class="dim" style="letter-spacing:.4em;font-weight:800">PRIME FOOTBALL 27</div></div></div></div>`);
  document.body.appendChild(el);
  requestAnimationFrame(() => { $('.wipe', el).style.transform = 'translateX(0) skewX(-12deg)'; });
  setTimeout(() => { $('.lg', el).style.opacity = 1; $('.lg', el).style.transform = 'scale(1.05)'; Audio2.sfx('boom'); cb(); }, 560);
  setTimeout(() => { $('.lg', el).style.opacity = 0; $('.wipe', el).style.transform = 'translateX(120%) skewX(-12deg)'; }, 1300);
  setTimeout(() => el.remove(), 1950);
}

const MM_ITEMS = [
  { k: 'ut', label: 'Ultimate XI', sub: 'Build your dream squad' },
  { k: 'kickoff', label: 'Kick Off', sub: 'Quick match with any club' },
  { k: 'career', label: 'Career Mode', sub: 'Manage a club through a season' },
  { k: 'clubs', label: 'Clubs', sub: 'Explore every league & club' },
  { k: 'tourn', label: 'Tournaments', sub: 'Knockout cups' },
  { k: 'customize', label: 'Customize', sub: 'Badge, kits & stadium' },
  { k: 'profile', label: 'Profile', sub: 'Stats & history' },
  { k: 'settings', label: 'Settings', sub: 'Audio, gameplay & saves' }
];
SCREENS.main = {
  bg: 'menu',
  render() {
    const pr = Save.data.profile;
    const el = h(`<div class="mm">
      <div class="topbar"><div class="brand"><span class="logo27">PRIME<b>27</b></span></div>
        <div class="cur"><span style="font-weight:700">${esc(pr.name)}</span><span class="lvl">LVL ${pr.level}</span><span><i class="pts"></i><b data-points>${fmtFull(Save.data.points)}</b></span></div></div>
      <div class="mm-body"><div class="mm-list">${MM_ITEMS.map((m, i) => `<button class="mm-item" data-nav data-k="${m.k}" ${i === 0 ? 'data-autofocus' : ''}>${m.label}<span class="sub">${m.sub}</span></button>`).join('')}</div>
      <div class="mm-feature"></div></div>
      ${hintsHTML(`<span class="r">Prime Football 27 · original fictional players & clubs</span>`)}</div>`);
    const feat = $('.mm-feature', el);
    const show = k => { feat.innerHTML = ''; feat.appendChild(mmFeature(k)); };
    $$('.mm-item', el).forEach(b => {
      b.addEventListener('focus', () => show(b.dataset.k));
      b.onclick = () => { Audio2.sfx('select'); mmGo(b.dataset.k); };
    });
    show('ut');
    return el;
  },
  back() { modal({ title: 'Quit to title?', body: 'Your progress is saved automatically.', buttons: [{ label: 'Stay', value: false, cancel: true }, { label: 'Title screen', value: true, primary: true }] }).then(v => v && UI.reset('title')); }
};
function mmGo(k) {
  if (k === 'ut') return utTransition(() => UI.go('home'));
  const map = { kickoff: 'kickoff', career: 'career', clubs: 'clubs', tourn: 'tourn', customize: 'customize', profile: 'profile', settings: 'settings' };
  UI.go(map[k]);
}
function mmFeature(k) {
  let html = '';
  const btn = (label) => `<button class="btn primary ftgo" data-nav><span class="key">A</span> ${label}</button>`;
  if (k === 'ut') {
    const totw = DB.players.filter(p => p.type === 'totw').sort((a, b) => b.ovr - a.ovr).slice(0, 4);
    html = `<div class="ft-body"><div class="ft-title">Team of<br>the Week 1</div><div class="ft-sub">New Team of the Week is now available in packs for a limited time!</div>${btn('Enter Ultimate XI')}<div class="ft-dots"><i class="on"></i><i></i></div></div>
      <div class="ft-cards">${totw.map(p => cardHTML(p, { nav: false })).join('')}</div>`;
  } else if (k === 'kickoff') {
    html = `<div class="ft-body"><div class="ft-title">Kick Off</div><div class="ft-sub">Pick any two of 48 clubs across six leagues and play a full 11v11 match.</div>${btn('Play Kick Off')}</div>
      <div class="ft-art row" style="gap:30px">${crestSVG('NGC', 150)}<span style="font-family:var(--head);font-weight:900;font-size:40px">VS</span>${crestSVG('RAU', 150)}</div>`;
  } else if (k === 'career') {
    const c = Save.data.career;
    html = `<div class="ft-body"><div class="ft-title">Manager Career</div><div class="ft-sub">${c ? `Continue with ${CLUBS[c.club].name} — Matchday ${Math.min(c.round + 1, 14)} of 14.` : 'Take charge of a club and chase the league title over a 14-matchday season.'}</div>${btn(c ? 'Continue Career' : 'New Career')}</div>
      <div class="ft-art">${c ? crestSVG(c.club, 200) : '<div style="font-size:180px;opacity:.5">🏆</div>'}</div>`;
  } else if (k === 'clubs') {
    html = `<div class="ft-body"><div class="ft-title">Clubs</div><div class="ft-sub">Explore all leagues, clubs and squads in the Prime Football 27 database. Play a friendly as any club.</div>${btn('Explore Clubs')}</div>
      <div class="ft-art row wrap" style="gap:12px;width:320px">${Object.keys(CLUBS).filter(c => !CLUBS[c].special).slice(0, 12).map(c => crestSVG(c, 64)).join('')}</div>`;
  } else if (k === 'tourn') {
    html = `<div class="ft-body"><div class="ft-title">Tournaments</div><div class="ft-sub">Enter the 8-team Prime Cup knockout. Win three matches to lift the trophy.</div>${btn('Enter Tournament')}</div><div class="ft-art" style="font-size:180px;opacity:.55">🏆</div>`;
  } else if (k === 'customize') {
    const pr = Save.data.profile;
    html = `<div class="ft-body"><div class="ft-title">Customize</div><div class="ft-sub">Club name, badge, home & away kits, stadium and tifo.</div>${btn('Customize Club')}</div><div class="ft-art row" style="gap:20px">${badgeSVG(pr.badge, 170)}${kitSVG(pr.kit.home, 140)}</div>`;
  } else if (k === 'profile') {
    const s = Save.data.stats;
    html = `<div class="ft-body"><div class="ft-title">${esc(Save.data.profile.name)}</div><div class="ft-sub">${s.played} matches · ${s.wins}W ${s.draws}D ${s.losses}L · ${s.gf} goals</div>${btn('View Profile')}</div>`;
  } else {
    html = `<div class="ft-body"><div class="ft-title">Settings</div><div class="ft-sub">Audio, gameplay difficulty, match length, camera, controls and save management.</div>${btn('Open Settings')}</div>`;
  }
  const el = h(`<div style="height:100%;display:flex;flex-direction:column;justify-content:center">${html}</div>`);
  $('.ftgo', el).onclick = () => { Audio2.sfx('select'); mmGo(k); };
  return el;
}

/* ---------------- Kick Off ---------------- */
function clubOptions(sel) {
  return Object.entries(LEAGUES).filter(([k, L]) => !L.special).map(([lk, L]) => `<optgroup label="${L.name}">${Object.entries(CLUBS).filter(([c, cl]) => cl.lg === lk).map(([c, cl]) => `<option value="${c}" ${c === sel ? 'selected' : ''}>${cl.name}</option>`).join('')}</optgroup>`).join('');
}
function clubTeam(code, { formation } = {}) {
  const sq = buildAISquad(0, { club: code, formation: formation || '4-3-3' });
  // pick best XI from club
  const s = { formation: sq.formation, players: [], subs: [] };
  const roster = DB.byClub[code].filter(p => p.type === 'base').sort((a, b) => b.ovr - a.ovr);
  const used = new Set();
  FORMATIONS[s.formation].forEach(([pos]) => {
    let p = roster.find(x => !used.has(x.id) && x.pos === pos) || roster.find(x => !used.has(x.id) && playerFitsPos(x, pos)) || roster.find(x => !used.has(x.id) && x.pos !== 'GK');
    used.add(p.id); s.players.push(p);
  });
  s.subs = roster.filter(x => !used.has(x.id)).slice(0, 7);
  const cl = CLUBS[code];
  return { name: cl.name, short: code, kit: { c1: cl.c[0], c2: cl.c[1] }, formation: s.formation, players: s.players, subs: s.subs, crest: code };
}
function teamOvr(t) { return squadRating(t.players); }
SCREENS.kickoff = {
  bg: 'menu',
  render(params) {
    const { el, body } = subShell('Kick Off', 'Play Now');
    el.classList.add('mm'); el.classList.remove('hub');
    body.innerHTML = `<div class="row" style="gap:40px;justify-content:center;align-items:stretch;flex:1">
      ${['home', 'away'].map((s, i) => `<div class="panel col" style="padding:24px;width:340px;align-items:center;gap:14px">
        <div class="h3">${s === 'home' ? 'Home (you)' : 'Away (CPU)'}</div><div class="crest-${s}" style="height:150px;display:grid;place-items:center"></div>
        <select class="sel-${s}" data-nav style="width:100%">${clubOptions(params[s] || (i ? 'RAU' : 'NGC'))}</select>
        <div class="ovr-${s}" style="font-weight:800"></div></div>`).join('<div style="align-self:center;font-family:var(--head);font-weight:900;font-size:44px">VS</div>')}
    </div>
    <div class="row" style="justify-content:center;gap:14px;margin-top:20px;flex-wrap:wrap">
      <label class="fld">Difficulty<select class="diff" data-nav>${Object.entries(DIFFICULTIES).map(([k, d]) => `<option value="${k}" ${k === Save.data.settings.difficulty ? 'selected' : ''}>${d.name}</option>`).join('')}</select></label>
      <label class="fld">Half length<select class="hl" data-nav>${[2, 3, 4, 5, 6, 8, 10].map(m => `<option value="${m}" ${m === Save.data.settings.halfLen ? 'selected' : ''}>${m} min</option>`).join('')}</select></label>
      <button class="btn primary play" data-nav style="align-self:flex-end"><span class="key">A</span> Play Match</button>
      <button class="btn sim" data-nav style="align-self:flex-end">Simulate</button></div>`;
    const upd = () => ['home', 'away'].forEach(s => { const c = $('.sel-' + s, el).value; $('.crest-' + s, el).innerHTML = crestSVG(c, 140); $('.ovr-' + s, el).textContent = `Team rating ${teamOvr(clubTeam(c))} · ${LEAGUES[CLUBS[c].lg].name}`; });
    $$('select', el).forEach(s => s.onchange = upd); upd();
    const go = (sim) => {
      const home = clubTeam($('.sel-home', el).value), away = clubTeam($('.sel-away', el).value);
      runMatch({ home, away, difficulty: $('.diff', el).value, halfLen: +$('.hl', el).value, sim, mode: 'kickoff', title: 'Kick Off' }, res => showResults(res, { title: 'Kick Off', onContinue: () => UI.go('kickoff', { home: home.short, away: away.short }, { push: false }) }));
    };
    $('.play', el).onclick = () => go(false); $('.sim', el).onclick = () => go(true);
    return el;
  }
};

/* ---------------- Career (simplified manager career) ---------------- */
function roundRobin(teams) {
  const t = teams.slice(), n = t.length, rounds = [];
  for (let r = 0; r < n - 1; r++) {
    const rd = [];
    for (let i = 0; i < n / 2; i++) { const a = t[i], b = t[n - 1 - i]; rd.push(r % 2 ? [b, a] : [a, b]); }
    rounds.push(rd); t.splice(1, 0, t.pop());
  }
  return rounds.concat(rounds.map(rd => rd.map(([a, b]) => [b, a])));
}
function simScore(aStr, bStr, homeAdv = 1.5) {
  const diff = (aStr + homeAdv - bStr) / 10;
  const la = clamp(1.35 + diff * 0.9, 0.2, 4), lb = clamp(1.15 - diff * 0.9, 0.2, 4);
  const pois = l => { let L = Math.exp(-l), k = 0, p = 1; do { k++; p *= Math.random(); } while (p > L); return k - 1; };
  return [pois(la), pois(lb)];
}
SCREENS.career = {
  bg: 'menu',
  render() {
    const c = Save.data.career;
    const { el, body } = subShell('Manager Career', 'Career Mode');
    el.classList.add('mm'); el.classList.remove('hub');
    if (!c) {
      body.innerHTML = `<div class="panel col" style="padding:28px;max-width:560px;gap:14px"><div class="h2">Start a new career</div>
        <div class="dim">Choose a club. You'll play a double round-robin league against the 7 other clubs in its league (14 matchdays). Play or simulate each fixture. Finish top to win the title and earn Ultimate XI coins.</div>
        <select class="cl" data-nav>${clubOptions('KBU')}</select><button class="btn primary go" data-nav><span class="key">A</span> Start Career</button></div>`;
      $('.go', el).onclick = () => {
        const club = $('.cl', el).value, lg = CLUBS[club].lg;
        const teams = Object.keys(CLUBS).filter(k => CLUBS[k].lg === lg);
        Save.data.career = { club, lg, season: 1, round: 0, fixtures: roundRobin(R.shuffle(teams)), table: Object.fromEntries(teams.map(t => [t, { p: 0, w: 0, d: 0, l: 0, gf: 0, ga: 0, pts: 0 }])), results: [] };
        Save.dirty(); UI.rerender();
      };
      return el;
    }
    const tbl = Object.entries(c.table).sort((a, b) => b[1].pts - a[1].pts || (b[1].gf - b[1].ga) - (a[1].gf - a[1].ga) || b[1].gf - a[1].gf);
    const done = c.round >= c.fixtures.length;
    const fx = !done ? c.fixtures[c.round].find(f => f.includes(c.club)) : null;
    body.innerHTML = `<div class="row" style="gap:24px;align-items:stretch;flex:1;min-height:0">
      <div class="panel col scroll" style="padding:18px;flex:1.3"><div class="h3">${LEAGUES[c.lg].name} · Season ${c.season}</div>
        <table class="tbl"><tr><th>#</th><th>Club</th><th>P</th><th>W</th><th>D</th><th>L</th><th>GD</th><th>Pts</th></tr>
        ${tbl.map(([k, r], i) => `<tr class="${k === c.club ? 'me' : ''}"><td>${i + 1}</td><td><span class="row" style="gap:8px">${crestSVG(k, 20)}${CLUBS[k].name}</span></td><td>${r.p}</td><td>${r.w}</td><td>${r.d}</td><td>${r.l}</td><td>${r.gf - r.ga}</td><td><b>${r.pts}</b></td></tr>`).join('')}</table></div>
      <div class="col" style="flex:1;gap:16px">
        <div class="panel col" style="padding:20px;gap:12px;align-items:center">
          ${done ? `<div class="h2">Season complete</div><div>${tbl[0][0] === c.club ? '🏆 Champions!' : `Finished ${tbl.findIndex(t => t[0] === c.club) + 1}${['st', 'nd', 'rd'][tbl.findIndex(t => t[0] === c.club)] || 'th'}`}</div><button class="btn primary ns" data-nav><span class="key">A</span> Next season</button>` :
        `<div class="h3">Matchday ${c.round + 1} of ${c.fixtures.length}</div><div class="row" style="gap:20px;align-items:center">${crestSVG(fx[0], 80)}<b style="font-family:var(--head);font-weight:900;font-size:26px">VS</b>${crestSVG(fx[1], 80)}</div>
          <div style="font-weight:800">${CLUBS[fx[0]].name} vs ${CLUBS[fx[1]].name}</div><div class="row"><button class="btn primary pl" data-nav><span class="key">A</span> Play</button><button class="btn sm" data-nav>Simulate</button></div>`}
        </div>
        <div class="panel col scroll" style="padding:16px;flex:1;min-height:0"><div class="h3">Your results</div>${c.results.slice().reverse().map(r => `<div class="row" style="justify-content:space-between;padding:5px 0;border-bottom:1px solid var(--line)"><span>MD${r.md} ${CLUBS[r.h].name}</span><b>${r.hg} - ${r.ag}</b><span>${CLUBS[r.a].name}</span></div>`).join('') || '<div class="dim">No matches yet</div>'}</div>
        <button class="btn danger small quit" data-nav style="align-self:flex-start">Abandon career</button>
      </div></div>`;
    const playRound = (myRes) => {
      const fxs = c.fixtures[c.round];
      for (const [hm, aw] of fxs) {
        let hg, ag;
        if (hm === fx[0] && aw === fx[1]) { hg = myRes.hg; ag = myRes.ag; c.results.push({ md: c.round + 1, h: hm, a: aw, hg, ag }); }
        else[hg, ag] = simScore(teamOvr(clubTeam(hm)), teamOvr(clubTeam(aw)));
        const H = c.table[hm], A = c.table[aw];
        H.p++; A.p++; H.gf += hg; H.ga += ag; A.gf += ag; A.ga += hg;
        if (hg > ag) { H.w++; H.pts += 3; A.l++; } else if (hg < ag) { A.w++; A.pts += 3; H.l++; } else { H.d++; A.d++; H.pts++; A.pts++; }
      }
      c.round++;
      if (c.round >= c.fixtures.length) {
        const tb = Object.entries(c.table).sort((a, b) => b[1].pts - a[1].pts || (b[1].gf - b[1].ga) - (a[1].gf - a[1].ga));
        const pos = tb.findIndex(t => t[0] === c.club) + 1;
        const coins = Math.max(1000, 12000 - pos * 1400);
        Wallet.add('coins', coins, `Career season ${c.season}: finished #${pos}`);
        Save.data.profile.history.unshift({ t: Date.now(), text: `Career: ${CLUBS[c.club].name} finished #${pos} in season ${c.season}` });
      }
      Save.dirty();
    };
    if (!done) {
      const go = sim => {
        const userHome = fx[0] === c.club;
        const home = clubTeam(fx[0]), away = clubTeam(fx[1]);
        runMatch({ home, away, userSide: userHome ? 'home' : 'away', difficulty: Save.data.settings.difficulty, halfLen: Save.data.settings.halfLen, sim, mode: 'career', title: `Matchday ${c.round + 1}` }, res => {
          playRound(res); showResults(res, { title: `Career · Matchday ${c.round}`, onContinue: () => UI.go('career', {}, { push: false }) });
        });
      };
      $('.pl', el).onclick = () => go(false); $('.sm', el).onclick = () => go(true);
    } else {
      $('.ns', el).onclick = () => { const teams = Object.keys(c.table); c.season++; c.round = 0; c.results = []; c.fixtures = roundRobin(R.shuffle(teams)); teams.forEach(t => c.table[t] = { p: 0, w: 0, d: 0, l: 0, gf: 0, ga: 0, pts: 0 }); Save.dirty(); UI.rerender(); };
    }
    $('.quit', el).onclick = async () => { if (await modal({ title: 'Abandon career?', body: 'This deletes your current career save.', buttons: [{ label: 'Cancel', value: false, cancel: true }, { label: 'Abandon', value: true, danger: true }] })) { Save.data.career = null; Save.dirty(); UI.rerender(); } };
    return el;
  }
};

/* ---------------- Clubs explorer ---------------- */
SCREENS.clubs = {
  bg: 'menu',
  render(params) {
    const { el, body } = subShell('Clubs', 'Explore');
    el.classList.add('mm'); el.classList.remove('hub');
    const lg = params.lg || 'PCL', club = params.club;
    body.innerHTML = `<div class="row" style="gap:20px;flex:1;min-height:0;align-items:stretch">
      <div class="panel col" style="padding:14px;width:250px;gap:4px">${Object.entries(LEAGUES).filter(([k, L]) => !L.special).map(([k, L]) => `<button class="prow" data-nav data-lg="${k}" style="${k === lg ? 'border-color:var(--teal)' : ''}">${leagueSVG(k, 24)} ${L.name}</button>`).join('')}</div>
      <div class="panel col scroll" style="padding:14px;width:300px;gap:4px">${Object.entries(CLUBS).filter(([c, cl]) => cl.lg === lg).map(([c, cl]) => `<button class="prow" data-nav data-club="${c}" ${c === club ? 'data-autofocus' : ''} style="${c === club ? 'border-color:var(--teal)' : ''}">${crestSVG(c, 26)} <span class="grow">${cl.name}</span><b>${teamOvr(clubTeam(c))}</b></button>`).join('')}</div>
      <div class="panel col grow" style="padding:16px;min-height:0">${club ? `<div class="row"><div>${crestSVG(club, 60)}</div><div class="grow"><div class="h2">${CLUBS[club].name}</div><div class="dim">${LEAGUES[CLUBS[club].lg].name} · ${DB.byClub[club].filter(p => p.type === 'base').length} players · Team rating ${teamOvr(clubTeam(club))}</div></div><button class="btn primary fr" data-nav>Play friendly as ${club}</button></div>
        <div class="plist scroll" style="flex:1;margin-top:10px">${DB.byClub[club].filter(p => p.type === 'base').sort((a, b) => b.ovr - a.ovr).map(p => cardHTML(p)).join('')}</div>` : '<div class="dim" style="margin:auto">Select a club to view its squad</div>'}</div></div>`;
    $$('[data-lg]', el).forEach(b => b.onclick = () => UI.go('clubs', { lg: b.dataset.lg }, { push: false }));
    $$('[data-club]', el).forEach(b => b.onclick = () => UI.go('clubs', { lg, club: b.dataset.club }, { push: false }));
    $$('.plist .card', el).forEach(c => c.onclick = () => inspectCard(P(c.dataset.pid)));
    if (club) $('.fr', el).onclick = () => UI.go('kickoff', { home: club, away: R.pick(Object.keys(CLUBS).filter(k => !CLUBS[k].special && k !== club)) });
    return el;
  },
  back() { UI.reset('main'); }
};

/* ---------------- Tournaments (8-team knockout) ---------------- */
SCREENS.tourn = {
  bg: 'menu',
  render() {
    const T = Save.data.tourn;
    const { el, body } = subShell('Prime Cup', 'Tournaments');
    el.classList.add('mm'); el.classList.remove('hub');
    if (!T) {
      body.innerHTML = `<div class="panel col" style="padding:28px;max-width:560px;gap:14px"><div class="h2">Enter the Prime Cup</div><div class="dim">8 clubs, single-elimination. Win the Quarter-Final, Semi-Final and Final. Winners earn 15,000 Ultimate XI coins.</div>
        <select class="cl" data-nav>${clubOptions('EPA')}</select><button class="btn primary go" data-nav><span class="key">A</span> Start Tournament</button></div>`;
      $('.go', el).onclick = () => {
        const me = $('.cl', el).value;
        const others = R.shuffle(Object.keys(CLUBS).filter(k => !CLUBS[k].special && k !== me)).slice(0, 7);
        Save.data.tourn = { me, rounds: [R.shuffle([me, ...others])], stage: 0, out: false, results: [] };
        Save.dirty(); UI.rerender();
      };
      return el;
    }
    const names = ['Quarter-Finals', 'Semi-Finals', 'Final'];
    const cur = T.rounds[T.stage] || [];
    const champion = T.stage === 3 ? T.rounds[3][0] : null;
    const myIdx = cur.indexOf(T.me);
    const opp = myIdx >= 0 ? cur[myIdx ^ 1] : null;
    body.innerHTML = `<div class="row" style="gap:30px;flex:1;align-items:center;justify-content:center">
      ${T.rounds.map((rd, ri) => `<div class="col" style="gap:${10 + ri * 30}px"><div class="h3">${names[ri] || 'Champion'}</div>${rd.map(c => `<div class="panel row" style="padding:8px 12px;gap:8px;min-width:200px;${c === T.me ? 'border-color:var(--gold)' : ''}">${crestSVG(c, 24)}<span style="font-weight:700">${CLUBS[c].name}</span></div>`).join('')}</div>`).join('')}
      <div class="panel col" style="padding:22px;gap:12px;align-items:center;min-width:260px">
        ${champion ? `<div style="font-size:70px">🏆</div><div class="h2">${CLUBS[champion].name}</div><div>${champion === T.me ? 'You won the Prime Cup!' : 'Cup winners'}</div><button class="btn primary nw" data-nav>New tournament</button>` :
        T.out ? `<div class="h2">Knocked out</div><button class="btn primary nw" data-nav>New tournament</button>` :
          `<div class="h3">${names[T.stage]}</div><div class="row" style="gap:16px">${crestSVG(T.me, 64)}<b>VS</b>${crestSVG(opp, 64)}</div><div class="row"><button class="btn primary pl" data-nav><span class="key">A</span> Play</button><button class="btn sm" data-nav>Simulate</button></div>`}
      </div></div>`;
    const advance = (myWon) => {
      const next = [];
      for (let i = 0; i < cur.length; i += 2) {
        const a = cur[i], b = cur[i + 1];
        if (a === T.me || b === T.me) next.push(myWon ? T.me : (a === T.me ? b : a));
        else { const [x, y] = simScore(teamOvr(clubTeam(a)), teamOvr(clubTeam(b)), 0); next.push(x > y ? a : x < y ? b : R.pick([a, b])); }
      }
      T.rounds.push(next); T.stage++;
      if (!myWon) T.out = true;
      // auto-sim remaining rounds if knocked out
      while (T.out && T.rounds[T.stage].length > 1) {
        const rd = T.rounds[T.stage], nx = [];
        for (let i = 0; i < rd.length; i += 2) { const [x, y] = simScore(teamOvr(clubTeam(rd[i])), teamOvr(clubTeam(rd[i + 1])), 0); nx.push(x >= y ? rd[i] : rd[i + 1]); }
        T.rounds.push(nx); T.stage++;
      }
      if (T.stage === 3 && T.rounds[3][0] === T.me) { Wallet.add('coins', 15000, 'Prime Cup winners'); Save.data.profile.history.unshift({ t: Date.now(), text: `Won the Prime Cup with ${CLUBS[T.me].name}` }); }
      Save.dirty();
    };
    if (!champion && !T.out) {
      const go = sim => runMatch({ home: clubTeam(T.me), away: clubTeam(opp), difficulty: Save.data.settings.difficulty, halfLen: Save.data.settings.halfLen, sim, knockout: true, mode: 'tourn', title: names[T.stage] }, res => {
        advance(res.winner === 'home'); showResults(res, { title: `Prime Cup · ${names[T.stage - 1]}`, onContinue: () => UI.go('tourn', {}, { push: false }) });
      });
      $('.pl', el).onclick = () => go(false); $('.sm', el).onclick = () => go(true);
    } else $('.nw', el).onclick = () => { Save.data.tourn = null; Save.dirty(); UI.rerender(); };
    return el;
  },
  back() { UI.reset('main'); }
};

/* ---------------- Settings ---------------- */
SCREENS.settings = {
  bg: 'menu',
  render() {
    const s = Save.data.settings;
    const { el, body } = subShell('Settings', 'Options');
    el.classList.add('mm'); el.classList.remove('hub');
    body.innerHTML = `<div class="row" style="gap:20px;align-items:flex-start;flex:1;min-height:0">
      <div class="panel col" style="padding:22px;width:400px;gap:14px"><div class="h3">Audio</div>
        ${[['music', 'Music volume'], ['sfx', 'Effects volume'], ['crowd', 'Crowd volume']].map(([k, l]) => `<label class="fld">${l}<input type="range" min="0" max="1" step="0.05" value="${s[k]}" data-k="${k}" data-nav></label>`).join('')}
        <div class="h3" style="margin-top:8px">Gameplay</div>
        <label class="fld">Default difficulty<select data-k="difficulty" data-nav>${Object.entries(DIFFICULTIES).map(([k, d]) => `<option value="${k}" ${k === s.difficulty ? 'selected' : ''}>${d.name}</option>`).join('')}</select></label>
        <label class="fld">Half length<select data-k="halfLen" data-nav>${[2, 3, 4, 5, 6, 8, 10].map(m => `<option value="${m}" ${m === s.halfLen ? 'selected' : ''}>${m} minutes</option>`).join('')}</select></label>
        <label class="fld">Camera<select data-k="camera" data-nav>${[['broadcast', 'Broadcast'], ['tele', 'Tele Broadcast (closer)'], ['wide', 'Wide']].map(([k, l]) => `<option value="${k}" ${k === s.camera ? 'selected' : ''}>${l}</option>`).join('')}</select></label>
        <label class="row" style="gap:10px;font-weight:700"><input type="checkbox" data-k="showLinks" ${s.showLinks ? 'checked' : ''} data-nav> Show chemistry links on pitch</label>
        <label class="row" style="gap:10px;font-weight:700"><input type="checkbox" data-k="reduceMotion" ${s.reduceMotion ? 'checked' : ''} data-nav> Reduce motion</label>
      </div>
      <div class="panel col" style="padding:22px;width:420px;gap:10px"><div class="h3">Controls — Keyboard / Controller</div>
        <div class="kv" style="font-size:13px">${CONTROLS_TABLE.map(([a, k, p]) => `<span>${a}</span><span><b>${k}</b> <span class="dim">· ${p}</span></span>`).join('')}</div></div>
      <div class="panel col" style="padding:22px;width:300px;gap:12px"><div class="h3">Save data</div>
        <div class="dim" style="font-size:13px">Progress saves automatically to this browser. Export a backup file to move it to another device.</div>
        <button class="btn ex" data-nav>Export save</button><button class="btn im" data-nav>Import save</button><input type="file" class="file hidden" accept=".json">
        <button class="btn danger rs" data-nav>Reset all progress</button></div></div>`;
    $$('[data-k]', el).forEach(i => i.oninput = i.onchange = () => {
      const k = i.dataset.k;
      s[k] = i.type === 'checkbox' ? i.checked : i.type === 'range' ? +i.value : (k === 'halfLen' ? +i.value : i.value);
      Audio2.applyVolumes(); document.body.classList.toggle('reduce-motion', !!s.reduceMotion); Save.dirty();
    });
    $('.ex', el).onclick = () => { const b = new Blob([Save.exportJSON()], { type: 'application/json' }); const a = document.createElement('a'); a.href = URL.createObjectURL(b); a.download = 'prime27-save.json'; try { a.click(); } catch (e) { } try { navigator.clipboard.writeText(Save.exportJSON()).then(() => toast('Save exported (file + copied to clipboard)', 'good'), () => toast('Save file exported', 'good')); } catch (e) { toast('Save file exported', 'good'); } };
    $('.im', el).onclick = () => $('.file', el).click();
    $('.file', el).onchange = e => { const f = e.target.files[0]; if (!f) return; f.text().then(t => { try { Save.importJSON(t); toast('Save imported', 'good'); UI.reset('main'); } catch (err) { toast(err.message, 'bad'); } }); };
    $('.rs', el).onclick = async () => { if (await modal({ title: 'Reset everything?', body: 'This permanently deletes your club, players, coins and history.', buttons: [{ label: 'Cancel', value: false, cancel: true }, { label: 'Delete all progress', value: true, danger: true }] })) { Save.wipe(); UI.reset('title'); } };
    return el;
  },
  back() { UI.reset('main'); }
};
const CONTROLS_TABLE = [
  ['Move', 'WASD / Arrows', 'Left stick'], ['Sprint', 'Shift', 'RT'], ['Short pass / Header', 'J', 'A'], ['Through ball', 'I', 'Y'],
  ['Shoot (hold for power)', 'K', 'X'], ['Finesse shot', 'O (hold)', 'RB + X'], ['Lob pass / Cross', 'L', 'B'], ['Skill move', 'E + direction', 'Right stick / LB'],
  ['Standing tackle (defending)', 'J', 'B'], ['Slide tackle (defending)', 'K', 'X'], ['Switch player', 'Q', 'LB'], ['Pause / Subs', 'Esc / P', 'Start'],
  ['Menu navigate', 'Arrows / mouse', 'D-pad'], ['Menu tabs', 'Q / E', 'LB / RB']
];

/* ---------------- Customize ---------------- */
SCREENS.customize = {
  bg: 'menu',
  render() {
    const pr = Save.data.profile;
    const { el, body } = subShell('Customize', pr.clubName);
    el.classList.add('mm'); el.classList.remove('hub');
    const pats = ['plain', 'stripes', 'hoops', 'sash', 'half'];
    body.innerHTML = `<div class="row" style="gap:20px;align-items:flex-start;flex-wrap:wrap">
      <div class="panel col" style="padding:22px;width:320px;gap:12px"><div class="h3">Club & badge</div><div class="bp" style="align-self:center"></div>
        <label class="fld">Club name<input type="text" data-f="clubName" value="${esc(pr.clubName)}" maxlength="22" data-nav></label>
        <label class="fld">Badge shape<select data-f="badge.shape" data-nav>${['shield', 'round', 'hex', 'crest'].map(x => `<option ${x === pr.badge.shape ? 'selected' : ''}>${x}</option>`).join('')}</select></label>
        <label class="fld">Badge icon<select data-f="badge.icon" data-nav>${['star', 'ball', 'crown', 'bolt', 'bird', 'flame'].map(x => `<option ${x === pr.badge.icon ? 'selected' : ''}>${x}</option>`).join('')}</select></label>
        <div class="row"><label class="fld grow">Primary<input type="color" data-f="badge.c1" value="${pr.badge.c1}" data-nav></label><label class="fld grow">Secondary<input type="color" data-f="badge.c2" value="${pr.badge.c2}" data-nav></label></div></div>
      ${['home', 'away'].map(k => `<div class="panel col" style="padding:22px;width:250px;gap:12px"><div class="h3">${k} kit</div><div class="kp-${k}" style="align-self:center"></div>
        <div class="row"><label class="fld grow">Main<input type="color" data-f="kit.${k}.c1" value="${pr.kit[k].c1}" data-nav></label><label class="fld grow">Trim<input type="color" data-f="kit.${k}.c2" value="${pr.kit[k].c2}" data-nav></label></div>
        <label class="fld">Pattern<select data-f="kit.${k}.pattern" data-nav>${pats.map(x => `<option ${x === pr.kit[k].pattern ? 'selected' : ''}>${x}</option>`).join('')}</select></label></div>`).join('')}
      <div class="panel col" style="padding:22px;width:290px;gap:12px"><div class="h3">Stadium</div>
        <label class="fld">Stadium name<input type="text" data-f="stadium.name" value="${esc(pr.stadium.name)}" maxlength="24" data-nav></label>
        <label class="fld">Seat colour<input type="color" data-f="stadium.seats" value="${pr.stadium.seats}" data-nav></label>
        <label class="fld">Tifo<select data-f="stadium.tifo" data-nav>${['flames', 'stripes', 'badge', 'none'].map(x => `<option ${x === pr.stadium.tifo ? 'selected' : ''}>${x}</option>`).join('')}</select></label>
        <label class="fld">Pitch pattern<select data-f="stadium.theme" data-nav>${['gold', 'classic', 'checker'].map(x => `<option ${x === pr.stadium.theme ? 'selected' : ''}>${x}</option>`).join('')}</select></label>
        <div class="dim" style="font-size:12px">Your kits, badge, seats and tifo appear in Ultimate XI matches.</div></div></div>`;
    const upd = () => { $('.bp', el).innerHTML = badgeSVG(pr.badge, 110, pr.clubName.slice(0, 12).toUpperCase()); $('.kp-home', el).innerHTML = kitSVG(pr.kit.home, 110); $('.kp-away', el).innerHTML = kitSVG(pr.kit.away, 110); };
    $$('[data-f]', el).forEach(i => i.oninput = i.onchange = () => {
      const path = i.dataset.f.split('.'); let o = pr; for (let j = 0; j < path.length - 1; j++) o = o[path[j]];
      o[path[path.length - 1]] = i.value; upd(); Save.dirty();
    });
    upd();
    return el;
  },
  back() { UI.reset('main'); }
};

/* ---------------- Profile ---------------- */
SCREENS.profile = {
  bg: 'menu',
  render(params) {
    const pr = Save.data.profile, s = Save.data.stats;
    const { el, body } = subShell(esc(pr.name), 'Profile');
    el.classList.add('mm'); el.classList.remove('hub');
    const tab = params.tab || 'matches';
    body.innerHTML = `<div class="row" style="gap:20px;align-items:stretch;flex:1;min-height:0">
      <div class="panel col" style="padding:22px;width:330px;gap:12px">
        <div class="row">${badgeSVG(pr.badge, 64)}<div><div class="h2">${esc(pr.clubName)}</div><div class="dim">Manager ${esc(pr.name)}</div></div></div>
        <div><div class="row" style="justify-content:space-between;font-weight:800"><span>Club Level ${pr.level}</span><span class="dim">${fmtFull(pr.xp)} / ${fmtFull(XP.need(pr.level))} XP</span></div><div class="bar gold"><i style="width:${pr.xp / XP.need(pr.level) * 100}%"></i></div></div>
        <div class="kv"><span>Matches</span><span>${s.played}</span><span>W / D / L</span><span>${s.wins} / ${s.draws} / ${s.losses}</span><span>Goals for / against</span><span>${s.gf} / ${s.ga}</span><span>Packs opened</span><span>${s.packs}</span><span>SBCs completed</span><span>${s.sbcs}</span><span>Players bought / sold</span><span>${s.bought} / ${s.sold}</span><span>Club size</span><span>${Save.data.club.items.length} players</span><span>Rivals best</span><span>${RIVALS_DIVS[Save.data.modes.rivals.best].name}</span></div>
      </div>
      <div class="panel col grow" style="padding:18px;min-height:0">
        <div class="seg">${[['matches', 'Match history'], ['history', 'Club history'], ['tx', 'Transactions']].map(([k, l]) => `<button data-nav data-t="${k}" class="${k === tab ? 'on' : ''}">${l}</button>`).join('')}</div>
        <div class="scroll" style="flex:1;margin-top:12px">${tab === 'matches' ? `<table class="tbl"><tr><th>Date</th><th>Mode</th><th>Match</th><th>Score</th><th>Result</th></tr>${Save.data.matches.map(m => `<tr><td>${new Date(m.t).toLocaleDateString()}</td><td>${m.mode}</td><td>${esc(m.home)} vs ${esc(m.away)}</td><td><b>${m.hg} - ${m.ag}</b></td><td class="${m.res === 'W' ? 'good' : m.res === 'L' ? 'bad' : 'warn'}">${m.res || '—'}</td></tr>`).join('') || '<tr><td colspan=5 class="dim">No matches yet</td></tr>'}</table>`
        : tab === 'history' ? pr.history.map(x => `<div class="row" style="padding:7px 0;border-bottom:1px solid var(--line)"><span class="dim" style="width:110px">${new Date(x.t).toLocaleDateString()}</span><span>${esc(x.text)}</span></div>`).join('')
          : `<table class="tbl"><tr><th>Date</th><th>Type</th><th>Description</th><th style="text-align:right">Amount</th></tr>${Save.data.tx.map(t => `<tr><td>${new Date(t.t).toLocaleString()}</td><td>${t.kind}</td><td>${esc(t.desc)}</td><td style="text-align:right" class="${t.amount >= 0 ? 'good' : 'bad'}">${t.amount >= 0 ? '+' : ''}${fmtFull(t.amount)} <i class="${t.cur === 'coins' ? 'coin' : 'pts'}"></i></td></tr>`).join('')}</table>`}</div></div></div>`;
    $$('[data-t]', el).forEach(b => b.onclick = () => UI.go('profile', { tab: b.dataset.t }, { push: false }));
    return el;
  },
  back() { UI.reset('main'); }
};
SCREENS.kickoff.back = () => UI.reset('main');
SCREENS.career.back = () => UI.reset('main');
