/* ============================================================
   UI / COMPONENTS — reusable card, pitch, pickers, inspectors
   ============================================================ */
function cardHTML(p, { mini = false, uid: u = '', nav = true, extra = '', chem = null, untr = false, cls = '' } = {}) {
  if (!p) return '';
  const lab = p.pos === 'GK' ? GK_LABELS : STAT_LABELS;
  const typeLbl = p.type !== 'base' ? `<div class="c-type">${CARD_TYPES[p.type].name}</div>` : '';
  const tag = nav ? 'button' : 'div';
  return `<${tag} class="card r-${rarityKey(p)} ${mini ? 'mini' : ''} ${untr ? 'untr' : ''} ${cls}" ${nav ? 'data-nav' : 'tabindex="-1"'} data-pid="${p.id}" ${u ? `data-uid="${u}"` : ''} draggable="${u ? 'true' : 'false'}">
    <div class="cbg"></div><div class="ctrim"></div>${typeLbl}
    <div class="c-img">${portraitSVG(p)}</div>
    <div class="c-ovr">${p.ovr}</div><div class="c-pos">${p.pos}</div>
    <div class="c-meta">${flagSVG(p.nat)}${p.club === 'ICN' ? crestSVG('ICN') : crestSVG(p.club)}</div>
    <div class="c-name">${esc(shortName(p.name))}</div>
    <div class="c-stats">${p.stats.map((s, i) => `<div><b>${s}</b><span>${lab[i]}</span></div>`).join('')}</div>
    <div class="c-foot">${flagSVG(p.nat)}${leagueSVG(p.lg === 'LEG' ? 'LEG' : p.lg)}${crestSVG(p.club)}</div>
    ${extra}
  </${tag}>${chem !== null ? chemDiamonds(chem) : ''}`;
}
function shortName(n) { const parts = n.split(' '); return parts.length > 1 ? parts.slice(1).join(' ') : n; }
function chemDiamonds(c) { return `<div class="chemd ${c === 0 ? 'zero' : ''}">${[0, 1, 2].map(i => `<i class="${i < c ? 'on' : ''}"></i>`).join('')}</div>`; }
function emptyCardHTML(pos, mini = true, attrs = '') {
  return `<button class="card empty ${mini ? 'mini' : ''}" data-nav ${attrs}><div class="cbg"></div><div class="ctrim"></div><div class="plus">+</div><div class="epos">${pos}</div></button>`;
}
function ovrClass(p) { if (p.type !== 'base') return 'ovr-x'; const t = tierOf(p.ovr); return t === 'gold' ? 'ovr-g' : t === 'silver' ? 'ovr-s' : 'ovr-b'; }
function playerRowHTML(p, right = '', attrs = '') {
  return `<button class="prow" data-nav ${attrs}><span class="ovr ${ovrClass(p)}">${p.ovr}</span>
    <span style="width:38px;font-weight:900">${p.pos}</span>${flagSVG(p.nat, 22, 15)} ${crestSVG(p.club, 20)}
    <span class="grow" style="font-weight:700">${esc(p.name)} <span class="dim" style="font-size:12px">· ${rarityName(p)}</span></span>${right}</button>`;
}
function statClass(v) { return v >= 80 ? 'hi' : v >= 65 ? 'mid' : 'lo'; }

/* ---------- card inspector (full statistics) ---------- */
function inspectCard(p, { item = null, actions = [] } = {}) {
  const lab = p.pos === 'GK' ? ['Diving', 'Handling', 'Kicking', 'Reflexes', 'Speed', 'Positioning'] : ['Pace', 'Shooting', 'Passing', 'Dribbling', 'Defending', 'Physical'];
  const cl = CLUBS[p.club], lg = LEAGUES[p.lg];
  const body = h(`<div class="row" style="align-items:flex-start;gap:26px">
    <div style="--cs:15px">${cardHTML(p, { nav: false })}</div>
    <div class="col grow" style="min-width:300px">
      <div><div class="h2">${esc(p.name)}</div><div class="dim">${rarityName(p)} · ${p.pos}${p.alt?.length ? ' (' + p.alt.join(', ') + ')' : ''}</div></div>
      <div class="kv">
        <span>Nation</span><span class="row" style="gap:6px">${flagSVG(p.nat)} ${NATIONS[p.nat].name}</span>
        <span>Club</span><span class="row" style="gap:6px">${crestSVG(p.club, 18)} ${cl.name}</span>
        <span>League</span><span class="row" style="gap:6px">${lg ? leagueSVG(p.lg, 18) + ' ' + lg.name : '—'}</span>
        <span>Age / Height</span><span>${p.age} yrs · ${p.height} cm</span>
        <span>Preferred foot</span><span>${p.foot === 'L' ? 'Left' : 'Right'}</span>
        <span>Skill moves / Weak foot</span><span>${'★'.repeat(p.sm)}<span class="dim">${'★'.repeat(5 - p.sm)}</span> · ${'★'.repeat(p.wf)}<span class="dim">${'★'.repeat(5 - p.wf)}</span></span>
        <span>Work rates</span><span>Att ${p.wr[0]} / Def ${p.wr[1]}</span>
        <span>Market value</span><span><i class="coin"></i> ${fmtFull(Market.value(p))}</span>
        ${item ? `<span>Status</span><span>${item.untr ? '<span class="bad">Untradeable</span>' : '<span class="good">Tradeable</span>'}</span>` : ''}
      </div>
      <div class="statlist">${p.stats.map((s, i) => `<div><span>${lab[i]}</span><span class="sv ${statClass(s)}">${s}</span></div>`).join('')}</div>
    </div></div>`);
  return modal({ title: 'Player Details', body, wide: false, buttons: [...actions, { label: 'Close', value: null, cancel: true }] });
}

/* ---------- compare two cards ---------- */
function compareHTML(a, b) {
  const lab = a.pos === 'GK' ? GK_LABELS : STAT_LABELS;
  return `<div class="row" style="gap:24px;align-items:flex-start">
    <div style="--cs:12px">${cardHTML(a, { nav: false })}</div>
    <div class="col" style="min-width:200px;gap:6px">${['OVR', ...lab].map((l, i) => {
      const x = i ? a.stats[i - 1] : a.ovr, y = i ? b.stats[i - 1] : b.ovr, d = x - y;
      return `<div class="row" style="justify-content:space-between;font-weight:800;border-bottom:1px solid var(--line);padding:3px 0"><span>${x}</span><span class="dim" style="font-size:12px">${l}</span><span>${y} <span class="${d > 0 ? 'good' : d < 0 ? 'bad' : 'dim'}" style="font-size:12px">${d > 0 ? '▲' + d : d < 0 ? '▼' + -d : '='}</span></span></div>`;
    }).join('')}</div>
    <div style="--cs:12px">${cardHTML(b, { nav: false })}</div></div>`;
}
function bestOwnedForPos(pos, excludeUid) {
  let best = null;
  for (const it of Save.data.club.items) { if (it.uid === excludeUid) continue; const p = P(it.pid); if (p.pos === pos && (!best || p.ovr > best.ovr)) best = p; }
  return best;
}

/* ---------- player picker modal (from club) ---------- */
function pickPlayer({ title = 'Select Player', pos = null, exclude = new Set(), allowUntr = true, pool = null, filter = null }) {
  return new Promise(resolve => {
    const items = (pool || Save.data.club.items).filter(it => !exclude.has(it.uid) && !Club.inMarket(it.uid) && (allowUntr || !it.untr) && (!filter || filter(it)));
    const body = h(`<div class="col" style="min-height:60vh">
      <div class="filters"><input type="text" placeholder="Search name" class="q" data-nav style="flex:1">
      <select class="fpos" data-nav><option value="">All positions</option>${POSITIONS.map(x => `<option ${x === pos ? 'selected' : ''}>${x}</option>`).join('')}</select>
      <select class="fsort" data-nav><option value="fit">Best fit</option><option value="ovr">Rating</option><option value="new">Newest</option></select></div>
      <div class="list col scroll" style="gap:6px;max-height:58vh"></div></div>`);
    const list = $('.list', body);
    const render = () => {
      const q = $('.q', body).value.toLowerCase(), fp = $('.fpos', body).value, so = $('.fsort', body).value;
      let arr = items.map(it => ({ it, p: P(it.pid) })).filter(x => (!q || x.p.name.toLowerCase().includes(q)) && (!fp || playerFitsPos(x.p, fp)));
      if (so === 'fit' && pos) arr.sort((a, b) => ((b.p.pos === pos) * 20 + playerFitsPos(b.p, pos) * 10 + b.p.ovr) - ((a.p.pos === pos) * 20 + playerFitsPos(a.p, pos) * 10 + a.p.ovr));
      else if (so === 'new') arr.sort((a, b) => b.it.at - a.it.at);
      else arr.sort((a, b) => b.p.ovr - a.p.ovr);
      list.innerHTML = arr.length ? arr.slice(0, 150).map(x => playerRowHTML(x.p, `${x.it.untr ? '<span class="pill bad">UNTR</span>' : ''} ${Club.inActiveSquad(x.it.uid) ? '<span class="pill">IN SQUAD</span>' : ''}`, `data-uid="${x.it.uid}"`)).join('') : '<div class="dim" style="padding:20px">No players match. Open packs or buy from the Transfer Market.</div>';
      $$('.prow', list).forEach(b => b.onclick = () => { Audio2.sfx('select'); close(b.dataset.uid); });
    };
    let close;
    $('.q', body).oninput = render; $('.fpos', body).onchange = render; $('.fsort', body).onchange = render;
    modal({ title, body, wide: true, buttons: [{ label: 'Cancel', value: null, cancel: true }], onOpen: (el, c) => { close = c; render(); } }).then(resolve);
  });
}

/* ---------- pitch view (squad builder & SBC & draft) ---------- */
function pitchHTML(formation, players, { chem = null, captainIdx = -1, selected = -1, showLinks = true, uids = [] } = {}) {
  const F = FORMATIONS[formation];
  const links = chem ? chem.links : formationLinks(formation).map(([a, b]) => ({ a, b, q: 'none' }));
  const col = { green: '#3ddc84', yellow: '#ffd23f', red: '#ff4d5e', none: 'rgba(255,255,255,.25)' };
  const svg = showLinks ? `<svg class="lines" viewBox="0 0 100 100" preserveAspectRatio="none">
    <rect x="3" y="3" width="94" height="94" fill="none" stroke="rgba(255,255,255,.35)" stroke-width=".35"/>
    <line x1="3" y1="50" x2="97" y2="50" stroke="rgba(255,255,255,.3)" stroke-width=".3"/>
    <ellipse cx="50" cy="50" rx="11" ry="9" fill="none" stroke="rgba(255,255,255,.3)" stroke-width=".3"/>
    <rect x="25" y="3" width="50" height="14" fill="none" stroke="rgba(255,255,255,.3)" stroke-width=".3"/><rect x="25" y="83" width="50" height="14" fill="none" stroke="rgba(255,255,255,.3)" stroke-width=".3"/>
    ${links.map(l => { const A = F[l.a], B = F[l.b]; return `<line x1="${A[1]}" y1="${A[2]}" x2="${B[1]}" y2="${B[2]}" stroke="${col[l.q]}" stroke-width="${l.q === 'none' ? .35 : .7}" stroke-linecap="round" opacity=".9"/>`; }).join('')}
  </svg>` : '';
  return `<div class="pitch">${svg}${F.map((f, i) => {
    const p = players[i];
    const oop = p && !playerFitsPos(p, f[0]);
    return `<div class="slot ${selected === i ? 'sel' : ''}" data-slot="${i}" style="left:${f[1]}%;top:${f[2]}%">
      ${i === captainIdx && p ? '<div class="cap">C</div>' : ''}
      ${p ? cardHTML(p, { mini: true, uid: uids[i] || '', chem: chem ? chem.per[i] : null, extra: '' }) : emptyCardHTML(f[0], true, `data-uid=""`)}
      ${oop ? `<div class="oop">${f[0]}</div>` : ''}
    </div>`;
  }).join('')}</div>`;
}

/* ---------- kit & badge graphics (customization) ---------- */
function kitSVG(k, size = 70) {
  const pat = k.pattern === 'stripes' ? `<g clip-path="url(#kc)">${[0, 1, 2, 3, 4].map(i => `<rect x="${12 + i * 12}" y="0" width="6" height="80" fill="${k.c2}"/>`).join('')}</g>` :
    k.pattern === 'hoops' ? `<g clip-path="url(#kc)">${[0, 1, 2, 3].map(i => `<rect x="0" y="${20 + i * 14}" width="80" height="7" fill="${k.c2}"/>`).join('')}</g>` :
      k.pattern === 'sash' ? `<g clip-path="url(#kc)"><polygon points="10,10 26,10 70,76 54,76" fill="${k.c2}"/></g>` :
        k.pattern === 'half' ? `<g clip-path="url(#kc)"><rect x="40" y="0" width="40" height="80" fill="${k.c2}"/></g>` : '';
  const body = 'M22 8 L32 4 Q40 10 48 4 L58 8 L76 22 L68 34 L60 28 L60 76 L20 76 L20 28 L12 34 L4 22 Z';
  return `<svg viewBox="0 0 80 80" width="${size}" height="${size}" class="kit-prev"><defs><clipPath id="kc"><path d="${body}"/></clipPath></defs><path d="${body}" fill="${k.c1}"/>${pat}<path d="M32 4 Q40 10 48 4" stroke="${k.c2}" stroke-width="3" fill="none"/><path d="${body}" fill="none" stroke="rgba(0,0,0,.35)" stroke-width="1.2"/></svg>`;
}
function badgeSVG(b, size = 48, text = '') {
  const shapes = {
    shield: 'M40 4 L72 14 L72 40 C72 60 56 72 40 76 C24 72 8 60 8 40 L8 14 Z',
    round: 'M40 4 A36 36 0 1 1 39.9 4 Z',
    hex: 'M40 4 L72 22 L72 58 L40 76 L8 58 L8 22 Z',
    crest: 'M12 6 H68 V44 C68 62 54 72 40 76 C26 72 12 62 12 44 Z'
  };
  const icons = {
    star: '<polygon points="40,22 45,35 59,35 48,44 52,58 40,50 28,58 32,44 21,35 35,35" />',
    ball: '<circle cx="40" cy="40" r="14"/><polygon points="40,32 47,37 44,45 36,45 33,37" fill-opacity=".0" stroke-width="2"/>',
    crown: '<path d="M24 50 L26 30 L34 40 L40 26 L46 40 L54 30 L56 50 Z"/>',
    bolt: '<polygon points="44,20 28,44 39,44 34,62 52,36 41,36"/>',
    bird: '<path d="M22 46 Q34 28 40 40 Q46 28 58 46 Q46 38 40 50 Q34 38 22 46Z"/>',
    flame: '<path d="M40 22 Q52 36 48 48 Q46 58 40 60 Q32 58 30 48 Q30 40 38 36 Q36 44 41 46 Q46 38 40 22Z"/>'
  };
  return `<svg viewBox="0 0 80 80" width="${size}" height="${size}"><path d="${shapes[b.shape] || shapes.shield}" fill="${b.c2}" stroke="${b.c1}" stroke-width="4"/><g fill="${b.c1}" stroke="${b.c1}">${icons[b.icon] || icons.star}</g>${text ? `<text x="40" y="70" font-size="9" text-anchor="middle" fill="${b.c1}" font-weight="900" font-family="Arial">${esc(text)}</text>` : ''}</svg>`;
}

/* ---------- pack art ---------- */
function packArtHTML(id) {
  const pk = PACKS[id];
  const words = pk.name.replace(' Pack', '').toUpperCase();
  return `<div class="packart pa-${pk.art}"><div class="pk">${words}<small>PF27 · ${pk.items} ITEMS</small></div></div>`;
}
