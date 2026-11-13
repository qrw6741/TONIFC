/* ============================================================
   DATA / PLAYERS — deterministic fictional player database
   Every card: name, face, nation, club, league, pos, ovr, 6 stats,
   foot, height, skill moves, weak foot, work rates, rarity/type.
   ============================================================ */
const PROFILE = { // stat offsets from overall: pac sho pas dri def phy
  ST: [4, 6, -6, 2, -40, 2], CF: [3, 4, 0, 5, -42, -4], LW: [8, 0, -2, 6, -45, -10], RW: [8, 0, -2, 6, -45, -10],
  CAM: [0, 0, 4, 6, -40, -10], LM: [6, -4, 0, 3, -25, -6], RM: [6, -4, 0, 3, -25, -6],
  CM: [-4, -4, 5, 2, -12, 0], CDM: [-6, -14, 0, -4, 4, 6],
  LB: [4, -30, -4, -2, 0, -2], RB: [4, -30, -4, -2, 0, -2], LWB: [6, -28, -2, 0, -4, -2], RWB: [6, -28, -2, 0, -4, -2],
  CB: [-8, -38, -14, -16, 6, 8], GK: [3, 2, -6, 3, -10, -25] // GK: div han kic ref spd pos
};
const STAT_KEYS = ['pac', 'sho', 'pas', 'dri', 'def', 'phy'];
const STAT_LABELS = ['PAC', 'SHO', 'PAS', 'DRI', 'DEF', 'PHY'];
const GK_LABELS = ['DIV', 'HAN', 'KIC', 'REF', 'SPD', 'POS'];

const CARD_TYPES = {
  base: { name: 'Base', order: 0 },
  totw: { name: 'Team of the Week', order: 3, color: '#111' },
  promo: { name: 'Nightfall', order: 4 },
  found: { name: 'Foundations', order: 2 },
  hero: { name: 'Hero', order: 5 },
  icon: { name: 'Icon', order: 6 }
};

const DB = { players: [], byId: {}, byClub: {}, ready: false };

function tierOf(ovr) { return ovr >= 76 ? 'gold' : ovr >= 71 ? 'silver' : 'bronze'; }
function rarityKey(p) { // visual design key
  if (p.type !== 'base') return p.type;
  return tierOf(p.ovr) + (p.rare ? '-rare' : '');
}
function rarityName(p) {
  if (p.type !== 'base') return CARD_TYPES[p.type].name;
  const t = tierOf(p.ovr); return (p.rare ? 'Rare ' : '') + t[0].toUpperCase() + t.slice(1);
}

function buildDatabase() {
  if (DB.ready) return;
  const rng = mulberry32(270027);
  const ri = (a, b) => Math.floor(a + rng() * (b - a + 1));
  const pk = arr => arr[Math.floor(rng() * arr.length)];
  const gauss = () => (rng() + rng() + rng() - 1.5) / 1.5;
  const usedNames = new Set();
  const natCodes = Object.keys(NATIONS);
  const genName = (nat) => {
    const N = NATIONS[nat];
    for (let i = 0; i < 30; i++) {
      const nm = `${pk(N.first)} ${pk(N.last)}`;
      if (!usedNames.has(nm)) { usedNames.add(nm); return nm; }
    }
    return `${pk(N.first)} ${pk(N.last)} ${ri(2, 9)}`;
  };
  const genStats = (pos, ovr) => {
    const prof = PROFILE[pos];
    return prof.map(o => clamp(Math.round(ovr + o + gauss() * 5), 18, 99));
  };
  const genFace = () => ({
    skin: ri(0, 7), hair: ri(0, 9), hairC: ri(0, 6), beard: rng() < 0.38 ? ri(1, 3) : 0, brow: ri(0, 2), seed: ri(0, 9999)
  });
  const make = (o) => {
    const p = Object.assign({
      foot: rng() < 0.74 ? 'R' : 'L', height: 0, sm: 2, wf: 3, wr: ['M', 'M'], rare: false, type: 'base', alt: []
    }, o);
    if (!p.height) p.height = p.pos === 'GK' ? ri(185, 199) : p.pos === 'CB' ? ri(181, 196) : ri(166, 191);
    if (['LB', 'LWB', 'LM', 'LW'].includes(p.pos) && rng() < 0.55) p.foot = 'L';
    const dri = p.stats[3];
    p.sm = p.pos === 'GK' ? 1 : clamp(Math.round((dri - 55) / 9 + rng() * 1.2), 1, 5);
    p.wf = clamp(ri(2, 4) + (rng() < 0.12 ? 1 : 0), 1, 5);
    const wl = ['L', 'M', 'H'];
    const g = POS_GROUP[p.pos];
    p.wr = [g === 'ATT' ? wl[ri(1, 2)] : g === 'DEF' ? wl[ri(0, 1)] : wl[ri(0, 2)], g === 'DEF' ? wl[ri(1, 2)] : g === 'ATT' ? wl[ri(0, 1)] : wl[ri(0, 2)]];
    p.alt = ALT_POS[p.pos].filter(() => rng() < 0.6).slice(0, 2);
    DB.players.push(p); DB.byId[p.id] = p;
    (DB.byClub[p.club] = DB.byClub[p.club] || []).push(p);
    return p;
  };

  // ---- real squads (top 5 leagues 2025/26); duplicates across clubs keep the first entry
  let n = 0;
  const seenNames = new Set();
  for (const code of REAL.order) {
    const cl = REAL.clubs[code];
    cl.roster.split('|').forEach(entry => {
      const [name, pos, nat, ovrS] = entry.split(';');
      if (!name || seenNames.has(name)) return;
      seenNames.add(name);
      const ovr = +ovrS;
      make({
        id: 'p' + (n++), name, nat: NATIONS[nat] ? nat : 'ENG', club: code, lg: cl.lg, pos, ovr, stats: genStats(pos, ovr),
        rare: rng() < (ovr >= 82 ? 0.85 : ovr >= 75 ? 0.5 : 0.3), face: genFace(), type: 'base', age: ri(18, 34)
      });
    });
  }
  const base = DB.players.slice();

  // ---- Team of the Week (in-forms of existing players)
  const pickSpecial = (count, minOvr, boost, type, prefix) => {
    const pool = base.filter(p => p.ovr >= minOvr && !p._special).sort(() => rng() - 0.5).slice(0, count);
    pool.forEach((src, i) => {
      src._special = true;
      const b = ri(boost[0], boost[1]);
      make({
        id: prefix + i, base: src.id, name: src.name, nat: src.nat, club: src.club, lg: src.lg, pos: src.pos, ovr: clamp(src.ovr + b, 1, 99),
        stats: src.stats.map(s => clamp(s + b + ri(0, 2), 1, 99)), rare: true, face: src.face, type, age: src.age, foot: src.foot, height: src.height
      });
    });
  };
  pickSpecial(24, 72, [3, 5], 'totw', 't');
  pickSpecial(18, 74, [6, 9], 'promo', 'n');
  pickSpecial(14, 64, [5, 8], 'found', 'f');

  // ---- Icons & Heroes (retired legends)
  REAL_ICONS.split('|').forEach((e, i) => {
    const [name, pos, nat, o] = e.split(';'); const ovr = +o;
    make({ id: 'i' + i, name, nat, club: 'ICN', lg: 'LEG', pos, ovr, stats: genStats(pos, ovr).map(s => clamp(s + 2, 1, 99)), rare: true, face: genFace(), type: 'icon', age: ri(40, 60) });
  });
  REAL_HEROES.split('|').forEach((e, i) => {
    const [name, pos, nat, o, lg] = e.split(';'); const ovr = +o;
    make({ id: 'h' + i, name, nat, club: 'HER', lg, pos, ovr, stats: genStats(pos, ovr).map(s => clamp(s + 1, 1, 99)), rare: true, face: genFace(), type: 'hero', age: ri(38, 50) });
  });
  DB.ready = true;
}

function P(id) { return DB.byId[id]; }

/* Market value estimate (coins) — exponential in rating, scaled by type/position */
function baseValue(p) {
  let v;
  if (p.ovr < 71) v = 150 + (p.ovr - 58) * 15;
  else if (p.ovr < 76) v = 350 + (p.ovr - 71) * 60 + (p.rare ? 150 : 0);
  else v = Math.round(750 * Math.pow(1.38, p.ovr - 76)) + (p.rare ? 400 : 0);
  const mult = { base: 1, totw: 2.2, found: 1.6, promo: 3, hero: 3.5, icon: 4.5 }[p.type] || 1;
  const posM = { ST: 1.2, LW: 1.15, RW: 1.15, CAM: 1.1, CB: 1.05, GK: 0.8, CF: 1.1 }[p.pos] || 1;
  return Math.max(150, Math.round(v * mult * posM / 50) * 50);
}
function quickSellValue(p) { return Math.max(50, Math.round(baseValue(p) * 0.08 / 10) * 10); }

/* ---------- procedural portrait (original SVG illustration) ---------- */
const SKINS = ['#f6d3b3', '#ecc09a', '#d9a277', '#c48a5c', '#a86f45', '#8a5634', '#6b3f24', '#4e2c18'];
const HAIRC = ['#141010', '#2d1d12', '#5a3a1e', '#8a5a2b', '#c99a4b', '#d9c38a', '#6b6b6b'];
function portraitSVG(p, kitA, kitB) {
  const f = p.face || { skin: 2, hair: 0, hairC: 0, beard: 0, brow: 0, seed: 1 };
  const skin = SKINS[f.skin], hair = HAIRC[f.hairC];
  const shade = 'rgba(0,0,0,.18)';
  const cl = CLUBS[p.club] || { c: ['#333', '#ddd'] };
  const A = kitA || cl.c[0], B = kitB || cl.c[1];
  let hairSvg = '';
  switch (f.hair) {
    case 0: hairSvg = `<path d="M30 40 Q30 16 50 15 Q70 16 70 40 Q66 28 50 27 Q34 28 30 40Z" fill="${hair}"/>`; break; // short
    case 1: hairSvg = `<path d="M29 42 Q27 12 50 12 Q73 12 71 42 Q70 24 60 22 Q50 30 38 23 Q31 28 29 42Z" fill="${hair}"/>`; break; // textured
    case 2: hairSvg = `<path d="M31 36 Q32 20 50 19 Q68 20 69 36 Q60 30 50 30 Q40 30 31 36Z" fill="${hair}" opacity=".85"/>`; break; // buzz
    case 3: hairSvg = `<path d="M28 46 Q22 10 50 10 Q78 10 72 46 L70 34 Q64 22 50 22 Q36 22 30 34Z" fill="${hair}"/><path d="M28 46 Q26 58 30 64 L32 46Z" fill="${hair}"/><path d="M72 46 Q74 58 70 64 L68 46Z" fill="${hair}"/>`; break; // long
    case 4: hairSvg = `<circle cx="50" cy="24" r="17" fill="${hair}"/><circle cx="36" cy="30" r="9" fill="${hair}"/><circle cx="64" cy="30" r="9" fill="${hair}"/>`; break; // afro
    case 5: hairSvg = `<path d="M33 34 Q34 20 50 19 Q66 20 67 34Z" fill="${skin}"/><path d="M33 33 Q50 24 67 33" stroke="${shade}" stroke-width="1.2" fill="none"/>`; break; // bald
    case 6: hairSvg = `<path d="M30 40 Q30 14 52 14 Q74 16 70 34 Q62 22 46 26 Q36 30 30 40Z" fill="${hair}"/><path d="M52 14 Q66 6 74 18 Q66 16 60 20Z" fill="${hair}"/>`; break; // quiff
    case 7: hairSvg = `<path d="M30 40 Q30 16 50 15 Q70 16 70 40 Q66 28 50 27 Q34 28 30 40Z" fill="${hair}"/>${[36, 42, 48, 54, 60].map(x => `<path d="M${x} 18 L${x + 2} 30" stroke="${shade}" stroke-width="1.5"/>`).join('')}`; break; // cornrows
    case 8: hairSvg = `<path d="M31 38 Q31 18 50 17 Q69 18 69 38 Q62 30 50 30 Q38 30 31 38Z" fill="${hair}"/><rect x="44" y="10" width="12" height="16" rx="6" fill="${hair}"/>`; break; // mohawk-ish
    default: hairSvg = `<path d="M29 44 Q26 14 50 13 Q74 14 71 44 Q68 26 56 24 L50 30 L44 24 Q32 26 29 44Z" fill="${hair}"/>`; // parted
  }
  const beard = f.beard === 1 ? `<path d="M36 52 Q38 68 50 70 Q62 68 64 52 Q60 62 50 63 Q40 62 36 52Z" fill="${hair}" opacity=".55"/>` :
    f.beard === 2 ? `<path d="M35 48 Q36 72 50 74 Q64 72 65 48 Q62 64 50 65 Q38 64 35 48Z" fill="${hair}" opacity=".9"/>` :
      f.beard === 3 ? `<path d="M43 60 Q50 57 57 60 Q55 63 50 62 Q45 63 43 60Z" fill="${hair}"/><path d="M46 66 Q50 70 54 66 L54 70 Q50 73 46 70Z" fill="${hair}"/>` : '';
  const browY = 40 + f.brow;
  return `<svg class="portrait" viewBox="0 0 100 100" preserveAspectRatio="xMidYMax meet">
    <defs><linearGradient id="sh${p.id}" x1="0" x2="1"><stop offset="0" stop-color="#000" stop-opacity=".0"/><stop offset="1" stop-color="#000" stop-opacity=".22"/></linearGradient></defs>
    <path d="M8 100 Q10 76 32 72 L42 68 L58 68 L68 72 Q90 76 92 100Z" fill="${A}"/>
    <path d="M42 68 L50 80 L58 68" fill="${B}"/><path d="M8 100 Q10 76 32 72 L36 100Z" fill="${B}" opacity=".35"/><path d="M92 100 Q90 76 68 72 L64 100Z" fill="${B}" opacity=".35"/>
    <rect x="43" y="58" width="14" height="14" rx="4" fill="${skin}"/><rect x="43" y="62" width="14" height="6" fill="${shade}"/>
    <ellipse cx="50" cy="43" rx="18" ry="22" fill="${skin}"/>
    <ellipse cx="32.5" cy="45" rx="3.2" ry="5" fill="${skin}"/><ellipse cx="67.5" cy="45" rx="3.2" ry="5" fill="${skin}"/>
    <ellipse cx="50" cy="43" rx="18" ry="22" fill="url(#sh${p.id})"/>
    <path d="M40 ${browY} Q44 ${browY - 2} 47 ${browY}" stroke="${hair}" stroke-width="2.2" fill="none" stroke-linecap="round"/><path d="M53 ${browY} Q56 ${browY - 2} 60 ${browY}" stroke="${hair}" stroke-width="2.2" fill="none" stroke-linecap="round"/>
    <ellipse cx="43.5" cy="45" rx="2.3" ry="1.6" fill="#1a1a1a"/><ellipse cx="56.5" cy="45" rx="2.3" ry="1.6" fill="#1a1a1a"/>
    <path d="M50 46 Q48 53 49 54 L52 54" stroke="${shade}" stroke-width="1.4" fill="none"/>
    <path d="M45 59 Q50 61.5 55 59" stroke="#7a3d33" stroke-width="1.6" fill="none" stroke-linecap="round"/>
    ${beard}${hairSvg}
  </svg>`;
}
