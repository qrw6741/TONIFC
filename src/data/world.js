/* ============================================================
   DATA / WORLD — nations, fictional leagues & clubs
   All club and league names are original/fictional.
   ============================================================ */
const NATIONS = Object.fromEntries(Object.entries(REAL_NATIONS).map(([k, v]) => [k, { name: v[0], flag: { t: v[1], c: v.slice(2) } }]));
const LEAGUES = REAL_LEAGUES;
const CLUBS = Object.fromEntries(REAL.order.map(k => [k, { name: REAL.clubs[k].name, lg: REAL.clubs[k].lg, c: REAL.clubs[k].c }]));
CLUBS.ICN = { name: 'Icons', lg: 'LEG', c: ['#e8d6a0', '#2b2416'], special: true };
CLUBS.HER = { name: 'Heroes', lg: null, c: ['#6b2ea6', '#ffd23f'], special: true };

const POSITIONS = ['GK', 'CB', 'LB', 'RB', 'LWB', 'RWB', 'CDM', 'CM', 'CAM', 'LM', 'RM', 'LW', 'RW', 'CF', 'ST'];
const ALT_POS = {
  GK: [], CB: ['CDM'], LB: ['LWB', 'LM'], RB: ['RWB', 'RM'], LWB: ['LB', 'LM'], RWB: ['RB', 'RM'],
  CDM: ['CM', 'CB'], CM: ['CDM', 'CAM'], CAM: ['CM', 'CF'], LM: ['LW', 'LB'], RM: ['RW', 'RB'],
  LW: ['LM', 'ST'], RW: ['RM', 'ST'], CF: ['ST', 'CAM'], ST: ['CF']
};
const POS_GROUP = { GK: 'GK', CB: 'DEF', LB: 'DEF', RB: 'DEF', LWB: 'DEF', RWB: 'DEF', CDM: 'MID', CM: 'MID', CAM: 'MID', LM: 'MID', RM: 'MID', LW: 'ATT', RW: 'ATT', CF: 'ATT', ST: 'ATT' };

/* ---------- flag rendering (SVG, original vector simplifications) ---------- */
function flagSVG(code, w = 24, h = 16) {
  const n = NATIONS[code];
  const W = 30, H = 20;
  const f = n ? n.flag : { t: 'solid', c: ['#888'] }, c = f.c;
  const stripes = (cols, vertical, weights) => { const ws = weights || cols.map(() => 1), tot = ws.reduce((a, b) => a + b, 0); let o = 0; return cols.map((col, i) => { const sz = (vertical ? W : H) * ws[i] / tot; const r = vertical ? `<rect x="${o}" y="0" width="${sz + 0.2}" height="${H}" fill="${col}"/>` : `<rect x="0" y="${o}" width="${W}" height="${sz + 0.2}" fill="${col}"/>`; o += sz; return r; }).join(''); };
  let inner = '';
  switch (f.t) {
    case 'v3': case 'v2': inner = stripes(c, true); break;
    case 'v3c': inner = stripes(c, true, [1, 2, 1]) + '<polygon points="15,6 17,11 15,15 13,11" fill="#ff0000"/>'; break;
    case 'v2p': inner = stripes(c, true, [2, 3]); break;
    case 'h2': case 'h3': case 'h5': inner = stripes(c, false); break;
    case 'h3w': inner = stripes(c, false, code === 'ESP' ? [1, 2, 1] : [2, 1, 1]); break;
    case 'cross': inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><rect x="13" y="0" width="4" height="${H}" fill="${c[1]}"/><rect x="0" y="8" width="${W}" height="4" fill="${c[1]}"/>`; break;
    case 'swiss': inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><rect x="13" y="4" width="4" height="12" fill="${c[1]}"/><rect x="9" y="8" width="12" height="4" fill="${c[1]}"/>`; break;
    case 'saltire': inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><path d="M0 0 L30 20 M30 0 L0 20" stroke="${c[1]}" stroke-width="4"/>`; break;
    case 'nordic': inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><rect x="8" y="0" width="6" height="${H}" fill="${c[1]}"/><rect x="0" y="7" width="${W}" height="6" fill="${c[1]}"/><rect x="9.5" y="0" width="3" height="${H}" fill="${c[2]}"/><rect x="0" y="8.5" width="${W}" height="3" fill="${c[2]}"/>`; break;
    case 'diamond': inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><polygon points="15,2 28,10 15,18 2,10" fill="${c[1]}"/><circle cx="15" cy="10" r="4.5" fill="${c[2]}"/>`; break;
    case 'circle': inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><circle cx="15" cy="10" r="6" fill="${c[1]}"/>`; break;
    case 'crescent': inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><circle cx="12" cy="10" r="5.5" fill="${c[1]}"/><circle cx="13.6" cy="10" r="4.4" fill="${c[0]}"/><circle cx="19" cy="10" r="1.6" fill="${c[1]}"/>`; break;
    case 'star': inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/><polygon points="15,4 16.8,9.2 22,9.2 17.8,12.4 19.4,17.5 15,14.3 10.6,17.5 12.2,12.4 8,9.2 13.2,9.2" fill="none" stroke="${c[1]}" stroke-width="1.2"/>`; break;
    case 'czech': inner = stripes([c[0], c[1]], false) + `<polygon points="0,0 14,10 0,20" fill="${c[2]}"/>`; break;
    case 'usa': inner = stripes([c[0], c[1], c[0], c[1], c[0], c[1], c[0]], false) + `<rect width="13" height="11" fill="${c[2]}"/>`; break;
    case 'uae': inner = `<rect width="${W}" height="${H}" fill="${c[1]}"/><rect width="${W}" height="6.67" fill="${c[0]}"/><rect y="13.33" width="${W}" height="6.67" fill="${c[2]}"/><rect width="8" height="${H}" fill="${c[3]}"/>`; break;
    default: inner = `<rect width="${W}" height="${H}" fill="${c[0]}"/>`;
  }
  return `<svg class="flag" viewBox="0 0 ${W} ${H}" width="${w}" height="${h}" preserveAspectRatio="none">${inner}</svg>`;
}

/* ---------- club crest (original procedural badges) ---------- */
function crestSVG(clubCode, size = 22) {
  const cl = CLUBS[clubCode]; if (!cl) return '';
  const [a, b] = cl.c;
  const hsh = hashStr(clubCode);
  const style = hsh % 4;
  const skip = ['FC', 'CD', 'AC', 'AS', 'SV', 'US', 'UD', 'CF', 'SC', 'SL', 'RC', 'TSV', 'AFC', 'SSC', 'RCD', 'CA', 'OGC', 'AJ', 'VfB', 'VfL', 'TSG', 'SS', 'RB', 'LOSC', 'Real', 'Club', 'Stade', 'Olympique', 'Borussia', 'Bayer', 'Eintracht', 'Deportivo', 'Sporting', '1.', 'FSV', '04', '05', '29', '1907', 'de', 'United', 'City'];
  const words = cl.name.split(' ').filter(w => !skip.includes(w) && w.length > 1);
  const init = (words[0] || cl.name)[0].toUpperCase();
  if (clubCode === 'ICN') return `<svg viewBox="0 0 40 40" width="${size}" height="${size}"><circle cx="20" cy="20" r="18" fill="#2b2416" stroke="#e8d6a0" stroke-width="2.5"/><text x="20" y="25.5" text-anchor="middle" font-size="14" font-weight="900" fill="#e8d6a0" font-family="Arial Black,Arial">I</text></svg>`;
  if (clubCode === 'HER') return `<svg viewBox="0 0 40 40" width="${size}" height="${size}"><polygon points="20,2 37,12 37,28 20,38 3,28 3,12" fill="#3a1666" stroke="#ffd23f" stroke-width="2.5"/><text x="20" y="25.5" text-anchor="middle" font-size="14" font-weight="900" fill="#ffd23f" font-family="Arial Black,Arial">H</text></svg>`;
  let shape;
  if (style === 0) shape = `<path d="M20 2 L36 7 L36 20 C36 30 28 36 20 38 C12 36 4 30 4 20 L4 7 Z" fill="${a}" stroke="${b}" stroke-width="2.5"/><path d="M20 2 L20 38" stroke="${b}" stroke-width="5" opacity=".55"/>`;
  else if (style === 1) shape = `<circle cx="20" cy="20" r="17" fill="${a}" stroke="${b}" stroke-width="3"/><circle cx="20" cy="20" r="11" fill="none" stroke="${b}" stroke-width="1.5" opacity=".6"/>`;
  else if (style === 2) shape = `<path d="M6 4 H34 V22 C34 31 27 36 20 38 C13 36 6 31 6 22 Z" fill="${b}" stroke="${a}" stroke-width="2.5"/><path d="M6 4 H34 V14 H6 Z" fill="${a}"/>`;
  else shape = `<polygon points="20,2 36,10 36,30 20,38 4,30 4,10" fill="${a}" stroke="${b}" stroke-width="2.5"/><polygon points="20,8 30,13 30,27 20,32 10,27 10,13" fill="none" stroke="${b}" stroke-width="1.2" opacity=".7"/>`;
  const txt = style === 2 ? a : b;
  return `<svg viewBox="0 0 40 40" width="${size}" height="${size}">${shape}<text x="20" y="${style === 2 ? 30 : 26}" text-anchor="middle" font-size="13" font-weight="900" fill="${txt}" font-family="Arial Black,Arial" stroke="${style === 2 ? b : a}" stroke-width=".4">${esc(init)}</text></svg>`;
}

function leagueSVG(lg, size = 20) {
  const L = LEAGUES[lg]; if (!L) return '';
  return `<svg viewBox="0 0 40 40" width="${size}" height="${size}"><rect x="3" y="3" width="34" height="34" rx="9" fill="${L.color}"/><text x="20" y="25" text-anchor="middle" font-size="11" font-weight="900" fill="#fff" font-family="Arial Black,Arial">${L.short}</text></svg>`;
}
